-- Synthetic, repeatable Phase 2 reference seed. No Auth users, balances, customers,
-- sales, payroll entries, or claims about current supplier/courier prices are created.

insert into public.organizations (
  id, organization_code, display_name, legal_name, currency_code, timezone_name, is_default, is_active
) values (
  '00000000-0000-4000-8000-00000000f001', 'falcon', 'Falcon', 'Falcon', 'EGP', 'Africa/Cairo', true, true
) on conflict (id) do nothing;

insert into accounting.accounts (
  id, organization_id, code, name, account_type, normal_balance,
  is_control_account, allows_manual_posting, metadata
)
values (
  md5('00000000-0000-4000-8000-00000000f001:account:refund_payable')::uuid,
  '00000000-0000-4000-8000-00000000f001', '2120',
  'Customer refunds payable', 'liability', 'credit', true, false,
  '{}'::jsonb
)
on conflict (organization_id, code) do nothing;

insert into accounting.account_roles (
  id, organization_id, role_key, description, expected_account_type,
  is_required_for_close
)
values (
  md5('00000000-0000-4000-8000-00000000f001:role:refund_payable')::uuid,
  '00000000-0000-4000-8000-00000000f001', 'refund_payable',
  'Approved customer refunds awaiting payment', 'liability', true
)
on conflict (organization_id, role_key) do nothing;

insert into accounting.account_role_mappings (
  id, organization_id, account_role_id, account_id, valid_from, metadata
)
select
  md5('00000000-0000-4000-8000-00000000f001:mapping:refund_payable')::uuid,
  '00000000-0000-4000-8000-00000000f001', ar.id, a.id,
  date '2020-01-01', jsonb_build_object('source', 'phase2_seed')
from accounting.account_roles as ar
join accounting.accounts as a
  on a.organization_id = ar.organization_id and a.code = '2120'
where ar.organization_id = '00000000-0000-4000-8000-00000000f001'
  and ar.role_key = 'refund_payable'
on conflict do nothing;

insert into private.organization_finance_settings (
  id, organization_id, version_no, effective_from, custom_deposit_bps,
  custom_shipping_prepaid_required, moderator_max_discount_bps,
  discount_applies_to_shipping_by_default, block_negative_margin_for_moderator,
  partner_withdrawal_approval_threshold_minor, withdrawal_aggregation_hours,
  withdrawal_execution_enabled, delivery_recognition_enabled, payroll_execution_enabled,
  change_reason
) values (
  '00000000-0000-4000-8000-00000000f101', '00000000-0000-4000-8000-00000000f001', 1,
  '2026-01-01 00:00:00+02', 5000, true, 2000, false, true,
  50000, 24, false, false, false,
  'Phase 2 bootstrap defaults; execution remains disabled pending accountable approval'
) on conflict (organization_id, version_no) do nothing;

insert into private.permissions (id, permission_key, description, is_sensitive)
select md5('falcon-permission:' || permission_key)::uuid, permission_key, description, is_sensitive
from (values
  ('customers.read', 'Read customer records', false),
  ('customers.create', 'Create customer records', false),
  ('customers.update', 'Update customer records', false),
  ('orders.read', 'Read orders', false),
  ('orders.create', 'Create orders', false),
  ('orders.update_before_print', 'Update orders before production', false),
  ('orders.confirm', 'Confirm eligible orders', true),
  ('orders.cancel', 'Cancel orders', true),
  ('orders.deliver', 'Record order delivery', true),
  ('discounts.grant', 'Grant policy-compliant discounts', true),
  ('discounts.override_negative_margin', 'Override negative margin protection', true),
  ('payments.record', 'Record customer payment evidence', true),
  ('payments.review', 'Review and confirm payments', true),
  ('refunds.request', 'Request customer refunds', true),
  ('refunds.approve', 'Approve customer refunds', true),
  ('refunds.execute', 'Execute customer refunds', true),
  ('print_batches.create', 'Create print batches', false),
  ('print_batches.receive', 'Receive and QC print batches', true),
  ('print_batches.close', 'Close print batches', true),
  ('supplier_invoices.create', 'Record supplier invoices', true),
  ('supplier_invoices.approve', 'Approve supplier invoices', true),
  ('supplier_payments.execute', 'Pay supplier invoices', true),
  ('shipments.create', 'Create shipments', false),
  ('shipments.update', 'Update shipment evidence and state', true),
  ('courier_settlements.prepare', 'Prepare courier settlements', true),
  ('courier_settlements.approve', 'Approve courier settlements', true),
  ('wallets.read_summary', 'Read non-sensitive wallet summaries', true),
  ('wallets.read_sensitive', 'Read wallet identities and balances', true),
  ('wallets.reconcile', 'Finalize wallet reconciliations', true),
  ('wallets.transfer', 'Transfer between Falcon wallets', true),
  ('expenses.create', 'Record expenses', true),
  ('expenses.approve', 'Approve expenses', true),
  ('expenses.pay', 'Pay approved expenses', true),
  ('expenses.reverse', 'Reverse approved unpaid expenses', true),
  ('payroll.read_own_scope', 'Read own payroll status', true),
  ('payroll.read_all', 'Read all payroll data', true),
  ('payroll.calculate', 'Calculate payroll periods', true),
  ('payroll.approve', 'Approve payroll', true),
  ('payroll.pay', 'Pay payroll', true),
  ('payroll.advance.record', 'Record approved employee advances', true),
  ('partner_withdrawals.request', 'Request own partner withdrawal', true),
  ('partner_withdrawals.approve', 'Approve another partner withdrawal', true),
  ('partner_withdrawals.execute', 'Execute approved partner withdrawal', true),
  ('ledger.read', 'Read ledger and statements', true),
  ('ledger.post', 'Post manual journals', true),
  ('ledger.reverse', 'Reverse posted journals', true),
  ('accounting.close_period', 'Close an accounting period', true),
  ('accounting.reopen_period', 'Exceptionally reopen a period', true),
  ('audit.read', 'Read audit events', true),
  ('attachments.read_sensitive', 'Read sensitive evidence', true),
  ('reports.export', 'Export authorized reports', true)
) as permission_seed(permission_key, description, is_sensitive)
on conflict (permission_key) do nothing;

insert into private.roles (id, organization_id, role_key, display_name, description, is_system)
select md5('falcon-role:' || role_key)::uuid, '00000000-0000-4000-8000-00000000f001', role_key, display_name, description, true
from (values
  ('super_admin', 'Super admin', 'Administrative role; financial capabilities are still explicit'),
  ('partner', 'Partner', 'Partner statements, approvals, and own withdrawal requests'),
  ('finance_manager', 'Finance manager', 'Finance operations and accounting close'),
  ('operations', 'Operations', 'Printing, inventory, shipment, and return operations'),
  ('moderator', 'Moderator', 'Customer and pre-production order work'),
  ('auditor', 'Auditor', 'Read-only ledger and audit access'),
  ('read_only', 'Read only', 'Non-sensitive operational read access')
) as role_seed(role_key, display_name, description)
on conflict (organization_id, role_key) do nothing;

insert into private.role_permissions (organization_id, role_id, permission_id)
select '00000000-0000-4000-8000-00000000f001', r.id, p.id
from private.roles as r
join private.permissions as p on (
  r.role_key = 'super_admin'
  or (r.role_key = 'finance_manager' and p.permission_key in (
    'customers.read','orders.read','orders.confirm','orders.cancel','orders.deliver','payments.review',
    'refunds.approve','refunds.execute','supplier_invoices.create','supplier_invoices.approve',
    'supplier_payments.execute','courier_settlements.prepare','courier_settlements.approve',
    'courier_settlements.finalize',
    'wallets.read_summary','wallets.read_sensitive','wallets.reconcile','wallets.transfer',
    'expenses.create','expenses.approve','expenses.pay','expenses.reverse','payroll.read_all','payroll.calculate',
    'payroll.approve','payroll.pay','payroll.advance.record','partner_withdrawals.approve','partner_withdrawals.execute',
    'ledger.read','ledger.post','ledger.reverse','accounting.close_period','reports.export','attachments.read_sensitive'
  ))
  or (r.role_key = 'operations' and p.permission_key in (
    'customers.read','orders.read','print_batches.create','print_batches.receive','print_batches.close',
    'shipments.create','shipments.update','courier_settlements.prepare','expenses.create'
  ))
  or (r.role_key = 'moderator' and p.permission_key in (
    'customers.read','customers.create','customers.update','orders.read','orders.create',
    'orders.update_before_print','discounts.grant','payments.record','refunds.request'
  ))
  or (r.role_key = 'partner' and p.permission_key in (
    'orders.read','wallets.read_summary','partner_withdrawals.request','partner_withdrawals.approve',
    'ledger.read','reports.export'
  ))
  or (r.role_key = 'auditor' and p.permission_key in ('ledger.read','audit.read','reports.export','attachments.read_sensitive'))
  or (r.role_key = 'read_only' and p.permission_key in ('customers.read','orders.read','wallets.read_summary'))
)
where r.organization_id = '00000000-0000-4000-8000-00000000f001'
on conflict do nothing;

-- Legacy shipping-label compatibility capabilities are inserted by migration 41.
insert into private.role_permissions (organization_id, role_id, permission_id)
select '00000000-0000-4000-8000-00000000f001', r.id, p.id
from private.roles as r
join private.permissions as p on (
  r.role_key = 'super_admin'
  or (r.role_key = 'operations' and p.permission_key in (
    'shipping_labels.read', 'shipping_labels.create', 'shipping_labels.update',
    'shipping_settings.read'
  ))
  or (r.role_key = 'moderator' and p.permission_key in (
    'shipping_labels.read', 'shipping_labels.create', 'shipping_labels.update',
    'shipping_settings.read'
  ))
  or (r.role_key in ('finance_manager', 'partner', 'auditor', 'read_only')
    and p.permission_key in ('shipping_labels.read', 'shipping_settings.read'))
)
where r.organization_id = '00000000-0000-4000-8000-00000000f001'
  and p.permission_key like 'shipping\_%' escape '\'
on conflict do nothing;

insert into public.governorate_shipping_fees (
  id, organization_id, governorate, shipping_fee
)
select
  md5('falcon-shipping-fee:' || governorate)::uuid,
  '00000000-0000-4000-8000-00000000f001',
  governorate,
  shipping_fee
from (values
  ('القاهرة', 45::numeric), ('الجيزة', 45), ('الإسكندرية', 50),
  ('القليوبية', 50), ('المنوفية', 55), ('الغربية', 55),
  ('الدقهلية', 55), ('الشرقية', 55), ('دمياط', 60),
  ('البحيرة', 60), ('كفر الشيخ', 60), ('الفيوم', 65),
  ('بني سويف', 65), ('المنيا', 70), ('أسيوط', 70),
  ('سوهاج', 75), ('قنا', 80), ('الأقصر', 85),
  ('أسوان', 90), ('بورسعيد', 60), ('الإسماعيلية', 60),
  ('السويس', 60), ('البحر الأحمر', 100), ('مطروح', 100),
  ('الوادي الجديد', 100), ('شمال سيناء', 100), ('جنوب سيناء', 100)
) as shipping_fee_seed(governorate, shipping_fee)
on conflict (organization_id, governorate) do update
set shipping_fee = excluded.shipping_fee;

insert into public.shipping_settings (id, organization_id, key, value)
values (
  md5('falcon-shipping-setting:store_config')::uuid,
  '00000000-0000-4000-8000-00000000f001',
  'store_config',
  jsonb_build_object(
    'store_name', 'Falcon store',
    'shipper_id', '6525',
    'default_product_type', 'COD',
    'default_weight', 1.0,
    'default_pieces', 1,
    'default_layout', '3',
    'business_phone', '01000000000',
    'barcode_prefix', 'FLC',
    'footer_note', 'Thank you for choosing Falcon'
  )
)
on conflict (organization_id, key) do nothing;

insert into private.role_permissions (organization_id, role_id, permission_id)
select '00000000-0000-4000-8000-00000000f001', r.id, p.id
from private.roles as r
join private.permissions as p on p.permission_key like 'profit_distributions.%'
where r.organization_id = '00000000-0000-4000-8000-00000000f001'
  and r.role_key in ('super_admin', 'finance_manager')
on conflict do nothing;

insert into private.role_permissions (organization_id, role_id, permission_id)
select '00000000-0000-4000-8000-00000000f001', r.id, p.id
from private.roles as r
join private.permissions as p on p.permission_key in (
  'payments.allocate', 'payments.reverse', 'credits.apply', 'refunds.reverse'
)
where r.organization_id = '00000000-0000-4000-8000-00000000f001'
  and r.role_key in ('super_admin', 'finance_manager')
on conflict do nothing;

insert into private.role_permissions (organization_id, role_id, permission_id)
select '00000000-0000-4000-8000-00000000f001', r.id, p.id
from private.roles as r
join private.permissions as p on p.permission_key in (
  'orders.return', 'orders.reverse_delivery', 'orders.reverse_return'
)
where r.organization_id = '00000000-0000-4000-8000-00000000f001'
  and r.role_key in ('super_admin', 'finance_manager', 'operations')
on conflict do nothing;

insert into accounting.accounting_periods (id, organization_id, period_start, period_end, status)
values (
  md5('falcon-period:' || date_trunc('month', (statement_timestamp() at time zone 'Africa/Cairo'))::date::text)::uuid,
  '00000000-0000-4000-8000-00000000f001',
  date_trunc('month', (statement_timestamp() at time zone 'Africa/Cairo'))::date,
  (date_trunc('month', (statement_timestamp() at time zone 'Africa/Cairo')) + interval '1 month - 1 day')::date,
  'open'
)
on conflict (organization_id, period_start) do nothing;

insert into public.phone_brands (id, organization_id, brand_code, display_name)
values ('00000000-0000-4000-8000-00000000f201', '00000000-0000-4000-8000-00000000f001', 'apple', 'Apple')
on conflict (organization_id, brand_code) do nothing;

insert into public.phone_models (
  id, organization_id, phone_brand_id, model_code, display_name, release_year,
  cost_risk_warning, risk_note
) values (
  '00000000-0000-4000-8000-00000000f202', '00000000-0000-4000-8000-00000000f001',
  '00000000-0000-4000-8000-00000000f201', 'iphone_17_demo', 'iPhone 17 (Demo Reference)',
  2025, true, 'Demo model exception only; no current price or cost is asserted'
) on conflict (organization_id, phone_brand_id, model_code) do nothing;

insert into public.product_categories (id, organization_id, category_code, display_name, description)
values (
  '00000000-0000-4000-8000-00000000f203', '00000000-0000-4000-8000-00000000f001',
  'phone_cases', 'Phone cases', 'Reference category for standard and custom cases'
) on conflict (organization_id, category_code) do nothing;

insert into public.suppliers (id, organization_id, supplier_code, display_name, notes, is_active)
values (
  '00000000-0000-4000-8000-00000000f204', '00000000-0000-4000-8000-00000000f001',
  'DEMO_PRINTER', 'Demo printer template', 'Template only; replace with verified commercial details', false
) on conflict (organization_id, supplier_code) do nothing;

insert into public.supplier_price_rules (
  id, organization_id, supplier_id, product_category_id, phone_model_id,
  supply_method_code, case_and_print_price_minor, currency_code, effective_from,
  priority, is_active, notes
) values (
  '00000000-0000-4000-8000-00000000f205', '00000000-0000-4000-8000-00000000f001',
  '00000000-0000-4000-8000-00000000f204', '00000000-0000-4000-8000-00000000f203',
  '00000000-0000-4000-8000-00000000f202', 'supplier_case_and_print', 1, 'EGP',
  '2026-01-01', 1, false, 'INACTIVE DEMO sentinel, not a real or usable supplier price'
) on conflict do nothing;

insert into public.shipping_zones (id, organization_id, zone_code, display_name, governorates)
values
  ('00000000-0000-4000-8000-00000000f211', '00000000-0000-4000-8000-00000000f001', 'CAIRO_TEMPLATE', 'Cairo template', array['Cairo']),
  ('00000000-0000-4000-8000-00000000f212', '00000000-0000-4000-8000-00000000f001', 'OTHER_TEMPLATE', 'Other governorates template', '{}'::text[])
on conflict (organization_id, zone_code) do nothing;

insert into public.inventory_locations (id, organization_id, code, name, location_kind)
values
  ('00000000-0000-4000-8000-00000000f221', '00000000-0000-4000-8000-00000000f001', 'FALCON_MAIN', 'Falcon main storage', 'falcon_storage'),
  ('00000000-0000-4000-8000-00000000f222', '00000000-0000-4000-8000-00000000f001', 'RETURN_INSPECTION', 'Return inspection', 'return_inspection'),
  ('00000000-0000-4000-8000-00000000f223', '00000000-0000-4000-8000-00000000f001', 'DAMAGED', 'Damaged stock', 'damaged')
on conflict (organization_id, code) do nothing;

insert into public.expense_categories (id, organization_id, code, name, requires_approval, requires_evidence)
values
  ('00000000-0000-4000-8000-00000000f231', '00000000-0000-4000-8000-00000000f001', 'OPERATIONS', 'Operations', true, true),
  ('00000000-0000-4000-8000-00000000f232', '00000000-0000-4000-8000-00000000f001', 'MARKETING', 'Marketing', true, true),
  ('00000000-0000-4000-8000-00000000f233', '00000000-0000-4000-8000-00000000f001', 'ADMIN', 'Administration', true, true)
on conflict (organization_id, code) do nothing;

insert into public.wallets (
  id, organization_id, code, name, provider, wallet_type,
  registered_owner_name, economic_owner_name, currency, notes
) values (
  '00000000-0000-4000-8000-00000000f241', '00000000-0000-4000-8000-00000000f001',
  'VODAFONE_MAAZ', 'Falcon Vodafone Cash', 'Vodafone Cash',
  'personal_wallet_dedicated_to_business', 'Maaz', 'Falcon', 'EGP',
  'Metadata only; no balance is seeded'
), (
  '00000000-0000-4000-8000-00000000f242', '00000000-0000-4000-8000-00000000f001',
  'CASH_CLEARING', 'Falcon cash clearing', 'Internal',
  'clearing', 'Falcon', 'Falcon', 'EGP',
  'Synthetic clearing wallet for deterministic transfer verification; no balance is seeded'
) on conflict (organization_id, code) do nothing;

insert into public.partners (id, organization_id, partner_code, full_name)
values
  ('00000000-0000-4000-8000-00000000f251', '00000000-0000-4000-8000-00000000f001', 'AHMED', 'Ahmed'),
  ('00000000-0000-4000-8000-00000000f252', '00000000-0000-4000-8000-00000000f001', 'MAAZ', 'Maaz')
on conflict (organization_id, partner_code) do nothing;

insert into public.partner_ownership_periods (
  id, organization_id, partner_id, effective_from, ownership_bps, profit_share_bps, source_reference
) values
  ('00000000-0000-4000-8000-00000000f253', '00000000-0000-4000-8000-00000000f001', '00000000-0000-4000-8000-00000000f251', '2026-01-01', 5000, 5000, 'phase1_source'),
  ('00000000-0000-4000-8000-00000000f254', '00000000-0000-4000-8000-00000000f001', '00000000-0000-4000-8000-00000000f252', '2026-01-01', 5000, 5000, 'phase1_source')
on conflict do nothing;

insert into public.bonus_schemes (
  id, organization_id, scheme_code, name, employee_kind, effective_from,
  minimum_score_bps, minimum_bonus_minor, maximum_bonus_minor,
  source_cutoff_policy, is_active
) values
  ('00000000-0000-4000-8000-00000000f261', '00000000-0000-4000-8000-00000000f001', 'MODERATOR_TEMPLATE', 'Moderator bonus template', 'moderator', '2026-01-01', 6000, 50000, 300000, '{"late_returns":"next_period_adjustment","status":"requires_approval"}', false),
  ('00000000-0000-4000-8000-00000000f262', '00000000-0000-4000-8000-00000000f001', 'OPERATIONS_TEMPLATE', 'Operations bonus template', 'operations', '2026-01-01', 6000, 50000, 200000, '{"late_returns":"next_period_adjustment","status":"requires_approval"}', false)
on conflict (organization_id, scheme_code, effective_from) do nothing;

insert into accounting.accounts (id, organization_id, code, name, account_type, normal_balance, is_control_account, allows_manual_posting)
select md5('falcon-account:' || code)::uuid, '00000000-0000-4000-8000-00000000f001', code, name, account_type, normal_balance, is_control, allows_manual
from (values
  ('1100', 'Falcon Vodafone Cash', 'asset', 'debit', true, false),
  ('1110', 'Falcon cash clearing', 'asset', 'debit', true, false),
  ('1200', 'Customer receivables', 'asset', 'debit', true, false),
  ('1210', 'Courier receivables', 'asset', 'debit', true, false),
  ('1300', 'Inventory', 'asset', 'debit', true, false),
  ('1410', 'Recoverable input tax', 'asset', 'debit', true, false),
  ('1400', 'Employee advances', 'asset', 'debit', true, false),
  ('2100', 'Customer deposits', 'liability', 'credit', true, false),
  ('2110', 'Customer credits and refunds', 'liability', 'credit', true, false),
  ('2200', 'Supplier payables', 'liability', 'credit', true, false),
  ('2210', 'Goods received not invoiced', 'liability', 'credit', true, false),
  ('2220', 'Courier payables', 'liability', 'credit', true, false),
  ('2230', 'Payroll payable', 'liability', 'credit', true, false),
  ('2240', 'Expense payable', 'liability', 'credit', true, false),
  ('2250', 'Partner loans payable', 'liability', 'credit', true, false),
  ('3100', 'Partner capital Ahmed', 'equity', 'credit', true, false),
  ('3110', 'Partner capital Maaz', 'equity', 'credit', true, false),
  ('3200', 'Partner current accounts', 'equity', 'credit', true, false),
  ('3300', 'Retained earnings', 'equity', 'credit', true, false),
  ('4100', 'Gross sales revenue', 'revenue', 'credit', false, false),
  ('4190', 'Sales discounts', 'contra_revenue', 'debit', false, false),
  ('4195', 'Sales returns', 'contra_revenue', 'debit', false, false),
  ('5100', 'Cost of goods sold', 'expense', 'debit', false, false),
  ('5110', 'Production cost variance', 'expense', 'debit', false, false),
  ('5200', 'Delivery expense', 'expense', 'debit', false, true),
  ('5290', 'Courier settlement variance', 'expense', 'debit', false, false),
  ('5295', 'Wallet reconciliation variance', 'expense', 'debit', false, false),
  ('5210', 'Return expense', 'expense', 'debit', false, true),
  ('6100', 'Payroll expense', 'expense', 'debit', false, false),
  ('6110', 'Bonus expense', 'expense', 'debit', false, false),
  ('6200', 'Operating expenses', 'expense', 'debit', false, true),
  ('6290', 'Financial transfer fees', 'expense', 'debit', false, true)
) as account_seed(code, name, account_type, normal_balance, is_control, allows_manual)
on conflict (organization_id, code) do nothing;

insert into accounting.account_roles (id, organization_id, role_key, description, expected_account_type, is_required_for_close)
select md5('falcon-account-role:' || role_key)::uuid, '00000000-0000-4000-8000-00000000f001', role_key, description, expected_type, required
from (values
  ('wallet_vodafone_maaz', 'Falcon Vodafone Cash wallet', 'asset', true),
  ('wallet_cash_clearing', 'Falcon cash clearing wallet', 'asset', true),
  ('customer_receivables', 'Customer trade receivables', 'asset', true),
  ('customer_deposits', 'Customer pre-delivery deposits', 'liability', true),
  ('customer_credits', 'Customer credit/refund liability', 'liability', true),
  ('courier_receivables', 'Contractual COD receivable', 'asset', true),
  ('inventory', 'Inventory control', 'asset', true),
  ('recoverable_input_tax', 'Recoverable supplier input tax', 'asset', true),
  ('supplier_payables', 'Supplier AP control', 'liability', true),
  ('goods_received_not_invoiced', 'GRNI control', 'liability', true),
  ('courier_payables', 'Courier fee payable', 'liability', true),
  ('payroll_payable', 'Payroll payable', 'liability', true),
  ('employee_advances', 'Employee advance receivable', 'asset', true),
  ('expense_payable', 'Expense payable', 'liability', true),
  ('partner_loans_payable', 'Partner loan liability', 'liability', true),
  ('partner_capital', 'Partner contributed capital', 'equity', true),
  ('partner_current_accounts', 'Partner current accounts', 'equity', true),
  ('retained_earnings', 'Retained earnings', 'equity', true),
  ('gross_sales_revenue', 'Gross sales', 'revenue', true),
  ('sales_discounts', 'Contra-revenue discounts', 'contra_revenue', true),
  ('sales_returns', 'Contra-revenue returns', 'contra_revenue', true),
  ('cost_of_goods_sold', 'Cost of goods sold', 'expense', true),
  ('production_cost_variance', 'Approved supplier production variance', 'expense', true),
  ('delivery_expense', 'Delivery expense', 'expense', false),
  ('courier_settlement_variance', 'Approved courier settlement variance', 'expense', true),
  ('wallet_reconciliation_variance', 'Approved wallet reconciliation difference', 'expense', true),
  ('payroll_expense', 'Payroll expense', 'expense', false),
  ('operating_expenses', 'Operating expenses', 'expense', false),
  ('financial_transfer_fees', 'Wallet transfer fees', 'expense', false)
) as role_seed(role_key, description, expected_type, required)
on conflict (organization_id, role_key) do nothing;

insert into accounting.account_role_mappings (organization_id, account_role_id, account_id, valid_from)
select '00000000-0000-4000-8000-00000000f001', ar.id, a.id, '2026-01-01'
from accounting.account_roles as ar
join accounting.accounts as a on a.organization_id = ar.organization_id and a.code = case ar.role_key
  when 'wallet_vodafone_maaz' then '1100' when 'customer_receivables' then '1200'
  when 'wallet_cash_clearing' then '1110'
  when 'customer_deposits' then '2100' when 'customer_credits' then '2110'
  when 'courier_receivables' then '1210' when 'inventory' then '1300'
  when 'recoverable_input_tax' then '1410'
  when 'supplier_payables' then '2200' when 'goods_received_not_invoiced' then '2210'
  when 'courier_payables' then '2220' when 'payroll_payable' then '2230'
  when 'employee_advances' then '1400'
  when 'expense_payable' then '2240' when 'partner_current_accounts' then '3200'
  when 'partner_capital' then '3100'
  when 'partner_loans_payable' then '2250'
  when 'retained_earnings' then '3300' when 'gross_sales_revenue' then '4100'
  when 'sales_discounts' then '4190' when 'sales_returns' then '4195'
  when 'cost_of_goods_sold' then '5100' when 'delivery_expense' then '5200'
  when 'courier_settlement_variance' then '5290'
  when 'wallet_reconciliation_variance' then '5295'
  when 'production_cost_variance' then '5110'
  when 'payroll_expense' then '6100' when 'operating_expenses' then '6200'
  when 'financial_transfer_fees' then '6290' end
where ar.organization_id = '00000000-0000-4000-8000-00000000f001'
on conflict do nothing;

insert into private.role_permissions(organization_id,role_id,permission_id)
select '00000000-0000-4000-8000-00000000f001',r.id,p.id
from private.roles r join private.permissions p on p.permission_key in('partners.capital.record','partners.loan.record')
where r.organization_id='00000000-0000-4000-8000-00000000f001' and r.role_key in('super_admin','finance_manager')
on conflict do nothing;
