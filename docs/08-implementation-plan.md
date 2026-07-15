# Implementation Plan

All Phase 2 work is local. Each migration is generated with the installed Supabase CLI, reviewed, applied from zero, and tested before the next domain. Rollback means a forward repair migration or local reset during development; applied migrations are never edited.

| Stage | Goal and likely files | Tests/reviews | Dependencies and rollback |
|---|---|---|---|
| 01 Foundation | Pin tooling; add `supabase/config.toml`, scripts, `.env.example`, migration/test layout; protect secrets. | Install/build/lint/typecheck, reset smoke, secret review. | None. Revert config/package changes; preserve `.env`. |
| 02 Schemas/IAM | Create organization, profiles compatibility, roles, permissions, assignments, private auth helpers. | RLS catalog, metadata abuse, role expiry, index review. | Foundation. Forward-drop only locally before data. |
| 03 Settings/reference | Effective finance settings, suppliers, couriers, wallets, account/reference enums. | Range/non-overlap/settings audit tests. | IAM. Repair seed/settings migration. |
| 04 Customers/catalog | Customers, addresses, products, variants, phone models, rates. | RLS, snapshot source, uniqueness/FK tests. | Reference. Additive correction. |
| 05 Orders/approvals | Orders/items, policies, discounts, exceptions, status history, generic approvals. | Deposit, gift, margin, SoD, state/concurrency tests. | Catalog/IAM. Forward constraints/functions repair. |
| 06 Payments | Payments, allocations, refunds, idempotent record/refund commands. | Allocation, duplicate, rollback, RLS tests; accounting mapping review. | Orders/wallet refs. Reverse test fixtures/reset locally. |
| 07 Printing/suppliers | Print batches/items, QC, effective prices, invoices/items/payments. | Pay-before-QC denial, snapshot, AP reconciliation. | Orders/catalog. Forward repair. |
| 08 Inventory | Locations, immutable movements, balances/reservations/custody. | No negative/duplicate movement, mixed supply, concurrent allocation. | Printing/catalog. Compensating movement. |
| 09 Shipping | Shipments, returns, rates, courier settlements/items. | Delivery/return states, expected formula, mismatch, concurrent consumption. | Orders/inventory. Reverse/cancel events. |
| 10 Wallets/expenses | Transfers, reconciliations, expenses, evidence links. | Profit-neutral transfer, fee, reconciliation, RLS. | IAM/settings. Reversal/adjustment. |
| 11 Ledger engine | Accounts, periods, entries/lines, post/reverse, posting map, immutable/period guards. | Balance, immutability, close lock, source uniqueness, privilege review. | All event models. Local reset or forward repair. |
| 12 Posting commands | Atomic payment, delivery/return, supplier/courier, wallet/expense postings with audit/outbox. | Accounting invariant, idempotency, partial failure, race suites. | Ledger. Reversal commands/forward repair. |
| 13 Payroll | Employees, bonus rules/slabs/reviews, advances, periods, entries/payments. | Score exclusions, ranges, day 1-10, partial pay, sensitive RLS. | Ledger/approvals. Reverse accrual/payment. |
| 14 Partners | Partners, capital/loans/current accounts, withdrawals/aggregation/approvals. | 300+300, concurrency, liquidity, SoD, no P&L impact. | Ledger/close settings. Reverse payment/current-account entry. |
| 15 Close/distribution | Close checklist/snapshots, lock command, distribution. | Reconciliations, suspense, lock, adjustment, 50/50 exact allocation. | All financial domains. Reopen prohibited; forward adjustment. |
| 16 Reports/types | Invoker views/private report RPCs, generated types, posting map/privilege docs. | Trial/subledger reconciliation, view-RLS bypass, type diff. | All schema. Drop/replace view in forward migration. |
| 17 Hardening | Advisors, grants, Storage policies, backup/restore smoke, legacy migration, full reset. | Full suite, secret/bundle scan, accounting/security review. | Everything. No production action; fix forward. |

## Migration design rules

- Keep schema/types before tables, tables before FKs/indexes, then functions/triggers, RLS/policies/grants, comments, and tests.
- Explicitly revoke default function/schema/table privileges before granting.
- Add indexes for FKs, unique business keys, effective ranges, common status/date queries, and RLS predicates; avoid speculative indexes.
- Backfill nullable columns before adding `NOT NULL`; validate large constraints separately in production planning.
- Seed only Falcon configuration, roles/permissions, chart of accounts, bonus slabs, synthetic users/data where local auth supports it.

## Phase 2 definition of done

Fresh local reset, ordered migrations, synthetic seed, generated types, typecheck, lint/build, database/RLS/accounting/idempotency/concurrency tests, zero critical findings, reviewed definer functions, private financial Storage, no secrets/real data, no deployment/push, and an evidence-based report.
