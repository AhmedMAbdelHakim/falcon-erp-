# Database Data Dictionary

## Shared Contract

Unless a row below says otherwise, business tables use a UUID `id` primary key, `organization_id` FK, `timestamptz` audit columns, explicit checks, named FKs, and indexes for FK/join and operational-filter paths. Money is EGP `bigint` minor units; percentages are basis points. Operational source tables are retained and deactivated/reversed rather than hard-deleted. Every `public` source table is RLS protected; authenticated users receive select only through relation-aware policies and mutate financial state through `api` RPCs. Exact fields, constraints, FK actions, comments, and indexes live in the named migration and remain the review authority.

**Retention codes:** `MASTER` = archive/deactivate; `EVENT` = append-only or reversal; `FIN` = statutory/accounting retention and no destructive delete; `TEMP` = operational lifecycle but audit retained.

| Table | Purpose / source of truth | Sensitive fields | Mutation / retention |
|---|---|---|---|
| `public.organizations` | Falcon organization, currency and timezone boundary | legal name | migration/admin only; MASTER |
| `public.profiles` | Auth user application status and organization link | identity/status | admin command; MASTER |
| `private.organization_finance_settings` | effective financial policy versions | approval and reserve settings | approved versioning; FIN |
| `private.roles` | organization role definitions | capability grouping | admin command; MASTER |
| `private.permissions` | global capability catalog | sensitive flag | migration/admin; MASTER |
| `private.role_permissions` | effective role grants/revocations | grant actors | admin command; EVENT |
| `private.user_roles` | effective user assignments | identity and revocation reason | admin command; EVENT |
| `private.command_executions` | idempotency claim and replay outcome | actor, fingerprint, sanitized error | private RPC only; FIN |
| `public.approval_requests` | fingerprint/amount-bound approval envelope | actor, reason, payload | approval commands; FIN |
| `public.approval_actions` | approval decision history | actor/reason | append-only; FIN |
| `private.outbox_events` | reliable post-commit integration queue | payload | worker only; EVENT |
| `audit.events` | security and financial audit trail | actor/IP/context | append-only; FIN |
| `public.attachments` | private storage object metadata and parent link | object path/checksum/classification | upload command; FIN |
| `public.customers` | customer master and normalized phone identity | name/phone/contact | customer commands; MASTER |
| `public.customer_addresses` | customer shipping addresses | full address | customer commands; MASTER |
| `public.phone_brands` | phone manufacturer reference | none | reference admin; MASTER |
| `public.phone_models` | model and cost-risk warning | risk note | reference admin; MASTER |
| `public.product_categories` | product hierarchy | none | reference admin; MASTER |
| `public.products` | sellable/service product definition | none | catalog admin; MASTER |
| `public.product_variants` | SKU/model-specific variant | SKU/barcode | catalog admin; MASTER |
| `public.suppliers` | supplier master | contact/phone/terms | finance admin; MASTER |
| `public.couriers` | courier and settlement schedule | contact/phone | operations admin; MASTER |
| `public.shipping_zones` | non-priced zone template | none | operations admin; MASTER |
| `public.product_price_rules` | effective sale-price rules | prices | finance/catalog command; FIN |
| `public.supplier_price_rules` | effective supplier cost rules | costs | finance command; FIN |
| `public.shipping_rate_rules` | effective courier commercial terms | rates | finance command; FIN |
| `public.orders` | order contractual aggregate and frozen policy totals | customer/shipping/payment totals | order commands; FIN |
| `public.order_items` | item-level terms, cost snapshots and fulfillment | prices/cost/margin | order commands; FIN |
| `public.order_status_history` | order transition evidence | actor/reason | append-only; EVENT |
| `public.order_exceptions` | payment/margin policy exception state | approval/reason | approval commands; FIN |
| `public.order_discounts` | order discount grant and snapshot | discount/reason | discount command; FIN |
| `public.order_discount_allocations` | deterministic item discount allocation | allocated amount | command only; FIN |
| `public.order_problems` | operational problem ownership/state | responsibility/reason | operations command; EVENT |
| `public.order_problem_costs` | financial impact of problems | costs/responsibility | finance command; FIN |
| `public.wallets` | wallet metadata, never stored balance | legal owner/last4 | finance admin; MASTER |
| `public.customer_payments` | receipt evidence and review lifecycle | transaction reference/evidence | payment commands; FIN |
| `public.payment_allocations` | confirmed receipt allocation to orders | amounts | payment command; FIN |
| `public.customer_credits` | customer liability lots | balances | payment/refund command; FIN |
| `public.customer_credit_movements` | immutable credit use/refund events | amounts | append-only command; FIN |
| `public.refunds` | bounded request/approval/execution lifecycle | payment/evidence/amount | refund commands; FIN |
| `public.wallet_transfers` | cash-location transfer lifecycle | references/fees | wallet command; FIN |
| `public.wallet_reconciliations` | book-to-provider reconciliation | actual balance/evidence | reconciliation command; FIN |
| `public.wallet_reconciliation_items` | reconciliation movement matching | external references | reconciliation command; FIN |
| `public.print_batches` | supplier production batch | totals/status | printing commands; FIN |
| `public.print_batch_items` | one production attempt per order item sequence | cost/quantity | printing commands; FIN |
| `public.print_batch_receipts` | physical supplier receipt header | evidence | receipt command; EVENT |
| `public.print_batch_receipt_items` | received quantity by attempt | quantity/cost | receipt command; EVENT |
| `public.print_batch_qc_events` | accepted/rejected QC quantities | defect evidence | append-only; EVENT |
| `public.grni_accruals` | accepted receipt inventory/GRNI obligation | cost/journal | posting command; FIN |
| `public.supplier_invoices` | supplier invoice approval/posting aggregate | tax/amount/evidence | supplier commands; FIN |
| `public.supplier_invoice_items` | invoice-to-attempt/GRNI match | cost/variance | supplier commands; FIN |
| `public.supplier_payments` | append-only AP payment/reversal | wallet/reference | payment command; FIN |
| `public.inventory_locations` | custody/location reference | none | reference admin; MASTER |
| `public.inventory_reservations` | order-item stock commitment | quantity/cost | inventory command; TEMP |
| `public.inventory_movements` | authoritative append-only quantity/cost events | costs/responsibility | inventory command; FIN |
| `public.shipments` | frozen courier contract and shipment state | recipient evidence/COD/fees | shipping commands; FIN |
| `public.shipment_items` | partial delivery/return quantities and frozen allocations | margin/cost/journals | delivery owner command; FIN |
| `public.shipment_status_history` | shipment transition evidence | actor/reason | append-only; EVENT |
| `public.returns` | return header and evidence lifecycle | reason/evidence | return command; FIN |
| `public.return_items` | item quantity/disposition and reversal link | cost/refund | return command; FIN |
| `public.courier_settlements` | reviewed COD/fee settlement aggregate | transfer/difference/evidence | settlement commands; FIN |
| `public.courier_settlement_items` | immutable contractual/remittance settlement lines | amounts/source | settlement command; FIN |
| `public.expense_categories` | evidence/approval category policy | none | finance admin; MASTER |
| `public.expenses` | expense/payable approval aggregate | counterparty/evidence/amount | expense commands; FIN |
| `public.expense_payments` | append-only expense payment/reversal | wallet/reference | payment command; FIN |
| `public.employees` | employee master and payroll enablement | identity/payment recipient | payroll admin; MASTER |
| `public.employee_compensation_periods` | effective approved compensation | salary/policy | payroll command; FIN |
| `public.employee_advances` | employee receivable lifecycle | amount/payment | payroll command; FIN |
| `public.bonus_schemes` | effective approved bonus policy/template | payout ranges | payroll admin; FIN |
| `public.bonus_metrics` | weighted performance definitions | source formula | payroll admin; MASTER |
| `public.bonus_slabs` | score-to-bonus bands | bonus amount | payroll admin; FIN |
| `public.employee_performance_reviews` | cutoff-stable calculation snapshot | attribution/score/bonus | payroll command; FIN |
| `public.employee_performance_scores` | metric-level scored inputs | score/evidence | payroll command; FIN |
| `public.bonus_adjustments` | late-return/approved next-period adjustment | amount/reason | payroll command; FIN |
| `public.payroll_periods` | monthly Cairo payroll run | policy/approval | payroll commands; FIN |
| `public.payroll_entries` | employee accrual snapshot and payment state | salary/bonus/deductions | payroll commands; FIN |
| `public.payroll_payments` | append-only payroll payment/reversal | recipient/reference | payroll command; FIN |
| `public.partners` | stable partner identity/serialization row | profile identity | admin; MASTER |
| `public.partner_ownership_periods` | effective ownership/profit percentages | approval/source | approved command/source constitution; FIN |
| `public.partner_capital_transactions` | capital/current-account events | amount/evidence | partner finance command; FIN |
| `public.partner_loans` | partner loan principal and repayment state | terms/amount | partner finance command; FIN |
| `public.partner_withdrawals` | rolling-24h controlled draw lifecycle | liquidity/source balances | withdrawal commands; FIN |
| `public.profit_distributions` | closed-period distribution aggregate | profit/reserve/approval | distribution command; FIN |
| `public.profit_distribution_lines` | deterministic partner allocations | percentage/amount | distribution command; FIN |
| `accounting.accounts` | organization chart of accounts | none | migration/approved admin; MASTER |
| `accounting.account_roles` | semantic posting role catalog | none | migration/approved admin; MASTER |
| `accounting.account_role_mappings` | effective account-role resolution | mapping | approved admin; FIN |
| `accounting.accounting_periods` | open/closing/closed period lock row | close/reopen actor | close commands; FIN |
| `accounting.journal_entries` | posted double-entry header and source claim | approval/correlation | posting/reversal only; FIN |
| `accounting.journal_lines` | authoritative debit/credit and dimensions | subledger IDs | posting/reversal only; FIN |
| `accounting.posting_events` | unique source-purpose posting claim | command fingerprint | append-only; FIN |
| `accounting.monthly_closings` | close validation and cumulative result snapshot | reserves/profit/approval | close commands; FIN |
| `accounting.closing_checklist_items` | blocking reconciliation controls | evidence/waiver | close commands; FIN |

## Views

The 18 reporting views are derived and never authoritative. Public operational views use `security_invoker`; accounting and audit views remain ungranted and require a later authorized reporting boundary. `wallet_balance_summary` deliberately reports confirmed receipts, not an authoritative wallet balance; posted mapped ledger lines remain the balance source.
