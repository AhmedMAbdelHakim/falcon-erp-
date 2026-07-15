# Migration Manifest

Migrations are immutable once applied outside a disposable local environment. This manifest records dependency order and intent; it does not replace the SQL review.

| Order | Migration | Purpose | Depends on |
|---:|---|---|---|
| 1 | `20260714162215_extensions_schemas_and_types.sql` | extensions, schemas, enums, shared timestamp trigger | empty Supabase PG17 database |
| 2 | `20260714162218_organization_iam_settings.sql` | Falcon organization boundary, versioned finance settings, profiles, roles, permissions, safe Auth bootstrap | 1, `auth.users` |
| 3 | `20260714162220_approvals_audit_and_commands.sql` | idempotent command claims, approvals, append-only audit, outbox, attachments | 2 |
| 4 | `20260714162223_customers_catalog_reference.sql` | customers, products/models, suppliers, couriers, price and shipping templates | 2-3 |
| 5 | `20260714162225_orders_payments_and_wallets.sql` | orders/items/status, discounts, wallets, receipts, allocations, credits, refunds, transfers, reconciliation | 4 |
| 6 | `20260714162227_printing_inventory_shipping_expenses.sql` | production attempts, QC/GRNI, supplier invoices, immutable inventory, itemized shipping/returns, courier settlement, expenses | 5 |
| 7 | `20260714162229_payroll_partners.sql` | employees, bonus inputs, payroll, partner capital/loans/withdrawals/distributions | 2-6 |
| 8 | `20260714162231_accounting_ledger_and_periods.sql` | chart of accounts, mappings, periods, journals, lines, posting/close records | 2-7 |
| 9 | `20260714162233_financial_posting_functions.sql` | period locking, balanced posting, immutable ledger, reversal, posting-event claims | 8 |
| 10 | `20260714162235_transactional_business_rpcs.sql` | private transactional command implementations and narrow `api` wrappers | 3-9 |
| 11 | `20260714162237_rls_grants_storage.sql` | RLS, privileges, function execution grants, private storage buckets/policies | 1-10, `storage` schema |
| 12 | `20260714162239_reporting_and_performance.sql` | security-invoker operational/accounting views and workload indexes | 1-11 |
| Seed | `supabase/seed.sql` | synthetic Falcon reference structure; no Auth users, balances, customers, sales, or asserted live prices | all migrations |

## Application Rules

- Apply through the pinned Supabase CLI, never by Dashboard-only mutation.
- A failed local reset blocks deployment and generated-type claims.
- New corrections receive a new timestamped migration; existing applied files are not edited.
- Seed is repeatable and non-production. Production opening balances require reconciled journals in an approved open period.

## Legacy Schema

`supabase/schema.sql` predates this migration chain and is not an input to `supabase db reset`. It contains the former shipping-label authorization model and must not be manually applied alongside these migrations. Its removal or archival can be handled after the new system passes reset and data-migration planning is approved.
