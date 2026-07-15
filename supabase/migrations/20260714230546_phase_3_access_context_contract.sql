create or replace function private.read_current_access_context()
returns table (
  user_id uuid,
  organization_id uuid,
  organization_code text,
  organization_name text,
  display_name text,
  profile_status public.user_status,
  currency_code text,
  timezone_name text,
  role_keys text[],
  permission_keys text[],
  generated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    join public.organizations as organization
      on organization.id = profile.organization_id
     and organization.is_active
    where profile.id = v_user_id
      and profile.status = 'active'
  ) then
    raise exception using errcode = '42501', message = 'Account is not active';
  end if;

  return query
  select
    profile.id,
    organization.id,
    organization.organization_code,
    organization.display_name,
    profile.display_name,
    profile.status,
    organization.currency_code,
    organization.timezone_name,
    coalesce(
      array_agg(distinct role.role_key order by role.role_key)
        filter (where role.role_key is not null),
      '{}'::text[]
    ),
    coalesce(
      array_agg(distinct permission.permission_key order by permission.permission_key)
        filter (where permission.permission_key is not null),
      '{}'::text[]
    ),
    statement_timestamp()
  from public.profiles as profile
  join public.organizations as organization
    on organization.id = profile.organization_id
   and organization.is_active
  left join private.user_roles as user_role
    on user_role.organization_id = profile.organization_id
   and user_role.user_id = profile.id
   and user_role.effective_from <= statement_timestamp()
   and (user_role.effective_to is null or user_role.effective_to > statement_timestamp())
   and user_role.revoked_at is null
  left join private.roles as role
    on role.organization_id = user_role.organization_id
   and role.id = user_role.role_id
   and role.is_active
  left join private.role_permissions as role_permission
    on role_permission.organization_id = role.organization_id
   and role_permission.role_id = role.id
   and role_permission.revoked_at is null
  left join private.permissions as permission
    on permission.id = role_permission.permission_id
   and permission.is_active
  where profile.id = v_user_id
    and profile.status = 'active'
  group by
    profile.id,
    organization.id,
    organization.organization_code,
    organization.display_name,
    profile.display_name,
    profile.status,
    organization.currency_code,
    organization.timezone_name;
end;
$$;

create or replace function api.read_current_access_context()
returns table (
  user_id uuid,
  organization_id uuid,
  organization_code text,
  organization_name text,
  display_name text,
  profile_status public.user_status,
  currency_code text,
  timezone_name text,
  role_keys text[],
  permission_keys text[],
  generated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.read_current_access_context()
$$;

revoke all on function private.read_current_access_context()
  from public, anon, authenticated;
grant execute on function private.read_current_access_context()
  to authenticated;

revoke all on function api.read_current_access_context()
  from public, anon, authenticated;
grant execute on function api.read_current_access_context()
  to authenticated;

comment on function api.read_current_access_context() is
  'Returns the caller current database-backed organization, active roles, and effective permissions for Phase 3 presentation guards. Auth metadata is not consulted and backend authorization remains authoritative.';
