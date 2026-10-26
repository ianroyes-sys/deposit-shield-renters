-- Applied to the live project on 2026-07-16 (MCP migration: storage_buckets_and_policies).
-- Tracked here so bucket security is reproducible, not a manual dashboard step.

insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('reports', 'reports', false)
on conflict (id) do nothing;

-- Owner-scoped access: object paths are `${auth.uid()}/${property_id}/...`
create policy "photos_owner_rw" on storage.objects
  for all using (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "reports_owner_rw" on storage.objects
  for all using (bucket_id = 'reports' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'reports' and (storage.foldername(name))[1] = auth.uid()::text);
