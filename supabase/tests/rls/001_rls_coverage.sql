begin;
set local search_path = public, extensions;
select plan(4);

select is(
  (select count(*)::integer from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'p') and not c.relrowsecurity),
  0,
  'every public table has RLS enabled'
);
select is(
  (select count(*)::integer from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'p') and c.relrowsecurity and not exists (
     select 1 from pg_policy p where p.polrelid = c.oid
   )),
  0,
  'every public table has at least one policy'
);
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'accounting' and grantee in ('anon', 'authenticated') and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'API roles cannot mutate accounting tables directly'
);
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'private' and grantee in ('anon', 'authenticated')),
  0,
  'API roles have no direct private-table grants'
);

select * from finish();
rollback;
