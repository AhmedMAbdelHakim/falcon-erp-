# Phase 2 Test Evidence

Evidence date: 2026-07-15, Africa/Cairo. Runtime: local Docker Desktop and Supabase CLI. All data was synthetic and local.

## Required Command Sequence

| Order | Command | Exit | Captured result |
|---:|---|---:|---|
| 1 | `npm run db:reset` | 0 | database recreated; 54 migrations and `supabase/seed.sql` applied; 73.3 s |
| 2 | `npm run db:lint` | 0 | `results: []`; no schema errors across the checked schemas |
| 3 | `npm run db:test` | 0 | 20 files, 328 assertions, all successful |
| 4 | `npm run db:test:concurrency` | 0 | both independent-session races passed |
| 5 | `npm run db:types` | 0 | generated file is 355,548 bytes; SHA-256 `e6504597028302a8c5c9ec7aa24269b80947ef852fa5907b3d9c4c5583f0bcb4` |
| 6 | `npm run typecheck` | 0 | `tsc -b --pretty false` passed |
| 7 | `npm run build` | 0 | 1,859 modules transformed; production build passed in 911 ms |
| 8 | `npm run lint` | 0 | `eslint .` passed with no findings |

The build emitted one non-failing advisory because the primary minified JavaScript chunk was 632.94 kB (169.89 kB gzip). It is not an accounting, security, or Phase 3 backend blocker.

## Aggregate Database Run

```text
All tests successful.
Files=20, Tests=328
Result: PASS
```

The 19 pre-existing files retained their 260 assertions. The additive contract suite is:

| Test file | Assertions | Primary proof |
|---|---:|---|
| `database/140_read_contracts.sql` | 68 | API privilege boundary, all role paths, organization isolation, ledger-derived reports, filtering, pagination, masking, closed-period reads, direct-base denial, and audit privacy |

The complete workflow, accounting, RLS, legacy, reversal, monthly-close, and idempotency coverage remains listed in `test-coverage-matrix.md`.

## Concurrency Evidence

`npm run db:test:concurrency` exited 0 using independent PostgreSQL sessions:

```json
{"concurrent_idempotency":{"status":"passed","elapsed_ms":2923,"command_rows":1,"journal_rows":1},"close_vs_post":{"status":"passed","elapsed_ms":1915,"error_code":"POSTING_PERIOD_CLOSED","journal_rows":0}}
```

## Read-Contract Catalog Evidence

- All 10 new `api` wrappers are `SECURITY INVOKER`.
- `authenticated` can execute each wrapper; `anon` cannot.
- Authenticated direct reads of accounting journal and audit base tables remain denied.
- Financial report fixtures reconcile to posted/reversed journal lines.
- A draft journal fixture is excluded from control-account reconciliation.
- Generated types contain all 10 new RPC signatures.

## Live Catalog Snapshot

| Artifact | Catalog count |
|---|---:|
| Ordered migrations | 54 |
| Backend base tables | 98 |
| API functions | 70 |
| Exposed-schema RLS policies | 96 |
| pgTAP files | 20 |
| pgTAP assertions | 328 |

## Additional Advisor Check

`npx supabase db advisors --local --type all --level warn --fail-on error` exited 0. It reported no errors. Existing performance warnings for legacy policy initialization, multiple permissive policies, and one duplicate index remain non-blocking and were not introduced by the read contracts.

## Blockers

None. No runtime result in this report is inferred or fabricated.
