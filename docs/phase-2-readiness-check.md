# Phase 2 Readiness Check

Verification date: 2026-07-14

## Phase 1 Status

`READY WITH DOCUMENTED RISKS`

The complete 2,452-line source was imported and verified by SHA-256. All required Phase 1 artifacts exist. The catalog contains 132 unique requirement IDs and the traceability matrix contains the same 132 IDs with zero delta. Four independent reviews were completed; all critical design/documentation findings were resolved. Two critical legacy repository conditions require remediation at the start of Phase 2.

## Repository Status

- Existing Vite/React/TypeScript shipping-label app on `master`; npm lockfile present.
- `npm run build`: passed on 2026-07-14; Vite reported one non-blocking large-chunk warning.
- `npm run lint`: failed on the pre-existing frontend/mock baseline with 66 errors and 7 warnings. Phase 2 must not claim lint success or expand unrelated UI refactoring.
- Supabase CLI/config/migrations/tests were absent at the gate.
- Existing `supabase/schema.sql` is a legacy shipping-label script, not migration history.
- No remote Supabase project, production data, deployment, push, or merge is authorized.

## Uncommitted User Changes

Before Phase 1, Git was clean. Current untracked/modified files are the Phase 1/2 documentation and imported source produced by Codex. Existing application files and user assets are preserved.

## Risk Classification and Controls

| Finding | Classification | Control before affected work |
|---|---|---|
| Legacy signup trusts `raw_user_meta_data.role` | Blocking for Security | First IAM migration removes metadata role trust, defaults profiles inactive/least privilege, and audits DB role assignment. Review existing real users before staging/production. |
| `.env` is tracked | Blocking for Security | Preserve local file, ignore/untrack it, add placeholder `.env.example`, scan history without output, and list credential rotation as mandatory manual step. |
| Broad authenticated label RLS | Requires Conservative Assumption | Preserve workflow but replace broad policies with organization/assignment controls and compatibility tests before accounting access. |
| Public unsafe definer functions | Blocking for Security | Move/rewrite private helpers, safe `search_path`, revoke `PUBLIC`, narrow wrapper grants, catalog tests. |
| Missing liquidity/evidence/opening-balance policies | Non-blocking for schema; blocking for affected production command | Seed enable flags false/null; commands reject until approved effective settings/evidence/opening data exist. Local tests may use explicit synthetic fixtures. |
| Legacy lint failures | Non-blocking for database | Keep baseline documented; TypeScript build/typecheck must remain passing. Do not report full lint success. |

## Assumptions Adopted

- Local-only implementation with synthetic configuration and test fixtures.
- EGP minor-unit bigint, basis points, Cairo business dates, explicit item-level delivery recognition, GRNI, gross courier AR/payable, and immutable double-entry ledger follow accepted ADRs.
- Existing Vite app is extended, not replaced.
- Financial command wrappers use exposed `api` invoker functions and non-exposed private implementations.
- Withdrawal, production delivery recognition, real payroll, and opening-balance commands remain disabled until their production policies/data are approved.

## Implementation Decision

`PHASE 2 EXECUTION APPROVED WITH CONTROLS`

Execution order is mandatory:

1. Secret-tracking and local tooling remediation.
2. IAM/legacy authorization remediation and audit foundation.
3. Migration-managed schema and tests from an empty local database.
4. Financial commands only after database guards, idempotency, RLS, and accounting invariants exist.
5. No remote migration, real data, deploy, push, merge, or Phase 3 UI.
