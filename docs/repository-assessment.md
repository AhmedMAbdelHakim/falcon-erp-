# Repository Assessment

Assessment date: 2026-07-14

## Current state

The repository is an existing Vite/React/TypeScript shipping-label application. It has login, label creation/listing/printing, shipping settings, mock-mode data, and a single SQL schema file. It is not a migration-managed accounting backend.

Git was clean on `master` before Phase 1 documentation began. `docs/phase-2-readiness-check.md` was created by the prior blocked readiness audit and is preserved.

## Existing stack

| Component | Detected state |
|---|---|
| Runtime | Node.js 24.16.0; npm 11.13.0 |
| Frontend | React 19.2.7, React Router 7.17.0, Vite 8.0.16 |
| Language | TypeScript 6.0.3; app compiler checks unused code but does not explicitly set `strict` |
| Styling | Tailwind CSS 4.3.1 plus application CSS |
| Backend client | `@supabase/supabase-js` 2.108.2 |
| Database assets | `supabase/schema.sql`; no `config.toml` or migration directory |
| Tests | No test files or test scripts detected |
| CI | No `.github` workflow detected |
| Environment template | No `.env.example` detected |
| Supabase CLI | Not installed on PATH |

Verification update: `npm run build` passed on 2026-07-14. The pre-existing `npm run lint` baseline failed with 66 errors and 7 warnings in legacy frontend/mock files. No Docker, Podman, PostgreSQL service, or WSL distribution was available, so local Supabase reset/tests require an external workstation prerequisite.

## Reusable components

- Supabase client/auth context can be adapted after generated types and authorization changes.
- Existing label, barcode, QR, batch-print, governorate fee, and shipping-setting flows are operational references.
- React/Tailwind/Vite can remain for the future internal UI; replacing it with Next.js is not justified by current requirements.
- `package-lock.json` gives a reproducible npm dependency baseline.

## Technical debt

- `src/lib/supabase.ts` combines a large mock database with the production client and embeds a fallback project URL.
- Database structure is one mutable `schema.sql` rather than ordered migrations.
- No generated database types, automated tests, CI, or local Supabase configuration exists.
- `package.json` uses range specifiers rather than exact versions.
- There is no explicit `typecheck` or `test` script.
- The existing shipping-label schema is narrower than the accounting domain and uses a two-role model.

## Security risks

1. `.env` is tracked by Git and is not ignored. Values were not read or printed. Treat history exposure as critical until keys are rotated and history is reviewed.
2. `handle_new_user` derives authorization role from `raw_user_meta_data`, which users can influence.
3. Existing `SECURITY DEFINER` helpers live in `public`; default function execution grants and `search_path` need review.
4. Existing label policies allow every authenticated user to read, insert, and update all labels, creating broad horizontal access.
5. No formal separation of operational, payroll, partner, accounting, and audit permissions exists.
6. No private attachment-bucket policy or incident/security event model is present.

## Migration risks

- Existing tables may hold user data; migrations must be additive and preserve label workflows until a verified cutover.
- Existing role values (`admin`, `staff`) do not map safely to the new role model without an explicit mapping.
- Existing schema seeds and triggers are not represented in migration history.
- Opening balances cannot be inferred from legacy labels or wallet values.
- Renaming/reusing `profiles` without compatibility planning could break authentication.

## Recommendation

**Extend and refactor in place.** Keep the Vite frontend and reusable shipping-label features, introduce local Supabase configuration and ordered migrations, isolate financial data in `accounting`, internal command/audit data in non-exposed schemas, and progressively replace broad legacy policies. Do not rebuild the UI in Phase 2.

## Files not to touch without explicit need

- `.env` values and any credential-bearing file.
- User assets under `public/` and `src/assets/`.
- Existing shipping-label pages/components until Phase 3 or a compatibility migration requires changes.
- Git history and remote/production Supabase resources.

## User-data protection plan

1. Take a logical backup before any staging/production migration.
2. Apply migrations locally from zero and to a sanitized legacy snapshot.
3. Use additive tables/columns and compatibility views during transition.
4. Reconcile row counts and financial opening balances explicitly.
5. Rotate any key that may have appeared in tracked `.env` history.
6. Test rollback as forward repair migrations; never edit an applied migration.
7. Require staging validation and accountant sign-off before production use.
