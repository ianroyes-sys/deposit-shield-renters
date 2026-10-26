"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { isStripeConfigured } from "@/lib/env";
import type { Phase } from "@/lib/types";

async function requireUser() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/login");
  return { supabase, user };
}

export async function markPhaseComplete(propertyId: string, phase: Phase) {
  const { supabase } = await requireUser();
  const column = phase === "move_in" ? "move_in_completed_at" : "move_out_completed_at";
  const { error } = await supabase
    .from("properties")
    .update({ [column]: new Date().toISOString() })
    .eq("id", propertyId);
  if (error) throw new Error(error.message);
  revalidatePath(`/app/p/${propertyId}`);
}

export async function deletePhoto(propertyId: string, photoId: string, storagePath: string) {
  const { supabase } = await requireUser();
  await supabase.storage.from("photos").remove([storagePath]);
  const { error } = await supabase.from("photos").delete().eq("id", photoId);
  if (error) throw new Error(error.message);
  revalidatePath(`/app/p/${propertyId}`);
}

export async function updateRooms(
  propertyId: string,
  rooms: { id?: string; name: string; sort: number }[]
) {
  const { supabase, user } = await requireUser();
  const toInsert = rooms.filter((r) => !r.id);
  const toUpdate = rooms.filter((r) => r.id);

  if (toInsert.length > 0) {
    const { error } = await supabase.from("rooms").insert(
      toInsert.map((r) => ({
        property_id: propertyId,
        user_id: user.id,
        name: r.name,
        sort: r.sort,
      }))
    );
    if (error) throw new Error(error.message);
  }

  for (const r of toUpdate) {
    const { error } = await supabase
      .from("rooms")
      .update({ name: r.name, sort: r.sort })
      .eq("id", r.id);
    if (error) throw new Error(error.message);
  }

  revalidatePath(`/app/p/${propertyId}`);
}

export async function deleteRoom(propertyId: string, roomId: string) {
  const { supabase } = await requireUser();
  const { error } = await supabase.from("rooms").delete().eq("id", roomId);
  if (error) throw new Error(error.message);
  revalidatePath(`/app/p/${propertyId}`);
}

export async function devUnlockProperty(propertyId: string) {
  // Guards against calling this server action directly (bypassing the UI,
  // which only renders the dev-unlock button when Stripe isn't configured).
  // Without this check, any signed-in user could unlock properties for free
  // in a production deployment that has Stripe fully configured.
  if (isStripeConfigured) {
    throw new Error("Dev unlock is disabled — Stripe is configured on this deployment.");
  }
  const { supabase, user } = await requireUser();
  const { error } = await supabase
    .from("properties")
    .update({ is_paid: true, stripe_session_id: "dev-unlock" })
    .eq("id", propertyId)
    .eq("user_id", user.id);
  if (error) throw new Error(error.message);
  revalidatePath(`/app/p/${propertyId}`);
}
