# Production Checklist

- [ ] Exact release commit/tag approved; no unreviewed dirty files.
- [ ] Hosted CI and dependency/secret scans green.
- [ ] Production environment variables and private secrets peer-reviewed.
- [ ] Backup and real Storage-object restore drill meets approved RPO/RTO.
- [ ] Forward migrations rehearsed from production-like snapshot.
- [ ] Frontend rollback and database forward-repair drill passed.
- [ ] Full UAT and parallel financial reconciliation signed.
- [ ] Monitoring, alert delivery, on-call and support escalation tested.
- [ ] Import totals signed and idempotent retry/rollback rehearsed.
- [ ] Go-live owner, finance, operations and technical approvals recorded.

All boxes remain unchecked in Phase 3.5 because no production action was authorized.
