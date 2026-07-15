begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, api, extensions;

select plan(17);

select has_function('api', 'read_current_access_context', array[]::text[],
  'current access context API exists');

select ok((
  select not procedure.prosecdef and procedure.proconfig @> array['search_path=""']
  from pg_proc as procedure
  join pg_namespace as namespace on namespace.oid = procedure.pronamespace
  where namespace.nspname = 'api'
    and procedure.proname = 'read_current_access_context'
), 'access context API wrapper is security invoker with an empty search path');

select ok(has_function_privilege('authenticated', 'api.read_current_access_context()', 'EXECUTE'),
  'authenticated can execute access context API');
select ok(not has_function_privilege('anon', 'api.read_current_access_context()', 'EXECUTE'),
  'anonymous cannot execute access context API');
select ok(not has_table_privilege('authenticated', 'private.user_roles', 'SELECT')
  and not has_table_privilege('authenticated', 'private.role_permissions', 'SELECT')
  and not has_table_privilege('authenticated', 'private.permissions', 'SELECT'),
  'private RBAC tables remain unavailable to authenticated clients');

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at,
  confirmation_token,recovery_token,email_change_token_new,email_change,
  is_sso_user,is_anonymous
) values (
  '00000000-0000-0000-0000-000000000000',
  '1f000000-0000-4000-8000-000000000001',
  'authenticated','authenticated','access-context@phase3.test',
  crypt('phase3',gen_salt('bf')),statement_timestamp(),'{}',
  '{"role":"super_admin","organization_id":"1f000000-0000-4000-8000-000000000999"}',
  statement_timestamp(),statement_timestamp(),'','','','',false,false
);

select set_config('request.jwt.claim.sub','1f000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select throws_ok($$select * from api.read_current_access_context()$$,
  '42501','Account is not active','pending profile is denied');
reset role;

update public.profiles
set status = 'active', activated_at = statement_timestamp(), activated_by = id
where id = '1f000000-0000-4000-8000-000000000001';

set local role authenticated;
select is((select organization_id from api.read_current_access_context()),
  '00000000-0000-4000-8000-00000000f001'::uuid,
  'organization comes from the active database profile, not user metadata');
select is((select cardinality(role_keys) from api.read_current_access_context()), 0,
  'active user without a role receives no role keys');
select is((select cardinality(permission_keys) from api.read_current_access_context()), 0,
  'active user without a role receives no permission keys');
select ok(not (select 'super_admin' = any(role_keys) from api.read_current_access_context()),
  'user-editable metadata cannot create a role');
reset role;

insert into private.user_roles(
  organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason
)
select
  '00000000-0000-4000-8000-00000000f001',
  '1f000000-0000-4000-8000-000000000001',
  role.id,
  statement_timestamp() - interval '1 minute',
  '1f000000-0000-4000-8000-000000000001',
  'Phase 3 access contract fixture'
from private.roles as role
where role.organization_id = '00000000-0000-4000-8000-00000000f001'
  and role.role_key = 'moderator';

set local role authenticated;
select is((select role_keys from api.read_current_access_context()),
  array['moderator']::text[], 'active database role is returned');
select ok((select 'customers.read' = any(permission_keys)
  from api.read_current_access_context()), 'effective permitted capability is returned');
select ok(not (select 'ledger.read' = any(permission_keys)
  from api.read_current_access_context()), 'ungranted ledger capability is omitted');
select ok((select currency_code = 'EGP' and timezone_name = 'Africa/Cairo'
  from api.read_current_access_context()), 'organization currency and timezone are returned');
select ok((select generated_at is not null and profile_status = 'active'
  from api.read_current_access_context()), 'context includes status and freshness');
reset role;

update private.user_roles
set effective_to = statement_timestamp() - interval '1 second'
where user_id = '1f000000-0000-4000-8000-000000000001';

set local role authenticated;
select is((select cardinality(role_keys) from api.read_current_access_context()), 0,
  'expired role disappears without relying on a stale client claim');
select is((select cardinality(permission_keys) from api.read_current_access_context()), 0,
  'permissions disappear when the role expires');
reset role;

select * from finish();
rollback;
