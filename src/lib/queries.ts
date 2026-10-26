import type { SupabaseClient } from "@supabase/supabase-js";
import type { Photo, Property, Room } from "@/lib/types";

export interface PropertyWithStats extends Property {
  moveInPhotoCount: number;
  moveOutPhotoCount: number;
  roomCount: number;
}

export async function getPropertiesWithStats(
  supabase: SupabaseClient
): Promise<PropertyWithStats[]> {
  const { data: properties } = await supabase
    .from("properties")
    .select("*")
    .order("created_at", { ascending: false });

  const props = (properties ?? []) as Property[];
  if (props.length === 0) return [];

  const ids = props.map((p) => p.id);

  const [{ data: photos }, { data: rooms }] = await Promise.all([
    supabase.from("photos").select("property_id, phase").in("property_id", ids),
    supabase.from("rooms").select("property_id").in("property_id", ids),
  ]);

  const photoRows = (photos ?? []) as Pick<Photo, "property_id" | "phase">[];
  const roomRows = (rooms ?? []) as Pick<Room, "property_id">[];

  return props.map((p) => ({
    ...p,
    moveInPhotoCount: photoRows.filter((ph) => ph.property_id === p.id && ph.phase === "move_in").length,
    moveOutPhotoCount: photoRows.filter((ph) => ph.property_id === p.id && ph.phase === "move_out").length,
    roomCount: roomRows.filter((r) => r.property_id === p.id).length,
  }));
}

export interface PropertyStatus {
  label: string;
  tone: "neutral" | "progress" | "success" | "brass";
}

export function getPropertyStatus(p: PropertyWithStats): PropertyStatus {
  if (p.move_out_completed_at) {
    return { label: "Move-out documented", tone: "success" };
  }
  if (p.move_in_completed_at) {
    return p.is_paid
      ? { label: "Move-in documented · Protected", tone: "success" }
      : { label: "Move-in documented", tone: "progress" };
  }
  if (p.moveInPhotoCount > 0) {
    return { label: "Move-in in progress", tone: "progress" };
  }
  return { label: "Not started", tone: "neutral" };
}

export async function getRoomsForProperty(
  supabase: SupabaseClient,
  propertyId: string
): Promise<Room[]> {
  const { data } = await supabase
    .from("rooms")
    .select("*")
    .eq("property_id", propertyId)
    .order("sort", { ascending: true });
  return (data ?? []) as Room[];
}

export interface RoomWithPhotos extends Room {
  moveInPhotos: Photo[];
  moveOutPhotos: Photo[];
}

export interface PropertyDetail {
  property: Property;
  rooms: RoomWithPhotos[];
  totalMoveInPhotos: number;
  totalMoveOutPhotos: number;
}

export async function getPropertyDetail(
  supabase: SupabaseClient,
  propertyId: string
): Promise<PropertyDetail | null> {
  const { data: property } = await supabase
    .from("properties")
    .select("*")
    .eq("id", propertyId)
    .maybeSingle();

  if (!property) return null;

  const [{ data: rooms }, { data: photos }] = await Promise.all([
    supabase.from("rooms").select("*").eq("property_id", propertyId).order("sort", { ascending: true }),
    supabase.from("photos").select("*").eq("property_id", propertyId).order("created_at", { ascending: true }),
  ]);

  const roomRows = (rooms ?? []) as Room[];
  const photoRows = (photos ?? []) as Photo[];

  const roomsWithPhotos: RoomWithPhotos[] = roomRows.map((r) => ({
    ...r,
    moveInPhotos: photoRows.filter((p) => p.room_id === r.id && p.phase === "move_in"),
    moveOutPhotos: photoRows.filter((p) => p.room_id === r.id && p.phase === "move_out"),
  }));

  return {
    property: property as Property,
    rooms: roomsWithPhotos,
    totalMoveInPhotos: photoRows.filter((p) => p.phase === "move_in").length,
    totalMoveOutPhotos: photoRows.filter((p) => p.phase === "move_out").length,
  };
}

export async function getPhotosForProperty(
  supabase: SupabaseClient,
  propertyId: string,
  phase?: "move_in" | "move_out"
): Promise<Photo[]> {
  let query = supabase
    .from("photos")
    .select("*")
    .eq("property_id", propertyId)
    .order("created_at", { ascending: true });
  if (phase) query = query.eq("phase", phase);
  const { data } = await query;
  return (data ?? []) as Photo[];
}
