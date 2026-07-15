# GitHub Backup and Vercel Staging Deployment

Prepared 2026-07-15 for the accepted Phase 2, Phase 3 and Phase 3.5 working tree. This procedure creates a GitHub backup branch and a Vercel Preview or dedicated staging environment only. It does not authorize production deployment, production Supabase, production data, live money, live messages or remote migrations without a separate approval.

## Verified Repository Contract

- Current checkout: `master` at `13bcbca13e2539f87cf008c26a034ba2e688a631`.
- Current remote: `origin https://github.com/AhmedMAbdelHakim/falcon-shipping.git`.
- Framework: Vite.
- Install command: `npm ci`.
- Build command: `npm run build`.
- Output directory: `dist`.
- SPA routing: `BrowserRouter`; `vercel.json` rewrites client routes to `/index.html`.
- Public browser variables: `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` only.
- `.env.example` contains placeholders only. Never add a service-role/secret key, database URL/password, JWT secret or production credential to Vercel browser variables.

## Pre-Commit Checks

Run from the repository root:

```powershell
git status --short --branch
git branch --show-current
git rev-parse HEAD
git remote -v
git check-ignore -v .env .env.local .vercel test-results dist node_modules
git grep -Il -E "(SUPABASE_SERVICE_ROLE_KEY|service_role_key|DATABASE_URL|POSTGRES_PASSWORD|JWT_SECRET|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.)" -- . ":(exclude).env*"
npm ci
npm run typecheck
npm run build
npm run test:spa
npm run lint
npm run test:unit
npm run test:components
npm run test:accessibility
npm run test:e2e
npm audit --omit=dev
git diff --check
```

The secret scan passes only when it prints no tracked filename. Never print or inspect the local `.env` value during release preparation.

## GitHub Backup Commands

Execute only after explicit commit-and-push authorization:

```powershell
git switch -c codex/staging-backup-2026-07-15
git status --short --branch
git add -A
git status --short
git diff --cached --check
git diff --cached --name-only
git commit -m "Prepare Falcon ERP staging baseline"
git push -u origin codex/staging-backup-2026-07-15
```

Confirm `.env`, `.vercel`, `dist`, `node_modules`, reports, traces and dumps are absent from `git diff --cached --name-only` before committing. Open a review request from the backup branch; do not merge it into `master` under this authorization.

## Vercel Staging Settings

Create a separate Vercel project named `falcon-erp-staging`. Do not connect these values to an existing production project.

| Setting | Exact value |
|---|---|
| Framework Preset | `Vite` |
| Root Directory | `.` |
| Install Command | `npm ci` |
| Build Command | `npm run build` |
| Output Directory | `dist` |
| Node.js | `24.x` |
| Git branch | `codex/staging-backup-2026-07-15` |
| Environment | Preview scoped to that branch, or dedicated `staging` environment with branch tracking |

For Vercel Hobby, scope both variables to Preview and specifically to the staging branch. For Vercel Pro, create `Settings > Environments > staging`, enable Branch Tracking for the staging branch, and place the variables only there. Do not set production-scoped variables and do not use `vercel --prod`.

Required Vercel variables:

| Name | Value source |
|---|---|
| `VITE_SUPABASE_URL` | API URL of the separate staging Supabase project |
| `VITE_SUPABASE_ANON_KEY` | Publishable key, or legacy anon key, of the staging project |

The anon/publishable key is designed for browser use but RLS remains mandatory. Never use `SUPABASE_SERVICE_ROLE_KEY`, a secret key, database password, connection string or JWT secret in Vite variables.

## Supabase Staging Prerequisites

1. Create a new Supabase project dedicated to staging. Use no production data or credentials.
2. Record the staging project ref in the approved operator secret store, not in Git.
3. Use synthetic users and data only; keep live SMS/email providers disabled.
4. Confirm Data API exposed schemas are `api` and `public`. The migrations provide explicit grants and RLS; do not grant tables manually to work around a denied request.
5. Confirm the `falcon-operational` and `falcon-financial` Storage buckets are private after migration.
6. Create named synthetic staging users and assign roles through the approved database workflow. Do not insert real customer, wallet, payroll or financial records.

## Staging Migration Procedure

These commands target only the newly created staging project. Run the dry run and obtain separate remote-migration authorization before the actual push.

```powershell
npx supabase login
npx supabase link --project-ref <STAGING_PROJECT_REF>
npx supabase migration list --linked
npx supabase db push --linked --include-seed --dry-run
```

Review that all 55 migrations target the staging ref and that the seed is the repository's synthetic reference seed. After explicit remote-migration authorization:

```powershell
npx supabase db push --linked --include-seed
npx supabase migration list --linked
npx supabase db lint --linked --level warning
```

Never use `supabase db reset` against a linked or remote project. Never repair migration history merely to make the lists match; stop and investigate any difference.

## Auth Redirect Configuration

In the staging Supabase dashboard open `Authentication > URL Configuration`:

- Site URL: the stable HTTPS staging alias, for example `https://falcon-erp-staging.vercel.app`.
- Additional Redirect URL: `https://falcon-erp-staging.vercel.app/**`.
- Branch previews, if required: `https://*-<VERCEL_TEAM_OR_ACCOUNT_SLUG>.vercel.app/**`.
- Local development: `http://127.0.0.1:5173/**`.

Prefer exact staging URLs. Do not allow a global `https://**.vercel.app/**` pattern. The current app uses password sign-in without an OAuth redirect, but Site URL and allow-list settings are still required for confirmation, reset and future approved redirect flows.

## Staging Deployment

After commit/push and separate deployment authorization, deploy the backup branch as a Preview/dedicated staging deployment from the Vercel dashboard. A CLI preview deployment, if authorized, is:

```powershell
npx vercel@latest link
npx vercel@latest
```

Do not add `--prod`.

## Post-Deployment Smoke Tests

1. Open `/login`, then directly open and refresh `/dashboard`, `/orders/<synthetic-id>`, `/finance/monthly-close` and `/legacy/labels/edit/<synthetic-id>`; none may return a Vercel 404.
2. Confirm hashed `/assets/*` files return JavaScript/CSS rather than `index.html`.
3. Sign in with each synthetic role; verify organization name and permitted navigation.
4. Prove moderator Ledger denial, cross-organization denial, logout and protected-route redirect.
5. Run one synthetic read per major route and approved command smoke tests with correlation IDs.
6. Confirm private Storage denied/allowed paths, audit records, balanced journals and no browser console errors.
7. Run the Phase 3.5 UAT package before requesting pilot approval.

## Rollback

1. Stop staging testing and disable sensitive synthetic commands if authorization or accounting checks fail.
2. In Vercel, promote the previously verified staging Preview deployment or redeploy the prior Git commit. Never use `--prod`.
3. Do not roll back applied database files or rewrite migration history. Use a reviewed forward corrective migration.
4. For uncertain data state, restore the staging backup into a separate project and reconcile before resuming.
5. Record deployment URL, commit, migration head, failure, rollback target, timestamps and reviewer decision.

References: [Vercel SPA rewrites](https://vercel.com/kb/guide/why-is-my-deployed-project-giving-404), [Supabase Auth redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls), and [Supabase Vercel environment behavior](https://supabase.com/docs/guides/troubleshooting/vercel-integration-environment-variables-not-syncing-for-persistent-git-branches-b9191e).
