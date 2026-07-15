begin;
set local search_path = public, extensions;
select plan(6);

select is(
  (select count(*)::integer from storage.buckets where id in ('falcon-operational', 'falcon-financial')),
  2,
  'both Falcon storage buckets exist'
);
select is(
  (select count(*)::integer from storage.buckets where id in ('falcon-operational', 'falcon-financial') and public),
  0,
  'Falcon storage buckets are private'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'falcon_storage_read' and 'authenticated' = any(roles)),
  1,
  'authenticated object reads use the Falcon policy'
);
select is(
  (select count(*)::integer from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'falcon_storage_insert' and 'authenticated' = any(roles)),
  1,
  'authenticated object inserts use the Falcon policy'
);
select ok(
  (select qual like '%current_organization_id()%' and qual like '%foldername%' and qual like '%attachments%'
   from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'falcon_storage_read'),
  'object reads require organization prefix and attachment metadata'
);
select ok(
  (select with_check like '%current_organization_id()%' and with_check like '%foldername%' and with_check like '%has_any_permission%'
   from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'falcon_storage_insert'),
  'object inserts require organization prefix and explicit permission'
);

select * from finish();
rollback;
