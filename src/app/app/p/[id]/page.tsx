import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getPropertyDetail } from "@/lib/queries";
import { getSignedUrls } from "@/lib/storage";
import { formatCents, propertyDisplayName } from "@/lib/format";
import { ProgressRing } from "@/components/ui/skeleton";
import { LinkButton } from "@/components/ui/button";
import { DeadlineCard } from "./deadline-card";
import { RoomChecklist } from "./room-checklist";
import type { Phase } from "@/lib/types";

export default async function PropertyOverviewPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();
  const detail = await getPropertyDetail(supabase, id);

  if (!detail) notFound();

  const { property, rooms, totalMoveInPhotos, totalMoveOutPhotos } = detail;

  const activePhase: Phase = property.move_in_completed_at ? "move_out" : "move_in";
  const activeRooms = rooms.length || 1;
  const documentedRooms = rooms.filter((r) =>
    (activePhase === "move_in" ? r.moveInPhotos : r.moveOutPhotos).length > 0
  ).length;
  const progress = (documentedRooms / activeRooms) * 100;

  const thumbPaths = rooms
    .map((r) => (activePhase === "move_in" ? r.moveInPhotos[0] : r.moveOutPhotos[0]))
    .filter((p): p is NonNullable<typeof p> => !!p)
    .map((p) => p.storage_path);
  const thumbnails = await getSignedUrls(supabase, "photos", thumbPaths);

  const canStartMoveOut = !!property.move_in_completed_at && !property.move_out_completed_at;
  const canCompare = totalMoveInPhotos > 0 && totalMoveOutPhotos > 0;
  const canEvidence = !!property.move_out_completed_at;

  return (
    <div>
      <div className="flex flex-col gap-6 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <Link href="/app" className="text-xs font-medium text-ink/40 hover:text-ink">
            ← All properties
          </Link>
          <h1 className="mt-2 font-display text-3xl text-ink">{propertyDisplayName(property)}</h1>
          <p className="mt-1 text-sm text-ink/50">
            {property.address_line1
              ? `${property.address_line1}${property.city ? `, ${property.city}` : ""}${property.state ? `, ${property.state}` : ""}`
              : "No address on file"}
          </p>
        </div>
        <div className="flex items-center gap-4 rounded-2xl border border-ink-100 bg-white p-4">
          <ProgressRing value={progress} />
          <div>
            <p className="text-xs text-ink/45">
              {activePhase === "move_in" ? "Move-in" : "Move-out"} progress
            </p>
            <p className="text-sm font-medium text-ink">
              {documentedRooms} / {activeRooms} rooms
            </p>
          </div>
        </div>
      </div>

      <div className="ledger-rule my-8" />

      <div className="grid gap-8 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <div className="mb-4 flex flex-wrap items-center gap-3">
            <LinkButton href={`/app/p/${id}/walkthrough?phase=${activePhase}`} size="md">
              {activePhase === "move_in" ? "Continue walkthrough" : "Continue move-out walkthrough"}
            </LinkButton>
            {property.move_in_completed_at && (
              <LinkButton href={`/app/p/${id}/report`} variant="ghost" size="md">
                Generate report
              </LinkButton>
            )}
            {canStartMoveOut && (
              <LinkButton href={`/app/p/${id}/walkthrough?phase=move_out`} variant="ghost" size="md">
                Start move-out
              </LinkButton>
            )}
            {canCompare && (
              <LinkButton href={`/app/p/${id}/compare`} variant="ghost" size="md">
                Compare
              </LinkButton>
            )}
            {canEvidence && (
              <LinkButton href={`/app/p/${id}/evidence`} variant="ghost" size="md">
                Evidence packet
              </LinkButton>
            )}
          </div>

          <h2 className="mb-3 font-display text-lg text-ink">Rooms</h2>
          <RoomChecklist rooms={rooms} activePhase={activePhase} thumbnails={thumbnails} />
        </div>

        <div className="flex flex-col gap-4">
          <DeadlineCard state={property.state} moveOutCompletedAt={property.move_out_completed_at} />
          <div className="rounded-2xl border border-ink-100 bg-white p-5">
            <p className="text-xs text-ink/45">Deposit amount</p>
            <p className="mt-1 font-display text-2xl text-ink">{formatCents(property.deposit_amount_cents)}</p>
            {!property.is_paid && (
              <p className="mt-3 text-xs text-ink/50">
                Unlock unlimited photos, the full report, and the evidence packet for $17 — one time, this property only.
              </p>
            )}
            {property.is_paid && (
              <span className="mt-3 inline-flex items-center rounded-full border border-brass/40 bg-brass-50 px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wide text-brass">
                Shield active
              </span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
