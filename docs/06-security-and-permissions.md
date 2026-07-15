# Security and Permissions

## Roles

| Role | Purpose |
|---|---|
| `super_admin` | User/role administration and emergency configuration; financial actions still follow SoD. |
| `partner` | Full authorized business reports, partner approvals, close/distribution approvals. |
| `finance_manager` | Payments, expenses, reconciliations, ledger posting/reversal, payroll processing, close preparation. |
| `operations` | Orders, printing, inventory, shipping, operational evidence; no posted-ledger mutation. |
| `moderator` | Assigned customer/order work and safe discounts; no payroll, partner, ledger, or close data. |
| `auditor` | Read-only broad records/audit/report access with sensitive export separately controlled. |
| `read_only` | Approved non-sensitive operational/report reads only. |

Roles are database assignments with effective dates and organization scope. User-editable Auth metadata is never authoritative.

## Permission matrix

Legend: `R` read, `C` create/draft, `U` update draft, `X` cancel, `A` approve, `P` post/execute, `V` reverse, `L` close, `E` export, `-` denied. Row/field scope still applies.

| Resource/action | super_admin | partner | finance_manager | operations | moderator | auditor | read_only |
|---|---|---|---|---|---|---|---|
| Users/role assignments | RCUA | R | - | - | - | R | - |
| Customers/addresses | RCU | R | R | RCU | RCU assigned | R | R |
| Catalog/rates | RCUA | RA | R | RCU | R | R | R |
| Orders/items drafts | R | RA | R | RCU | RCU assigned | R | R scoped |
| Safe discount <=20% | - | AP | - | C | CP assigned | R | - |
| Negative-margin/exception | - | AP other/request | - | C request | C request | R | - |
| Payments/refunds | R | RA | RCPVX | C evidence | R assigned summary | R | - |
| Print/inventory/shipping | R | RA | R | RCUP | R assigned | R | R scoped |
| Courier settlements | R | RA | RCPVX | C evidence | - | R | R summary |
| Wallets/reconciliations | R | RA | RCPVX | C evidence | - | R | R summary |
| Expenses | R | RA | RCPVX | C request | - | R | R summary |
| Payroll/employee financial | R | RA | RCPVX | R own operational score only | - | R | - |
| Partner accounts/withdrawals | R | RACP own/other approve | R processing | - | - | R | - |
| Journal/periods | R | RAL | RCPVL | - | - | R | R reports only |
| Audit/security events | R | R | R | R own actions | R own actions | R | - |
| Sensitive export | E audited | E audited | E audited | E scoped | - | E audited | - |

`super_admin` does not automatically become a finance approver/poster. Capabilities may require an additional role, preserving separation of duties.

### Command-specific capabilities

| Capability | Request/prepare | Approve | Execute/post |
|---|---|---|---|
| `payment.record` / `refund.execute` | operations may attach evidence; finance prepares | partner/finance approver per threshold, never requester | finance command role |
| `order.deliver` / `order.return` | operations | evidence/exception approver when configured | operations command role after revalidation |
| `supplier.invoice` / `supplier.pay` | operations receives/QCs; finance prepares invoice/payment | finance/partner per threshold, never preparer where SoD applies | finance command role |
| `courier.settle` | finance prepares from immutable items | different finance/partner approver for differences | finance command role |
| `payroll.approve` / `payroll.pay` | finance prepares | partner or designated different approver | finance command role |
| `partner.withdraw` | linked partner identity requests | other `partner_id` above threshold | finance/authorized partner after liquidity guard |
| `journal.reverse` | finance requests | different authorized approver | finance posting role |
| `period.close` | finance prepares/reconciles | required partner identity/identities | dedicated close command after approval |
| `profit.distribute` | finance prepares from close | required partner identity/identities | dedicated distribution command |

Every approval binds organization, command capability, subject ID, amount/range, canonical subject fingerprint, requester identity and partner entity where relevant, approver identity/partner entity, expiry, and one-time consumption. Role revocation, subject mutation, wrong subject, expiry, reuse, or same partner entity invalidates execution.

## RLS strategy

1. All exposed tables enable and force RLS where appropriate.
2. Policies target named roles (`TO authenticated`) and call stable private authorization helpers that check current database assignments.
3. Every policy includes organization scope; customer/order access additionally uses assignment or capability.
4. UPDATE policies have both `USING` and `WITH CHECK`; required SELECT policy exists.
5. Client roles receive only needed table privileges. Sensitive tables expose no direct DML.
6. `accounting`, `private`, and `audit` are not Data API schemas. Defense-in-depth RLS/privileges still apply.
7. Exposed views are `security_invoker`; otherwise access is revoked and data is served by authorized report RPC.
8. Policy predicates and FKs are indexed; RLS test users cover every role and cross-scope denial.

## Sensitive commands

Payment/refund, delivery/return, supplier invoice/payment, courier settlement, wallet transfer/reconciliation adjustment, expense post, payroll approval/payment, partner withdrawal, journal post/reverse, close, and profit distribution are RPC-only.

The Data API exposes thin `api` schema wrappers only; `private` is not an exposed schema. Every privileged private implementation:

- resides in `private` or an explicitly controlled API schema;
- has `SECURITY DEFINER` only when required;
- sets `search_path = pg_catalog, public, accounting, private, audit` with all objects schema-qualified;
- verifies `auth.uid()` and current database permission;
- locks source rows and revalidates state/approval;
- uses idempotency and correlation IDs;
- revokes `EXECUTE` from `PUBLIC`, `anon`, and general `authenticated`, then grants only the exact invoker wrapper/capability path;
- records success/failure security/audit context without secrets.

## Sensitive data

- Customer phones/addresses, employee salary/advances/deductions, partner balances, wallet legal-holder metadata, payment references, attachment paths, and audit payloads are sensitive.
- Moderators see only assigned customer/order fields needed for fulfillment.
- Payroll and partner data use restricted tables or security-invoker projections, not client-side column hiding.
- Exports are permissioned, reasoned, watermarked/identified where feasible, and audited.

## Separation of duties

- A requester cannot approve their own exceptional payment policy, negative-margin override, large withdrawal, sensitive refund, close, or configuration change when approval is required.
- Partner A approves Partner B's above-threshold withdrawal.
- Finance prepares close; required partner approval locks it.
- Journal reversal requires a different approver from creator when policy requires.
- Approval is not execution: commands revalidate current source state, amount, threshold, and approval scope before consuming it.

## Approval lifecycle

`draft -> submitted -> approved/rejected/expired/cancelled -> consumed`

The request stores type, subject, requester, requested values/fingerprint, reason, evidence, expiry, and required role. Actions are append-only. A material change invalidates prior approval.

## Threat model and misuse cases

| Threat/misuse | Control |
|---|---|
| Authenticated user reads all labels/orders | Scoped RLS and negative cross-user/role tests. |
| User self-assigns admin via metadata | Database role assignments; ignore `raw_user_meta_data`. |
| Browser calls definer function directly | Revoke default execute, private schema, narrow wrapper, explicit auth. |
| Double-click/retry posts revenue twice | Idempotency registry plus source-purpose unique constraint. |
| Moderator edits price/discount to negative margin | Server recomputation, snapshot, permission and margin check. |
| Partner splits EGP 600 into small withdrawals | Locked rolling 24-hour aggregate and approval check. |
| Staff changes closed-period source row | Period guard, revoked DML, immutable ledger, adjustment workflow. |
| Settlement hides a shortage | Item-derived expectation and mandatory difference evidence/approval. |
| Unauthorized payroll export | Restricted projection/RPC and audited export capability. |
| Receipt URL leaks | Private bucket, parent authorization, short-lived signed URL. |
| Stale JWT retains sensitive capability | Commands query current assignments; role revocation test. |
| Tracked secret is reused | Untrack/ignore, scan history, rotate credentials, bundle scan. |

## Secret and session management

- Browser receives only a publishable/anon key. Service role, DB password, provider secrets, and signing secrets live in approved server/CI secret stores.
- `.env` is ignored and untracked; `.env.example` contains names/placeholders only.
- Production keys are rotated after any suspected Git exposure. Secret scanning runs in CI and before release.
- Sensitive commands require a valid user identity and current role. Short JWT lifetime and session revocation policy are set before production; higher-risk commands may validate session ID/freshness.

## Audit and incident logging

Audit events record actor, effective roles, organization, command/action, subject, result, reason, correlation, idempotency reference, IP/user-agent when available, and safe before/after metadata. Financial and security audit records are append-only. Incident events include repeated denial, self-approval attempts, duplicate fingerprints, period-lock violations, secret-scan findings, and export activity.

## Remaining security gates

Before production: rotate/validate tracked `.env` credentials, review Git history without exposing values, map real Auth IDs to roles, verify Storage policies, run Supabase advisors, establish session/incident/export policy, and complete staging penetration/authorization tests.
