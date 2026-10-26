import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { getPropertyDetail } from "@/lib/queries";
import { getSignedUrls } from "@/lib/storage";
import { FREE_PHOTO_LIMIT, isStripeConfigured } from "@/lib/env";
import { WalkthroughClient } from "./walkthrough-client";
import type { Phase } from "@/lib/types";

export default async function WalkthroughPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ phase?: string }>;
}) {
  const { id } = await params;
  const { phase: phaseParam } = await searchParams;
  const phase: Phase = phaseParam === "move_out" ? "move_out" : "move_in";

  const supabase = await createClient();
  const detail = await getPropertyDetail(supabase, id);
  if (!detail) notFound();

  const { property, rooms, totalMoveInPhotos, totalMoveOutPhotos } = detail;

  if (rooms.length === 0) {
    redirect(`/app/p/${id}`);
  }

  const totalExistingPhotos = totalMoveInPhotos + totalMoveOutPhotos;

  const allPaths = rooms.flatMap((r) =>
    (phase === "move_in" ? r.moveInPhotos : r.moveOutPhotos).map((p) => p.storage_path)
  );
  const signedUrls = await getSignedUrls(supabase, "photos", allPaths);

  const roomsForClient = rooms.map((r) => ({
    id: r.id,
    name: r.name,
    photos: (phase === "move_in" ? r.moveInPhotos : r.moveOutPhotos).map((p) => ({
      id: p.id,
      storagePath: p.storage_path,
      signedUrl: signedUrls[p.storage_path] ?? "",
      note: p.note,
      condition: p.condition,
      sha256: p.sha256,
      capturedAt: p.captured_at,
    })),
  }));

  return (
    <WalkthroughClient
      propertyId={id}
      phase={phase}
      isPaid={property.is_paid}
      rooms={roomsForClient}
      totalExistingPhotos={totalExistingPhotos}
      freePhotoLimit={FREE_PHOTO_LIMIT}
      stripeConfigured={isStripeConfigured}
    />
  );
}
