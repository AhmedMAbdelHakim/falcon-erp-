# Backup and Restore Plan

> Phase 3.5 update (2026-07-15): the local executable restore drill now passes. See `phase-3.5-backup-restore-report.md`. A real private Storage-object and production-volume drill remains required in staging.

## Staging drill

1. Take a database backup using the platform-supported Postgres backup mechanism and record project, timestamp, migration head, checksum, and operator.
2. Restore into a new isolated project; never overwrite the source during a drill.
3. Apply any migrations newer than the backup, regenerate types, and run DB lint and all pgTAP tests.
4. Reconcile row counts for organizations, journals, journal lines, payments, inventory movements, close records, and audit events.
5. Verify journal debit equals credit, closed periods remain closed, private Storage references resolve, and representative role access works.
6. Record RPO, RTO, differences, and reviewer sign-off.

The local full-database drill restored into an isolated temporary database, matched critical counts and balance invariants, and removed the target. Production backup policy, retention and real object-byte recovery still require human approval and staging evidence.
