# Phase 2 Finding Ledger

Evidence date: 2026-07-15, Africa/Cairo. `VERIFIED` means the finding passed executable local PostgreSQL/Supabase evidence on a database recreated from the complete migration history. Test references are listed in `phase-2-test-evidence.md`.

| ID | Finding | Severity | Status | Runtime evidence |
|---|---|---|---|---|
| P2-001 | Missing transactional workflows across orders, payments, production, shipping, expenses, payroll, and partners | Critical | VERIFIED | workflow tests `040` through `130`; 328-test aggregate pass |
| P2-002 | Monthly close evidence, recovery, cumulative-loss, reserve, and distributable-profit workflow | Critical | VERIFIED | `090` passed 18 assertions; close/post race passed |
| P2-003 | Legacy shipping-label compatibility and data preservation | Critical | VERIFIED | clean reset plus `025` and RLS `020` |
| P2-004 | Local reset and complete verification suite | Critical | VERIFIED | reset, lint, 328 pgTAP assertions, concurrency, types, typecheck, build, lint |
| P2-005 | Payment allocation and customer-credit conservation | High | VERIFIED | `040` passed 28 assertions, including refund and receipt reversals |
| P2-006 | Retryable SQL failures converted to terminal outcomes | High | VERIFIED | shared SQLSTATE tests, command implementation audit, concurrent replay harness |
| P2-007 | Approval commands did not recompute canonical fingerprints | High | VERIFIED | hostile fingerprint tests in `040`, `110`, `130`; approval-bound workflow tests |
| P2-008 | Relation-family RLS exceeded assigned or authorized scope | High | VERIFIED | RLS `001`, `010`, `020`, and `030`; read-role matrix in `140` |
| P2-009 | Missing organization-scoped approval, evidence, and journal references | High | VERIFIED | `030` catalog regression reports zero missing reference FKs |
| P2-010 | Courier partial-delivery and return reporting was not authoritative | High | VERIFIED | `050` passed contractual COD, reported cash, partial return, and settlement assertions |
| P2-011 | Profit distribution ownership, floor allocation, retained remainder, approval, and posting | High | VERIFIED | `080` passed 19 assertions |
| P2-012 | Behavioral, RLS, idempotency, storage, and concurrency suites were structural only | High | VERIFIED | 328 executed pgTAP assertions plus two-session concurrency harness |
| P2-013 | Generated local database types | High | VERIFIED | `npm run db:types` exited 0 after clean reset; 10 read RPCs present |
| P2-014 | Manual journal control-account and source-purpose bypass | Critical | VERIFIED | `110` hostile and valid posting cases passed |
| P2-015 | Partner approval identity could be spoofed | High | VERIFIED | `080` partner identity and separation-of-duties cases passed |
| P2-016 | Shipment/return quantity and negative-inventory conservation | High | VERIFIED | `050` quantity, duplicate-return, and stock conservation cases passed; commands lock aggregate rows |
| P2-017 | Reversal-aware supplier and distribution reporting | High | VERIFIED | `070` reversal report fixture plus `040`, `060`, `110`, and report tests in `140` |
| P2-018 | Type generation could overwrite the prior file on failure | Medium | VERIFIED | fail-safe generation behavior and successful generation verified |
| P2-019 | Order confirmation, deterministic discount, and payment intake RPCs | Critical | VERIFIED | `040` and `130`; replay and tamper cases passed |
| P2-020 | Close attestation, source checks, cancel/recover, and exceptional reopen | Critical | VERIFIED | `090` passed 18 assertions |
| P2-021 | Cumulative profit, reserve, distributable basis, and three-stage distribution | Critical | VERIFIED | `080` and `090` passed executable closed-basis calculations |
| P2-022 | Missing authenticated accounting, ledger, monthly-close, audit, and financial-report read contracts | High | VERIFIED | lifecycle `OPEN` -> `IMPLEMENTED` -> `VERIFIED`; 3 additive migrations; `140` passed 68 assertions; clean 328-test aggregate; generated types passed |

## Totals

| Severity | Open | Implemented | Verified |
|---|---:|---:|---:|
| Critical | 0 | 0 | 8 |
| High | 0 | 0 | 13 |
| Medium | 0 | 0 | 1 |

There are no remaining `OPEN` or `IMPLEMENTED` findings.
