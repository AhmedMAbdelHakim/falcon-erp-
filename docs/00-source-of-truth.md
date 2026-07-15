# Falcon Source of Truth

## Provenance

- Primary source: `falcon_accounts_chat_full.md`
- Source date: 2026-07-14
- Imported from: `D:\~\DAWNLOADS\falcon_accounts_chat_full.md`
- Lines read: 2,452 of 2,452
- SHA-256: `A46E4F0DF6BE37D0DE06C19CCCE7BF745F88EE08CF97ECC4584218221D30BABB`
- Interpretation date: 2026-07-14

This document normalizes the conversation into decisions. It does not replace the original wording. Source precedence is `AGENTS.md`, this document, accounting policy, accepted ADRs, requirements/traceability, original conversation, then documented conservative assumptions.

## Confirmed business decisions

| Area | Confirmed decision |
|---|---|
| Organization | V1 serves one organization, Falcon. |
| Partners | Ahmed owns 50%; Maaz owns 50%. Distributable profit is split 50/50. |
| Compensation | Salary for work is separate from ownership and profit distributions. |
| Wallet | Current collection wallet is Vodafone Cash, legally named to Maaz but accounted for as Falcon money. |
| Future wallets | InstaPay named to Ahmed and Fawry named to Maaz may be added. |
| Printer | The printer is accounted for per print batch and paid after receipt, quantity/quality inspection, and invoice finalization. |
| Procurement | Support supplier case plus print, Falcon case plus print, ready stock, free reprint, and paid reprint. |
| Courier | Settlements are expected Mondays and Thursdays; delivery and return fees are deducted from remittance. |
| Revenue | Product and shipping revenue are recognized on confirmed customer delivery, not order creation, confirmation, printing, shipping, or cash receipt. |
| Custom orders | Default required deposit is 50% of paid-product value plus 100% of shipping. Printing is blocked until allocated cleared payments meet it. |
| Orders | An order may contain multiple paid products, accessories, gifts, design services, replacements, and reprints. |
| Gifts | Sale price is zero; actual cost remains part of order cost and margin. |
| Discounts | Ahmed, Maaz, and moderators may grant up to 20% of paid-product value. Shipping is excluded by default. Moderators cannot approve negative margin. |
| Payroll | Monthly; due on day 1, payable through day 10, overdue afterward; partial payment is supported. |
| Moderator bonus | EGP 500-3,000 based on delivered operational performance; score below 60 earns zero. |
| Operations bonus | EGP 500-2,000 based on preparation, accuracy, timing, and cooperation; score below 60 earns zero. |
| Withdrawals | Aggregate each partner's withdrawals over rolling 24 hours. Up to EGP 500 needs no other-partner approval; above that threshold does. |
| Closing | Profit distribution occurs only after approved monthly close. Posted financial records and closed periods are immutable except through reversal/adjustment. |

## Accounting rules

1. Cash balance is not profit. Available liquidity excludes deposits, payables, payroll, courier differences, reserves, and minimum operating capital.
2. Customer deposits are contract liabilities until delivery.
3. Delivery creates revenue and courier receivable/COD settlement exposure; courier remittance settles the receivable later.
4. Product cost, printing, packaging, gifts, delivery, returns, payment fees, discounts, and attributable error costs contribute to order margin.
5. Wallet transfers move assets and do not affect profit; transfer fees are expenses.
6. Printer invoices create supplier payables; payment clears the payable and is not a new expense.
7. Payroll is accrued separately from payroll payment.
8. Partner capital, loans, current accounts, distributions, and withdrawals are distinct from revenue and expense.
9. Posted entries balance, are immutable, and are corrected with linked reversals.
10. Historical events use price, cost, rate, policy, bonus-rule, and ownership snapshots.

## Operational rules

- Every financially relevant order, payment, expense, print item, shipment, settlement, payroll payment, withdrawal, and approval has a stable ID and audit trail.
- A Custom item cannot enter printing until the required deposit is fully allocated and cleared.
- A print batch cannot be paid before receipt and inspection.
- Delivery and `financially_settled` are separate states.
- Settlement expected value is derived from shipment items: collected COD minus delivery fees, return fees, and approved deductions.
- Settlement differences require reason, evidence, review, and approval before close.
- Falcon-owned inventory is tracked by movement and location, including printer custody, packaging, courier, return inspection, and damage.
- No permanent deletion of financial records; cancel or reverse.
- Approvals retain requester, approver, timestamps, decision, reason, and evidence. Required separation of duties prevents self-approval.

## Numerical settings

| Setting | Value |
|---|---:|
| Currency | EGP |
| Timezone | Africa/Cairo |
| Custom product deposit | 5,000 bps |
| Custom shipping prepaid | 100% |
| Partner ownership/profit share | 5,000 bps each |
| Moderator maximum discount | 2,000 bps |
| Withdrawal approval threshold | 50,000 minor units |
| Withdrawal aggregation | rolling 24 hours |
| Salary due day | 1 |
| Salary payment window end | 10 |
| Moderator bonus range | 50,000-300,000 minor units |
| Operations bonus range | 50,000-200,000 minor units |
| Courier settlement schedule | Monday and Thursday |

## Event timeline

`order -> deposit -> confirmation -> print batch -> receipt/QC -> supplier invoice/payment -> packaging -> shipment -> delivery/revenue -> courier receivable -> courier settlement -> wallet reconciliation -> monthly close -> profit distribution`

## Conflict matrix

| ID | Source tension | Conservative resolution |
|---|---|---|
| CON-001 | Earlier assistant proposal limited moderator autonomous discount to 10%; user later fixed maximum at 20%. | Final user decision governs: moderator may approve up to 20% only when shipping is excluded and margin is non-negative. |
| CON-002 | “Return costs shipping only” can conflict with total business loss including damaged product/packaging. | Store courier return fee separately from total return loss. The former follows the rate; the latter records all evidenced loss. |
| CON-003 | “Pay printer after receipt” omits explicit inspection in one answer. | Receipt, quantity/quality inspection, and finalized invoice are all prerequisites to payment. |
| CON-004 | “Withdraw as needed” conflicts with later threshold. | Final numeric rule applies: rolling 24-hour aggregation and cross-partner approval above EGP 500. |
| CON-005 | Source ERD suggests delivery posting trigger; the execution constitution requires explicit commands. | Use an authorized idempotent `mark_order_delivered` transaction; triggers only guard invariants. |
| CON-006 | Existing repository schema models shipping labels and broad admin/staff roles, not the approved domain. | Preserve it during Phase 1; Phase 2 migrates deliberately and does not treat it as accounting truth. |

## Explicit assumptions

- V1 is single-organization and EGP-only, while organization/currency columns preserve extension paths.
- Standard ready orders default to COD unless an explicit payment policy says otherwise.
- Half-minor-unit deposit calculations round upward so a Custom order is never underfunded by rounding.
- Delivery recognition requires a trusted command and evidence/state validation; a client status update alone is insufficient.
- Return revenue is reversed when a delivered sale is validly returned; pre-delivery returns never create revenue.
- Opening balances require a separately approved reconciliation and are not inferred from the current wallet balance.
- Partner withdrawals and future-profit advances remain disabled until minimum operating capital, liability horizon, reserve treatment, and advance cap are approved.
- The system records the accounting ownership of personal-name wallets but does not claim legal or regulatory sufficiency.

## Open decisions

Non-blocking for schema foundation but blocking for affected production commands: printer/courier legal names, exact governorate rates, initial product catalog, minimum operating capital, liability horizon, reserve formula, future-profit advance cap, actual salaries/proration, payment and delivery evidence standards, exact order-number format, report retention, attachment retention, and production backup objectives. They must be configured and approved before the relevant command is enabled.
