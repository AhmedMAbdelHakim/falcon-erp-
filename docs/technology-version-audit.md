# Technology Version Audit

Verification date: 2026-07-14. Registry checks used npm metadata on this date; framework/runtime claims use official project sources. The Supabase changelog was scanned for breaking changes relevant to Data API exposure and local PostgreSQL upgrades.

| Technology | Installed | Available stable | Selected | Compatibility/security notes | Upgrade decision | Official source |
|---|---:|---:|---:|---|---|---|
| Node.js | 24.16.0 | 24.18.0 LTS; 26.5.0 Current | Node 24 LTS line | Vite 8 requires Node 20.19+ or 22.12+; Node recommends production use of LTS. | Keep major 24; environment patch update recommended, not performed automatically. | [Node releases](https://nodejs.org/en/about/previous-releases) |
| npm | 11.13.0 | Locally verified only | 11.13.0 | Works with current lockfile/runtime. | Keep; lock dependency graph. | [npm CLI](https://docs.npmjs.com/cli/) |
| React | 19.2.7 | 19.2.7 | 19.2.7 | Existing stable app; no backend reason to change major. | Pin exact in Phase 2. | [React 19.2](https://react.dev/blog/2025/10/01/react-19-2), [npm](https://www.npmjs.com/package/react) |
| React DOM | 19.2.7 | 19.2.7 | 19.2.7 | Must match React. | Pin exact. | [npm](https://www.npmjs.com/package/react-dom) |
| React Router | 7.17.0 | 7.18.1 | 7.17.0 initially | UI dependency; upgrading is unrelated to Phase 2 backend. | Pin installed; defer upgrade to Phase 3 review. | [npm](https://www.npmjs.com/package/react-router-dom) |
| Vite | 8.0.16 | 8.1.4 | 8.0.16 initially | Vite 8 stable uses Rolldown and supports current Node. Existing build must be preserved. | Pin installed; consider 8.1 patch after build tests. | [Vite releases](https://vite.dev/releases), [Vite 8](https://vite.dev/blog/announcing-vite8) |
| Vite React plugin | 6.0.2 | 6.0.3 | 6.0.2 initially | Major 6 is paired with Vite 8. | Pin installed; patch optional. | [npm](https://www.npmjs.com/package/@vitejs/plugin-react) |
| TypeScript | 6.0.3 | 7.0.2 | 6.0.3 | Available major 7 is a material toolchain change; no need to upgrade during backend migration. | Pin 6.0.3; enable explicit strict checks. | [TypeScript](https://www.typescriptlang.org/), [npm](https://www.npmjs.com/package/typescript) |
| Supabase JS | 2.108.2 | 2.110.5 | 2.108.2 initially | Stable v2 client; publishable key only in browser; generated DB types required. | Pin installed, then evaluate minor update with tests. | [Supabase JS reference](https://supabase.com/docs/reference/javascript/introduction), [npm](https://www.npmjs.com/package/@supabase/supabase-js) |
| Supabase CLI | not installed | 2.109.1 | 2.109.1 | Required for local stack, migrations, pgTAP, and type generation. CLI notes service images can change even within major, so exact pinning matters. | Add exact dev dependency in Phase 2. | [CLI docs](https://supabase.com/docs/reference/cli/introduction), [CLI repository](https://github.com/supabase/cli), [npm](https://www.npmjs.com/package/supabase) |
| PostgreSQL local | not running | Supabase CLI-supported PG 17 line | CLI 2.109.1 bundled version, verify after start | Supabase announced self-hosted PG15-to-17 breaking change; schema must avoid unsupported assumptions and test actual local version. | Record exact server version after local start; do not independently install a different major. | [Supabase changelog](https://supabase.com/changelog?tags=breaking-change), [PostgreSQL docs](https://www.postgresql.org/docs/current/) |
| Tailwind CSS | 4.3.1 | 4.3.2 | 4.3.1 | UI dependency, stable and working. | Pin installed; defer patch unless needed. | [npm](https://www.npmjs.com/package/tailwindcss) |
| ESLint | 10.5.0 | 10.7.0 | 10.5.0 | Existing major works with flat config. | Pin installed; defer unrelated patch. | [ESLint releases](https://eslint.org/blog/), [npm](https://www.npmjs.com/package/eslint) |
| Vitest | absent | 4.1.10 | 4.1.10 | Vite-native TypeScript unit/integration runner. | Add exact in Phase 2 if application unit tests are introduced. | [Vitest](https://vitest.dev/), [npm](https://www.npmjs.com/package/vitest) |
| pgTAP | absent | Supabase local supported extension | local bundled version | Required for database/RLS tests; actual extension version comes from local image. | Enable and record after local start. | [Supabase database tests](https://supabase.com/docs/guides/database/testing) |
| Zod | absent | 4.4.3 | Deferred | Form/schema validation is useful but Phase 2 database commands do not require adding it. | Reassess in Phase 3. | [npm](https://www.npmjs.com/package/zod) |

## Supabase breaking-change review

- Data and GraphQL API exposure may no longer be automatic for new tables. Phase 2 will use explicit schema exposure, grants, and RLS rather than assuming API visibility.
- Local/self-hosted PostgreSQL moved toward PG17. Migrations and tests must use the exact CLI service image and verify extensions/functions.
- `pg_graphql` introspection defaults are irrelevant because GraphQL is not required for V1.
- CLI commands/config are discovered with `--help`; no remote `db push` or migration is allowed in Phase 2.

## Selection policy

Phase 2 will pin exact versions and preserve `package-lock.json`. Existing stable major versions remain unless a required local tool cannot work with them. No beta, RC, canary, deprecated package, or `latest` specifier is selected. Available versions were verified; no dependency upgrade has yet been applied by this Phase 1 audit.
