# Phase 2 Test Coverage Matrix

All rows are `VERIFIED` by the final local run of 20 files and 328 pgTAP assertions unless a separate harness is named.

| Area | Executed assertion | Evidence | Status |
|---|---|---|---|
| Schema | required schemas, tables, functions, types, indexes, triggers | `database/001`, `database/030`, `database/140` | VERIFIED |
| Reset | complete migration history and synthetic seed apply from zero | `npm run db:reset` | VERIFIED |
| RLS | every exposed table has RLS; assigned and denied paths execute | `rls/001`, `010`, `020`, `030`, `database/140` | VERIFIED |
| Views and read RPCs | views execute as `security_invoker`; API read wrappers are invoker-only and narrowly granted | `rls/030`, `database/140` | VERIFIED |
| Read-role matrix | finance, partner, auditor, super-admin, read-only, operations, moderator, and no-role paths | `database/140` | VERIFIED |
| Read isolation | organization mismatch, direct private-base reads, and anonymous execution fail | `database/140` | VERIFIED |
| Read privacy | close evidence and audit payloads omit confidential fields; reconciliation output is aggregate | `database/140` | VERIFIED |
| Financial reports | dashboard, P&L, trial balance, liquidity, and control reconciliation derive from ledger truth | `database/140` | VERIFIED |
| Ledger reads | header/line filters, deterministic cursors, page limits, empty results, and balance | `database/140` | VERIFIED |
| Close and audit reads | open/closed states, checklist filtering/masking, audit filtering and pagination | `database/140` | VERIFIED |
| Command boundary | authenticated direct financial DML denied | `rls/030`, workflow tests | VERIFIED |
| Ledger | debits equal credits; posted records immutable | `database/010`, workflow suites | VERIFIED |
| Periods | close/post share lock; closing/closed periods reject posts | `database/090`, concurrency harness | VERIFIED |
| Idempotency | same key/payload replays; changed payload fails | `database/020`, `040`, `110`, `120`, `130`, harness | VERIFIED |
| Retry | deadlock/serialization classification and retry claim release | `database/030`, implementation audit, harness | VERIFIED |
| Orders | deterministic discounts, confirmation, cancel | `database/050`, `130` | VERIFIED |
| Payments | intake, confirmation, allocation, customer credit | `database/040` | VERIFIED |
| Refunds | request, approval, execution, reversal | `database/040` | VERIFIED |
| Payment reversal | receipt and downstream state reverse without mutation | `database/040` | VERIFIED |
| Delivery | revenue posts once from item-level delivery | `database/050` | VERIFIED |
| Inventory | delivery/return/production quantities conserve stock | `database/050`, `070` | VERIFIED |
| Printing | batch lifecycle and QC evidence | `database/070` | VERIFIED |
| GRNI | accepted receipt capitalizes; invoice clears matched accrual | `database/070` | VERIFIED |
| Supplier | invoice approval, payment, reversal-aware report | `database/070` | VERIFIED |
| Courier | contractual COD/fee, reported cash, settlement differences | `database/050` | VERIFIED |
| Expenses | record, approve, pay, approved reversal | `database/060` | VERIFIED |
| Payroll | calculate, freeze, approve, pay | `database/060` | VERIFIED |
| Advances | employee receivable posts without payroll expense | `database/060` | VERIFIED |
| Partners | capital, loan, rolling withdrawal, identity and SoD | `database/080` | VERIFIED |
| Distribution | closed basis, ownership floor, retained remainder, post | `database/080` | VERIFIED |
| Wallet transfer | principal P&L-neutral; fee separate | `database/120` | VERIFIED |
| Wallet reconciliation | ledger-derived expected balance and variance | `database/100`, `database/140` | VERIFIED |
| Manual journals | control accounts/source bypass denied | `database/110` | VERIFIED |
| Reversals | exact inverse, approval consumed, reports net reversals | `database/040`, `060`, `070`, `110`, `140` | VERIFIED |
| Monthly close | 15 controls, attestation, reserve, approve, close/recover/reopen | `database/090`, `database/140` | VERIFIED |
| Legacy shipping | data and organization ownership preserved | `database/025`, `rls/020` | VERIFIED |
| Types | generated from the final local catalog, including all 10 read RPCs | `npm run db:types` | VERIFIED |
| Application | typecheck, production build, ESLint | required command sequence | VERIFIED |

## Required Commands

```powershell
npm run db:reset
npm run db:lint
npm run db:test
npm run db:test:concurrency
npm run db:types
npm run typecheck
npm run build
npm run lint
```

All commands exited 0 on 2026-07-15 in the order shown. Exact results are in `phase-2-test-evidence.md`.
