# Release and Rollback Runbook

## Controlled staging release

1. Confirm approved change set, CI success, backup, migration manifest, environment variables, and named release owner.
2. Deploy immutable frontend assets, apply forward migrations to staging, regenerate types, and run smoke/RLS/accounting tests.
3. Validate login, role switching, dashboard/report equality, one synthetic command per workflow family, audit correlation, and legacy labels.
4. Stop on invariant, authorization, data-loss, or migration failure.

## Rollback

Frontend rollback selects the prior immutable artifact. Database changes use an reviewed forward corrective migration; never rewrite applied migrations or reset a remote project. If data correctness is uncertain, disable sensitive commands, preserve evidence, restore only into an isolated environment, and reconcile before resuming.

No deployment or rollback was executed in Phase 3.
