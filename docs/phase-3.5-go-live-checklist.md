# Phase 3.5 Go-Live Checklist

No item below is marked complete by Phase 3.5 unless executable evidence exists.

| Gate | Required evidence | Current state |
|---|---|---|
| Exact candidate CI | Green application, database and browser jobs | Pending hosted run |
| Staging release | Immutable artifact, migration head, smoke evidence | Pending authorization |
| UAT | Signed persona checklists and zero Critical/High defects | Pending |
| Import rehearsal | Full approved files, signed totals and rollback | Pending |
| Backup and Storage restore | Database plus real object bytes restored and reconciled | Database local PASS; object bytes pending |
| Rollback rehearsal | Prior artifact restored; DB forward-repair path exercised | Pending staging |
| Monitoring/on-call | Test alerts received by named responders | Pending |
| Security | Secret scan, audit, RLS, cross-org and session tests on candidate | Local PASS; staging rerun pending |
| Financial parallel run | Closed period and reports reconciled against approved baseline | Pending |
| Cutover approval | Named owner, finance, operations and technical approvals | Not authorized |

Current production gate: not approved. Current staging entry gate: approved by the Phase 3.5 decision.
