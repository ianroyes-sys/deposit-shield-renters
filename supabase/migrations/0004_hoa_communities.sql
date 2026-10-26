-- Deposit Shield Communities (HOA mode) — applied live 2026-07-16 (MCP migration: hoa_communities).

create table public.associations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text,
  state text,
  created_by uuid not null references auth.users (id) on delete cascade,
  is_paid boolean not null default false,
  plan text,
  created_at timestamptz not null default now()
);

create table public.association_members (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.associations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('board','resident')),
  unit_label text,
  display_name text,
  created_at timestamptz not null default now(),
  unique (association_id, user_id)
);

create table public.association_codes (
  association_id uuid not null references public.associations (id) on delete cascade,
  role text not null check (role in ('board','resident')),
  code text not null unique,
  primary key (association_id, role)
);

-- Membership helpers (security definer avoids recursive RLS)
create or replace function public.is_member(aid uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from association_members where association_id = aid and user_id = auth.uid());
$$;

create or replace function public.is_board(aid uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from association_members where association_id = aid and user_id = auth.uid() and role = 'board');
$$;

-- Create an association: creator becomes board, codes generated
create or replace function public.create_association(p_name text, p_city text, p_state text, p_display_name text, p_unit_label text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  aid uuid;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  insert into associations (name, city, state, created_by) values (p_name, p_city, p_state, auth.uid()) returning id into aid;
  insert into association_members (association_id, user_id, role, display_name, unit_label)
    values (aid, auth.uid(), 'board', p_display_name, p_unit_label);
  insert into association_codes (association_id, role, code)
    values (aid, 'board', 'B-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
           (aid, 'resident', 'R-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)));
  return aid;
end;
$$;

-- Join via code (role inferred from the code)
create or replace function public.join_association(p_code text, p_display_name text, p_unit_label text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  rec record;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  select association_id, role into rec from association_codes where code = p_code;
  if rec is null then raise exception 'INVALID_JOIN_CODE'; end if;
  insert into association_members (association_id, user_id, role, display_name, unit_label)
    values (rec.association_id, auth.uid(), rec.role, p_display_name, p_unit_label)
    on conflict (association_id, user_id) do update set role = excluded.role;
  return rec.association_id;
end;
$$;

create table public.violations (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.associations (id) on delete cascade,
  created_by uuid not null references auth.users (id) on delete cascade,
  unit_label text,
  address text,
  category text not null,
  rule_reference text,
  description text,
  status text not null default 'open' check (status in ('open','courtesy_sent','warning_sent','fine_issued','resolved','dismissed')),
  opened_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.violation_events (
  id uuid primary key default gen_random_uuid(),
  violation_id uuid not null references public.violations (id) on delete cascade,
  association_id uuid not null references public.associations (id) on delete cascade,
  actor uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('courtesy_notice','warning','fine','comment','resolved','dismissed')),
  note text,
  fine_amount_cents integer,
  pdf_path text,
  created_at timestamptz not null default now()
);

create table public.hoa_photos (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.associations (id) on delete cascade,
  parent_type text not null check (parent_type in ('violation','inspection','arc')),
  parent_id uuid not null,
  uploaded_by uuid not null references auth.users (id) on delete cascade,
  storage_path text not null,
  sha256 text not null,
  captured_at timestamptz not null,
  lat double precision,
  lng double precision,
  note text,
  created_at timestamptz not null default now()
);
create index hoa_photos_parent_idx on public.hoa_photos (parent_type, parent_id);
create index hoa_photos_assoc_idx on public.hoa_photos (association_id);

create table public.inspection_areas (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.associations (id) on delete cascade,
  name text not null,
  cadence_days integer,
  sort integer not null default 0
);

create table public.inspections (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.associations (id) on delete cascade,
  area_id uuid not null references public.inspection_areas (id) on delete cascade,
  performed_by uuid not null references auth.users (id) on delete cascade,
  performed_at timestamptz not null default now(),
  condition text not null default 'good' check (condition in ('good','fair','attention')),
  notes text,
  pdf_path text
);

create table public.arc_requests (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.associations (id) on delete cascade,
  requester uuid not null references auth.users (id) on delete cascade,
  unit_label text,
  title text not null,
  description text,
  status text not null default 'pending' check (status in ('pending','approved','denied','withdrawn')),
  decision_note text,
  decided_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.associations (id) on delete cascade,
  author uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text,
  pinned boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.motions (
  id uuid primary key default gen_random_uuid(),
  association_id uuid not null references public.associations (id) on delete cascade,
  created_by uuid not null references auth.users (id) on delete cascade,
  title text not null,
  description text,
  status text not null default 'open' check (status in ('open','passed','failed','withdrawn')),
  closes_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.motion_votes (
  id uuid primary key default gen_random_uuid(),
  motion_id uuid not null references public.motions (id) on delete cascade,
  association_id uuid not null references public.associations (id) on delete cascade,
  voter uuid not null references auth.users (id) on delete cascade,
  vote text not null check (vote in ('yes','no','abstain')),
  created_at timestamptz not null default now(),
  unique (motion_id, voter)
);

-- RLS
alter table public.associations enable row level security;
alter table public.association_members enable row level security;
alter table public.association_codes enable row level security;
alter table public.violations enable row level security;
alter table public.violation_events enable row level security;
alter table public.hoa_photos enable row level security;
alter table public.inspection_areas enable row level security;
alter table public.inspections enable row level security;
alter table public.arc_requests enable row level security;
alter table public.announcements enable row level security;
alter table public.motions enable row level security;
alter table public.motion_votes enable row level security;

create policy "assoc_select_member" on public.associations for select using (public.is_member(id));
create policy "assoc_update_board" on public.associations for update using (public.is_board(id)) with check (public.is_board(id));

create policy "members_select_member" on public.association_members for select using (public.is_member(association_id));
create policy "members_delete_self_or_board" on public.association_members for delete using (user_id = auth.uid() or public.is_board(association_id));

-- Join codes: board-only visibility (residents never see the board code)
create policy "codes_select_board" on public.association_codes for select using (public.is_board(association_id));

create policy "violations_select_member" on public.violations for select using (public.is_member(association_id));
create policy "violations_write_board" on public.violations for insert with check (public.is_board(association_id) and created_by = auth.uid());
create policy "violations_update_board" on public.violations for update using (public.is_board(association_id)) with check (public.is_board(association_id));

create policy "vevents_select_member" on public.violation_events for select using (public.is_member(association_id));
create policy "vevents_insert_board" on public.violation_events for insert with check (public.is_board(association_id) and actor = auth.uid());

create policy "hoa_photos_select_member" on public.hoa_photos for select using (public.is_member(association_id));
create policy "hoa_photos_insert_member" on public.hoa_photos for insert with check (public.is_member(association_id) and uploaded_by = auth.uid());

create policy "areas_select_member" on public.inspection_areas for select using (public.is_member(association_id));
create policy "areas_write_board" on public.inspection_areas for insert with check (public.is_board(association_id));
create policy "areas_update_board" on public.inspection_areas for update using (public.is_board(association_id)) with check (public.is_board(association_id));
create policy "areas_delete_board" on public.inspection_areas for delete using (public.is_board(association_id));

create policy "inspections_select_member" on public.inspections for select using (public.is_member(association_id));
create policy "inspections_write_board" on public.inspections for insert with check (public.is_board(association_id) and performed_by = auth.uid());
create policy "inspections_update_board" on public.inspections for update using (public.is_board(association_id)) with check (public.is_board(association_id));

create policy "arc_select_member" on public.arc_requests for select using (public.is_member(association_id));
create policy "arc_insert_member" on public.arc_requests for insert with check (public.is_member(association_id) and requester = auth.uid());
create policy "arc_update_board_or_own" on public.arc_requests for update using (public.is_board(association_id) or requester = auth.uid()) with check (public.is_board(association_id) or requester = auth.uid());

create policy "ann_select_member" on public.announcements for select using (public.is_member(association_id));
create policy "ann_write_board" on public.announcements for insert with check (public.is_board(association_id) and author = auth.uid());
create policy "ann_update_board" on public.announcements for update using (public.is_board(association_id)) with check (public.is_board(association_id));
create policy "ann_delete_board" on public.announcements for delete using (public.is_board(association_id));

create policy "motions_select_member" on public.motions for select using (public.is_member(association_id));
create policy "motions_write_board" on public.motions for insert with check (public.is_board(association_id) and created_by = auth.uid());
create policy "motions_update_board" on public.motions for update using (public.is_board(association_id)) with check (public.is_board(association_id));

create policy "votes_select_member" on public.motion_votes for select using (public.is_member(association_id));
create policy "votes_insert_board" on public.motion_votes for insert with check (public.is_board(association_id) and voter = auth.uid());

-- Free-tier enforcement (server-side): unpaid associations max 2 non-closed violations, 1 inspection area
create or replace function public.enforce_hoa_free_limits()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  paid boolean;
  n integer;
begin
  select is_paid into paid from associations where id = new.association_id;
  if coalesce(paid, false) then return new; end if;
  if tg_table_name = 'violations' then
    select count(*) into n from violations where association_id = new.association_id and status not in ('resolved','dismissed');
    if n >= 2 then raise exception 'FREE_VIOLATION_LIMIT_REACHED' using errcode = 'P0001'; end if;
  elsif tg_table_name = 'inspection_areas' then
    select count(*) into n from inspection_areas where association_id = new.association_id;
    if n >= 1 then raise exception 'FREE_AREA_LIMIT_REACHED' using errcode = 'P0001'; end if;
  end if;
  return new;
end;
$$;

create trigger violations_free_limit before insert on public.violations
  for each row execute function public.enforce_hoa_free_limits();
create trigger areas_free_limit before insert on public.inspection_areas
  for each row execute function public.enforce_hoa_free_limits();

-- Storage: association-scoped paths `assoc/{association_id}/...` readable/writable by members
create policy "hoa_photos_storage_rw" on storage.objects
  for all using (
    bucket_id in ('photos','reports')
    and (storage.foldername(name))[1] = 'assoc'
    and public.is_member(((storage.foldername(name))[2])::uuid)
  )
  with check (
    bucket_id in ('photos','reports')
    and (storage.foldername(name))[1] = 'assoc'
    and public.is_member(((storage.foldername(name))[2])::uuid)
  );
