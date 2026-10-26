import { NextResponse, type NextRequest } from "next/server";
import { pdf } from "@react-pdf/renderer";
import { createClient } from "@/lib/supabase/server";
import { getPropertyDetail } from "@/lib/queries";
import { getSignedUrls, getSignedUrl, reportStoragePath } from "@/lib/storage";
import { getStateLaw } from "@/lib/state-deposit-laws";
import { formatCents, formatDate } from "@/lib/format";
import { ConditionReportDocument } from "@/lib/pdf/condition-report";
import { EvidencePacketDocument } from "@/lib/pdf/evidence-packet";
import { buildDemandLetter, buildSmallClaimsChecklist } from "@/lib/demand-letter";
import { streamToBuffer } from "@/lib/pdf/render";
import type { ReportRoom } from "@/lib/pdf/types";
import type { Phase, ReportKind } from "@/lib/types";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  const { propertyId, kind } = (await request.json()) as {
    propertyId?: string;
    kind?: ReportKind;
  };

  if (!propertyId || !kind) {
    return NextResponse.json({ error: "Missing propertyId or kind" }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Not signed in" }, { status: 401 });
  }

  const detail = await getPropertyDetail(supabase, propertyId);
  if (!detail || detail.property.user_id !== user.id) {
    return NextResponse.json({ error: "Property not found" }, { status: 404 });
  }

  const { property, rooms } = detail;
  const law = getStateLaw(property.state);
  const watermark = kind !== "evidence_packet" && !property.is_paid;

  if (kind === "evidence_packet" && !property.is_paid) {
    return NextResponse.json({ error: "Evidence packets require Shield." }, { status: 402 });
  }

  const propertyInfo = {
    displayName: property.nickname || property.address_line1 || "Untitled property",
    addressLines: [
      [property.address_line1, property.address_line2].filter(Boolean).join(", "),
      [property.city, property.state, property.zip].filter(Boolean).join(", "),
    ].filter((l) => l.length > 0),
    tenantEmail: user.email || "Tenant",
    depositAmountLabel: formatCents(property.deposit_amount_cents),
    dateLabel: formatDate(new Date().toISOString()),
    stateName: law?.name,
    stateDeadlineDays: law?.returnDeadlineDays,
  };

  async function roomsToReportRooms(phase: Phase): Promise<ReportRoom[]> {
    const allPaths = rooms.flatMap((r) =>
      (phase === "move_in" ? r.moveInPhotos : r.moveOutPhotos).map((p) => p.storage_path)
    );
    const signed = await getSignedUrls(supabase, "photos", allPaths);
    return rooms.map((r) => ({
      name: r.name,
      photos: (phase === "move_in" ? r.moveInPhotos : r.moveOutPhotos).map((p) => ({
        url: signed[p.storage_path] ?? "",
        capturedAt: p.captured_at,
        condition: p.condition,
        note: p.note,
        sha256: p.sha256,
      })),
    }));
  }

  let buffer: Buffer;

  if (kind === "evidence_packet") {
    const [moveInRooms, moveOutRooms] = await Promise.all([
      roomsToReportRooms("move_in"),
      roomsToReportRooms("move_out"),
    ]);
    let deadlineDateLabel: string | null = null;
    if (property.move_out_completed_at && law) {
      const d = new Date(property.move_out_completed_at);
      d.setDate(d.getDate() + law.returnDeadlineDays);
      deadlineDateLabel = formatDate(d.toISOString());
    }
    const letterLines = buildDemandLetter(property, law, user.email || "tenant@example.com");
    const checklistItems = buildSmallClaimsChecklist(law);

    const doc = (
      <EvidencePacketDocument
        property={propertyInfo}
        moveInRooms={moveInRooms}
        moveOutRooms={moveOutRooms}
        stateName={law?.name ?? "your state"}
        deadlineDays={law?.returnDeadlineDays ?? 30}
        itemizedRequired={law?.itemizedStatementRequired ?? true}
        smallClaimsLimit={law?.smallClaimsLimit ?? "varies by state"}
        deadlineDateLabel={deadlineDateLabel}
        letterLines={letterLines}
        checklistItems={checklistItems}
      />
    );
    buffer = await streamToBuffer(await pdf(doc).toBuffer());
  } else {
    const reportRooms = await roomsToReportRooms(kind);
    const doc = (
      <ConditionReportDocument
        title={kind === "move_in" ? "Move-in condition report" : "Move-out condition report"}
        phaseLabel={kind === "move_in" ? "Move-in" : "Move-out"}
        property={propertyInfo}
        rooms={reportRooms}
        watermark={watermark}
      />
    );
    buffer = await streamToBuffer(await pdf(doc).toBuffer());
  }

  const storagePath = reportStoragePath(user.id, propertyId, kind);
  const { error: uploadError } = await supabase.storage
    .from("reports")
    .upload(storagePath, buffer, { contentType: "application/pdf", upsert: true });
  if (uploadError) {
    return NextResponse.json({ error: uploadError.message }, { status: 500 });
  }

  const { data: reportRow, error: insertError } = await supabase
    .from("reports")
    .insert({ property_id: propertyId, user_id: user.id, kind, storage_path: storagePath })
    .select("id")
    .single();
  if (insertError) {
    return NextResponse.json({ error: insertError.message }, { status: 500 });
  }

  const url = await getSignedUrl(supabase, "reports", storagePath);

  return NextResponse.json({ reportId: reportRow.id, url, watermarked: watermark });
}
