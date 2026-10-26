-- HOA hardening — applied live 2026-07-16 (MCP migrations: hoa_hardening + fix_join_association).
-- Closes security round-2 findings:
--   1. ARC self-approval: residents can only withdraw their own pending request (trigger guard).
--   2. Free-tier violation cap now enforced on UPDATE transitions (resolved->open bypass closed).
--   3. hoa_photos inserts require per-parent authorization (board for violation/inspection,
--      requester-or-board for arc) and association match (evidence-tampering gap closed).
--   4. Storage policy uuid cast made exception-safe (safe_uuid).
--   5. join_association throttled: 20 attempts / 10 min / user; attempts table is RLS-locked
--      (no policies) so clients cannot read or reset it.

create or replace function public.arc_requests_guard_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.is_board(new.association_id) then
    return new;
  end if;
  if old.requester <> auth.uid() then
    raise exception 'NOT_AUTHORIZED';
  end if;
  if old.status <> 'pending' or new.status <> 'withdrawn' then
    raise exception 'RESIDENTS_CAN_ONLY_WITHDRAW_PENDING_REQUESTS';
  end if;
  if new.title <> old.title
     or new.description is distinct from old.description
     or new.unit_label is distinct from old.unit_label
     or new.decision_note is distinct from old.decision_note
     or new.decided_at is distinct from old.decided_at then
    raise exception 'RESIDENTS_CANNOT_MODIFY_OTHER_FIELDS';
  end if;
  return new;
end;
$$;

drop trigger if exists arc_requests_update_guard on public.arc_requests;
create trigger arc_requests_update_guard
  before update on public.arc_requests
  for each row execute function public.arc_requests_guard_update();

create or replace function public.enforce_hoa_free_limits()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  paid boolean;
  n integer;
  new_active boolean;
  old_active boolean;
begin
  select is_paid into paid from associations where id = new.association_id;
  if coalesce(paid, false) then return new; end if;

  if tg_table_name = 'violations' then
    new_active := new.status not in ('resolved','dismissed');
    if tg_op = 'UPDATE' then
      old_active := old.status not in ('resolved','dismissed');
      if new_active and not old_active then
        select count(*) into n from violations
          where association_id = new.association_id
            and status not in ('resolved','dismissed')
            and id <> new.id;
        if n >= 2 then raise exception 'FREE_VIOLATION_LIMIT_REACHED' using errcode = 'P0001'; end if;
      end if;
      return new;
    end if;
    if new_active then
      select count(*) into n from violations
        where association_id = new.association_id and status not in ('resolved','dismissed');
      if n >= 2 then raise exception 'FREE_VIOLATION_LIMIT_REACHED' using errcode = 'P0001'; end if;
    end if;
  elsif tg_table_name = 'inspection_areas' then
    select count(*) into n from inspection_areas where association_id = new.association_id;
    if n >= 1 then raise exception 'FREE_AREA_LIMIT_REACHED' using errcode = 'P0001'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists violations_free_limit_update on public.violations;
create trigger violations_free_limit_update
  before update on public.violations
  for each row execute function public.enforce_hoa_free_limits();

create or replace function public.hoa_photo_parent_ok(p_association_id uuid, p_parent_type text, p_parent_id uuid)
returns boolean language sql security definer set search_path = public stable as $$
  select case p_parent_type
    when 'violation' then exists (
      select 1 from violations v
      where v.id = p_parent_id and v.association_id = p_association_id
    ) and public.is_board(p_association_id)
    when 'inspection' then exists (
      select 1 from inspections i
      where i.id = p_parent_id and i.association_id = p_association_id
    ) and public.is_board(p_association_id)
    when 'arc' then exists (
      select 1 from arc_requests a
      where a.id = p_parent_id and a.association_id = p_association_id
        and (a.requester = auth.uid() or public.is_board(p_association_id))
    )
    else false
  end;
$$;

drop policy if exists "hoa_photos_insert_member" on public.hoa_photos;
drop policy if exists "hoa_photos_insert_authorized" on public.hoa_photos;
create policy "hoa_photos_insert_authorized" on public.hoa_photos
  for insert with check (
    uploaded_by = auth.uid()
    and public.hoa_photo_parent_ok(association_id, parent_type, parent_id)
  );

create or replace function public.safe_uuid(t text)
returns uuid language plpgsql immutable as $$
begin
  return t::uuid;
exception when others then
  return null;
end;
$$;

drop policy if exists "hoa_photos_storage_rw" on storage.objects;
create policy "hoa_photos_storage_rw" on storage.objects
  for all using (
    bucket_id in ('photos','reports')
    and (storage.foldername(name))[1] = 'assoc'
    and public.is_member(public.safe_uuid((storage.foldername(name))[2]))
  )
  with check (
    bucket_id in ('photos','reports')
    and (storage.foldername(name))[1] = 'assoc'
    and public.is_member(public.safe_uuid((storage.foldername(name))[2]))
  );

create table if not exists public.join_code_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  attempted_at timestamptz not null default now()
);
create index if not exists join_code_attempts_user_time_idx
  on public.join_code_attempts (user_id, attempted_at);
alter table public.join_code_attempts enable row level security;

create or replace function public.join_association(p_code text, p_display_name text, p_unit_label text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  rec record;
begin
  if auth.uid() is null then raise exception 'NOT_AUTHENTICATED'; end if;
  if (select count(*) from join_code_attempts
        where user_id = auth.uid() and attempted_at > now() - interval '10 minutes') >= 20 then
    raise exception 'TOO_MANY_ATTEMPTS';
  end if;
  insert into join_code_attempts (user_id) values (auth.uid());
  select association_id, role into rec from association_codes where code = p_code;
  if rec is null then raise exception 'INVALID_JOIN_CODE'; end if;
  insert into association_members (association_id, user_id, role, display_name, unit_label)
    values (rec.association_id, auth.uid(), rec.role, p_display_name, p_unit_label)
    on conflict (association_id, user_id) do update set role = excluded.role;
  return rec.association_id;
end;
$$;
