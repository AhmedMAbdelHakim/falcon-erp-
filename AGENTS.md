# Falcon Accounting and Operations Constitution

## Project and authority

This repository contains Falcon's internal shipping-label application and the planned accounting and operations backend. The primary business source is `falcon_accounts_chat_full.md`. Requirements derived from it are governed by `docs/00-source-of-truth.md`, `docs/03-accounting-policy.md`, accepted ADRs, the requirements catalog, and the traceability matrix, in that order.

When sources conflict, record the conflict and choose the interpretation that prevents incorrect posting, unauthorized disclosure, data loss, duplicate revenue, unapproved withdrawals, or closed-period mutation. Never hide an assumption in code.

## Phase control

- Do not enter a later phase without an explicit user prompt for that phase.
- Phase 1 creates documentation only; Phase 2 may create local backend code, migrations, seed data, generated types, and tests; Phase 3 owns final UI and deployment work.
- Never deploy, run remote migrations, modify production data, push, merge, or use real customer data without an explicit instruction.
- Do not claim success until the required commands have actually run and their results are reported.

## Current commands

```powershell
npm ci
npm run lint
npm run build
```

Phase 2 must add explicit `typecheck`, database reset, database test, and generated-type verification commands before relying on them.

## Code standards

- Use TypeScript strict settings, English `snake_case` database identifiers, and clear domain boundaries.
- Preserve the existing shipping-label workflow unless an approved migration explicitly replaces it.
- Keep browser code free of privileged keys and financial posting authority.
- Use Arabic, RTL, mobile-first UI text in Phase 3; code and API identifiers remain English.
- Derived totals are projections or cached values only; document their authoritative source.

## Money and accounting

- Store EGP as signed `bigint` minor units; suffix monetary columns with `_minor`.
- `100` minor units equals EGP 1. Percentages use basis points, where `10000` is 100%.
- Do not use `float`, `real`, `double precision`, or JavaScript floating-point arithmetic for money.
- Use double-entry accounting. Every posted journal entry must balance and must be immutable.
- Correct posted entries through an approved reversal and, when needed, a corrected entry.
- Customer deposits are liabilities until delivery. Delivery and courier settlement are separate events.
- Partner withdrawals are equity/current-account movements, never operating expenses.
- Wallet transfers do not affect profit; transfer fees are separate expenses.
- Closed periods reject direct mutation. Adjustments post into an open period with references to the affected period.

## Database and transactions

- SQL migrations in `supabase/migrations/` are the database source of truth. Never edit an already-applied migration; add a new forward migration.
- Use UUID primary keys, explicit foreign keys, named checks, unique constraints, comments, and indexes supporting foreign keys and policy predicates.
- Critical commands execute in one database transaction through narrowly granted RPCs.
- The client must not insert journal entries, post/reverse entries, close periods, approve withdrawals, or transition sensitive financial state directly.
- Use row locks and deterministic lock order for concurrent financial commands.
- Every posting command and period close must derive the Cairo accounting date and lock the same `accounting_periods` row before checking open/closed state.
- Withdrawal aggregation must lock the stable partner row before summing non-cancelled requests in the rolling 24-hour window; locking only existing withdrawal rows is insufficient.
- Every externally retryable command has a scoped idempotency key, request fingerprint, stored outcome, and correlation ID.
- Claim idempotency with a unique `(organization_id, command_type, idempotency_key)` row; concurrent claimants wait on that row and then replay or reject by fingerprint.
- Snapshot effective prices, costs, discounts, shipping rates, payment policies, bonus rules, and ownership shares at the event that fixes them.
- Triggers are limited to timestamps, append-only audit support, immutable/closed-period guards, and final invariant enforcement. Business transitions use explicit commands.

## Supabase, RLS, and privileges

- Enable RLS on every table in an exposed schema and test both allowed and denied access.
- `authenticated` is authentication, not authorization. Policies must check organization, role, ownership, or assigned work as appropriate.
- Authorization data must not come from `raw_user_meta_data` or other user-editable claims.
- Prefer database role mappings. JWT/app metadata may be a cache, not the sole authority for sensitive commands.
- Put privileged helpers in a non-exposed schema. Every `SECURITY DEFINER` function must set a safe `search_path`, authenticate and authorize explicitly, and have `EXECUTE` revoked from `PUBLIC` before narrow grants.
- Views exposed through the Data API must be `security_invoker` where supported; otherwise keep them private or revoke API access.
- Financial attachments use private Storage buckets and object-level policies.
- Apply least privilege and separation of request, approval, posting, reversal, and period close.

## Audit, deletion, and secrets

- Financial, approval, security, and configuration events require append-only audit records with actor, time, correlation, before/after metadata where lawful, and reason.
- Never hard-delete posted financial records, payments, approvals, settlements, payroll, withdrawals, or audit events. Use cancel, void, or reverse workflows.
- Never read, print, commit, or expose secret values. Do not modify the real `.env` unless explicitly authorized.
- `.env`, service-role keys, database passwords, access tokens, and real receipts/customer records must not enter Git.

## Testing policy

- Test schema constraints, RLS positive and negative paths, RPC privileges, accounting invariants, idempotency, concurrency, reversals, period locks, reconciliations, and reset-from-zero.
- Required regression cases are listed in `docs/07-testing-strategy.md`; a migration is incomplete until its tests pass on a fresh local reset.
- Seed only synthetic identities and data. Tests must be deterministic and independent of remote services.

## Definition of done

A phase is complete only when its traceability rows are covered, required migrations and tests apply from zero, generated types are current, lint/typecheck/tests pass, critical security and accounting findings are zero, user changes are preserved, and the phase report lists the actual evidence.

## Protected files and actions

- Do not alter or delete `.env`, user assets, existing shipping-label behavior, production data, or Git history without explicit approval.
- Never use `git reset --hard`, `git clean`, force push, or destructive database reset against a remote project.
- Do not replace `falcon_accounts_chat_full.md`; preserve its SHA-256 provenance in `docs/00-source-of-truth.md`.
