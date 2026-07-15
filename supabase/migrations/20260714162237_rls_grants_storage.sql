create table public.attachments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  bucket_id text not null,
  object_name text not null,
  entity_type text not null,
  entity_id uuid not null,
  classification text not null default 'operational',
  media_type text,
  size_bytes bigint,
  checksum_sha256 text,
  uploaded_by uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  deleted_at timestamptz,
  constraint attachments_uploader_org_fk foreign key (organization_id, uploaded_by)
    references public.profiles(organization_id, id) on delete restrict,
  constraint attachments_bucket_chk check (bucket_id in ('falcon-operational', 'falcon-financial')),
  constraint attachments_object_name_chk check (btrim(object_name) <> '' and object_name not like '/%'),
  constraint attachments_entity_type_chk check (entity_type ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint attachments_classification_chk check (classification in ('operational', 'financial', 'payroll', 'audit')),
  constraint attachments_size_chk check (size_bytes is null or size_bytes >= 0),
  constraint attachments_checksum_chk check (checksum_sha256 is null or checksum_sha256 ~ '^[0-9a-f]{64}$'),
  constraint attachments_bucket_object_uk unique (bucket_id, object_name),
  constraint attachments_org_id_id_uk unique (organization_id, id)
);

create index attachments_entity_idx on public.attachments (organization_id, entity_type, entity_id, created_at desc);
create index attachments_active_idx on public.attachments (organization_id, classification, created_at desc) where deleted_at is null;

create trigger attachments_append_only
before update or delete on public.attachments
for each row execute function private.prevent_row_mutation();

create or replace function private.has_any_permission(p_organization_id uuid, p_permission_keys text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from unnest(p_permission_keys) as key(permission_key)
    where private.has_permission(p_organization_id, key.permission_key)
  )
$$;

create or replace function private.can_read_relation(p_organization_id uuid, p_relation text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_organization_id is distinct from private.current_organization_id() then
    return false;
  end if;

  return case
    when p_relation in ('customers', 'customer_addresses', 'phone_brands', 'phone_models', 'product_categories', 'products', 'product_variants', 'product_price_rules')
      then private.has_any_permission(p_organization_id, array['customers.read', 'orders.read'])
    when p_relation in ('orders', 'order_items', 'order_status_history', 'order_exceptions', 'order_discounts', 'order_discount_allocations', 'order_problems', 'order_problem_costs')
      then private.has_any_permission(p_organization_id, array['orders.read', 'orders.confirm', 'orders.deliver'])
    when p_relation in ('wallets', 'customer_payments', 'customer_credits', 'refunds', 'payment_allocations', 'customer_credit_movements', 'wallet_transfers', 'wallet_reconciliations', 'wallet_reconciliation_items')
      then private.has_any_permission(p_organization_id, array['payments.review', 'wallets.read_sensitive', 'wallets.reconcile', 'ledger.read'])
    when p_relation in ('suppliers', 'supplier_price_rules', 'print_batches', 'print_batch_items', 'print_batch_receipts', 'print_batch_receipt_items', 'print_batch_qc_events', 'grni_accruals', 'supplier_invoices', 'supplier_invoice_items', 'supplier_payments')
      then private.has_any_permission(p_organization_id, array['print_batches.create', 'print_batches.receive', 'supplier_invoices.approve', 'ledger.read'])
    when p_relation in ('couriers', 'shipping_zones', 'shipping_rate_rules', 'inventory_locations', 'inventory_reservations', 'inventory_movements', 'shipments', 'shipment_items', 'shipment_status_history', 'returns', 'return_items', 'courier_settlements', 'courier_settlement_items')
      then private.has_any_permission(p_organization_id, array['orders.read', 'shipments.update', 'courier_settlements.prepare', 'ledger.read'])
    when p_relation in ('expense_categories', 'expenses', 'expense_payments')
      then private.has_any_permission(p_organization_id, array['expenses.create', 'expenses.approve', 'expenses.pay', 'ledger.read'])
    when p_relation in ('employees', 'employee_compensation_periods', 'employee_advances', 'bonus_schemes', 'bonus_metrics', 'bonus_slabs', 'employee_performance_reviews', 'employee_performance_scores', 'bonus_adjustments', 'payroll_periods', 'payroll_entries', 'payroll_payments')
      then private.has_permission(p_organization_id, 'payroll.read_all')
    when p_relation in ('partners', 'partner_ownership_periods', 'partner_capital_transactions', 'partner_loans', 'partner_withdrawals', 'profit_distributions', 'profit_distribution_lines')
      then private.has_any_permission(p_organization_id, array['ledger.post', 'audit.read'])
    when p_relation in ('approval_requests', 'approval_actions')
      then private.has_any_permission(p_organization_id, array['payments.review', 'refunds.approve', 'supplier_invoices.approve', 'courier_settlements.approve', 'expenses.approve', 'payroll.approve', 'partner_withdrawals.approve', 'ledger.post'])
    when p_relation = 'attachments'
      then private.has_any_permission(p_organization_id, array['attachments.read_sensitive', 'audit.read'])
    else false
  end;
end;
$$;

revoke all on function private.has_any_permission(uuid, text[]) from public, anon, authenticated;
revoke all on function private.can_read_relation(uuid, text) from public, anon, authenticated;

do $rls$
declare
  relation record;
begin
  for relation in
    select c.relname
    from pg_class as c
    join pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
      and c.relname not in ('organizations', 'profiles')
      and exists (
        select 1 from pg_attribute as a
        where a.attrelid = c.oid and a.attname = 'organization_id' and not a.attisdropped
      )
  loop
    execute format('alter table public.%I enable row level security', relation.relname);
    execute format(
      'create policy falcon_select on public.%I for select to authenticated using (private.can_read_relation(organization_id, %L))',
      relation.relname,
      relation.relname
    );
  end loop;
end
$rls$;

create policy organizations_select on public.organizations
for select to authenticated
using (id = private.current_organization_id());

create policy profiles_select_self_or_auditor on public.profiles
for select to authenticated
using (
  organization_id = private.current_organization_id()
  and (id = (select auth.uid()) or private.has_permission(organization_id, 'audit.read'))
);

create policy employees_select_own_scope on public.employees
for select to authenticated
using (
  organization_id = private.current_organization_id()
  and profile_id = (select auth.uid())
  and private.has_permission(organization_id, 'payroll.read_own_scope')
);

create policy payroll_entries_select_own_scope on public.payroll_entries
for select to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'payroll.read_own_scope')
  and exists (
    select 1 from public.employees as employee
    where employee.id = payroll_entries.employee_id
      and employee.organization_id = payroll_entries.organization_id
      and employee.profile_id = (select auth.uid())
  )
);

create or replace function private.can_read_partner_row(p_organization_id uuid, p_partner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_organization_id = private.current_organization_id()
    and (
      private.has_any_permission(p_organization_id, array['ledger.post', 'audit.read'])
      or exists (
        select 1 from public.partners as partner
        where partner.organization_id = p_organization_id
          and partner.id = p_partner_id
          and partner.profile_id = (select auth.uid())
      )
    )
$$;

revoke all on function private.can_read_partner_row(uuid, uuid) from public, anon, authenticated;
grant execute on function private.can_read_partner_row(uuid, uuid) to authenticated;

create policy partners_select_own on public.partners for select to authenticated
using (private.can_read_partner_row(organization_id, id));
create policy partner_ownership_select_own on public.partner_ownership_periods for select to authenticated
using (private.can_read_partner_row(organization_id, partner_id));
create policy partner_capital_select_own on public.partner_capital_transactions for select to authenticated
using (private.can_read_partner_row(organization_id, partner_id));
create policy partner_loans_select_own on public.partner_loans for select to authenticated
using (private.can_read_partner_row(organization_id, partner_id));
create policy partner_withdrawals_select_own_or_approver on public.partner_withdrawals for select to authenticated
using (
  private.can_read_partner_row(organization_id, partner_id)
  or (
    organization_id = private.current_organization_id()
    and private.has_permission(organization_id, 'partner_withdrawals.approve')
    and status = 'submitted'
  )
);
create policy profit_distribution_lines_select_own on public.profit_distribution_lines for select to authenticated
using (private.can_read_partner_row(organization_id, partner_id));
create policy profit_distributions_select_visible_line on public.profit_distributions for select to authenticated
using (
  organization_id = private.current_organization_id()
  and (
    private.has_any_permission(organization_id, array['ledger.post', 'audit.read'])
    or exists (
      select 1 from public.profit_distribution_lines as line
      where line.organization_id = profit_distributions.organization_id
        and line.profit_distribution_id = profit_distributions.id
        and private.can_read_partner_row(line.organization_id, line.partner_id)
    )
  )
);

create policy attachments_select_own on public.attachments for select to authenticated
using (organization_id = private.current_organization_id() and uploaded_by = (select auth.uid()));

revoke all on all tables in schema public from public, anon, authenticated;
grant select on all tables in schema public to authenticated;
revoke all on all tables in schema accounting from public, anon, authenticated;
revoke all on all tables in schema private from public, anon, authenticated;
revoke all on all tables in schema audit from public, anon, authenticated;

grant usage on schema api to authenticated;
grant usage on schema private to authenticated;
grant execute on function private.current_organization_id() to authenticated;
grant execute on function private.has_permission(uuid, text) to authenticated;
grant execute on function private.has_any_permission(uuid, text[]) to authenticated;
grant execute on function private.can_read_relation(uuid, text) to authenticated;

do $grants$
declare
  routine record;
begin
  for routine in
    select p.oid::regprocedure as signature
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'api'
  loop
    execute format('revoke all on function %s from public, anon', routine.signature);
    execute format('grant execute on function %s to authenticated', routine.signature);
  end loop;
end
$grants$;

insert into storage.buckets (id, name, public, file_size_limit)
values
  ('falcon-operational', 'falcon-operational', false, 10485760),
  ('falcon-financial', 'falcon-financial', false, 10485760)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit;

create policy falcon_storage_read on storage.objects
for select to authenticated
using (
  bucket_id in ('falcon-operational', 'falcon-financial')
  and (storage.foldername(name))[1] = private.current_organization_id()::text
  and exists (
    select 1 from public.attachments as attachment
    where attachment.organization_id = private.current_organization_id()
      and attachment.bucket_id = storage.objects.bucket_id
      and attachment.object_name = storage.objects.name
      and attachment.deleted_at is null
      and (
        attachment.uploaded_by = (select auth.uid())
        or private.has_any_permission(attachment.organization_id, array['attachments.read_sensitive', 'audit.read'])
      )
  )
);

create policy falcon_storage_insert on storage.objects
for insert to authenticated
with check (
  bucket_id in ('falcon-operational', 'falcon-financial')
  and (storage.foldername(name))[1] = private.current_organization_id()::text
  and (
    (bucket_id = 'falcon-operational' and private.has_any_permission(private.current_organization_id(), array['orders.create', 'shipments.update', 'expenses.create']))
    or (bucket_id = 'falcon-financial' and private.has_any_permission(private.current_organization_id(), array['payments.review', 'expenses.pay', 'payroll.pay', 'ledger.post']))
  )
);

comment on table public.attachments is 'Immutable storage metadata; object access remains bound to private buckets and organization-aware policies.';
