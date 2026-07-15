begin;
set local search_path = public, extensions;
select plan(5);

select is(
  (select count(*)::integer from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where p.prosecdef and n.nspname in ('private', 'accounting', 'audit')
   and coalesce(array_to_string(p.proconfig, ','), '') not like '%search_path=%'),
  0,
  'sensitive security-definer functions set search_path'
);
select is(
  (select count(*)::integer from information_schema.routine_privileges
   where routine_schema in ('private', 'accounting', 'audit') and grantee = 'PUBLIC' and privilege_type = 'EXECUTE'),
  0,
  'PUBLIC cannot execute sensitive functions'
);
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'public' and grantee = 'anon' and privilege_type in ('INSERT', 'UPDATE', 'DELETE')),
  0,
  'anonymous callers cannot mutate operational tables'
);
select is(
  (select count(*)::integer from information_schema.role_table_grants
   where table_schema = 'accounting' and grantee = 'authenticated' and table_name in ('journal_entries', 'journal_lines')),
  0,
  'authenticated callers have no direct ledger grants'
);
select ok(
  not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private' and p.prokind = 'f'
      and pg_get_functiondef(p.oid) ~* 'raw_user_meta_data|user_metadata'),
  'authorization functions do not trust user metadata'
);

select * from finish();
rollback;
