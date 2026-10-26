import { NextResponse, type NextRequest } from "next/server";
import { Resend } from "resend";
import { createClient } from "@/lib/supabase/server";
import { env, isResendConfigured } from "@/lib/env";

export async function POST(request: NextRequest) {
  const { reportId } = (await request.json()) as { reportId?: string };
  if (!reportId) {
    return NextResponse.json({ error: "Missing reportId" }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Not signed in" }, { status: 401 });
  }

  const { data: report } = await supabase
    .from("reports")
    .select("id, storage_path, property_id, kind")
    .eq("id", reportId)
    .eq("user_id", user.id)
    .maybeSingle();

  if (!report || !report.storage_path) {
    return NextResponse.json({ error: "Report not found" }, { status: 404 });
  }

  const { data: property } = await supabase
    .from("properties")
    .select("landlord_email, landlord_name, nickname, address_line1, is_paid")
    .eq("id", report.property_id)
    .maybeSingle();

  if (!property?.is_paid) {
    return NextResponse.json({ error: "Sending requires Shield on this property." }, { status: 402 });
  }

  if (!property.landlord_email) {
    return NextResponse.json({ error: "Add a landlord email on this property first." }, { status: 400 });
  }

  const { data: signed } = await supabase.storage
    .from("reports")
    .createSignedUrl(report.storage_path, 60 * 60);

  if (!signed?.signedUrl) {
    return NextResponse.json({ error: "Could not generate a download link." }, { status: 500 });
  }

  const propertyName = property.nickname || property.address_line1 || "the property";
  const subject = `Condition report — ${propertyName}`;
  const body = `Hi ${property.landlord_name || ""},\n\nAttached is the ${report.kind.replace("_", " ")} condition report for ${propertyName}, generated with Deposit Shield.\n\nDownload: ${signed.signedUrl}\n\nThanks,\n${user.email}`;

  if (!isResendConfigured) {
    return NextResponse.json({
      sent: false,
      mailto: `mailto:${property.landlord_email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`,
      downloadUrl: signed.signedUrl,
    });
  }

  const resend = new Resend(env.resendApiKey);
  const pdfRes = await fetch(signed.signedUrl);
  const pdfBuffer = Buffer.from(await pdfRes.arrayBuffer());

  const { error: sendError } = await resend.emails.send({
    from: "Deposit Shield <reports@resend.dev>",
    to: property.landlord_email,
    subject,
    text: body,
    attachments: [
      {
        filename: `${report.kind}-condition-report.pdf`,
        content: pdfBuffer,
      },
    ],
  });

  if (sendError) {
    return NextResponse.json({ error: sendError.message }, { status: 500 });
  }

  await supabase
    .from("reports")
    .update({ sent_to: property.landlord_email, sent_at: new Date().toISOString() })
    .eq("id", reportId);

  return NextResponse.json({ sent: true });
}
