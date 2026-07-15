# Architecture Decisions

## ADR-001: Money representation

- **Status:** Accepted
- **Context:** EGP calculations must be exact across PostgreSQL, JSON, and TypeScript.
- **Decision:** Store money as `bigint` minor units and rates as integer basis points. Serialize potentially unsafe integers as strings. Use centralized integer rounding; Custom deposits round upward.
- **Alternatives:** PostgreSQL `numeric` plus Decimal library; floating point.
- **Consequences:** Exact and fast arithmetic; UI adapters are required and raw JavaScript number math is forbidden.
- **Risks:** Accidental `Number` conversion or inconsistent rounding; schema and boundary tests mitigate it.

## ADR-002: Double-entry ledger

- **Status:** Accepted
- **Context:** Operational balances alone cannot prove profit, liabilities, or partner equity.
- **Decision:** `accounting.journal_entries` plus `journal_lines` are the financial source of truth; posting must balance and reconcile to subledgers.
- **Alternatives:** Single financial-transactions table; totals on orders/wallets.
- **Consequences:** Strong auditability and reports; more posting design and reconciliation work.
- **Risks:** Incorrect mappings; event-specific tests and accountant review required.

## ADR-003: Supabase RLS strategy

- **Status:** Accepted
- **Context:** Data API access must not make every authenticated user an administrator.
- **Decision:** RLS on all exposed tables with database role assignments, organization/work predicates, explicit grants, and negative tests. Authorization ignores user-editable metadata.
- **Alternatives:** UI-only checks; JWT role only; server service-role proxy for all access.
- **Consequences:** Defense at database boundary; policies require careful indexing/testing.
- **Risks:** Policy gaps or recursion; catalog checks, helper functions in `private`, and adversarial tests mitigate them.

## ADR-004: SQL migrations are source of truth

- **Status:** Accepted
- **Context:** Existing `schema.sql` is not reproducible migration history.
- **Decision:** Ordered immutable files under `supabase/migrations/` define schema; seed is synthetic and separate. Applied files are never edited.
- **Alternatives:** Dashboard changes; one mutable dump; ORM-managed schema.
- **Consequences:** Reviewable reset and promotion path; legacy baseline needs deliberate migration.
- **Risks:** Drift; CI/reset/diff checks and no dashboard-only changes.

## ADR-005: Server-side financial commands

- **Status:** Accepted
- **Context:** Delivery, payment, settlement, payroll, withdrawal, and close span multiple records.
- **Decision:** Narrow authenticated database RPCs validate, lock, mutate, post, audit, and emit outbox records in one transaction.
- **Alternatives:** Client request chains; generic status triggers; broad service-role API.
- **Consequences:** Atomic invariants and smaller attack surface; SQL functions become critical code.
- **Risks:** Definer privilege abuse; private schema, safe search path, explicit auth, revoked `PUBLIC`, and tests.

## ADR-006: Immutable posted entries

- **Status:** Accepted
- **Context:** Financial history must remain explainable.
- **Decision:** Posted entries/lines cannot update/delete; one linked reversal negates them. Closed-period corrections post approved adjustments in an open period.
- **Alternatives:** Edit in place; soft-delete and replace.
- **Consequences:** Complete history and reliable close; users need correction workflows.
- **Risks:** Excess reversals; reason/evidence/approval and reporting linkage.

## ADR-007: Snapshot strategy

- **Status:** Accepted
- **Context:** Current prices/policies must not rewrite historical margin/payroll/distribution.
- **Decision:** Snapshot sale price, unit cost, printer/shipping rate, discount, payment policy, product/model label where necessary, bonus rule, and ownership share at the fixing event.
- **Alternatives:** Join current master data; copy every field indiscriminately.
- **Consequences:** Stable history with intentional duplication.
- **Risks:** Missing snapshot fields; traceability and immutability tests.

## ADR-008: Single-organization architecture

- **Status:** Accepted
- **Context:** V1 serves Falcon only; multi-tenant SaaS is out of scope.
- **Decision:** Seed one organization and include `organization_id` on owned data/keys for isolation and future migration, without tenant administration features.
- **Alternatives:** No organization key; full multi-tenant platform.
- **Consequences:** Clear scope with inexpensive future path.
- **Risks:** False sense of SaaS readiness; documentation states it is not multi-tenant.

## ADR-009: Timezone handling

- **Status:** Accepted
- **Context:** Salary windows, settlement days, and accounting dates use Cairo business time.
- **Decision:** Store events as `timestamptz`; store accounting periods/dates as `date`; derive business date using `Africa/Cairo` in centralized commands.
- **Alternatives:** Local timestamp without zone; UTC date for all rules.
- **Consequences:** Unambiguous history and correct local deadlines.
- **Risks:** Client-derived dates; database commands and boundary tests prevent them.

## ADR-010: Testing pyramid

- **Status:** Accepted
- **Context:** Financial/security failures must be caught below the UI.
- **Decision:** Highest coverage at schema/constraint/pgTAP/RLS/RPC layers, then TypeScript unit/integration tests, with focused E2E for critical user journeys and accessibility/RTL in Phase 3.
- **Alternatives:** E2E-only; manual testing.
- **Consequences:** Fast invariant evidence and smaller E2E suite.
- **Risks:** Local Supabase tooling dependency; pin CLI and provide deterministic commands.

## ADR-011: Explicit commands over business triggers

- **Status:** Accepted
- **Context:** A generic status update trigger could recognize revenue accidentally.
- **Decision:** Delivery and all sensitive transitions use explicit command RPCs. Triggers only maintain timestamps/audit assistance and block immutable/closed-period violations.
- **Alternatives:** `AFTER UPDATE status` posting triggers.
- **Consequences:** Intent, authorization, idempotency, and errors are explicit.
- **Risks:** Direct DML bypass; revoke DML and add guards/RLS.

## ADR-012: Preserve and isolate legacy label system

- **Status:** Accepted
- **Context:** Existing UI/schema may contain useful shipping-label behavior and user data.
- **Decision:** Extend/refactor in place. Baseline legacy schema, remediate its authorization, and add new domains without deleting existing user work.
- **Alternatives:** Rewrite repository; reuse legacy tables as accounting truth.
- **Consequences:** Lower migration risk but temporary coexistence complexity.
- **Risks:** Naming/policy collisions; migration tests against fresh and legacy snapshots.

## ADR-013: Serialized period and withdrawal guards

- **Status:** Accepted
- **Context:** Locking only existing event rows permits close/post and first-withdrawal phantom races.
- **Decision:** Every posting and close locks the same accounting-period row first. Every withdrawal locks its stable partner row before calculating non-cancelled requests in the rolling 24-hour window.
- **Alternatives:** Aggregate queries without a stable lock; serializable isolation globally; advisory locks.
- **Consequences:** Deterministic serialization with modest contention.
- **Risks:** A command that omits the common guard; shared helper and catalog/integration tests are mandatory.

## ADR-014: Exposed RPC wrapper boundary

- **Status:** Accepted
- **Context:** Private functions are intentionally not exposed through PostgREST, but browser commands need a callable API.
- **Decision:** Expose an `api` schema containing thin invoker wrappers only. Private implementations hold narrowly justified definer privilege, explicit auth, safe search path, and exact grants; `private` remains outside Data API exposure.
- **Alternatives:** Definer functions in `public`; Edge Function proxy for every command; exposing `private`.
- **Consequences:** Clear API inventory and private implementation boundary.
- **Risks:** Environment schema exposure drift; catalog and direct-endpoint tests verify configuration/grants.
