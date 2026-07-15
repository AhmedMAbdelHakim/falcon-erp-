create table public.organizations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_code text not null,
  display_name text not null,
  legal_name text,
  currency_code text not null default 'EGP',
  timezone_name text not null default 'Africa/Cairo',
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint organizations_code_format_chk
    check (organization_code ~ '^[a-z][a-z0-9_]{1,31}$'),
  constraint organizations_display_name_not_blank_chk
    check (btrim(display_name) <> ''),
  constraint organizations_legal_name_not_blank_chk
    check (legal_name is null or btrim(legal_name) <> ''),
  constraint organizations_currency_code_chk
    check (currency_code = 'EGP'),
  constraint organizations_timezone_name_chk
    check (timezone_name = 'Africa/Cairo'),
  constraint organizations_code_uk unique (organization_code)
);

comment on table public.organizations is
  'Organization boundary. V1 seeds one active Falcon organization in EGP and Africa/Cairo.';
comment on column public.organizations.currency_code is
  'ISO 4217 code. V1 is constrained to EGP; monetary amounts are bigint minor units elsewhere.';

create unique index organizations_one_default_uidx
  on public.organizations (is_default)
  where is_default;
create index organizations_created_by_idx on public.organizations (created_by);

create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function private.set_updated_at();

create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  display_name text not null,
  status public.user_status not null default 'pending',
  employee_reference text,
  activated_at timestamptz,
  activated_by uuid references auth.users(id) on delete set null,
  suspended_at timestamptz,
  suspended_by uuid references auth.users(id) on delete set null,
  status_reason text,
  last_seen_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint profiles_display_name_not_blank_chk check (btrim(display_name) <> ''),
  constraint profiles_employee_reference_not_blank_chk
    check (employee_reference is null or btrim(employee_reference) <> ''),
  constraint profiles_status_reason_not_blank_chk
    check (status_reason is null or btrim(status_reason) <> ''),
  constraint profiles_active_state_chk check (
    (status = 'active' and activated_at is not null)
    or status <> 'active'
  ),
  constraint profiles_suspended_state_chk check (
    (status = 'suspended' and suspended_at is not null and status_reason is not null)
    or status <> 'suspended'
  ),
  constraint profiles_organization_id_id_uk unique (organization_id, id),
  constraint profiles_activated_by_org_fk
    foreign key (organization_id, activated_by)
    references public.profiles (organization_id, id) on delete restrict,
  constraint profiles_suspended_by_org_fk
    foreign key (organization_id, suspended_by)
    references public.profiles (organization_id, id) on delete restrict
);

comment on table public.profiles is
  'Application identity linked to auth.users. Status and database role assignments are authoritative; Auth user metadata is ignored for authorization.';

create index profiles_organization_status_idx
  on public.profiles (organization_id, status, id);
create index profiles_activated_by_idx on public.profiles (activated_by);
create index profiles_suspended_by_idx on public.profiles (suspended_by);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create table private.organization_finance_settings (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  version_no bigint not null,
  effective_from timestamptz not null,
  effective_to timestamptz,
  currency_code text not null default 'EGP',
  timezone_name text not null default 'Africa/Cairo',
  custom_deposit_bps integer not null default 5000,
  custom_shipping_prepaid_required boolean not null default true,
  moderator_max_discount_bps integer not null default 2000,
  discount_applies_to_shipping_by_default boolean not null default false,
  block_negative_margin_for_moderator boolean not null default true,
  partner_withdrawal_approval_threshold_minor bigint not null default 50000,
  withdrawal_aggregation_hours integer not null default 24,
  withdrawal_execution_enabled boolean not null default false,
  minimum_operating_capital_minor bigint,
  protected_liability_horizon_days integer,
  reserve_requirement_bps integer,
  future_profit_advance_cap_minor bigint,
  delivery_recognition_enabled boolean not null default false,
  delivery_evidence_policy jsonb,
  payroll_execution_enabled boolean not null default false,
  salary_window_start_day smallint not null default 1,
  salary_window_end_day smallint not null default 10,
  moderator_bonus_min_minor bigint not null default 50000,
  moderator_bonus_max_minor bigint not null default 300000,
  operations_bonus_min_minor bigint not null default 50000,
  operations_bonus_max_minor bigint not null default 200000,
  opening_balance_import_enabled boolean not null default false,
  approved_by uuid references auth.users(id) on delete set null,
  approval_reference_id uuid,
  approved_at timestamptz,
  change_reason text not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint organization_finance_settings_version_positive_chk check (version_no > 0),
  constraint organization_finance_settings_effective_range_chk
    check (effective_to is null or effective_to > effective_from),
  constraint organization_finance_settings_currency_chk check (currency_code = 'EGP'),
  constraint organization_finance_settings_timezone_chk check (timezone_name = 'Africa/Cairo'),
  constraint organization_finance_settings_custom_deposit_bps_chk
    check (custom_deposit_bps between 0 and 10000),
  constraint organization_finance_settings_discount_bps_chk
    check (moderator_max_discount_bps between 0 and 10000),
  constraint organization_finance_settings_withdrawal_threshold_chk
    check (partner_withdrawal_approval_threshold_minor >= 0),
  constraint organization_finance_settings_aggregation_hours_chk
    check (withdrawal_aggregation_hours between 1 and 168),
  constraint organization_finance_settings_capital_chk
    check (minimum_operating_capital_minor is null or minimum_operating_capital_minor >= 0),
  constraint organization_finance_settings_horizon_chk
    check (protected_liability_horizon_days is null or protected_liability_horizon_days between 0 and 366),
  constraint organization_finance_settings_reserve_bps_chk
    check (reserve_requirement_bps is null or reserve_requirement_bps between 0 and 10000),
  constraint organization_finance_settings_advance_cap_chk
    check (future_profit_advance_cap_minor is null or future_profit_advance_cap_minor >= 0),
  constraint organization_finance_settings_delivery_policy_chk check (
    delivery_evidence_policy is null or jsonb_typeof(delivery_evidence_policy) = 'object'
  ),
  constraint organization_finance_settings_delivery_enablement_chk check (
    not delivery_recognition_enabled or delivery_evidence_policy is not null
  ),
  constraint organization_finance_settings_withdrawal_enablement_chk check (
    not withdrawal_execution_enabled
    or (
      minimum_operating_capital_minor is not null
      and protected_liability_horizon_days is not null
      and reserve_requirement_bps is not null
      and future_profit_advance_cap_minor is not null
    )
  ),
  constraint organization_finance_settings_salary_window_chk check (
    salary_window_start_day between 1 and 31
    and salary_window_end_day between salary_window_start_day and 31
  ),
  constraint organization_finance_settings_moderator_bonus_chk check (
    moderator_bonus_min_minor >= 0
    and moderator_bonus_max_minor >= moderator_bonus_min_minor
  ),
  constraint organization_finance_settings_operations_bonus_chk check (
    operations_bonus_min_minor >= 0
    and operations_bonus_max_minor >= operations_bonus_min_minor
  ),
  constraint organization_finance_settings_reason_not_blank_chk check (btrim(change_reason) <> ''),
  constraint organization_finance_settings_approval_pair_chk check (
    (approved_by is null and approved_at is null)
    or (approved_by is not null and approved_at is not null)
  ),
  constraint organization_finance_settings_org_version_uk unique (organization_id, version_no),
  constraint organization_finance_settings_approved_by_org_fk
    foreign key (organization_id, approved_by)
    references public.profiles (organization_id, id) on delete restrict,
  constraint organization_finance_settings_created_by_org_fk
    foreign key (organization_id, created_by)
    references public.profiles (organization_id, id) on delete restrict,
  constraint organization_finance_settings_no_overlap_excl exclude using gist (
    organization_id with =,
    tstzrange(effective_from, effective_to, '[)') with &&
  )
);

comment on table private.organization_finance_settings is
  'Versioned, non-overlapping financial policy snapshots. Production-sensitive commands default disabled until approved policy is present.';
comment on column private.organization_finance_settings.partner_withdrawal_approval_threshold_minor is
  'Signed bigint EGP minor units; 50000 means EGP 500.00.';
comment on column private.organization_finance_settings.approval_reference_id is
  'Approval request identifier. The FK is added after the approvals table exists to preserve migration order.';

create index organization_finance_settings_organization_idx
  on private.organization_finance_settings (organization_id, effective_from desc);
create index organization_finance_settings_approved_by_idx
  on private.organization_finance_settings (approved_by);
create index organization_finance_settings_created_by_idx
  on private.organization_finance_settings (created_by);

create trigger organization_finance_settings_set_updated_at
before update on private.organization_finance_settings
for each row execute function private.set_updated_at();

create or replace function private.protect_finance_settings_history()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.effective_to is not null
    or new.effective_to is null
    or old.organization_id <> new.organization_id
    or old.version_no <> new.version_no
    or old.effective_from <> new.effective_from
    or old.currency_code <> new.currency_code
    or old.timezone_name <> new.timezone_name
    or old.custom_deposit_bps <> new.custom_deposit_bps
    or old.custom_shipping_prepaid_required <> new.custom_shipping_prepaid_required
    or old.moderator_max_discount_bps <> new.moderator_max_discount_bps
    or old.discount_applies_to_shipping_by_default <> new.discount_applies_to_shipping_by_default
    or old.block_negative_margin_for_moderator <> new.block_negative_margin_for_moderator
    or old.partner_withdrawal_approval_threshold_minor <> new.partner_withdrawal_approval_threshold_minor
    or old.withdrawal_aggregation_hours <> new.withdrawal_aggregation_hours
    or old.withdrawal_execution_enabled <> new.withdrawal_execution_enabled
    or old.minimum_operating_capital_minor is distinct from new.minimum_operating_capital_minor
    or old.protected_liability_horizon_days is distinct from new.protected_liability_horizon_days
    or old.reserve_requirement_bps is distinct from new.reserve_requirement_bps
    or old.future_profit_advance_cap_minor is distinct from new.future_profit_advance_cap_minor
    or old.delivery_recognition_enabled <> new.delivery_recognition_enabled
    or old.delivery_evidence_policy is distinct from new.delivery_evidence_policy
    or old.payroll_execution_enabled <> new.payroll_execution_enabled
    or old.salary_window_start_day <> new.salary_window_start_day
    or old.salary_window_end_day <> new.salary_window_end_day
    or old.moderator_bonus_min_minor <> new.moderator_bonus_min_minor
    or old.moderator_bonus_max_minor <> new.moderator_bonus_max_minor
    or old.operations_bonus_min_minor <> new.operations_bonus_min_minor
    or old.operations_bonus_max_minor <> new.operations_bonus_max_minor
    or old.opening_balance_import_enabled <> new.opening_balance_import_enabled
    or old.approved_by is distinct from new.approved_by
    or old.approval_reference_id is distinct from new.approval_reference_id
    or old.approved_at is distinct from new.approved_at
    or old.change_reason <> new.change_reason
    or old.created_by is distinct from new.created_by
    or old.created_at <> new.created_at then
    raise exception using
      errcode = '55000',
      message = 'Financial setting versions are immutable except for closing an open effective range';
  end if;

  return new;
end;
$$;

revoke all on function private.protect_finance_settings_history()
  from public, anon, authenticated;

create trigger organization_finance_settings_protect_history
before update on private.organization_finance_settings
for each row execute function private.protect_finance_settings_history();

create table private.roles (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  role_key text not null,
  display_name text not null,
  description text,
  is_system boolean not null default true,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint roles_key_format_chk check (role_key ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint roles_supported_system_role_chk check (
    not is_system or role_key in (
      'super_admin', 'partner', 'finance_manager', 'operations',
      'moderator', 'auditor', 'read_only'
    )
  ),
  constraint roles_display_name_not_blank_chk check (btrim(display_name) <> ''),
  constraint roles_description_not_blank_chk check (description is null or btrim(description) <> ''),
  constraint roles_organization_role_key_uk unique (organization_id, role_key),
  constraint roles_organization_id_id_uk unique (organization_id, id),
  constraint roles_created_by_org_fk
    foreign key (organization_id, created_by)
    references public.profiles (organization_id, id) on delete restrict
);

comment on table private.roles is
  'Organization-scoped RBAC roles. super_admin does not implicitly grant financial command capabilities.';

create index roles_organization_active_idx
  on private.roles (organization_id, role_key)
  where is_active;
create index roles_created_by_idx on private.roles (created_by);

create trigger roles_set_updated_at
before update on private.roles
for each row execute function private.set_updated_at();

create table private.permissions (
  id uuid primary key default extensions.gen_random_uuid(),
  permission_key text not null,
  description text not null,
  is_sensitive boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint permissions_key_format_chk
    check (permission_key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  constraint permissions_description_not_blank_chk check (btrim(description) <> ''),
  constraint permissions_permission_key_uk unique (permission_key)
);

comment on table private.permissions is
  'Global capability catalog. Authorization uses current database assignments, never user-editable JWT metadata.';

create trigger permissions_set_updated_at
before update on private.permissions
for each row execute function private.set_updated_at();

create table private.role_permissions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  role_id uuid not null,
  permission_id uuid not null references private.permissions(id) on delete restrict,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default statement_timestamp(),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  revoke_reason text,
  constraint role_permissions_role_org_fk
    foreign key (organization_id, role_id)
    references private.roles (organization_id, id) on delete restrict,
  constraint role_permissions_revocation_chk check (
    (revoked_at is null and revoked_by is null and revoke_reason is null)
    or (revoked_at is not null and revoke_reason is not null and btrim(revoke_reason) <> '')
  ),
  constraint role_permissions_grant_before_revoke_chk
    check (revoked_at is null or revoked_at >= granted_at),
  constraint role_permissions_grant_uk unique (organization_id, role_id, permission_id, granted_at),
  constraint role_permissions_granted_by_org_fk
    foreign key (organization_id, granted_by)
    references public.profiles (organization_id, id) on delete restrict,
  constraint role_permissions_revoked_by_org_fk
    foreign key (organization_id, revoked_by)
    references public.profiles (organization_id, id) on delete restrict
);

comment on table private.role_permissions is
  'Append-preserving role capability grants. Revocation timestamps take effect immediately.';

create unique index role_permissions_one_current_grant_uidx
  on private.role_permissions (organization_id, role_id, permission_id)
  where revoked_at is null;
create index role_permissions_role_id_idx on private.role_permissions (role_id);
create index role_permissions_permission_id_idx on private.role_permissions (permission_id);
create index role_permissions_granted_by_idx on private.role_permissions (granted_by);
create index role_permissions_revoked_by_idx on private.role_permissions (revoked_by);

create table private.user_roles (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  user_id uuid not null,
  role_id uuid not null,
  effective_from timestamptz not null default statement_timestamp(),
  effective_to timestamptz,
  assigned_by uuid references auth.users(id) on delete set null,
  assignment_reason text not null,
  revoked_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  revocation_reason text,
  created_at timestamptz not null default statement_timestamp(),
  constraint user_roles_profile_org_fk
    foreign key (organization_id, user_id)
    references public.profiles (organization_id, id) on delete restrict,
  constraint user_roles_role_org_fk
    foreign key (organization_id, role_id)
    references private.roles (organization_id, id) on delete restrict,
  constraint user_roles_assigned_by_org_fk
    foreign key (organization_id, assigned_by)
    references public.profiles (organization_id, id) on delete restrict,
  constraint user_roles_revoked_by_org_fk
    foreign key (organization_id, revoked_by)
    references public.profiles (organization_id, id) on delete restrict,
  constraint user_roles_effective_range_chk
    check (effective_to is null or effective_to > effective_from),
  constraint user_roles_assignment_reason_not_blank_chk check (btrim(assignment_reason) <> ''),
  constraint user_roles_revocation_chk check (
    (revoked_at is null and revoked_by is null and revocation_reason is null)
    or (
      revoked_at is not null
      and revoked_at >= effective_from
      and revocation_reason is not null
      and btrim(revocation_reason) <> ''
    )
  ),
  constraint user_roles_revoke_within_effective_range_chk check (
    revoked_at is null or effective_to is null or effective_to <= revoked_at
  ),
  constraint user_roles_no_overlap_excl exclude using gist (
    organization_id with =,
    user_id with =,
    role_id with =,
    tstzrange(effective_from, effective_to, '[)') with &&
  )
);

comment on table private.user_roles is
  'Effective-dated, organization-scoped user role assignments. Inactive profiles, expired roles, and revoked capabilities authorize nothing.';

create index user_roles_user_effective_idx
  on private.user_roles (organization_id, user_id, effective_from, effective_to);
create index user_roles_role_id_idx on private.user_roles (role_id);
create index user_roles_assigned_by_idx on private.user_roles (assigned_by);
create index user_roles_revoked_by_idx on private.user_roles (revoked_by);

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_organization_id uuid;
  v_display_name text;
begin
  select o.id
    into v_organization_id
  from public.organizations as o
  where o.is_default
    and o.is_active;

  if v_organization_id is null then
    raise exception using
      errcode = '55000',
      message = 'Falcon organization is not provisioned';
  end if;

  v_display_name := coalesce(nullif(split_part(new.email, '@', 1), ''), 'Pending user');

  insert into public.profiles (id, organization_id, display_name, status)
  values (new.id, v_organization_id, v_display_name, 'pending');

  return new;
end;
$$;

comment on function private.handle_new_auth_user() is
  'Creates a pending least-privilege profile for the default organization. It deliberately ignores raw_user_meta_data and raw_app_meta_data.';
revoke all on function private.handle_new_auth_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_auth_user();

create or replace function private.current_organization_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.organization_id
  from public.profiles as p
  join public.organizations as o on o.id = p.organization_id
  where p.id = (select auth.uid())
    and p.status = 'active'
    and o.is_active
$$;

comment on function private.current_organization_id() is
  'Returns the active caller organization from database state; returns null for anonymous or inactive users.';
revoke all on function private.current_organization_id() from public, anon, authenticated;

create or replace function private.has_permission(
  p_organization_id uuid,
  p_permission_key text
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
      from public.profiles as p
      join public.organizations as o
        on o.id = p.organization_id
       and o.is_active
      join private.user_roles as ur
        on ur.organization_id = p.organization_id
       and ur.user_id = p.id
       and ur.effective_from <= statement_timestamp()
       and (ur.effective_to is null or ur.effective_to > statement_timestamp())
       and ur.revoked_at is null
      join private.roles as r
        on r.organization_id = ur.organization_id
       and r.id = ur.role_id
       and r.is_active
      join private.role_permissions as rp
        on rp.organization_id = r.organization_id
       and rp.role_id = r.id
       and rp.revoked_at is null
      join private.permissions as perm
        on perm.id = rp.permission_id
       and perm.is_active
      where p.id = (select auth.uid())
        and p.organization_id = p_organization_id
        and p.status = 'active'
        and perm.permission_key = p_permission_key
    )
$$;

comment on function private.has_permission(uuid, text) is
  'Authoritative RBAC capability check using active database assignments and the current Auth identity.';
revoke all on function private.has_permission(uuid, text) from public, anon, authenticated;

create or replace function private.require_permission(
  p_organization_id uuid,
  p_permission_key text
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if not private.has_permission(p_organization_id, p_permission_key) then
    raise exception using errcode = '42501', message = 'Permission denied';
  end if;
end;
$$;

comment on function private.require_permission(uuid, text) is
  'Raises a sanitized authorization error when the current user lacks a current database capability.';
revoke all on function private.require_permission(uuid, text) from public, anon, authenticated;

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table private.organization_finance_settings enable row level security;
alter table private.roles enable row level security;
alter table private.permissions enable row level security;
alter table private.role_permissions enable row level security;
alter table private.user_roles enable row level security;

revoke all on table public.organizations from public, anon, authenticated;
revoke all on table public.profiles from public, anon, authenticated;
revoke all on table private.organization_finance_settings from public, anon, authenticated;
revoke all on table private.roles from public, anon, authenticated;
revoke all on table private.permissions from public, anon, authenticated;
revoke all on table private.role_permissions from public, anon, authenticated;
revoke all on table private.user_roles from public, anon, authenticated;
