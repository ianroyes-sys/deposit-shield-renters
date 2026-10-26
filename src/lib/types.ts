export type Phase = "move_in" | "move_out";
export type PhotoCondition = "good" | "fair" | "damaged";
export type ReportKind = "move_in" | "move_out" | "evidence_packet";

export interface Property {
  id: string;
  user_id: string;
  nickname: string | null;
  address_line1: string | null;
  address_line2: string | null;
  city: string | null;
  state: string | null;
  zip: string | null;
  landlord_name: string | null;
  landlord_email: string | null;
  deposit_amount_cents: number | null;
  lease_start: string | null;
  move_in_completed_at: string | null;
  move_out_completed_at: string | null;
  is_paid: boolean;
  stripe_session_id: string | null;
  created_at: string;
}

export interface Room {
  id: string;
  property_id: string;
  user_id: string;
  name: string;
  sort: number;
  created_at: string;
}

export interface Photo {
  id: string;
  property_id: string;
  room_id: string;
  user_id: string;
  phase: Phase;
  storage_path: string;
  sha256: string;
  captured_at: string;
  lat: number | null;
  lng: number | null;
  note: string | null;
  condition: PhotoCondition;
  created_at: string;
}

export interface Report {
  id: string;
  property_id: string;
  user_id: string;
  kind: ReportKind;
  storage_path: string | null;
  sent_to: string | null;
  sent_at: string | null;
  created_at: string;
}

export const DEFAULT_ROOM_NAMES = [
  "Entry",
  "Living Room",
  "Kitchen",
  "Bedroom",
  "Bathroom",
];
