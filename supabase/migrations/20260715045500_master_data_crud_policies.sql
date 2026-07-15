do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'customers',
    'suppliers',
    'couriers',
    'wallets',
    'inventory_locations',
    'expense_categories',
    'employees',
    'partners',
    'product_categories',
    'products',
    'product_variants',
    'phone_brands',
    'phone_models'
  ]
  loop
    execute format('grant select, insert, update on public.%I to authenticated', v_table);
  end loop;
end $$;

create policy customers_insert_manage on public.customers
for insert to authenticated
with check (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['customers.create', 'customers.update'])
);

create policy customers_update_manage on public.customers
for update to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'customers.update')
)
with check (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'customers.update')
);

create policy suppliers_insert_manage on public.suppliers
for insert to authenticated
with check (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['supplier_invoices.create', 'supplier_invoices.approve'])
);

create policy suppliers_update_manage on public.suppliers
for update to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['supplier_invoices.create', 'supplier_invoices.approve'])
)
with check (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['supplier_invoices.create', 'supplier_invoices.approve'])
);

create policy couriers_insert_manage on public.couriers
for insert to authenticated
with check (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['courier_settlements.prepare', 'courier_settlements.approve'])
);

create policy couriers_update_manage on public.couriers
for update to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['courier_settlements.prepare', 'courier_settlements.approve'])
)
with check (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['courier_settlements.prepare', 'courier_settlements.approve'])
);

create policy wallets_insert_manage on public.wallets
for insert to authenticated
with check (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'wallets.transfer')
);

create policy wallets_update_manage on public.wallets
for update to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'wallets.transfer')
)
with check (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'wallets.transfer')
);

create policy inventory_locations_insert_manage on public.inventory_locations
for insert to authenticated
with check (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['print_batches.create', 'shipments.create'])
);

create policy inventory_locations_update_manage on public.inventory_locations
for update to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['print_batches.create', 'shipments.create'])
)
with check (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['print_batches.create', 'shipments.create'])
);

create policy expense_categories_insert_manage on public.expense_categories
for insert to authenticated
with check (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'expenses.create')
);

create policy expense_categories_update_manage on public.expense_categories
for update to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'expenses.create')
)
with check (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'expenses.create')
);

create policy employees_insert_manage on public.employees
for insert to authenticated
with check (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'payroll.read_all')
);

create policy employees_update_manage on public.employees
for update to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'payroll.read_all')
)
with check (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'payroll.read_all')
);

create policy partners_insert_manage on public.partners
for insert to authenticated
with check (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['partners.capital.record', 'partner_withdrawals.approve'])
);

create policy partners_update_manage on public.partners
for update to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['partners.capital.record', 'partner_withdrawals.approve'])
)
with check (
  organization_id = private.current_organization_id()
  and private.has_any_permission(organization_id, array['partners.capital.record', 'partner_withdrawals.approve'])
);

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'product_categories',
    'products',
    'product_variants',
    'phone_brands',
    'phone_models'
  ]
  loop
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (organization_id = private.current_organization_id() and private.has_permission(organization_id, %L))',
      v_table || '_insert_manage',
      v_table,
      'orders.create'
    );
    execute format(
      'create policy %I on public.%I for update to authenticated using (organization_id = private.current_organization_id() and private.has_permission(organization_id, %L)) with check (organization_id = private.current_organization_id() and private.has_permission(organization_id, %L))',
      v_table || '_update_manage',
      v_table,
      'orders.update_before_print',
      'orders.update_before_print'
    );
  end loop;
end $$;
