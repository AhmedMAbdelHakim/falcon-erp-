# Phase 2 Security Review

## Review Scope

IAM bootstrap, SQL privileges, RLS, exposed schemas, security-definer functions, command idempotency, audit data, attachments/storage, secrets, and the legacy shipping-label schema were reviewed against the Phase 1 security constitution.

## Controls Implemented

- `.env` is removed from Git tracking and environment variants are ignored; `.env.example` contains names only.
- Signup/profile creation ignores user-controlled role metadata. Production role membership is administrator-assigned in database rows.
- `api` is the only exposed command surface; implementations remain in `private` and ledger internals in `accounting`.
- Definer functions set an empty search path, fully qualify objects, revoke public execution, and expose only selected wrappers.
- Financial mutations occur through transactional commands with capability checks, approvals, idempotency records, and append-only audit events.
- Public tables receive RLS and least-privilege grants. Reporting views are security-invoker views.
- Financial storage buckets are private and policies bind objects to visible parent records.

## Findings

| Severity | Finding | Disposition |
|---|---|---|
| Critical | Legacy schema trusted `raw_user_meta_data.role`, enabling self-assigned admin | Superseded by migrations; legacy file retained as historical input but must not be applied to a new environment |
| Critical | `.env` was tracked in Git history | Removed from current index; credentials must be rotated and repository history handled through an approved incident procedure |
| High | Database/RLS policies cannot be executed on this workstation without Docker | Blocking verification item; do not deploy |
| High | Bootstrap database types are not generated from a reset database | Clearly marked bootstrap-only; regenerate after reset |
| Medium | Production Auth users and role links cannot be seeded safely | Manual production step by design |

## Secrets Review

No secret values were printed or copied into new files. Removing a tracked file does not erase its historical content, so all Supabase credentials ever stored there must be treated as exposed and rotated. History rewriting is intentionally not performed automatically because it is destructive and requires coordination with every clone.

## Security-Definer Checklist

Every definer function must satisfy all of: immutable owner controlled by migrations; `search_path = ''`; fully qualified relation/function names; no dynamic SQL from callers; caller identity derived from `auth.uid()`; explicit permission or trusted-trigger boundary; execution revoked from `public`, `anon`, and `authenticated` unless a narrow wrapper is deliberately granted.

## Independent Review Outcome

The repair pass closed the manual-control-account bypass, partner identity spoofing, broad partner base-table visibility, organization-folder-only storage reads, read-only financial uploads, and mutable attachment metadata. Remaining deployment blockers are broad relation-family read scopes, execution-fingerprint recomputation, missing role-impersonation/storage tests, dormant legacy IAM in `supabase/schema.sql`, and absent runtime verification.
