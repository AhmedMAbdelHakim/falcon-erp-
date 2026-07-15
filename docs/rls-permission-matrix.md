# RLS and Permission Matrix

RLS supplies row filtering; SQL privileges and RPC capability checks supply command authorization. A session is never authorized by `raw_user_meta_data` or `user_metadata`.

| Surface | Moderator | Operations | Finance manager | Partner | Auditor |
|---|---|---|---|---|---|
| Customers and orders | assigned/read; create/update non-financial fields | operational read/update through commands | read | aggregate/read | read |
| Discounts and policy exceptions | request | request | approve by capability | approve exceptional policy | read |
| Payments and wallets | no wallet balances; submit evidence only | read status | confirm/allocate/refund/transfer/reconcile | read summaries | read |
| Printing and inventory | order status read | create/receive/QC/ship | supplier invoice/payable actions | read summaries | read |
| Shipping and returns | assigned order status | dispatch/delivery/return evidence | settlement approve/finalize | read summaries | read |
| Expenses | none | submit permitted categories | approve/pay/reverse | read summaries | read |
| Payroll | own status only where enabled | performance input only | calculate/approve/pay | summary only | read |
| Partners | none | none | record approved capital/loan; execute approved withdrawal | own partner account/request | read |
| Ledger/periods | none | none | post/reverse/close within capabilities | statements and distributions | read-only |
| Audit | none | own command outcomes | finance/security events | material events | read-only |
| Attachments | only records visible through parent | operational parents | financial parents | approved summaries | read |

## Policy Pattern

- Every `public` table has RLS enabled and forced where compatible with Supabase ownership semantics.
- Organization rows require active membership through `private.is_org_member(organization_id)`.
- Sensitive reads additionally require `private.has_permission(organization_id, permission_code)`.
- Direct mutations are denied by omission for financial tables; users invoke granted `api` wrappers.
- Service-role access is reserved for migrations, trusted maintenance, and controlled background work.
- Views use `security_invoker = true`; their base-table RLS remains authoritative.
- Storage buckets are private. Object policies derive organization and parent-record access from database rows rather than client path claims alone.

## Separation of Duties

The same user may not approve their own payment-policy exception, refund, supplier invoice payment, courier settlement, payroll approval, or partner withdrawal where approval is required. The database records requester, approver, decision, and consumed command. Production partner identities are linked manually after Auth users are created.

## Phase 2 Read Contracts

| Contract family | Super admin | Finance manager | Partner | Auditor | Read only | Operations | Moderator |
|---|---|---|---|---|---|---|---|
| Financial dashboard, P&L, trial balance, control reconciliation | allow | allow | allow | allow | deny | deny | deny |
| Journal and monthly close detail | allow | allow | allow | allow | deny | deny | deny |
| Wallet liquidity summary | allow | allow | allow | allow through `ledger.read` | allow summary | deny | deny |
| Audit search/entity timeline | allow | deny | deny | allow | deny | deny | deny |

The API functions re-check `private.has_permission` against the requested organization. A caller with a valid role in one organization receives `42501` for another organization. API wrappers are security-invoker functions; protected private implementations are not Data API schemas. Accounting and audit base tables remain ungranted to authenticated users. Existing public payroll and partner table grants remain subject to their positive/negative RLS policies; the new aggregate reports do not expose employee or partner identities.
