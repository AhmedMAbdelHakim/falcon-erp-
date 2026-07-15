# Phase 2 Migration And Rollback Plan

## Supported Path: Fresh Phase 2 Database

1. Install Docker Desktop with WSL 2 support and confirm `docker version` works.
2. Run `npm ci`, `npm run db:start`, and `npm run db:reset`.
3. Confirm migrations `20260714162215` through `20260714162247` apply in order.
4. Run `npm run db:lint`, `npm run db:test`, and `npm run db:types`.
5. Run `npm run typecheck`, `npm run build`, and `npm run lint`.
6. Preserve the complete command output and generated type diff as release evidence.

No Phase 2 migration may be reordered after a shared environment has applied it.
Corrections are forward-only additive migrations.

## Existing Legacy Shipping Database

Do not run the fresh chain directly over the historical `supabase/schema.sql`
objects. The old `public.profiles` name conflicts with the Phase 2 identity table.

1. Stop writes and take a tested logical backup including `auth`, `public`, and storage metadata.
2. Record row counts and deterministic hashes for profiles, labels, settings, and fees.
3. In one maintenance transaction, move the four legacy tables and their three helpers/triggers into a quarantined `legacy_shipping` schema.
4. Apply the Phase 2 migration chain to create authoritative organization, identity, accounting, and compatibility objects.
5. Create or approve one organization mapping for every legacy row. Ambiguous rows stop migration.
6. Migrate profile names into `display_name`. Convert reviewed legacy admins into database role assignments; never copy role claims from Auth user metadata.
7. Copy labels, settings, and fees with explicit `organization_id` and validated profile ownership.
8. Compare source/target counts, per-organization money totals, tracking-number sets, and sampled full-row hashes.
9. Run role-impersonation tests before reopening writes. Retain quarantined tables read-only through the acceptance window.

## Rollback

Before accepting any new Phase 2 financial writes, rollback is restore-based:
stop writes, restore the verified pre-cutover backup, and point the application at
the restored project. After financial writes begin, destructive down-migrations
are prohibited. Correct forward with compensating migrations and journal
reversals so audit history remains intact.

For a failed compatibility copy, leave the new database offline, discard it, fix
the mapping/copy script, and repeat from the same immutable backup. Never merge
partially copied rows back into the legacy production tables.

## Release Gates

- Zero Critical findings.
- Clean reset and seed from an empty local database.
- Database lint, pgTAP, RLS impersonation, storage, concurrency, type generation, typecheck, build, and lint all pass.
- Legacy count/hash reconciliation passes on a representative backup fixture.
- Rollback restore has been timed and exercised.

