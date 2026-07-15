# Production Readiness Checklist

This checklist is deliberately **not approved** for production.

> Phase 3.5 update (2026-07-15): local automated QA, cross-browser, import and database restore controls now pass. The current decision is `READY FOR STAGING`, not production approval. See `phase-3.5-final-report.md`.

| Area | Current state |
|---|---|
| Arabic RTL, responsive shell, light/dark, state handling | Pass locally |
| Financial read sources and RPC-only commands | Pass by code review and Phase 2 database evidence |
| Typecheck, build, lint, unit tests | Pass locally |
| Database reset/lint/pgTAP/RLS/accounting/concurrency | Pass after final schema migration |
| Desktop/mobile visual smoke | Pass in in-app browser |
| Automated component, axe, E2E, cross-browser | Pass locally: seven profiles |
| CI workflow | Defined; no hosted run evidence |
| Authorized staging and named users | Open |
| Backup/restore drill | Database pass locally; real Storage bytes pending staging |
| Monitoring/alert destinations | Open |
| Import/opening-balance dry run | Pass locally on deterministic synthetic fixtures |
| UAT and Ahmed/Moaz/financial reviewer approval | Open; no approval claimed |
| Production deployment/cutover approval | Not authorized |

Production remains NO-GO until every open control has executable or signed evidence.
