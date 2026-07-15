# Phase 3 Security Review

- Authentication uses Supabase Auth; routes require both a session and active access-context row.
- Organization, roles, and permissions come from current database mappings. User metadata is ignored.
- Sensitive actions call the closed `api` RPC catalog. Canonical fingerprints are computed by the database; idempotency and correlation IDs are generated per submission.
- New financial UI performs no direct table mutation. RLS and RPC authorization remain the enforcement boundary.
- Browser configuration accepts only URL and publishable/anon key. No service-role key is referenced by client source.
- Reports use permissioned RPCs and masked audit contracts. Export is not enabled, avoiding unaudited sensitive downloads.

Database security evidence: clean reset, DB lint, RLS/pgTAP suite (345 assertions), organization isolation, and concurrency tests passed after the access-context migration. Open operational gaps are staging session-switch tests, private Storage end-to-end tests, dedicated secret scanner in CI, and penetration review.
