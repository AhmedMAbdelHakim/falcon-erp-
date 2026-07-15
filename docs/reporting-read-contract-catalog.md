# Reporting Read Contract Catalog

Evidence date: 2026-07-15, Africa/Cairo. Status: `VERIFIED` by clean reset, generated types, and `database/140_read_contracts.sql`.

## Shared Rules

- Every contract requires an authenticated user with a current database role and the stated permission for the requested organization.
- Money is signed EGP minor-unit `bigint`. Accounting filters are `date` values interpreted as Cairo business dates.
- Financial truth comes from `posted` and `reversed` journal entries. A reversal and its original remain visible and net through their lines.
- Closed periods remain readable. Adjustments post in an open period and expose `affected_closed_period_id` for drill-down.
- Lists use deterministic keyset cursors and enforce page sizes from 1 through 100.
- API wrappers are `SECURITY INVOKER`; non-exposed private implementations are `SECURITY DEFINER`, use an empty search path, and re-check live database permissions.
- `PUBLIC` and `anon` execution are revoked. `authenticated` receives explicit per-function execution only.

## Contracts

| Contract | Definition and source | Server filters / pagination | Permission | Reconciliation and freshness | Drill-down / closed behavior |
|---|---|---|---|---|---|
| `api.read_dashboard_summary` | Period revenue, contra revenue, net revenue, expense and profit from journal account types; cumulative wallet cash from wallet-dimension lines; protected control liabilities, pending withdrawals, reserve, safe cash, wallet reconciliation and alert counts | Required `period_start`, `period_end` | `ledger.read` | `last_posted_at`, `last_reconciled_at`, `generated_at`; liquidity uses the same conservative formula as withdrawal execution | Journal, reconciliation, approval, unposted-event and inventory alert routes; closed entries remain included as-of |
| `api.read_profit_and_loss` | Monthly gross revenue, contra revenue, net revenue, expense and profit/loss from journal lines and account types | Required date range; one row per month | `ledger.read` | Direct ledger aggregation; `last_posted_at`, `generated_at` | Month to journal list; returns explicit `period_status`, including `closed` |
| `api.read_trial_balance` | Opening net converted to debit/credit, period movement, and closing debit/credit by chart account | Required date range | `ledger.read` | Closing debit total must equal closing credit total; `generated_at` | Account to journal lines; closed rows remain immutable and readable |
| `api.read_control_account_reconciliation` | Effective mapped wallet, customer-money, courier, supplier/GRNI, payroll and partner control balances compared with approved journal-line dimensions | Required `as_of_date` | `ledger.read` | Returns ledger balance, dimensioned balance, difference, status and `last_posted_at`; draft/future entries excluded | Account role/code to ledger lines; aggregate only for payroll and partners |
| `api.read_liquidity_summary` | Book cash by wallet from posted wallet-dimension lines plus latest provider reconciliation | Required `as_of_date` | `wallets.read_summary` or `ledger.read` | Physical balance, difference, `is_reconciled`, reconciliation-through, finalized and last-posted timestamps | Wallet to reconciliation; legal holder, provider reference and evidence paths omitted |
| `api.list_journal_entries` | Authorized journal headers with period/posting state, totals, source, reversal/correction and affected-period relationships | Optional date/status/source filters; cursor `(accounting_date, entry_number)`; default 50 | `ledger.read` | Header totals are authoritative and lines are available separately | `journal_entry_id` to lines; closed-period and adjustment state explicit |
| `api.list_journal_lines` | Account and approved explicit subledger dimensions for one authorized journal | Required entry; cursor `line_number`; default 100 | `ledger.read` | Debit/credit lines reconcile to header | Account and source IDs; unrestricted `dimensions` JSON omitted |
| `api.list_monthly_closes` | Period status, close computed totals, approval, validation summary, actor timestamps and reopen metadata | Optional period/close status; cursor `(period_start, period_id)`; default 24 | `ledger.read` | Stored close totals and `generated_at`; private settings snapshot omitted | Period to checklist, approval and audit correlation; close/reopen state explicit |
| `api.list_monthly_close_checklist` | Checklist status, expected/actual/difference, notes, checker and evidence metadata | Required closing ID; optional item status | `ledger.read` | Stored close evidence and update timestamps | Item to close; top-level path, URL, token, secret and checksum keys removed |
| `api.search_audit_events` | Permission-aware entity/correlation timeline with category, action, subject, actor, result, reason and timestamp | Optional time/category/action/result/subject/correlation filters; cursor `(occurred_at, event_id)`; default 50 | `audit.read` | `has_state_change` and `has_metadata` indicators preserve traceability without payload disclosure | Subject, command and correlation drill-down; raw state, metadata, role payload, IP, user-agent and idempotency reference omitted |

## Approved Operational Reports

The existing public `security_invoker` views remain the minimum operational read models for order profitability, customer deposits, courier receivables and settlements, supplier payables, payroll status, partner accounts, inventory, approvals, unposted events and wallet reconciliations. Their base-table RLS continues to enforce organization, assignment, own-payroll and own-partner scope. They are operational drill-downs; the new ledger contracts above remain the financial source of truth and reconciliation boundary.

## Privacy Boundary

- Moderator and operations roles cannot execute dashboard financial, ledger, close, audit, control-reconciliation or wallet-balance contracts.
- Read-only may execute liquidity summary but not confidential profit, ledger, close or audit contracts.
- Partner may execute authorized ledger/report contracts but cannot execute unrestricted audit search; own-partner base-table RLS remains unchanged.
- Finance manager may execute financial/report contracts but not unrestricted audit search.
- Auditor and super admin may execute audit search; all mutation remains denied unless a separate command capability exists.
- No contract returns raw attachments, employee payroll detail, unrestricted partner identity, journal request hashes, idempotency keys, private settings payloads, or raw audit payloads.

## Runtime Evidence

`supabase/tests/database/140_read_contracts.sql` contributes 68 assertions. It verifies every role family, no-role and cross-organization denial, direct private-table denial, server filters, keyset page limits, empty results, closed-period reporting, P&L/trial/liquidity reconciliation, draft exclusion, explicit missing-dimension differences, checklist masking, audit omission, and API privilege posture.
