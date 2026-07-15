# Production Runbook

## Preconditions

Use only an approved immutable candidate with green hosted CI, signed UAT/parallel-run evidence, tested backups, named release/rollback owners and a recorded maintenance window. Browser configuration may contain only the public Supabase URL and publishable/anon key.

## Release

1. Record commit, artifact digest, migration head, operator and approvals.
2. Take database and private Storage backups and verify checksums.
3. Apply forward migrations in order; stop on any warning, invariant or authorization failure.
4. Regenerate types and compare to the approved candidate.
5. Deploy immutable frontend assets and run role, RLS, RPC, accounting and legacy-label smoke tests.
6. Monitor auth failures, RPC errors, posting latency and audit correlations through the approved observation window.

## Stop Conditions

Stop sensitive commands for imbalance, cross-organization disclosure, duplicate posting, closed-period mutation, missing audit evidence, import mismatch or failed backup. Preserve all evidence and follow the rollback and disaster-recovery guides.
