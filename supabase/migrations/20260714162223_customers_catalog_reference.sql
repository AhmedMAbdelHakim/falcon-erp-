create or replace function private.prevent_hard_delete()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception using errcode = '55000', message = 'Record must be archived, not deleted';
end;
$$;

comment on function private.prevent_hard_delete() is
  'Enforces archive/deactivate workflows for customer and catalog master data.';
revoke all on function private.prevent_hard_delete() from public, anon, authenticated;

create table public.customers (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  customer_number text not null,
  full_name text not null,
  phone_original text,
  phone_normalized text,
  alternate_phone_original text,
  alternate_phone_normalized text,
  assigned_to_user_id uuid,
  notes text,
  is_active boolean not null default true,
  archived_at timestamptz,
  archived_by uuid references auth.users(id) on delete set null,
  archive_reason text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint customers_assignee_org_fk
    foreign key (organization_id, assigned_to_user_id)
    references public.profiles (organization_id, id) on delete restrict,
  constraint customers_number_format_chk
    check (customer_number ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  constraint customers_name_not_blank_chk check (btrim(full_name) <> ''),
  constraint customers_phone_pair_chk check (
    (phone_original is null) = (phone_normalized is null)
    and (alternate_phone_original is null) = (alternate_phone_normalized is null)
  ),
  constraint customers_phone_original_not_blank_chk check (
    (phone_original is null or btrim(phone_original) <> '')
    and (alternate_phone_original is null or btrim(alternate_phone_original) <> '')
  ),
  constraint customers_phone_normalized_format_chk check (
    (phone_normalized is null or phone_normalized ~ '^\+[1-9][0-9]{7,14}$')
    and (alternate_phone_normalized is null or alternate_phone_normalized ~ '^\+[1-9][0-9]{7,14}$')
  ),
  constraint customers_distinct_phones_chk check (
    phone_normalized is null
    or alternate_phone_normalized is null
    or phone_normalized <> alternate_phone_normalized
  ),
  constraint customers_notes_not_blank_chk check (notes is null or btrim(notes) <> ''),
  constraint customers_archive_state_chk check (
    (archived_at is null and archived_by is null and archive_reason is null)
    or (archived_at is not null and not is_active and archive_reason is not null and btrim(archive_reason) <> '')
  ),
  constraint customers_organization_number_uk unique (organization_id, customer_number),
  constraint customers_organization_id_id_uk unique (organization_id, id)
);

comment on table public.customers is
  'Customer master. Original and normalized phones are retained separately; similar names never trigger an automatic merge.';

create unique index customers_active_phone_normalized_uidx
  on public.customers (organization_id, phone_normalized)
  where phone_normalized is not null and archived_at is null;
create unique index customers_active_alternate_phone_normalized_uidx
  on public.customers (organization_id, alternate_phone_normalized)
  where alternate_phone_normalized is not null and archived_at is null;
create index customers_assigned_to_idx
  on public.customers (organization_id, assigned_to_user_id, is_active);
create index customers_created_by_idx on public.customers (created_by);
create index customers_updated_by_idx on public.customers (updated_by);
create index customers_archived_by_idx on public.customers (archived_by);

create trigger customers_set_updated_at
before update on public.customers
for each row execute function private.set_updated_at();
create trigger customers_prevent_delete
before delete on public.customers
for each row execute function private.prevent_hard_delete();

create table public.customer_addresses (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  customer_id uuid not null,
  label text,
  recipient_name text not null,
  recipient_phone_original text,
  recipient_phone_normalized text,
  governorate text not null,
  city text not null,
  area text,
  address_line_1 text not null,
  address_line_2 text,
  landmark text,
  postal_code text,
  delivery_notes text,
  is_default boolean not null default false,
  is_active boolean not null default true,
  archived_at timestamptz,
  archived_by uuid references auth.users(id) on delete set null,
  archive_reason text,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint customer_addresses_customer_org_fk
    foreign key (organization_id, customer_id)
    references public.customers (organization_id, id) on delete restrict,
  constraint customer_addresses_label_not_blank_chk check (label is null or btrim(label) <> ''),
  constraint customer_addresses_recipient_not_blank_chk check (btrim(recipient_name) <> ''),
  constraint customer_addresses_phone_pair_chk check (
    (recipient_phone_original is null) = (recipient_phone_normalized is null)
  ),
  constraint customer_addresses_phone_original_not_blank_chk
    check (recipient_phone_original is null or btrim(recipient_phone_original) <> ''),
  constraint customer_addresses_phone_format_chk check (
    recipient_phone_normalized is null or recipient_phone_normalized ~ '^\+[1-9][0-9]{7,14}$'
  ),
  constraint customer_addresses_required_text_chk check (
    btrim(governorate) <> '' and btrim(city) <> '' and btrim(address_line_1) <> ''
  ),
  constraint customer_addresses_optional_text_chk check (
    (area is null or btrim(area) <> '')
    and (address_line_2 is null or btrim(address_line_2) <> '')
    and (landmark is null or btrim(landmark) <> '')
    and (postal_code is null or btrim(postal_code) <> '')
    and (delivery_notes is null or btrim(delivery_notes) <> '')
  ),
  constraint customer_addresses_default_active_chk check (not is_default or is_active),
  constraint customer_addresses_archive_state_chk check (
    (archived_at is null and archived_by is null and archive_reason is null)
    or (archived_at is not null and not is_active and not is_default and archive_reason is not null and btrim(archive_reason) <> '')
  ),
  constraint customer_addresses_organization_id_id_uk unique (organization_id, id)
);

comment on table public.customer_addresses is
  'Mutable customer address book. Orders copy immutable address snapshots and never derive history from this table.';

create unique index customer_addresses_one_default_uidx
  on public.customer_addresses (organization_id, customer_id)
  where is_default and archived_at is null;
create index customer_addresses_customer_idx
  on public.customer_addresses (organization_id, customer_id, is_active);
create index customer_addresses_created_by_idx on public.customer_addresses (created_by);
create index customer_addresses_updated_by_idx on public.customer_addresses (updated_by);
create index customer_addresses_archived_by_idx on public.customer_addresses (archived_by);

create trigger customer_addresses_set_updated_at
before update on public.customer_addresses
for each row execute function private.set_updated_at();
create trigger customer_addresses_prevent_delete
before delete on public.customer_addresses
for each row execute function private.prevent_hard_delete();

create table public.phone_brands (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  brand_code text not null,
  display_name text not null,
  is_active boolean not null default true,
  archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint phone_brands_code_format_chk check (brand_code ~ '^[a-z][a-z0-9_]{1,31}$'),
  constraint phone_brands_name_not_blank_chk check (btrim(display_name) <> ''),
  constraint phone_brands_archive_state_chk check (archived_at is null or not is_active),
  constraint phone_brands_org_code_uk unique (organization_id, brand_code),
  constraint phone_brands_organization_id_id_uk unique (organization_id, id)
);

comment on table public.phone_brands is 'Organization-scoped phone manufacturer reference data.';

create index phone_brands_created_by_idx on public.phone_brands (created_by);
create trigger phone_brands_set_updated_at
before update on public.phone_brands
for each row execute function private.set_updated_at();
create trigger phone_brands_prevent_delete
before delete on public.phone_brands
for each row execute function private.prevent_hard_delete();

create table public.phone_models (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  phone_brand_id uuid not null,
  model_code text not null,
  display_name text not null,
  release_year smallint,
  cost_risk_warning boolean not null default false,
  risk_note text,
  is_active boolean not null default true,
  archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint phone_models_brand_org_fk
    foreign key (organization_id, phone_brand_id)
    references public.phone_brands (organization_id, id) on delete restrict,
  constraint phone_models_code_format_chk check (model_code ~ '^[a-z0-9][a-z0-9_+-]{1,63}$'),
  constraint phone_models_name_not_blank_chk check (btrim(display_name) <> ''),
  constraint phone_models_release_year_chk check (release_year is null or release_year between 1990 and 2200),
  constraint phone_models_risk_note_chk check (
    (not cost_risk_warning and risk_note is null)
    or (cost_risk_warning and risk_note is not null and btrim(risk_note) <> '')
  ),
  constraint phone_models_archive_state_chk check (archived_at is null or not is_active),
  constraint phone_models_org_brand_code_uk unique (organization_id, phone_brand_id, model_code),
  constraint phone_models_organization_id_id_uk unique (organization_id, id)
);

comment on table public.phone_models is
  'Phone model reference; cost_risk_warning supports configured risk warnings such as iPhone 17 variants.';

create index phone_models_brand_idx
  on public.phone_models (organization_id, phone_brand_id, is_active);
create index phone_models_created_by_idx on public.phone_models (created_by);
create trigger phone_models_set_updated_at
before update on public.phone_models
for each row execute function private.set_updated_at();
create trigger phone_models_prevent_delete
before delete on public.phone_models
for each row execute function private.prevent_hard_delete();

create table public.product_categories (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  parent_category_id uuid,
  category_code text not null,
  display_name text not null,
  description text,
  is_active boolean not null default true,
  archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint product_categories_code_format_chk check (category_code ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint product_categories_name_not_blank_chk check (btrim(display_name) <> ''),
  constraint product_categories_description_chk check (description is null or btrim(description) <> ''),
  constraint product_categories_not_self_parent_chk check (parent_category_id is null or parent_category_id <> id),
  constraint product_categories_archive_state_chk check (archived_at is null or not is_active),
  constraint product_categories_org_code_uk unique (organization_id, category_code),
  constraint product_categories_organization_id_id_uk unique (organization_id, id),
  constraint product_categories_parent_org_fk
    foreign key (organization_id, parent_category_id)
    references public.product_categories (organization_id, id) on delete restrict
);

comment on table public.product_categories is 'Hierarchical product categories used by products and effective supplier price rules.';

create index product_categories_parent_idx
  on public.product_categories (organization_id, parent_category_id);
create index product_categories_created_by_idx on public.product_categories (created_by);
create trigger product_categories_set_updated_at
before update on public.product_categories
for each row execute function private.set_updated_at();
create trigger product_categories_prevent_delete
before delete on public.product_categories
for each row execute function private.prevent_hard_delete();

create table public.products (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  product_category_id uuid,
  product_code text not null,
  display_name text not null,
  description text,
  product_kind text not null,
  default_item_type public.item_type not null,
  requires_phone_model boolean not null default false,
  tracks_inventory boolean not null default false,
  is_active boolean not null default true,
  archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint products_category_org_fk
    foreign key (organization_id, product_category_id)
    references public.product_categories (organization_id, id) on delete restrict,
  constraint products_code_format_chk check (product_code ~ '^[A-Z0-9][A-Z0-9_-]{1,63}$'),
  constraint products_name_not_blank_chk check (btrim(display_name) <> ''),
  constraint products_description_chk check (description is null or btrim(description) <> ''),
  constraint products_kind_chk check (product_kind in (
    'standard_case', 'custom_case', 'ready_stock', 'accessory', 'gift',
    'design_service', 'packaging', 'raw_case'
  )),
  constraint products_phone_model_kind_chk check (
    not requires_phone_model or product_kind in ('standard_case', 'custom_case', 'ready_stock', 'raw_case')
  ),
  constraint products_inventory_kind_chk check (
    not tracks_inventory or product_kind <> 'design_service'
  ),
  constraint products_archive_state_chk check (archived_at is null or not is_active),
  constraint products_org_code_uk unique (organization_id, product_code),
  constraint products_organization_id_id_uk unique (organization_id, id)
);

comment on table public.products is
  'Product definition supporting standard/custom cases, ready stock, accessories, gifts, design services, packaging, and raw cases.';

create index products_category_idx
  on public.products (organization_id, product_category_id, is_active);
create index products_created_by_idx on public.products (created_by);
create trigger products_set_updated_at
before update on public.products
for each row execute function private.set_updated_at();
create trigger products_prevent_delete
before delete on public.products
for each row execute function private.prevent_hard_delete();

create table public.product_variants (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  product_id uuid not null,
  phone_model_id uuid,
  variant_code text not null,
  display_name text not null,
  sku text,
  barcode text,
  attributes jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint product_variants_product_org_fk
    foreign key (organization_id, product_id)
    references public.products (organization_id, id) on delete restrict,
  constraint product_variants_phone_model_org_fk
    foreign key (organization_id, phone_model_id)
    references public.phone_models (organization_id, id) on delete restrict,
  constraint product_variants_code_format_chk check (variant_code ~ '^[A-Z0-9][A-Z0-9_-]{1,63}$'),
  constraint product_variants_name_not_blank_chk check (btrim(display_name) <> ''),
  constraint product_variants_sku_not_blank_chk check (sku is null or btrim(sku) <> ''),
  constraint product_variants_barcode_not_blank_chk check (barcode is null or btrim(barcode) <> ''),
  constraint product_variants_attributes_object_chk check (jsonb_typeof(attributes) = 'object'),
  constraint product_variants_archive_state_chk check (archived_at is null or not is_active),
  constraint product_variants_org_product_code_uk unique (organization_id, product_id, variant_code),
  constraint product_variants_organization_id_id_uk unique (organization_id, id)
);

comment on table public.product_variants is
  'Sellable/stock variant. Phone linkage is optional for accessories and required by a final-invariant trigger for model-specific products.';

create unique index product_variants_active_sku_uidx
  on public.product_variants (organization_id, sku)
  where sku is not null and archived_at is null;
create unique index product_variants_active_barcode_uidx
  on public.product_variants (organization_id, barcode)
  where barcode is not null and archived_at is null;
create index product_variants_product_idx
  on public.product_variants (organization_id, product_id, is_active);
create index product_variants_phone_model_idx
  on public.product_variants (organization_id, phone_model_id, is_active);
create index product_variants_created_by_idx on public.product_variants (created_by);

create or replace function private.validate_product_variant_model()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requires_phone_model boolean;
begin
  select p.requires_phone_model
    into strict v_requires_phone_model
  from public.products as p
  where p.organization_id = new.organization_id
    and p.id = new.product_id;

  if v_requires_phone_model and new.phone_model_id is null then
    raise exception using errcode = '23514', message = 'Product variant requires a phone model';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_product_variant_model() from public, anon, authenticated;

create or replace function private.validate_product_model_requirement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.requires_phone_model
    and exists (
      select 1
      from public.product_variants as pv
      where pv.organization_id = new.organization_id
        and pv.product_id = new.id
        and pv.phone_model_id is null
        and pv.archived_at is null
    ) then
    raise exception using
      errcode = '23514',
      message = 'Active variants without phone models prevent this product change';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_product_model_requirement() from public, anon, authenticated;

create trigger products_validate_model_requirement
before update of requires_phone_model on public.products
for each row execute function private.validate_product_model_requirement();

create trigger product_variants_validate_model
before insert or update of organization_id, product_id, phone_model_id on public.product_variants
for each row execute function private.validate_product_variant_model();
create trigger product_variants_set_updated_at
before update on public.product_variants
for each row execute function private.set_updated_at();
create trigger product_variants_prevent_delete
before delete on public.product_variants
for each row execute function private.prevent_hard_delete();

create table public.suppliers (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  supplier_code text not null,
  display_name text not null,
  legal_name text,
  contact_name text,
  phone_original text,
  phone_normalized text,
  payment_terms_days integer not null default 0,
  notes text,
  is_active boolean not null default true,
  archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint suppliers_code_format_chk check (supplier_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  constraint suppliers_name_not_blank_chk check (btrim(display_name) <> ''),
  constraint suppliers_optional_text_chk check (
    (legal_name is null or btrim(legal_name) <> '')
    and (contact_name is null or btrim(contact_name) <> '')
    and (notes is null or btrim(notes) <> '')
  ),
  constraint suppliers_phone_pair_chk check ((phone_original is null) = (phone_normalized is null)),
  constraint suppliers_phone_original_not_blank_chk check (phone_original is null or btrim(phone_original) <> ''),
  constraint suppliers_phone_format_chk check (phone_normalized is null or phone_normalized ~ '^\+[1-9][0-9]{7,14}$'),
  constraint suppliers_payment_terms_chk check (payment_terms_days between 0 and 3650),
  constraint suppliers_archive_state_chk check (archived_at is null or not is_active),
  constraint suppliers_org_code_uk unique (organization_id, supplier_code),
  constraint suppliers_organization_id_id_uk unique (organization_id, id)
);

comment on table public.suppliers is 'Supplier master for printing, cases, packaging, and other procurements.';

create index suppliers_created_by_idx on public.suppliers (created_by);
create trigger suppliers_set_updated_at
before update on public.suppliers
for each row execute function private.set_updated_at();
create trigger suppliers_prevent_delete
before delete on public.suppliers
for each row execute function private.prevent_hard_delete();

create table public.couriers (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  courier_code text not null,
  display_name text not null,
  legal_name text,
  contact_name text,
  phone_original text,
  phone_normalized text,
  settlement_weekdays smallint[] not null default array[1, 4]::smallint[],
  settlement_timezone_name text not null default 'Africa/Cairo',
  notes text,
  is_active boolean not null default true,
  archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint couriers_code_format_chk check (courier_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  constraint couriers_name_not_blank_chk check (btrim(display_name) <> ''),
  constraint couriers_optional_text_chk check (
    (legal_name is null or btrim(legal_name) <> '')
    and (contact_name is null or btrim(contact_name) <> '')
    and (notes is null or btrim(notes) <> '')
  ),
  constraint couriers_phone_pair_chk check ((phone_original is null) = (phone_normalized is null)),
  constraint couriers_phone_original_not_blank_chk check (phone_original is null or btrim(phone_original) <> ''),
  constraint couriers_phone_format_chk check (phone_normalized is null or phone_normalized ~ '^\+[1-9][0-9]{7,14}$'),
  constraint couriers_settlement_weekdays_chk check (
    cardinality(settlement_weekdays) between 1 and 7
    and settlement_weekdays <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
  ),
  constraint couriers_timezone_chk check (settlement_timezone_name = 'Africa/Cairo'),
  constraint couriers_archive_state_chk check (archived_at is null or not is_active),
  constraint couriers_org_code_uk unique (organization_id, courier_code),
  constraint couriers_organization_id_id_uk unique (organization_id, id)
);

comment on table public.couriers is
  'Courier master. ISO weekdays default to Monday and Thursday, matching Falcon settlement operations.';

create index couriers_created_by_idx on public.couriers (created_by);
create trigger couriers_set_updated_at
before update on public.couriers
for each row execute function private.set_updated_at();
create trigger couriers_prevent_delete
before delete on public.couriers
for each row execute function private.prevent_hard_delete();

create table public.shipping_zones (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  zone_code text not null,
  display_name text not null,
  governorates text[] not null default '{}'::text[],
  is_active boolean not null default true,
  archived_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint shipping_zones_code_format_chk check (zone_code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  constraint shipping_zones_name_not_blank_chk check (btrim(display_name) <> ''),
  constraint shipping_zones_governorates_chk check (array_position(governorates, null) is null),
  constraint shipping_zones_archive_state_chk check (archived_at is null or not is_active),
  constraint shipping_zones_org_code_uk unique (organization_id, zone_code),
  constraint shipping_zones_organization_id_id_uk unique (organization_id, id)
);

comment on table public.shipping_zones is 'Named shipping zones used by effective courier rate rules.';

create index shipping_zones_created_by_idx on public.shipping_zones (created_by);
create trigger shipping_zones_set_updated_at
before update on public.shipping_zones
for each row execute function private.set_updated_at();
create trigger shipping_zones_prevent_delete
before delete on public.shipping_zones
for each row execute function private.prevent_hard_delete();

create table public.product_price_rules (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  product_variant_id uuid not null,
  sale_price_minor bigint not null,
  currency_code text not null default 'EGP',
  effective_from date not null,
  effective_to date,
  priority integer not null default 100,
  is_active boolean not null default true,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint product_price_rules_variant_org_fk
    foreign key (organization_id, product_variant_id)
    references public.product_variants (organization_id, id) on delete restrict,
  constraint product_price_rules_price_chk check (sale_price_minor >= 0),
  constraint product_price_rules_currency_chk check (currency_code = 'EGP'),
  constraint product_price_rules_effective_range_chk check (effective_to is null or effective_to > effective_from),
  constraint product_price_rules_priority_chk check (priority between 0 and 1000000),
  constraint product_price_rules_notes_chk check (notes is null or btrim(notes) <> ''),
  constraint product_price_rules_organization_id_id_uk unique (organization_id, id),
  constraint product_price_rules_equal_priority_no_overlap_excl exclude using gist (
    organization_id with =,
    product_variant_id with =,
    priority with =,
    daterange(effective_from, effective_to, '[)') with &&
  ) where (is_active)
);

comment on table public.product_price_rules is
  'Effective sale prices in bigint EGP minor units. Highest priority wins; equal-priority periods cannot overlap.';

create index product_price_rules_lookup_idx
  on public.product_price_rules (organization_id, product_variant_id, effective_from, effective_to, priority desc)
  where is_active;
create index product_price_rules_created_by_idx on public.product_price_rules (created_by);
create trigger product_price_rules_set_updated_at
before update on public.product_price_rules
for each row execute function private.set_updated_at();
create trigger product_price_rules_prevent_delete
before delete on public.product_price_rules
for each row execute function private.prevent_hard_delete();

create table public.supplier_price_rules (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  supplier_id uuid not null,
  product_id uuid,
  product_category_id uuid,
  phone_model_id uuid,
  supply_method_code text not null,
  case_and_print_price_minor bigint,
  printing_only_price_minor bigint,
  currency_code text not null default 'EGP',
  effective_from date not null,
  effective_to date,
  priority integer not null default 100,
  is_active boolean not null default true,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint supplier_price_rules_supplier_org_fk
    foreign key (organization_id, supplier_id)
    references public.suppliers (organization_id, id) on delete restrict,
  constraint supplier_price_rules_product_org_fk
    foreign key (organization_id, product_id)
    references public.products (organization_id, id) on delete restrict,
  constraint supplier_price_rules_category_org_fk
    foreign key (organization_id, product_category_id)
    references public.product_categories (organization_id, id) on delete restrict,
  constraint supplier_price_rules_phone_model_org_fk
    foreign key (organization_id, phone_model_id)
    references public.phone_models (organization_id, id) on delete restrict,
  constraint supplier_price_rules_supply_method_chk check (supply_method_code in (
    'supplier_case_and_print', 'falcon_case_print_only', 'ready_stock',
    'free_reprint', 'paid_reprint', 'no_production'
  )),
  constraint supplier_price_rules_prices_chk check (
    (case_and_print_price_minor is not null or printing_only_price_minor is not null)
    and (case_and_print_price_minor is null or case_and_print_price_minor >= 0)
    and (printing_only_price_minor is null or printing_only_price_minor >= 0)
  ),
  constraint supplier_price_rules_method_price_chk check (
    (supply_method_code <> 'supplier_case_and_print' or case_and_print_price_minor is not null)
    and (supply_method_code <> 'falcon_case_print_only' or printing_only_price_minor is not null)
  ),
  constraint supplier_price_rules_currency_chk check (currency_code = 'EGP'),
  constraint supplier_price_rules_effective_range_chk check (effective_to is null or effective_to > effective_from),
  constraint supplier_price_rules_priority_chk check (priority between 0 and 1000000),
  constraint supplier_price_rules_notes_chk check (notes is null or btrim(notes) <> ''),
  constraint supplier_price_rules_organization_id_id_uk unique (organization_id, id),
  constraint supplier_price_rules_equal_priority_no_overlap_excl exclude using gist (
    organization_id with =,
    supplier_id with =,
    (coalesce(product_id, '00000000-0000-0000-0000-000000000000'::uuid)) with =,
    (coalesce(product_category_id, '00000000-0000-0000-0000-000000000000'::uuid)) with =,
    (coalesce(phone_model_id, '00000000-0000-0000-0000-000000000000'::uuid)) with =,
    supply_method_code with =,
    priority with =,
    daterange(effective_from, effective_to, '[)') with &&
  ) where (is_active)
);

comment on table public.supplier_price_rules is
  'Effective printer/supplier price hierarchy in bigint EGP minor units. Higher priority wins; equal-priority identical scopes cannot overlap.';

create index supplier_price_rules_lookup_idx
  on public.supplier_price_rules (
    organization_id, supplier_id, supply_method_code, product_id,
    product_category_id, phone_model_id, effective_from, effective_to, priority desc
  ) where is_active;
create index supplier_price_rules_product_idx on public.supplier_price_rules (product_id);
create index supplier_price_rules_category_idx on public.supplier_price_rules (product_category_id);
create index supplier_price_rules_phone_model_idx on public.supplier_price_rules (phone_model_id);
create index supplier_price_rules_created_by_idx on public.supplier_price_rules (created_by);
create trigger supplier_price_rules_set_updated_at
before update on public.supplier_price_rules
for each row execute function private.set_updated_at();
create trigger supplier_price_rules_prevent_delete
before delete on public.supplier_price_rules
for each row execute function private.prevent_hard_delete();

create table public.shipping_rate_rules (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  courier_id uuid not null,
  shipping_zone_id uuid not null,
  service_type text not null default 'standard',
  delivery_fee_minor bigint not null,
  return_fee_minor bigint not null,
  cod_fixed_fee_minor bigint not null default 0,
  cod_fee_bps integer not null default 0,
  currency_code text not null default 'EGP',
  effective_from date not null,
  effective_to date,
  priority integer not null default 100,
  is_active boolean not null default true,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint shipping_rate_rules_courier_org_fk
    foreign key (organization_id, courier_id)
    references public.couriers (organization_id, id) on delete restrict,
  constraint shipping_rate_rules_zone_org_fk
    foreign key (organization_id, shipping_zone_id)
    references public.shipping_zones (organization_id, id) on delete restrict,
  constraint shipping_rate_rules_service_type_format_chk
    check (service_type ~ '^[a-z][a-z0-9_]{1,31}$'),
  constraint shipping_rate_rules_amounts_chk check (
    delivery_fee_minor >= 0 and return_fee_minor >= 0 and cod_fixed_fee_minor >= 0
  ),
  constraint shipping_rate_rules_cod_bps_chk check (cod_fee_bps between 0 and 10000),
  constraint shipping_rate_rules_currency_chk check (currency_code = 'EGP'),
  constraint shipping_rate_rules_effective_range_chk check (effective_to is null or effective_to > effective_from),
  constraint shipping_rate_rules_priority_chk check (priority between 0 and 1000000),
  constraint shipping_rate_rules_notes_chk check (notes is null or btrim(notes) <> ''),
  constraint shipping_rate_rules_organization_id_id_uk unique (organization_id, id),
  constraint shipping_rate_rules_equal_priority_no_overlap_excl exclude using gist (
    organization_id with =,
    courier_id with =,
    shipping_zone_id with =,
    service_type with =,
    priority with =,
    daterange(effective_from, effective_to, '[)') with &&
  ) where (is_active)
);

comment on table public.shipping_rate_rules is
  'Effective delivery, return, and COD fee rules in bigint EGP minor units. Historical shipments snapshot the selected rule and amounts.';

create index shipping_rate_rules_lookup_idx
  on public.shipping_rate_rules (
    organization_id, courier_id, shipping_zone_id, service_type,
    effective_from, effective_to, priority desc
  ) where is_active;
create index shipping_rate_rules_zone_idx on public.shipping_rate_rules (shipping_zone_id);
create index shipping_rate_rules_created_by_idx on public.shipping_rate_rules (created_by);
create trigger shipping_rate_rules_set_updated_at
before update on public.shipping_rate_rules
for each row execute function private.set_updated_at();
create trigger shipping_rate_rules_prevent_delete
before delete on public.shipping_rate_rules
for each row execute function private.prevent_hard_delete();

alter table public.customers enable row level security;
alter table public.customer_addresses enable row level security;
alter table public.phone_brands enable row level security;
alter table public.phone_models enable row level security;
alter table public.product_categories enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.suppliers enable row level security;
alter table public.couriers enable row level security;
alter table public.shipping_zones enable row level security;
alter table public.product_price_rules enable row level security;
alter table public.supplier_price_rules enable row level security;
alter table public.shipping_rate_rules enable row level security;

revoke all on table public.customers from public, anon, authenticated;
revoke all on table public.customer_addresses from public, anon, authenticated;
revoke all on table public.phone_brands from public, anon, authenticated;
revoke all on table public.phone_models from public, anon, authenticated;
revoke all on table public.product_categories from public, anon, authenticated;
revoke all on table public.products from public, anon, authenticated;
revoke all on table public.product_variants from public, anon, authenticated;
revoke all on table public.suppliers from public, anon, authenticated;
revoke all on table public.couriers from public, anon, authenticated;
revoke all on table public.shipping_zones from public, anon, authenticated;
revoke all on table public.product_price_rules from public, anon, authenticated;
revoke all on table public.supplier_price_rules from public, anon, authenticated;
revoke all on table public.shipping_rate_rules from public, anon, authenticated;
