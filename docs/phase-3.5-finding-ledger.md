# Phase 3.5 Finding Ledger

| ID | Severity | State | Closure evidence |
|---|---|---|---|
| P3-OPS-001 | High | VERIFIED | Local full logical backup restored into isolated database; import suites deterministic; CI, recovery and UAT controls documented. Staging execution remains a later gate. |
| P3-UI-005 | Medium | VERIFIED | Vitest component suite, axe, keyboard/focus, Chromium/Firefox/WebKit and responsive profile tests all pass. |
| P3-PERF-001 | Medium | VERIFIED | Route lazy loading removes the over-500 kB chunk and measured local navigation is below the 5 s QA ceiling. |
| P35-QA-001 | Medium | VERIFIED | E2E fixture originally violated organization-code format; corrected to `falcon_sandbox` and fixture loader now fails transactionally. |
| P35-QA-002 | Medium | VERIFIED | Cross-organization fixture originally attempted immutable profile reassignment; changed to supported default-organization provisioning flow. |
| P35-REC-001 | Medium | VERIFIED | Restore cleanup originally used a non-owner role; corrected to `supabase_admin`, rerun passed, and temporary database count was zero. |
| P35-ENV-001 | Low | ACCEPTED | Literal `~` in the local repository path breaks Vitest module URL resolution. Verified suite runs from `C:\falcon-phase35-qa`; normal CI checkout paths are unaffected. |
| P35-UAT-001 | High | DEFERRED | Human UAT and accountable sign-off require an authorized staging environment. This blocks UAT/pilot/go-live, not entry into staging. |
| P35-OPS-002 | High | DEFERRED | Hosted CI, monitoring destinations, real Storage object recovery and release rollback require staging infrastructure and approval. This blocks pilot/go-live. |
| P35-REL-001 | Medium | VERIFIED | Root Vercel metadata and database dump/backup files were not ignored. `.gitignore` now excludes `.vercel`, `*.dump`, `*.dump.gz`, `*.backup` and `*.sql.gz`; 16-path ignore matrix passed. |
| P35-REL-002 | High | VERIFIED | `BrowserRouter` nested routes would return Vercel 404s without a static fallback. Minimal Vercel SPA rewrite added; production preview passed four direct nested routes and preserved hashed asset routing. |

Current staging blockers: 0. Current pilot/go-live blockers: 2 deferred controls.
