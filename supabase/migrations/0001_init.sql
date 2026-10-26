-- Deposit Shield initial schema
-- Applies to a Supabase project. Run via `supabase db push` or the SQL editor.
--
-- STORAGE BUCKETS (create manually or via `supabase storage` — not created by SQL migrations
-- unless the storage extension objects are inserted directly):
--   1. `photos`  — private bucket for move-in/move-out photos.
--   2. `reports` — private bucket for generated PDF reports.
-- Both buckets must be PRIVATE. The app only ever reads/writes via signed URLs
-- generated server-side (service role) or via RLS-scoped storage policies below.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- properties
-- ---------------------------------------------------------------------------
create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  nickname text,
  address_line1 text,
  address_line2 text,
  city text,
  state text,
  zip text,
  landlord_name text,
  landlord_email text,
  deposit_amount_cents integer,
  lease_start date,
  move_in_completed_at timestamptz,
  move_out_completed_at timestamptz,
  is_paid boolean not null default false,
  stripe_session_id text,
  created_at timestamptz not null default now()
);

alter table public.properties enable row level security;

create policy "properties_select_own" on public.properties
  for select using (auth.uid() = user_id);
create policy "properties_insert_own" on public.properties
  for insert with check (auth.uid() = user_id);
create policy "properties_update_own" on public.properties
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "properties_delete_own" on public.properties
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- rooms
-- ---------------------------------------------------------------------------
create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  sort integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.rooms enable row level security;

create policy "rooms_select_own" on public.rooms
  for select using (auth.uid() = user_id);
create policy "rooms_insert_own" on public.rooms
  for insert with check (auth.uid() = user_id);
create policy "rooms_update_own" on public.rooms
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "rooms_delete_own" on public.rooms
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- photos
-- ---------------------------------------------------------------------------
create table if not exists public.photos (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  room_id uuid not null references public.rooms (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  phase text not null check (phase in ('move_in', 'move_out')),
  storage_path text not null,
  sha256 text not null,
  captured_at timestamptz not null,
  lat double precision,
  lng double precision,
  note text,
  condition text not null default 'good' check (condition in ('good', 'fair', 'damaged')),
  created_at timestamptz not null default now()
);

alter table public.photos enable row level security;

create index if not exists photos_property_phase_idx on public.photos (property_id, phase);
create index if not exists photos_room_idx on public.photos (room_id);

create policy "photos_select_own" on public.photos
  for select using (auth.uid() = user_id);
create policy "photos_insert_own" on public.photos
  for insert with check (auth.uid() = user_id);
create policy "photos_update_own" on public.photos
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "photos_delete_own" on public.photos
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- reports
-- ---------------------------------------------------------------------------
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  property_id uuid not null references public.properties (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('move_in', 'move_out', 'evidence_packet')),
  storage_path text,
  sent_to text,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.reports enable row level security;

create policy "reports_select_own" on public.reports
  for select using (auth.uid() = user_id);
create policy "reports_insert_own" on public.reports
  for insert with check (auth.uid() = user_id);
create policy "reports_update_own" on public.reports
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "reports_delete_own" on public.reports
  for delete using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- storage policies (bucket objects live in storage.objects; owner is folder-scoped
-- by convention: `${auth.uid()}/${property_id}/...`)
-- ---------------------------------------------------------------------------
-- Run after creating the `photos` and `reports` buckets in the Supabase dashboard
-- (or via `supabase storage buckets create photos --private` etc). Example policies:
--
-- create policy "photos_owner_rw" on storage.objects
--   for all using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text)
--   with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);
--
-- create policy "reports_owner_rw" on storage.objects
--   for all using (bucket_id = 'reports' and (storage.foldername(name))[1] = auth.uid()::text)
--   with check (bucket_id = 'reports' and (storage.foldername(name))[1] = auth.uid()::text);
