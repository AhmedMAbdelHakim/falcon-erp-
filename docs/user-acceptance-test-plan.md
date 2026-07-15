# User Acceptance Test Plan

> Phase 3.5 update (2026-07-15): executable pre-UAT QA is complete and the detailed persona package is in `phase-3.5-uat-package.md`. No human UAT approval is claimed.

UAT must run in authorized staging with synthetic or approved sanitized data.

| Persona | Critical journeys |
|---|---|
| Operations | Customer/order lookup, print batch receive/QC/close, shipment, delivery evidence, return, legacy label printing. |
| Moderator | Assigned customer/order scope, safe discount, payment evidence, refund request; denied finance and partner data. |
| Finance | Payment confirmation/allocation, supplier invoice/payment, courier settlement, wallet reconciliation/transfer, expense, payroll, ledger reversal, close preparation. |
| Partner | Own withdrawal, other-partner approval where allowed, reports, close/distribution approval. |
| Auditor | Read reports, ledger and audit; all mutation denied. |

For each journey record user, role, input fixture, expected and actual state, journal IDs, audit correlation, screenshots, and pass/fail. Repeat double-click/retry, stale-version, denied role, closed-period, and mobile cases. Ahmed, Moaz, and the financial reviewer have not approved UAT.
