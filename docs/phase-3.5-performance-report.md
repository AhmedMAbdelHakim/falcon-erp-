# Phase 3.5 Performance Report

| Metric | Before | After | Result |
|---|---:|---:|---|
| Largest/initial JS chunk | 683.90 kB | 469.84 kB | 31.3% smaller |
| Largest/initial JS gzip | 183.89 kB | 136.97 kB | 25.5% smaller |
| Production build time | 0.89 s baseline | 1.05 s | PASS |
| Local authenticated initial load | Not measured | 88 ms | PASS under 5,000 ms QA ceiling |
| Local SPA transition, Dashboard to Orders | Not measured | 154 ms | PASS under 5,000 ms QA ceiling |

All page modules are loaded with React `lazy` and `Suspense`; Vite emitted separate route chunks. The timing sample used local Vite and local Supabase and is a regression indicator, not a public-network SLA. Staging must collect browser telemetry under realistic network, cache and data volume before pilot approval.
