# Testing Strategy

## Test pyramid and evidence

1. **Schema/pgTAP:** tables, types, comments, constraints, FKs, indexes, privileges, RLS, functions, and migration invariants.
2. **Database command integration:** transactional RPCs, ledger postings, idempotency, row locks, approvals, reversals, and period locks.
3. **TypeScript unit/integration:** money serialization/display, validators, generated types, client error mapping, and mocked provider boundaries.
4. **Focused E2E in Phase 3:** order-to-delivery, print batch, settlement, payroll, withdrawal, close, Arabic RTL/mobile/accessibility.

Every test runs on synthetic data after a clean local reset. Reports list exact commands and pass/fail counts.

## Mandatory acceptance cases

| Test ID | Case | Expected result |
|---|---|---|
| TEST-ORD-001 | Send Custom item to print before deposit. | Rejected atomically. |
| TEST-ACC-001 | Record Custom deposit before delivery. | Wallet/deposit liability posts; revenue remains zero. |
| TEST-ACC-002 | Deliver valid order. | Revenue, deposit consumption, receivable, and COGS post once. |
| TEST-IDM-001 | Replay delivery with same idempotency key/fingerprint. | Original result returned; no new entry. |
| TEST-IDM-002 | Reuse key with different fingerprint. | Conflict rejected. |
| TEST-PMT-001 | Replay payment record/refund with same key and lose first response. | Original payment/refund result returns; no duplicate wallet or ledger effect. |
| TEST-PMT-002 | Allocate payment beyond cleared amount/obligation or refund beyond refundable credit. | Command rejects atomically. |
| TEST-LED-001 | Post unbalanced entry. | Database rejects it. |
| TEST-LED-002 | Update/delete posted entry or line. | Database rejects it. |
| TEST-LED-003 | Reverse posted entry twice. | First succeeds with opposite lines; second fails. |
| TEST-RLS-001 | Moderator reads payroll/partner/ledger sensitive data. | No rows/permission denied. |
| TEST-RLS-002 | Direct API bypass of assigned-order scope. | Denied. |
| TEST-RLS-003 | Revoked user executes sensitive command with stale token. | Denied by current database assignment. |
| TEST-DSC-001 | Default 20% product discount with shipping present. | Shipping excluded from discount base. |
| TEST-DSC-002 | Moderator discount causes negative margin. | Rejected; partner override requires separate approval. |
| TEST-ORD-002 | Gift with sale price zero and actual cost. | Cost remains in order margin/COGS. |
| TEST-SNP-001 | Change printer/rate/discount rule after historical order. | Historical snapshots and margin unchanged. |
| TEST-SHP-001 | Settlement expected/actual differ. | Close blocked until reason/evidence/review/approval. |
| TEST-SHP-002 | Deliver order then settle later. | Revenue precedes cash and open courier receivable reconciles. |
| TEST-SHP-003 | Courier reports less COD than contractual delivery obligation. | Expected remains frozen contractual receivable and shortage appears as difference/claim. |
| TEST-SHP-004 | Settle prepaid, COD, partial, carry-forward, and negative-net items. | Correct AR/payable items remain or clear once; no fabricated collection. |
| TEST-CLS-001 | Mutate transaction in closed month. | Rejected. |
| TEST-CLS-002 | Post approved adjustment referencing closed month into open month. | Accepted and traceable without changing close. |
| TEST-CLS-003 | Race final posting against close for the same period. | Shared period-row lock serializes; either posting is included before close or rejected after close. |
| TEST-PRT-001 | Withdraw EGP 300 then 300 within rolling 24h. | Second requires other-partner approval. |
| TEST-PRT-002 | Split concurrent withdrawals around threshold. | Locks serialize aggregate; no bypass. |
| TEST-WAL-001 | Transfer between Falcon wallets. | Total assets/profit unchanged except separately posted fee. |
| TEST-PRN-001 | Pay printer before receipt/QC/final invoice. | Rejected. |
| TEST-PAYR-001 | Evaluate unpaid salary on Cairo day 11. | Status is overdue; partial payment leaves liability. |
| TEST-RET-001 | Return delivered order. | Linked revenue/cost correction and separate return losses; no final sales inclusion. |
| TEST-RET-002 | Return before delivery. | No revenue reversal because no revenue was posted. |
| TEST-CON-001 | Two workers settle same shipment. | One consumes it; the other fails/replays safely. |
| TEST-ATX-001 | Inject failure after operational update before journal/audit. | Entire command rolls back. |
| TEST-SOD-001 | Requester approves own controlled request. | Rejected. |
| TEST-SEC-001 | Catalog scan of exposed tables/functions. | All exposed tables have RLS; unsafe default function grants count is zero. |
| TEST-SEC-002 | Call private implementation directly through Data API. | No endpoint/exposure; only the allowed `api` wrapper is callable. |
| TEST-AR-001 | Receive overpayment, partially deliver, then refund excess. | Excess remains customer credit; delivery does not over-consume it; refund clears liability. |
| TEST-AR-002 | Collect non-COD customer receivable after delivery. | Receipt clears AR without creating revenue again. |
| TEST-GRNI-001 | Partially receive/QC a batch, then invoice with variance and supplier credit. | Accepted GRNI, AP, variance, credit, and payment reconcile. |
| TEST-DEL-001 | Deliver one of several shipment items. | Only delivered quantity posts; discount/deposit/shipping allocations stay within snapshots. |
| TEST-DEL-002 | Deliver two shipments concurrently with distinct keys. | Each shipment item quantity posts once; no overlap or order-level duplicate. |
| TEST-RET-003 | Partially return one item after prior-period close/settlement. | Open-period correction references original; unaffected items/close remain unchanged. |
| TEST-DST-001 | Distribute an odd minor-unit amount 50/50. | Floor shares post and one-minor remainder stays retained; total is conserved. |
| TEST-PRT-003 | Withdraw with required liquidity/advance policy unset. | Execution is blocked. |
| TEST-IDM-003 | Simultaneous same key/hash, changed hash, and lost response. | One execution; waiter replays result; changed hash conflicts; retry retrieves committed result. |
| TEST-OBS-001 | Inject a business validation failure inside command subtransaction. | No business/ledger writes; one redacted terminal failure outcome retains correlation. |
| TEST-EVD-001 | Deliver with missing, wrong-parent, tampered, or unauthorized evidence. | Production recognition command is disabled/rejected under configured evidence policy. |
| TEST-MRG-001 | Change quantity/cost/gift/packaging/shipping inputs after margin approval. | Approval fingerprint invalidates and command recomputes before printing/delivery. |
| TEST-ALT-001 | Re-evaluate same operational exception repeatedly. | One deduplicated alert ages/escalates and requires resolution evidence. |

## Schema and constraint tests

- Required schemas/extensions/tables/comments exist.
- Money/rate/date columns follow naming/type ADRs.
- Ownership bps total exactly 10,000 for an effective organization snapshot.
- Allocations do not exceed payment/order obligations.
- Quantities and one-sided journal lines are positive; exactly one debit/credit side is set.
- Source-purpose and idempotency uniqueness hold.
- Effective-date ranges do not overlap where one rule must apply.
- Financial FKs never cascade-delete protected history.
- FK and RLS predicate columns have indexes.

## RLS and privilege tests

For every role, test allowed and denied SELECT/INSERT/UPDATE/DELETE/RPC paths. Include unauthenticated, inactive user, expired role, wrong organization, wrong assignment, same-role different user, stale role, direct table DML, view bypass, function default execute, and attachment object access. Test both `USING` and `WITH CHECK` behavior.

## Accounting invariant tests

- Trial balance is always balanced after any committed command.
- Customer deposit/control, supplier AP, courier AR, payroll payable, wallet, inventory, and partner subledgers reconcile.
- Revenue source-purpose occurs once per delivery; return/reversal linkage is complete.
- Posted and closed-period records are immutable.
- Distribution allocations equal approved distributable amount and ownership snapshot.
- Cash/safe-withdrawal report does not substitute for profit.

## Idempotency and concurrency

Run same-key same-payload concurrently, same-key changed-payload, commit followed by lost response, failed-command retry, simultaneous distinct keys for overlapping shipment quantities, concurrent payment allocations, settlement item consumption, first-time and boundary partner withdrawals, close versus each posting/reversal type, and reversal races. Use deterministic barriers and assert final rows/ledger, not only returned errors.

## Reconciliation and recovery

- Wallet statement versus ledger with zero/nonzero differences.
- Courier expected/actual and supplier invoice/payment aging.
- Backup/restore smoke test on an isolated local/staging database.
- Fresh reset, all migrations, seed, generated types, and test rerun.
- Legacy snapshot migration test preserves label rows and auth/profile compatibility.

## TypeScript and future UI

Unit tests cover bigint-string parsing, EGP formatting, integer rounding/allocation, Cairo business date, validation, and Arabic error mapping. Phase 3 adds keyboard, focus, screen-reader labels, contrast, no color-only status, true RTL, mobile widths, print layout, and destructive-action confirmation.

## Quality gates

- Critical accounting/security failures: zero.
- Database reset/migrations/seed: pass from zero.
- pgTAP/RLS/accounting/idempotency/concurrency suites: all pass.
- Typecheck/lint/build: pass.
- Generated types: no diff after regeneration.
- Supabase advisors: no unresolved security errors; performance warnings reviewed.
- No real data, secrets, remote migration, or deployment.
