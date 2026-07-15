# Phase 2 Decisions

## Adopted controls

| ID | Decision | Reason |
|---|---|---|
| P2-DEC-001 | Extend Vite/React; do not migrate to Next.js. | Existing app builds and Phase 2 is backend-only. |
| P2-DEC-002 | Pin Supabase CLI as an exact dev dependency and use local Docker services. | Reproducible migrations/tests without remote access. |
| P2-DEC-003 | Treat ordered migrations as schema truth; preserve `schema.sql` as legacy reference only. | Avoid dashboard/schema drift and preserve user work. |
| P2-DEC-004 | Add exposed `api` wrappers plus non-exposed `private` implementations. | Callable browser RPC boundary with narrow grants and safe definer posture. |
| P2-DEC-005 | Recognize delivery per shipment item/quantity. | Supports multi-item/split delivery without duplicate order-level posting. |
| P2-DEC-006 | Accrue courier fee payable at delivery/return and GRNI at accepted printer QC. | Correct gross presentation and event timing. |
| P2-DEC-007 | Commands with unresolved real-world policies remain disabled by effective settings. | Prevents invented evidence, liquidity, payroll, or opening-balance rules. |
| P2-DEC-008 | Preserve the legacy frontend lint baseline as documented debt. | Avoid unrelated Phase 3/UI refactor while requiring build/typecheck success. |

## Conflict resolutions carried from Phase 1

- Final moderator discount is 20% with cost-complete non-negative-margin control.
- Courier return fee and total Falcon return loss are separate.
- Printer payment requires receipt, QC, and finalized invoice.
- Withdrawal threshold is rolling 24 hours and uses a stable partner lock.
- Explicit command RPCs own posting; status triggers do not.
- Expected courier COD comes from contractual delivery obligations, not courier-reported collection.

## Commands deliberately disabled for production

- Partner withdrawal/future-profit advance until liquidity policy settings are approved.
- Delivery recognition until evidence policy is configured and approved.
- Real payroll until salary/proration/final-pay policies and employee amounts are approved.
- Opening balance import until accountant-approved reconciliation exists.

Test fixtures may enable these controls with synthetic values in local transactions; seed data does not claim real values.
