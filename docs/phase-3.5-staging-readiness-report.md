# Phase 3.5 Staging Readiness Report

| Control | Result | Evidence / staging action |
|---|---|---|
| Public environment variables | PASS | `.env.example` contains URL and publishable/anon key placeholders only |
| Secret exposure | PASS locally | Tracked pattern scan has no matches; configure approved secret store in staging |
| Dependency lock/audit | PASS | `npm ci` clean harness; audit found 0 vulnerabilities |
| Supabase configuration | PASS locally | Docker reset from zero and explicit Data API grants |
| Authentication/session | PASS | Multi-user login, logout and protected-route redirect |
| RLS/cross organization | PASS | pgTAP and browser sandbox identity |
| Private Storage | PASS for policy/metadata | Two private buckets and organization-prefix policies; real object-byte drill required in staging |
| Migrations | PASS | 55 forward migrations applied from zero |
| Generated types | PASS | Regeneration hash unchanged |
| Reproducible build | PASS | Typecheck/build/lint and route chunks |
| CI definition | DEFINED | Application, database and seven-profile browser jobs; hosted run not yet observed |
| Docker reproducibility | PASS locally | Supabase reset and 351 pgTAP assertions |
| Rollback/recovery | PASS locally | Isolated logical restore; remote release rollback remains a staging exercise |
| Import validation | PASS | Five fixture families, balanced totals, duplicate rejection, deterministic digest |
| GitHub backup preflight | PASS | Existing `origin` inspected; ignored artifact and tracked-secret scans pass; no commit or push performed |
| Vercel project contract | PASS locally | Vite, `npm ci`, `npm run build`, `dist`, and required SPA rewrite are recorded in `vercel.json` |
| Production-preview nested routes | PASS | Dashboard, order detail, monthly close and legacy edit direct navigation return the SPA; hashed asset remains an asset |

No current local backend or frontend blocker prevents provisioning an authorized staging environment. Staging must use synthetic or approved sanitized data and a separate project; production data and credentials are prohibited.

## GitHub and Vercel Preflight Evidence

On 2026-07-15 the accepted working tree passed `npm ci`, typecheck, production build, SPA fallback verification, ESLint, 7 unit tests, 15 component tests, 1 jsdom axe test, 3 Chromium E2E scenarios, `npm audit --omit=dev`, tracked secret scanning and `git diff --check`. `.env.example` contains exactly two public placeholders. No Git branch, commit, push, Vercel project, deployment, Supabase link or remote migration was created by this preflight.
