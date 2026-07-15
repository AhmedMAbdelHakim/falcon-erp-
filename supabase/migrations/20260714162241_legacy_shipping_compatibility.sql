-- Organization-scoped compatibility surface for the pre-Phase-2 shipping-label app.
-- supabase/schema.sql is historical input and must not be executed beside migrations.

alter table public.profiles
  add column full_name text generated always as (display_name) stored,
  add column role text not null default 'staff';

alter table public.profiles
  add constraint profiles_legacy_role_check check (role in ('admin', 'staff'));

comment on column public.profiles.role is
  'Read-only compatibility label derived from authoritative private.user_roles; never used for authorization.';

create or replace function private.sync_legacy_profile_role(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles as p
  set role = case when exists (
    select 1
    from private.user_roles as ur
    join private.roles as r
      on r.organization_id = ur.organization_id
     and r.id = ur.role_id
    where ur.user_id = p_user_id
      and ur.organization_id = p.organization_id
      and ur.revoked_at is null
      and ur.effective_from <= statement_timestamp()
      and (ur.effective_to is null or ur.effective_to > statement_timestamp())
      and r.is_active
      and r.role_key in ('super_admin', 'finance_manager')
  ) then 'admin' else 'staff' end
  where p.id = p_user_id;
end;
$$;

revoke all on function private.sync_legacy_profile_role(uuid) from public, anon, authenticated;

create or replace function private.sync_legacy_profile_role_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.sync_legacy_profile_role(coalesce(new.user_id, old.user_id));
  return coalesce(new, old);
end;
$$;

revoke all on function private.sync_legacy_profile_role_trigger() from public, anon, authenticated;

create trigger user_roles_sync_legacy_profile_role
after insert or update or delete on private.user_roles
for each row execute function private.sync_legacy_profile_role_trigger();

do $$
declare
  v_user_id uuid;
begin
  for v_user_id in select id from public.profiles loop
    perform private.sync_legacy_profile_role(v_user_id);
  end loop;
end;
$$;

create or replace function private.protect_profile_compatibility_columns()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_expected_role text;
begin
  if new.organization_id <> old.organization_id then
    raise exception using errcode = '55000', message = 'PROFILE_ORGANIZATION_IMMUTABLE';
  end if;

  select case when exists (
    select 1
    from private.user_roles as ur
    join private.roles as r
      on r.organization_id = ur.organization_id and r.id = ur.role_id
    where ur.user_id = old.id
      and ur.organization_id = old.organization_id
      and ur.revoked_at is null
      and ur.effective_from <= statement_timestamp()
      and (ur.effective_to is null or ur.effective_to > statement_timestamp())
      and r.is_active
      and r.role_key in ('super_admin', 'finance_manager')
  ) then 'admin' else 'staff' end into v_expected_role;

  if new.role <> v_expected_role then
    raise exception using errcode = '42501', message = 'PROFILE_ROLE_IS_DERIVED';
  end if;
  return new;
end;
$$;

revoke all on function private.protect_profile_compatibility_columns() from public, anon, authenticated;

create trigger profiles_protect_legacy_compatibility
before update on public.profiles
for each row execute function private.protect_profile_compatibility_columns();

create table public.governorate_shipping_fees (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null default private.current_organization_id()
    references public.organizations(id) on delete restrict,
  governorate text not null,
  shipping_fee numeric(12, 2) not null default 0,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint governorate_shipping_fees_org_id_key unique (organization_id, id),
  constraint governorate_shipping_fees_org_name_key unique (organization_id, governorate),
  constraint governorate_shipping_fees_name_check check (btrim(governorate) <> ''),
  constraint governorate_shipping_fees_nonnegative_check check (shipping_fee >= 0)
);

create table public.shipping_settings (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null default private.current_organization_id()
    references public.organizations(id) on delete restrict,
  key text not null,
  value jsonb not null,
  updated_at timestamptz not null default statement_timestamp(),
  created_at timestamptz not null default statement_timestamp(),
  constraint shipping_settings_org_id_key unique (organization_id, id),
  constraint shipping_settings_org_key_key unique (organization_id, key),
  constraint shipping_settings_key_check check (key ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint shipping_settings_value_check check (jsonb_typeof(value) = 'object')
);

create table public.labels (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null default private.current_organization_id()
    references public.organizations(id) on delete restrict,
  tracking_number text not null,
  customer_name text not null,
  primary_phone text not null,
  secondary_phone text,
  governorate text not null,
  city text not null,
  address text not null,
  landmark text,
  product_name text,
  contents text not null,
  pieces integer not null default 1,
  weight numeric(12, 3) not null default 1,
  cod_amount numeric(14, 2) not null default 0,
  shipping_fee numeric(12, 2) not null default 0,
  payment_method text not null default 'COD',
  instructions text,
  internal_notes text,
  shipper_id text not null default '6525',
  store_name text not null default 'Falcon store',
  product_type text not null default 'COD',
  status text not null default 'Ready',
  is_printed boolean not null default false,
  printed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint labels_org_id_key unique (organization_id, id),
  constraint labels_org_tracking_key unique (organization_id, tracking_number),
  constraint labels_created_by_org_fk foreign key (organization_id, created_by)
    references public.profiles(organization_id, id) on delete restrict,
  constraint labels_text_check check (
    btrim(tracking_number) <> '' and btrim(customer_name) <> ''
    and btrim(primary_phone) <> '' and btrim(governorate) <> ''
    and btrim(city) <> '' and btrim(address) <> '' and btrim(contents) <> ''
  ),
  constraint labels_quantities_check check (pieces > 0 and weight > 0),
  constraint labels_amounts_check check (cod_amount >= 0 and shipping_fee >= 0),
  constraint labels_payment_method_check check (payment_method in ('COD', 'Paid', 'Partial Deposit')),
  constraint labels_status_check check (status in ('Draft', 'Ready', 'Printed', 'Cancelled')),
  constraint labels_printed_state_check check (
    (is_printed and printed_at is not null and status in ('Printed', 'Cancelled'))
    or (not is_printed and printed_at is null)
  ),
  constraint labels_cancelled_state_check check (
    (status = 'Cancelled' and cancelled_at is not null and nullif(btrim(cancellation_reason), '') is not null)
    or (status <> 'Cancelled' and cancelled_at is null and cancellation_reason is null)
  )
);

comment on table public.labels is
  'Organization-scoped compatibility waybills for the legacy shipping-label UI; not the Phase-2 order or shipment accounting authority.';

create index labels_org_phone_idx on public.labels (organization_id, primary_phone);
create index labels_org_governorate_idx on public.labels (organization_id, governorate);
create index labels_org_status_created_idx on public.labels (organization_id, status, created_at desc);

create trigger governorate_shipping_fees_set_updated_at
before update on public.governorate_shipping_fees
for each row execute function private.set_updated_at();

create trigger shipping_settings_set_updated_at
before update on public.shipping_settings
for each row execute function private.set_updated_at();

create trigger labels_set_updated_at
before update on public.labels
for each row execute function private.set_updated_at();

create or replace function private.protect_legacy_shipping_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and new.organization_id <> old.organization_id then
    raise exception using errcode = '55000', message = 'ORGANIZATION_ID_IMMUTABLE';
  end if;
  if tg_table_name = 'labels' and tg_op = 'UPDATE' and new.created_by <> old.created_by then
    raise exception using errcode = '55000', message = 'LABEL_CREATOR_IMMUTABLE';
  end if;
  return new;
end;
$$;

revoke all on function private.protect_legacy_shipping_scope() from public, anon, authenticated;

create trigger labels_protect_scope
before update on public.labels
for each row execute function private.protect_legacy_shipping_scope();

create trigger shipping_settings_protect_scope
before update on public.shipping_settings
for each row execute function private.protect_legacy_shipping_scope();

create trigger governorate_shipping_fees_protect_scope
before update on public.governorate_shipping_fees
for each row execute function private.protect_legacy_shipping_scope();

alter table public.governorate_shipping_fees enable row level security;
alter table public.shipping_settings enable row level security;
alter table public.labels enable row level security;

create policy labels_select on public.labels for select to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'shipping_labels.read')
);

create policy labels_insert on public.labels for insert to authenticated
with check (
  organization_id = private.current_organization_id()
  and created_by = auth.uid()
  and private.has_permission(organization_id, 'shipping_labels.create')
);

create policy labels_update on public.labels for update to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'shipping_labels.update')
)
with check (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'shipping_labels.update')
);

create policy labels_delete on public.labels for delete to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'shipping_labels.delete')
);

create policy shipping_settings_select on public.shipping_settings for select to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'shipping_settings.read')
);

create policy shipping_settings_write on public.shipping_settings for all to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'shipping_settings.manage')
)
with check (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'shipping_settings.manage')
);

create policy governorate_fees_select on public.governorate_shipping_fees for select to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'shipping_settings.read')
);

create policy governorate_fees_write on public.governorate_shipping_fees for all to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'shipping_settings.manage')
)
with check (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'shipping_settings.manage')
);

revoke all on table public.governorate_shipping_fees from public, anon, authenticated;
revoke all on table public.shipping_settings from public, anon, authenticated;
revoke all on table public.labels from public, anon, authenticated;
grant select, insert, update, delete on table public.labels to authenticated;
grant select, insert, update, delete on table public.governorate_shipping_fees to authenticated;
grant select, insert, update, delete on table public.shipping_settings to authenticated;

insert into private.permissions (id, permission_key, description, is_sensitive)
select md5('falcon-permission:' || permission_key)::uuid, permission_key, description, is_sensitive
from (values
  ('shipping_labels.read', 'Read legacy shipping labels', false),
  ('shipping_labels.create', 'Create legacy shipping labels', false),
  ('shipping_labels.update', 'Update and print legacy shipping labels', true),
  ('shipping_labels.delete', 'Permanently delete legacy shipping labels', true),
  ('shipping_settings.read', 'Read legacy shipping settings and fees', false),
  ('shipping_settings.manage', 'Manage legacy shipping settings and fees', true)
) as compatibility_permissions(permission_key, description, is_sensitive)
on conflict (permission_key) do nothing;
