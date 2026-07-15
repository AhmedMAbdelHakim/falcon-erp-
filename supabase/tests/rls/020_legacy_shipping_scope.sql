begin;
set local search_path = public, extensions;
select plan(8);

select ok((select relrowsecurity from pg_class where oid = 'public.labels'::regclass), 'labels has RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.shipping_settings'::regclass), 'shipping settings has RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.governorate_shipping_fees'::regclass), 'governorate fees have RLS');

select is(
  (select count(*)::integer from pg_policy where polrelid = 'public.labels'::regclass),
  4,
  'labels has explicit CRUD policies'
);
select is(
  (select count(*)::integer from pg_policy where polrelid = 'public.shipping_settings'::regclass),
  2,
  'shipping settings has read and write policies'
);
select is(
  (select count(*)::integer from pg_policy where polrelid = 'public.governorate_shipping_fees'::regclass),
  2,
  'governorate fees have read and write policies'
);
select ok(
  not exists (
    select 1 from information_schema.routine_privileges
    where routine_schema = 'private' and routine_name like '%legacy%'
      and grantee in ('PUBLIC', 'anon', 'authenticated')
  ),
  'compatibility security-definer helpers are not callable by API roles'
);
select ok(
  not exists (
    select 1 from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'private'
      and p.proname like '%legacy%'
      and pg_get_functiondef(p.oid) ~* 'raw_user_meta_data|user_metadata'
  ),
  'compatibility authorization ignores user metadata'
);

select * from finish();
rollback;

