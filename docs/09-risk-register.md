# Risk Register

Scale: probability/impact `Low`, `Medium`, `High`, `Critical`.

| ID | Description | Probability | Impact | Detection | Mitigation | Contingency | Owner | Status |
|---|---|---|---|---|---|---|---|---|
| RSK-001 | Duplicate financial posting | High | Critical | Source/idempotency uniqueness and replay tests | Atomic idempotent commands and source-purpose unique keys | Reverse duplicate, reconcile, incident review | Finance engineering | Open |
| RSK-002 | Revenue recognized before/after delivery incorrectly | Medium | Critical | Event posting and order-ledger reconciliation tests | Delivery-only command; no status trigger/direct DML | Reverse/correct and freeze affected period/report | Accounting owner | Open |
| RSK-003 | Missing/broad RLS exposes customer or financial data | High | Critical | Catalog/adversarial role tests | RLS all exposed tables, least grants, DB role assignments | Disable API/grants, rotate sessions, incident audit | Security owner | Open |
| RSK-004 | Excessive definer/function privilege | High | Critical | Function grant/search-path scan and advisors | Private schema, revoke PUBLIC, explicit auth, narrow wrappers | Revoke execute and disable command | Database owner | Open |
| RSK-005 | Rounding/allocation error | Medium | High | Boundary/property tests and reconciliation | Bigint minor units, centralized integer algorithms | Adjustment with audit; fix forward | Accounting engineering | Open |
| RSK-006 | Data loss or unrecoverable migration | Medium | Critical | Fresh/legacy reset and restore smoke | Immutable migrations, backups, staging rehearsal | Restore isolated backup and forward repair | DBA | Open |
| RSK-007 | Untraceable edit/deletion | Medium | Critical | Audit/immutability/delete tests | Append-only audit, no hard delete, reversals | Freeze access, reconstruct from ledger/backup | Security/finance | Open |
| RSK-008 | Incorrect courier settlement | High | High | Shipment-item reconciliation/difference alerts | Item-derived expectation and mandatory evidence/approval | Keep open, investigate, post approved adjustment | Finance manager | Open |
| RSK-009 | Unsafe/incorrect partner withdrawal | High | Critical | Rolling-window/concurrency/liquidity tests | Row locks, 24h aggregate, SoD, safe amount | Reverse/partner current adjustment; suspend withdrawals | Partners/finance | Open |
| RSK-010 | Wrong bonus/payroll calculation | Medium | High | Snapshot/formula/exclusion tests | Effective rules, metric provenance, approval | Correct next payroll or approved adjustment | Payroll owner | Open |
| RSK-011 | Historical price/policy mutation | Medium | High | Snapshot regression tests | Immutable snapshots and effective-dated master data | Reconstruct from audit/evidence; adjustment | Operations/finance | Open |
| RSK-012 | Closed-period mutation | Medium | Critical | Period lock and direct-DML tests | DB guard, revoked DML, open-period adjustments | Incident, restore/reconcile, corrective entry | Finance manager | Open |
| RSK-013 | Secret exposure from tracked `.env` | High | Critical | Git/secret/bundle scans without printing values | Ignore/untrack, rotate, CI scanner, secret store | Revoke/rotate immediately and review access logs | Security owner | Blocking until remediated |
| RSK-014 | Migration fails against legacy label data | Medium | High | Sanitized legacy snapshot migration test | Additive baseline, compatibility planning, backups | Restore and forward-fix migration | Database owner | Open |
| RSK-015 | Poor mobile/RTL usability causes workflow bypass | Medium | Medium | Phase 3 mobile/RTL/accessibility tests | Mobile-first Arabic design and ergonomic commands | Assisted fallback and UI iteration | Product/QA | Deferred to Phase 3 |
| RSK-016 | User bypasses intended workflow through direct API | High | Critical | Direct-DML/RPC privilege negative tests | Database constraints, grants, RLS, explicit commands | Revoke endpoint/grant and investigate | Security owner | Open |
| RSK-017 | Concurrent settlement/inventory/payment consumes same item twice | Medium | Critical | Deterministic race tests | Row locks, versions, unique consumption constraints | Reconcile/reverse and patch forward | Database owner | Open |
| RSK-018 | Personal-name wallet creates ownership/legal dispute | Medium | High | Reconciliation and legal review | Record legal holder/accounting owner; partner acknowledgement | Move to business account; preserve evidence | Partners/legal | Production blocker |
| RSK-019 | Opening balances are guessed from cash | High | Critical | Opening trial/subledger reconciliation | Controlled approved opening-balance process | Reset opening load and re-reconcile | Accountant | Production blocker |
| RSK-020 | Reports diverge from ledger | Medium | High | Trial/control reconciliation tests | Ledger-derived financial reports and as-of metadata | Disable affected report; rebuild projection | Reporting owner | Open |
| RSK-021 | Attachment evidence is public or orphaned | Medium | High | Storage policy/orphan tests | Private bucket and parent authorization/checksum | Revoke links, quarantine, incident review | Security owner | Open |
| RSK-022 | Tax/legal interpretation is presented as compliant | Medium | High | Documentation/release review | Explicit compliance boundary and specialist sign-off | Remove claim, obtain review, adjust policy | Product/legal | Production blocker |
