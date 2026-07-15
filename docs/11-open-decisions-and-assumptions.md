# Open Decisions and Assumptions

## Confirmed decisions

- Single Falcon organization, EGP, `Africa/Cairo`.
- Ahmed/Maaz ownership and distributable profit are 50/50.
- Current wallet is Vodafone Cash named to Maaz but accounted for as Falcon funds.
- Revenue is recognized at delivery; settlement is a later event.
- Custom deposit is 50% of paid products plus 100% shipping.
- Printer is paid after batch receipt, QC, and invoice finalization.
- Courier settles Monday/Thursday and deducts delivery/return fees.
- Moderator discount maximum is 20%, excludes shipping by default, and cannot create negative margin.
- Salary window is days 1-10; bonus ranges and withdrawal threshold are as recorded in the source of truth.
- Posted entries and closed periods are immutable; correction uses reversal/adjustment.

## Conservative assumptions

| ID | Assumption | Reason | Change mechanism |
|---|---|---|---|
| ASM-001 | EGP-only ledger in V1; currency columns still exist. | All confirmed numbers are EGP; avoids false FX support. | ADR plus migration. |
| ASM-002 | Custom deposit fractional minor unit rounds upward. | Prevents printing while underfunded. | Versioned finance setting. |
| ASM-003 | Standard ready order defaults to COD. | Source allows COD and full payment but does not fix one default. | Payment-policy setting. |
| ASM-004 | Delivery requires trusted evidence/state validation. | A status field alone is unsafe for revenue. | Command validation/evidence policy. |
| ASM-005 | Delivered return reverses revenue; pre-delivery return does not. | Preserves recognition integrity. | Accounting policy version. |
| ASM-006 | Printer/courier/reference models support multiple providers despite one current provider. | Low-cost extension path without multi-tenancy. | Reference data. |
| ASM-007 | Withdrawals and future-profit advances default to disabled until minimum operating capital, protected-liability horizon, reserve treatment, and advance cap are approved. | Zero defaults could overstate safe cash. | Effective-dated settings and audited enablement. |
| ASM-008 | Opening balances enter only through an approved opening-balance command after reconciliation. | Current wallet cash is not enough to infer liabilities/equity. | Controlled migration/command. |
| ASM-009 | Integer percentage multiplication is half-up; negative amounts reverse the rounded original. | Deterministic EGP arithmetic and exact reversals. | ADR-001. |
| ASM-010 | Accounting dates are Cairo business dates; timestamps remain UTC-capable `timestamptz`. | Matches payroll/close rules without ambiguous storage. | ADR-009. |

## Conflicts resolved

| Conflict | Resolution |
|---|---|
| Moderator 10% proposal versus final 20% decision | Final 20% applies with non-negative-margin guard. |
| “Return cost is shipping only” versus broader business loss | Separate courier return fee from total business return loss. |
| Payment after receipt versus QC requirement | Receipt, QC, and finalized invoice all precede payment. |
| Withdrawals “as needed” versus EGP 500 threshold | Final rolling 24-hour threshold controls. |
| Delivery posting trigger versus explicit transaction command | Authorized idempotent RPC owns delivery; trigger only protects invariants. |
| Existing shipping-label schema versus new accounting model | Preserve legacy behavior; migrations introduce governed domains and later compatibility work. |

## Decisions that can wait

- Actual printer/courier names and contracts.
- Exact governorate rates, product catalog, phone variants, packaging costs, salaries, and opening balances.
- Minimum operating capital, protected-liability horizon, reserve formula, and future-profit advance cap. Until decided, withdrawal execution is blocked.
- Order-number format and evidence/attachment retention duration.
- Exact delivery-proof rules and off-cycle courier process.
- Production RPO/RTO, hosting region, monitoring vendor, and incident contacts.
- Tax/e-invoice treatment after Egyptian accountant/legal review.

## Blocking decisions

### Blocking for production, not for local Phase 2 foundation

- Confirmed opening balances and reconciliation date.
- Real user IDs and role assignment approval.
- Rotation of any credential that may have existed in tracked `.env` history.
- Accountant approval of chart of accounts, returns, close, and profit-distribution policy.
- Legal review of business funds held in personal-name wallets.
- Production backup/recovery objectives and staging validation.
- Accepted delivery evidence types, issuer/tracking rules, checksum/parent linkage, timestamp tolerance, and independent-review threshold. Delivery recognition remains disabled in production until configured and approved.

No unresolved decision blocks local schema, invariant, RLS, and synthetic-test implementation when the conservative assumptions above are used.
