import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getPropertyDetail } from "@/lib/queries";
import { getSignedUrls } from "@/lib/storage";
import { propertyDisplayName } from "@/lib/format";
import { ConditionBadge } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/skeleton";
import { LinkButton } from "@/components/ui/button";

export default async function ComparePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();
  const detail = await getPropertyDetail(supabase, id);
  if (!detail) notFound();

  const { property, rooms } = detail;

  const allPaths = rooms.flatMap((r) => [
    ...r.moveInPhotos.map((p) => p.storage_path),
    ...r.moveOutPhotos.map((p) => p.storage_path),
  ]);
  const signedUrls = await getSignedUrls(supabase, "photos", allPaths);

  const hasAnyPhotos = rooms.some((r) => r.moveInPhotos.length > 0 || r.moveOutPhotos.length > 0);

  return (
    <div>
      <Link href={`/app/p/${id}`} className="text-xs font-medium text-ink/40 hover:text-ink">
        ← {propertyDisplayName(property)}
      </Link>
      <h1 className="mt-2 font-display text-3xl text-ink">Move-in vs. move-out</h1>
      <p className="mt-1 text-sm text-ink/50">Room by room, side by side.</p>

      <div className="ledger-rule my-8" />

      {!hasAnyPhotos ? (
        <EmptyState
          title="Nothing to compare yet"
          description="Capture at least one move-in and one move-out photo to see a comparison."
          action={<LinkButton href={`/app/p/${id}`}>Back to property</LinkButton>}
        />
      ) : (
        <div className="flex flex-col gap-10">
          {rooms.map((room) => {
            const worseConditions = room.moveOutPhotos.filter((p) => p.condition !== "good");
            const changed = worseConditions.length > 0;
            return (
              <div key={room.id}>
                <div className="mb-3 flex items-center gap-3">
                  <h2 className="font-display text-xl text-ink">{room.name}</h2>
                  {changed && (
                    <span className="rounded-full border border-clay/30 bg-clay-50 px-2.5 py-0.5 text-[11px] font-medium text-clay">
                      Condition changed
                    </span>
                  )}
                </div>
                <div className="grid gap-6 sm:grid-cols-2">
                  <PhaseColumn
                    label="Move-in"
                    photos={room.moveInPhotos}
                    signedUrls={signedUrls}
                  />
                  <PhaseColumn
                    label="Move-out"
                    photos={room.moveOutPhotos}
                    signedUrls={signedUrls}
                  />
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

function PhaseColumn({
  label,
  photos,
  signedUrls,
}: {
  label: string;
  photos: { id: string; storage_path: string; condition: "good" | "fair" | "damaged"; note: string | null }[];
  signedUrls: Record<string, string>;
}) {
  return (
    <div>
      <p className="mb-2 font-mono text-[11px] uppercase tracking-wide text-brass">{label}</p>
      {photos.length === 0 ? (
        <div className="flex h-32 items-center justify-center rounded-xl border border-dashed border-ink-100 text-xs text-ink/40">
          No photos
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-2">
          {photos.map((p) => (
            <div key={p.id} className="overflow-hidden rounded-lg border border-ink-100 bg-white">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={signedUrls[p.storage_path]} alt="" className="aspect-square w-full object-cover" />
              <div className="p-1.5">
                <ConditionBadge condition={p.condition} />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
