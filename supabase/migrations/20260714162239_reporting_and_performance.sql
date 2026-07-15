create view public.order_financial_summary
with (security_invoker = true)
as
select
  o.organization_id, o.id as order_id, o.order_number, o.customer_id, o.status, o.payment_status,
  o.products_subtotal_minor, o.discount_total_minor, o.shipping_charge_minor, o.order_total_minor,
  o.required_deposit_minor, o.confirmed_payment_minor, o.balance_due_minor,
  o.expected_cost_minor, o.actual_cost_minor, o.expected_margin_minor, o.actual_margin_minor,
  o.confirmed_at, o.delivered_at, o.financially_settled_at
from public.orders as o;

create view public.order_item_margin_summary
with (security_invoker = true)
as
select
  i.organization_id, i.order_id, i.id as order_item_id, i.line_number, i.item_type,
  i.fulfillment_status, i.quantity, i.line_gross_minor, i.line_discount_minor,
  i.line_revenue_minor, i.unit_expected_cost_minor * i.quantity::bigint as expected_cost_minor,
  i.actual_cost_minor, i.line_revenue_minor - i.actual_cost_minor as actual_margin_minor,
  i.costing_status
from public.order_items as i;

create view public.wallet_balance_summary
with (security_invoker = true)
as
select
  w.organization_id, w.id as wallet_id, w.code, w.name, w.provider, w.currency, w.is_active,
  coalesce(sum(p.amount_minor) filter (where p.status = 'confirmed'), 0)::bigint as confirmed_customer_receipts_minor,
  max(p.confirmed_at) filter (where p.status = 'confirmed') as last_confirmed_receipt_at
from public.wallets as w
left join public.customer_payments as p on p.organization_id = w.organization_id and p.wallet_id = w.id
group by w.organization_id, w.id, w.code, w.name, w.provider, w.currency, w.is_active;

create view public.wallet_reconciliation_summary
with (security_invoker = true)
as
select
  r.organization_id, r.id as reconciliation_id, r.wallet_id,
  r.period_started_at, r.period_ended_at, r.reconciliation_date,
  r.status, r.opening_book_balance_minor, r.system_movements_minor,
  r.expected_closing_balance_minor, r.actual_closing_balance_minor,
  r.difference_minor, r.finalized_at
from public.wallet_reconciliations as r;

create view public.customer_deposit_summary
with (security_invoker = true)
as
select
  c.organization_id, c.customer_id,
  sum(c.original_amount_minor)::bigint as original_credit_minor,
  sum(c.remaining_amount_minor)::bigint as available_credit_minor,
  count(*) filter (where c.remaining_amount_minor > 0)::bigint as open_credit_lots
from public.customer_credits as c
group by c.organization_id, c.customer_id;

create view public.supplier_payable_summary
with (security_invoker = true)
as
select
  i.organization_id, i.supplier_id,
  sum(i.total_minor)::bigint as invoiced_minor,
  coalesce(sum(p.paid_minor), 0)::bigint as paid_minor,
  (sum(i.total_minor) - coalesce(sum(p.paid_minor), 0))::bigint as open_payable_minor
from public.supplier_invoices as i
left join lateral (
  select sum(case when sp.reverses_supplier_payment_id is null then sp.amount_minor else -sp.amount_minor end)::bigint as paid_minor
  from public.supplier_payments as sp
  where sp.organization_id = i.organization_id and sp.supplier_invoice_id = i.id
) as p on true
where i.status not in ('draft', 'cancelled', 'reversed')
group by i.organization_id, i.supplier_id;

create view public.courier_receivable_summary
with (security_invoker = true)
as
select
  s.organization_id, s.courier_id,
  sum(s.expected_cod_minor)::bigint as contractual_cod_minor,
  coalesce(sum(s.reported_collected_cod_minor), 0)::bigint as courier_reported_cod_minor,
  sum(s.courier_delivery_fee_minor + s.courier_return_fee_minor)::bigint as accrued_courier_fees_minor,
  count(*) filter (where s.settlement_status <> 'settled')::bigint as unsettled_shipments
from public.shipments as s
where s.status in ('partially_delivered', 'delivered', 'returned')
group by s.organization_id, s.courier_id;

create view public.courier_settlement_summary
with (security_invoker = true)
as
select
  s.organization_id, s.id as settlement_id, s.courier_id, s.settlement_no,
  s.period_start, s.period_end, s.status, s.contractual_cod_minor, s.delivery_fees_minor,
  s.return_fees_minor, s.expected_net_settlement_minor, s.actual_transfer_minor,
  s.difference_minor, s.difference_classification, s.is_off_cycle
from public.courier_settlements as s;

create view public.inventory_balance_by_location
with (security_invoker = true)
as
select
  movement.organization_id,
  movement.location_id,
  movement.product_variant_id,
  sum(movement.quantity_delta)::bigint as quantity_on_hand,
  sum(movement.cost_delta_minor)::bigint as inventory_cost_minor
from (
  select organization_id, to_location_id as location_id, product_variant_id,
    quantity::bigint as quantity_delta, total_cost_minor::bigint as cost_delta_minor
  from public.inventory_movements where to_location_id is not null
  union all
  select organization_id, from_location_id as location_id, product_variant_id,
    -quantity::bigint, -total_cost_minor::bigint
  from public.inventory_movements where from_location_id is not null
) as movement
group by movement.organization_id, movement.location_id, movement.product_variant_id;

create view public.inventory_negative_balance_alerts
with (security_invoker = true)
as
select *
from public.inventory_balance_by_location
where quantity_on_hand < 0 or inventory_cost_minor < 0;

create view public.employee_bonus_summary
with (security_invoker = true)
as
select
  r.organization_id, r.employee_id,
  count(*)::bigint as review_count,
  count(*) filter (where r.status = 'approved')::bigint as approved_review_count,
  max(r.metric_period_end) as latest_review_period_end
from public.employee_performance_reviews as r
group by r.organization_id, r.employee_id;

create view public.payroll_status_summary
with (security_invoker = true)
as
select
  e.organization_id, e.payroll_period_id, e.status,
  count(*)::bigint as employee_count,
  sum(e.net_payroll_minor)::bigint as net_payroll_minor,
  sum(e.paid_minor)::bigint as paid_minor,
  sum(e.net_payroll_minor - e.paid_minor)::bigint as outstanding_minor
from public.payroll_entries as e
group by e.organization_id, e.payroll_period_id, e.status;

create view public.partner_account_summary
with (security_invoker = true)
as
select
  p.organization_id, p.id as partner_id, p.partner_code, p.full_name,
  coalesce((select sum(case when t.transaction_type in ('capital_contribution', 'current_account_credit') then t.amount_minor else -t.amount_minor end)
    from public.partner_capital_transactions as t where t.organization_id = p.organization_id and t.partner_id = p.id), 0)::bigint as capital_and_current_minor,
  coalesce((select sum(w.requested_amount_minor) from public.partner_withdrawals as w
    where w.organization_id = p.organization_id and w.partner_id = p.id and w.status = 'executed'), 0)::bigint as executed_withdrawals_minor,
  coalesce((select sum(l.allocated_amount_minor)
    from public.profit_distribution_lines as l
    join public.profit_distributions as d
      on d.id = l.profit_distribution_id and d.organization_id = l.organization_id
    where l.organization_id = p.organization_id and l.partner_id = p.id and d.status = 'posted'), 0)::bigint as allocated_profit_minor
from public.partners as p;

create view accounting.monthly_profit_and_loss
with (security_invoker = true)
as
select
  je.organization_id,
  date_trunc('month', je.accounting_date)::date as month_start,
  sum(case when a.account_type = 'revenue' then jl.credit_minor - jl.debit_minor else 0 end)::bigint as gross_revenue_minor,
  sum(case when a.account_type = 'contra_revenue' then jl.debit_minor - jl.credit_minor else 0 end)::bigint as contra_revenue_minor,
  sum(case when a.account_type = 'expense' then jl.debit_minor - jl.credit_minor else 0 end)::bigint as expense_minor,
  sum(case
    when a.account_type = 'revenue' then jl.credit_minor - jl.debit_minor
    when a.account_type in ('contra_revenue', 'expense') then jl.credit_minor - jl.debit_minor
    else 0 end)::bigint as profit_loss_minor
from accounting.journal_entries as je
join accounting.journal_lines as jl on jl.journal_entry_id = je.id
join accounting.accounts as a on a.id = jl.account_id
where je.status in ('posted', 'reversed')
group by je.organization_id, date_trunc('month', je.accounting_date)::date;

create view accounting.monthly_close_readiness
with (security_invoker = true)
as
select
  p.organization_id, p.id as accounting_period_id, p.period_start, p.period_end, p.status,
  c.id as monthly_closing_id, c.status as closing_status,
  count(i.id) filter (where i.is_blocking and i.status <> 'passed')::bigint as blocking_items,
  coalesce(bool_and(not i.is_blocking or i.status = 'passed'), false) as is_ready
from accounting.accounting_periods as p
left join accounting.monthly_closings as c on c.organization_id = p.organization_id and c.accounting_period_id = p.id
left join accounting.closing_checklist_items as i on i.monthly_closing_id = c.id
group by p.organization_id, p.id, p.period_start, p.period_end, p.status, c.id, c.status;

create view public.unposted_financial_events
with (security_invoker = true)
as
select
  si.organization_id, 'shipment_item_delivery'::text as event_type, si.id as event_id,
  si.delivered_at as occurred_at, si.order_item_id as subject_id
from public.shipment_items as si
where si.delivered_quantity > 0 and si.revenue_journal_entry_id is null
union all
select
  e.organization_id, 'approved_expense'::text, e.id, e.updated_at, e.id
from public.expenses as e
where e.status in ('approved', 'partially_paid', 'paid') and e.journal_entry_id is null;

create view public.approval_queue_summary
with (security_invoker = true)
as
select
  a.organization_id, a.request_type, a.status,
  count(*)::bigint as request_count,
  min(a.requested_at) as oldest_requested_at,
  sum(coalesce(a.requested_amount_minor, 0))::bigint as requested_amount_minor
from public.approval_requests as a
where a.status in ('draft', 'submitted', 'approved')
group by a.organization_id, a.request_type, a.status;

create view audit.audit_exception_summary
with (security_invoker = true)
as
select
  e.organization_id, e.event_category, e.action, e.result,
  count(*)::bigint as event_count,
  min(e.occurred_at) as first_occurred_at,
  max(e.occurred_at) as last_occurred_at
from audit.events as e
where e.result in ('denied', 'failed')
group by e.organization_id, e.event_category, e.action, e.result;

revoke all on all tables in schema accounting from public, anon, authenticated;
revoke all on all tables in schema audit from public, anon, authenticated;
grant select on public.order_financial_summary, public.order_item_margin_summary,
  public.wallet_balance_summary, public.wallet_reconciliation_summary,
  public.customer_deposit_summary, public.supplier_payable_summary,
  public.courier_receivable_summary, public.courier_settlement_summary,
  public.inventory_balance_by_location, public.inventory_negative_balance_alerts,
  public.employee_bonus_summary, public.payroll_status_summary,
  public.partner_account_summary, public.unposted_financial_events,
  public.approval_queue_summary to authenticated;

comment on view public.wallet_balance_summary is 'Operational receipt summary only; authoritative wallet balance comes from mapped posted ledger lines.';
comment on view accounting.monthly_profit_and_loss is 'Security-invoker P&L from posted ledger lines; exposed only through a separately authorized server/reporting command.';
