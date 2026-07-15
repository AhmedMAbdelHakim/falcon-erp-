# Phase 2 Consolidated Review Findings

Five independent static reviews covered accounting, database reliability, security, Falcon operations, and destructive behavior. Findings below are consolidated after the repair pass.

## Critical - Remaining

1. **Required business workflows remain incomplete.** Order confirmation, deterministic discounts, and payment intake now have RPCs, but delivery/return/reversal, payment allocation/credit/refund conservation, printing/GRNI/supplier payments, courier settlement, expenses, payroll, partners, and profit distribution remain open.
2. **Database execution is unverified.** Docker/Postgres is unavailable, so reset, seed, pgTAP, RLS impersonation, deferred constraints, generated types, and concurrency behavior have not run.

## High - Remaining

- Payment confirmation classifies the full receipt from one optional primary order and does not perform allocation/credit conservation.
- Some close reconciliations still require accountable manual evidence and runtime validation.
- Many operational journal/evidence UUIDs remain soft references; future commands that should enforce semantic linkage are absent.
- Older RPCs still collapse retryable SQL failures into terminal idempotency failures; remediation RPCs use retry classification and transient claim release.
- Some single-column FKs coexist with composite organization FKs or still need organization-scoped reinforcement.
- Profit-distribution conservation is implemented but has no executed invariant/SoD fixture.
- Some expense, supplier, and approval relation-family reads remain broader than final assigned-row scope.
- Older execution commands do not recompute every approval fingerprint; remediation RPCs use canonical payload hashing.
- Courier receivable reporting is not sufficient for partial delivery/return accounting.
- pgTAP files are mainly structural; business, role-impersonation, and concurrency fixtures remain absent.
- `database.generated.ts` is a clearly labeled bootstrap shape, not CLI-generated truth.

## Fixed During Review

- Manual journals now reject control accounts through both account IDs and semantic roles; manual source/purpose values cannot pre-claim business events.
- A synthetic current Cairo accounting period is provisioned for local seed use.
- Approval submission and decision RPCs now support accountable state transitions and server-canonical payload fingerprints.
- Partner approval IDs have composite FKs and are bound to the acting Auth profile.
- Aggregate shipment quantities, return quantities, and nonnegative inventory use locked database checks.
- Payment self-review is rejected.
- Reversed originals remain in monthly P&L; supplier reversals and draft distributions no longer inflate summaries.
- Profit distributions reference monthly closings with an organization-scoped FK.
- Partner base-table RLS is own-row oriented; storage reads require attachment metadata and financial uploads require write capabilities.
- Attachment metadata is append-only.
- The TypeScript RPC adapter passes command-specific SQL arguments.
- A partner-loan payable account and mapping were added.
- Failed type generation preserves the prior type file.
- The legacy labels/settings/fees contract now has an organization-scoped compatibility migration, capability RLS, derived display-only role label, seed data, and a restore-based live migration plan.
- Order confirmation, deterministic discount allocation, and payment evidence intake now use narrow idempotent RPCs.
- Monthly close now has evidence refresh/attestation, cancellation, recovery, and exceptional reopen commands.
- Monthly close now derives cumulative P&L, prior posted allocations, a versioned protected reserve, and distributable profit; distribution calculation/approval/posting preserves integer remainder and actor separation.

## Verdict

Critical unresolved findings: **2**. High unresolved findings: **10**. Implemented-but-unverified work is not counted as verified. The migrations are not deployable and do not satisfy Phase 2 Definition of Done.
