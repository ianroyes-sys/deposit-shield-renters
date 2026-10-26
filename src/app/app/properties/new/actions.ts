"use server";

import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export interface CreatePropertyInput {
  nickname: string;
  addressLine1: string;
  addressLine2: string;
  city: string;
  state: string;
  zip: string;
  depositAmountDollars: string;
  leaseStart: string;
  landlordName: string;
  landlordEmail: string;
  rooms: string[];
}

export async function createProperty(input: CreatePropertyInput) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login?next=/app/properties/new");
  }

  const depositCents = input.depositAmountDollars
    ? Math.round(parseFloat(input.depositAmountDollars) * 100)
    : null;

  const { data: property, error } = await supabase
    .from("properties")
    .insert({
      user_id: user.id,
      nickname: input.nickname || null,
      address_line1: input.addressLine1 || null,
      address_line2: input.addressLine2 || null,
      city: input.city || null,
      state: input.state || null,
      zip: input.zip || null,
      landlord_name: input.landlordName || null,
      landlord_email: input.landlordEmail || null,
      deposit_amount_cents: Number.isFinite(depositCents) ? depositCents : null,
      lease_start: input.leaseStart || null,
    })
    .select("id")
    .single();

  if (error || !property) {
    throw new Error(error?.message || "Could not create property");
  }

  const roomNames = input.rooms.filter((r) => r.trim().length > 0);
  if (roomNames.length > 0) {
    const { error: roomsError } = await supabase.from("rooms").insert(
      roomNames.map((name, i) => ({
        property_id: property.id,
        user_id: user.id,
        name,
        sort: i,
      }))
    );
    if (roomsError) {
      throw new Error(roomsError.message);
    }
  }

  redirect(`/app/p/${property.id}`);
}
