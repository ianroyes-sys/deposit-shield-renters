-- Server-side enforcement of the free-tier 10-photo limit.
-- The UI gates at 10 photos for unpaid properties, but RLS alone only checks
-- ownership — without this trigger a user could insert unlimited photos via
-- the REST API and never pay.

create or replace function public.enforce_free_photo_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  paid boolean;
  photo_count integer;
begin
  select is_paid into paid from public.properties where id = new.property_id;
  if not coalesce(paid, false) then
    select count(*) into photo_count from public.photos where property_id = new.property_id;
    if photo_count >= 10 then
      raise exception 'FREE_PHOTO_LIMIT_REACHED' using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists photos_free_limit on public.photos;
create trigger photos_free_limit
  before insert on public.photos
  for each row execute function public.enforce_free_photo_limit();
