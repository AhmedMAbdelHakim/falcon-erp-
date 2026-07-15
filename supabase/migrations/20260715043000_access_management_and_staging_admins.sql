create or replace function private.has_role(
  p_organization_id uuid,
  p_role_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.profiles as profile
      join private.user_roles as user_role
        on user_role.organization_id = profile.organization_id
       and user_role.user_id = profile.id
       and user_role.effective_from <= statement_timestamp()
       and (user_role.effective_to is null or user_role.effective_to > statement_timestamp())
       and user_role.revoked_at is null
      join private.roles as role
        on role.organization_id = user_role.organization_id
       and role.id = user_role.role_id
       and role.is_active
      where profile.id = (select auth.uid())
        and profile.organization_id = p_organization_id
        and profile.status = 'active'
        and role.role_key = p_role_key
    )
$$;

revoke all on function private.has_role(uuid, text) from public, anon, authenticated;

create or replace function private.require_super_admin(p_organization_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.has_role(p_organization_id, 'super_admin') then
    raise exception using errcode = '42501', message = 'Super admin role required';
  end if;
end;
$$;

revoke all on function private.require_super_admin(uuid) from public, anon, authenticated;

create or replace function private.list_access_roles(p_organization_id uuid)
returns table (
  role_id uuid,
  role_key text,
  display_name text,
  description text,
  permission_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_super_admin(p_organization_id);

  return query
  select
    role.id,
    role.role_key,
    role.display_name,
    role.description,
    count(permission.id) filter (where permission.id is not null)
  from private.roles as role
  left join private.role_permissions as role_permission
    on role_permission.organization_id = role.organization_id
   and role_permission.role_id = role.id
   and role_permission.revoked_at is null
  left join private.permissions as permission
    on permission.id = role_permission.permission_id
   and permission.is_active
  where role.organization_id = p_organization_id
    and role.is_active
  group by role.id, role.role_key, role.display_name, role.description
  order by role.role_key;
end;
$$;

create or replace function private.list_access_users(p_organization_id uuid)
returns table (
  user_id uuid,
  email text,
  display_name text,
  profile_status public.user_status,
  role_keys text[],
  permission_count bigint,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_super_admin(p_organization_id);

  return query
  select
    profile.id,
    auth_user.email::text,
    profile.display_name,
    profile.status,
    coalesce(
      array_agg(distinct role.role_key order by role.role_key)
        filter (where role.role_key is not null),
      '{}'::text[]
    ),
    count(distinct permission.permission_key),
    profile.updated_at
  from public.profiles as profile
  join auth.users as auth_user
    on auth_user.id = profile.id
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
  where profile.organization_id = p_organization_id
  group by profile.id, auth_user.email, profile.display_name, profile.status, profile.updated_at
  order by profile.display_name, auth_user.email;
end;
$$;

create or replace function private.update_user_roles(
  p_organization_id uuid,
  p_user_id uuid,
  p_role_keys text[]
)
returns table (
  user_id uuid,
  email text,
  display_name text,
  profile_status public.user_status,
  role_keys text[],
  permission_count bigint,
  updated_at timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_normalized_role_keys text[];
  v_active_super_admin_count integer;
begin
  perform private.require_super_admin(p_organization_id);

  if v_actor_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.profiles as profile
    where profile.organization_id = p_organization_id
      and profile.id = p_user_id
  ) then
    raise exception using errcode = '23503', message = 'Target user is not in this organization';
  end if;

  select array_agg(distinct role_key order by role_key)
    into v_normalized_role_keys
  from unnest(coalesce(p_role_keys, '{}'::text[])) as role_key
  where role_key is not null
    and btrim(role_key) <> '';

  v_normalized_role_keys := coalesce(v_normalized_role_keys, '{}'::text[]);

  if exists (
    select 1
    from unnest(v_normalized_role_keys) as requested(role_key)
    where not exists (
      select 1
      from private.roles as role
      where role.organization_id = p_organization_id
        and role.role_key = requested.role_key
        and role.is_active
    )
  ) then
    raise exception using errcode = '22023', message = 'Unknown or inactive role requested';
  end if;

  select count(distinct user_role.user_id)
    into v_active_super_admin_count
  from private.user_roles as user_role
  join private.roles as role
    on role.organization_id = user_role.organization_id
   and role.id = user_role.role_id
   and role.role_key = 'super_admin'
   and role.is_active
  join public.profiles as profile
    on profile.organization_id = user_role.organization_id
   and profile.id = user_role.user_id
   and profile.status = 'active'
  where user_role.organization_id = p_organization_id
    and user_role.effective_from <= statement_timestamp()
    and (user_role.effective_to is null or user_role.effective_to > statement_timestamp())
    and user_role.revoked_at is null
    and user_role.user_id <> p_user_id;

  if not ('super_admin' = any(v_normalized_role_keys))
     and coalesce(v_active_super_admin_count, 0) = 0 then
    raise exception using errcode = '23514', message = 'At least one active super admin must remain';
  end if;

  update private.user_roles as user_role
     set revoked_at = statement_timestamp(),
         revoked_by = v_actor_id,
         revocation_reason = 'Updated from Falcon access management',
         effective_to = least(coalesce(user_role.effective_to, statement_timestamp()), statement_timestamp())
  from private.roles as role
  where role.organization_id = user_role.organization_id
    and role.id = user_role.role_id
    and user_role.organization_id = p_organization_id
    and user_role.user_id = p_user_id
    and user_role.effective_from <= statement_timestamp()
    and (user_role.effective_to is null or user_role.effective_to > statement_timestamp())
    and user_role.revoked_at is null
    and not (role.role_key = any(v_normalized_role_keys));

  insert into private.user_roles (
    organization_id,
    user_id,
    role_id,
    effective_from,
    assigned_by,
    assignment_reason
  )
  select
    p_organization_id,
    p_user_id,
    role.id,
    statement_timestamp(),
    v_actor_id,
    'Assigned from Falcon access management'
  from private.roles as role
  where role.organization_id = p_organization_id
    and role.role_key = any(v_normalized_role_keys)
    and role.is_active
    and not exists (
      select 1
      from private.user_roles as existing_role
      where existing_role.organization_id = p_organization_id
        and existing_role.user_id = p_user_id
        and existing_role.role_id = role.id
        and existing_role.effective_from <= statement_timestamp()
        and (existing_role.effective_to is null or existing_role.effective_to > statement_timestamp())
        and existing_role.revoked_at is null
    );

  update public.profiles as profile
     set status = 'active',
         activated_at = coalesce(profile.activated_at, statement_timestamp()),
         activated_by = coalesce(profile.activated_by, v_actor_id)
   where profile.organization_id = p_organization_id
     and profile.id = p_user_id
     and profile.status = 'pending';

  return query
  select *
  from private.list_access_users(p_organization_id) as access_user
  where access_user.user_id = p_user_id;
end;
$$;

create or replace function api.list_access_roles(p_organization_id uuid)
returns table (
  role_id uuid,
  role_key text,
  display_name text,
  description text,
  permission_count bigint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.list_access_roles(p_organization_id)
$$;

create or replace function api.list_access_users(p_organization_id uuid)
returns table (
  user_id uuid,
  email text,
  display_name text,
  profile_status public.user_status,
  role_keys text[],
  permission_count bigint,
  updated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.list_access_users(p_organization_id)
$$;

create or replace function api.update_user_roles(
  p_organization_id uuid,
  p_user_id uuid,
  p_role_keys text[]
)
returns table (
  user_id uuid,
  email text,
  display_name text,
  profile_status public.user_status,
  role_keys text[],
  permission_count bigint,
  updated_at timestamptz
)
language sql
volatile
security invoker
set search_path = ''
as $$
  select * from private.update_user_roles(p_organization_id, p_user_id, p_role_keys)
$$;

revoke all on function private.list_access_roles(uuid) from public, anon, authenticated;
revoke all on function private.list_access_users(uuid) from public, anon, authenticated;
revoke all on function private.update_user_roles(uuid, uuid, text[]) from public, anon, authenticated;

grant execute on function private.list_access_roles(uuid) to authenticated;
grant execute on function private.list_access_users(uuid) to authenticated;
grant execute on function private.update_user_roles(uuid, uuid, text[]) to authenticated;

revoke all on function api.list_access_roles(uuid) from public, anon, authenticated;
revoke all on function api.list_access_users(uuid) from public, anon, authenticated;
revoke all on function api.update_user_roles(uuid, uuid, text[]) from public, anon, authenticated;

grant execute on function api.list_access_roles(uuid) to authenticated;
grant execute on function api.list_access_users(uuid) to authenticated;
grant execute on function api.update_user_roles(uuid, uuid, text[]) to authenticated;

comment on function api.list_access_roles(uuid) is
  'Super-admin-only list of active organization roles and their current permission counts.';
comment on function api.list_access_users(uuid) is
  'Super-admin-only list of organization user profiles, Auth emails, active roles, and permission counts.';
comment on function api.update_user_roles(uuid, uuid, text[]) is
  'Super-admin-only replacement of a user current role assignments while preserving at least one active super admin.';

with staging_user(user_id, email, display_name, role_keys) as (
  values
    ('0c5df41b-f056-444f-9146-d4658f8c5f2c'::uuid, 'qa-admin@falcon.test', 'QA Administrator', array['super_admin']::text[]),
    ('3d000000-0000-4000-8000-000000000101'::uuid, 'finance-admin@falcon.test', 'مدير مالي', array['finance_manager']::text[]),
    ('3d000000-0000-4000-8000-000000000102'::uuid, 'operations-admin@falcon.test', 'مسؤول التشغيل والمخزون', array['operations']::text[]),
    ('3d000000-0000-4000-8000-000000000103'::uuid, 'moderator-admin@falcon.test', 'مشرف المبيعات والعملاء', array['moderator']::text[]),
    ('3d000000-0000-4000-8000-000000000104'::uuid, 'auditor-admin@falcon.test', 'مراجع رقابي', array['auditor']::text[]),
    ('3d000000-0000-4000-8000-000000000105'::uuid, 'readonly-admin@falcon.test', 'مشاهدة فقط', array['read_only']::text[])
),
upsert_auth as (
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    is_sso_user,
    is_anonymous
  )
  select
    '00000000-0000-0000-0000-000000000000',
    staging_user.user_id,
    'authenticated',
    'authenticated',
    staging_user.email,
    extensions.crypt('FalconQA-2026', extensions.gen_salt('bf')),
    statement_timestamp(),
    jsonb_build_object('provider', 'email', 'providers', array['email']),
    '{}'::jsonb,
    statement_timestamp(),
    statement_timestamp(),
    '',
    '',
    '',
    '',
    false,
    false
  from staging_user
  on conflict (id) do update
    set email = excluded.email,
        encrypted_password = excluded.encrypted_password,
        email_confirmed_at = excluded.email_confirmed_at,
        raw_app_meta_data = excluded.raw_app_meta_data,
        updated_at = statement_timestamp()
  returning id, email
),
upsert_identity as (
  insert into auth.identities (
    provider_id,
    user_id,
    identity_data,
    provider,
    last_sign_in_at,
    created_at,
    updated_at
  )
  select
    staging_user.user_id::text,
    staging_user.user_id,
    jsonb_build_object(
      'sub', staging_user.user_id::text,
      'email', staging_user.email,
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    statement_timestamp(),
    statement_timestamp(),
    statement_timestamp()
  from staging_user
  on conflict (provider_id, provider) do update
    set identity_data = excluded.identity_data,
        updated_at = statement_timestamp()
  returning user_id
),
upsert_profile as (
  insert into public.profiles (
    id,
    organization_id,
    display_name,
    status,
    activated_at,
    activated_by,
    created_at,
    updated_at
  )
  select
    staging_user.user_id,
    '00000000-0000-4000-8000-00000000f001',
    staging_user.display_name,
    'active',
    statement_timestamp(),
    '0c5df41b-f056-444f-9146-d4658f8c5f2c',
    statement_timestamp(),
    statement_timestamp()
  from staging_user
  on conflict (id) do update
    set organization_id = excluded.organization_id,
        display_name = excluded.display_name,
        status = 'active',
        activated_at = coalesce(public.profiles.activated_at, excluded.activated_at),
        activated_by = coalesce(public.profiles.activated_by, excluded.activated_by),
        updated_at = statement_timestamp()
  returning id
),
revoke_stale as (
  update private.user_roles as user_role
     set revoked_at = statement_timestamp(),
         revoked_by = '0c5df41b-f056-444f-9146-d4658f8c5f2c',
         revocation_reason = 'Staging access baseline refreshed',
         effective_to = least(coalesce(user_role.effective_to, statement_timestamp()), statement_timestamp())
  from staging_user, private.roles as role
  where user_role.organization_id = '00000000-0000-4000-8000-00000000f001'
    and user_role.user_id = staging_user.user_id
    and role.organization_id = user_role.organization_id
    and role.id = user_role.role_id
    and user_role.effective_from <= statement_timestamp()
    and (user_role.effective_to is null or user_role.effective_to > statement_timestamp())
    and user_role.revoked_at is null
    and not (role.role_key = any(staging_user.role_keys))
  returning user_role.id
)
insert into private.user_roles (
  organization_id,
  user_id,
  role_id,
  effective_from,
  assigned_by,
  assignment_reason
)
select
  '00000000-0000-4000-8000-00000000f001',
  staging_user.user_id,
  role.id,
  statement_timestamp(),
  '0c5df41b-f056-444f-9146-d4658f8c5f2c',
  'Staging access baseline'
from staging_user
join private.roles as role
  on role.organization_id = '00000000-0000-4000-8000-00000000f001'
 and role.role_key = any(staging_user.role_keys)
where not exists (
  select 1
  from private.user_roles as user_role
  where user_role.organization_id = '00000000-0000-4000-8000-00000000f001'
    and user_role.user_id = staging_user.user_id
    and user_role.role_id = role.id
    and user_role.effective_from <= statement_timestamp()
    and (user_role.effective_to is null or user_role.effective_to > statement_timestamp())
    and user_role.revoked_at is null
);

notify pgrst, 'reload schema';
