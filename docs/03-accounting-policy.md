# Accounting Policy

Status: proposed for local V1 implementation; production use requires accountant approval.

## Currency and precision

- Functional currency: EGP.
- Storage: signed `bigint` minor units (`_minor`), where `100 = EGP 1`.
- Percentages: integer basis points (`_bps`), where `10000 = 100%`.
- General multiplication: integer half-up rounding. Required Custom deposit rounds upward. Reversals negate the originally posted minor amount rather than recomputing.
- No floating-point money in SQL or TypeScript. JSON transports money as decimal strings where values may exceed JavaScript safe integer range.

## Preliminary chart of accounts

| Code range | Type | Representative accounts |
|---|---|---|
| 1000-1999 | Assets | Vodafone Cash, InstaPay, Fawry, cash, customer receivable, courier receivable, employee advances, inventory, supplier advances |
| 2000-2999 | Liabilities | Customer deposits, customer credits, GRNI/accrued production, supplier payable, courier payable/deductions, payroll payable, partner loans, refunds payable |
| 3000-3999 | Equity | Ahmed capital/current/distributions, Maaz capital/current/distributions, retained earnings, current-year earnings |
| 4000-4999 | Revenue | Product sales, accessory sales, design service, shipping revenue, sales returns/discount contra-revenue |
| 5000-5999 | COGS | Case/print cost, packaging, gifts, direct production loss |
| 6000-6999 | Operating expense | Courier delivery/return, ads, payroll/bonus, payment/transfer fees, software, transport, admin, damage/loss |
| 7000-7999 | Other/clearing | Reconciliation difference, suspense (restricted), rounding difference |

Control accounts require linked subledger references. Suspense may be used only by finance with approval and must be zero before close.

## Recognition policies

### Revenue and deposits

Cash received before delivery is a customer-deposit liability. Unallocated excess remains a customer-credit liability. Delivery is recognized per delivered shipment item through an authorized idempotent command: allocated deposit is consumed only up to the recognized obligation, contractual COD becomes courier receivable, and other unpaid credit becomes customer receivable. Later direct collection clears customer AR. Order creation, confirmation, printing, shipment, and payment alone do not recognize revenue.

Product revenue is presented gross before discounts; snapshotted discounts debit contra-revenue at the related item delivery. Order-level discount and shipping are allocated to shipment items by deterministic largest-remainder minor-unit allocation with a stable item-ID tie-break. Allocations can never exceed the order snapshots. Shipping revenue is recognized according to an explicit shipment allocation and at most once for each allocated minor unit.

### COGS and inventory

Delivery recognizes item-level snapshotted cost. Supplier-provided case/print may be expensed to COGS from received production/clearing; Falcon-owned stock credits inventory. Gifts carry zero revenue and actual cost. Packaging and attributable direct loss are included in order margin.

### Shipping and returns

Shipping charge billed to the customer is gross shipping revenue. Courier delivery/return fees are expenses, not netted out of revenue. At confirmed delivery, the snapshotted delivery fee is accrued: debit courier delivery expense and credit courier payable. Return service similarly accrues its fee when confirmed. Settlement clears gross courier receivable and courier payable against net wallet cash; courier-reported collection and actual remittance are evidence fields, never the source of expected gross COD.

A delivered return reverses only the returned shipment-item revenue, contra-discount allocation, COGS, and recoverable inventory through linked lines, and records courier, packaging, damage, or rework loss separately. Cross-period returns post in the current open period while referencing the original item/entry/closed period. A pre-delivery return records no sales reversal. Refund approval establishes a refund payable; payment clears it.

### Suppliers and courier

Accepted receipt/QC establishes inventory/WIP/direct production value against GRNI using the snapshotted expected accepted cost. Partial receipts accrue accepted quantities only; rejected or disputed quantities do not become payable without approval. The final invoice debits GRNI, records approved price/quantity variance to inventory or production variance, and credits supplier AP. Supplier credits reverse the relevant AP/cost. Payment clears AP.

Delivery establishes courier receivable from the frozen contractual order balance and courier-fee payable from the rate snapshot; settlement clears both against net wallet cash. Differences remain explicit until approved.

### Payroll

Approved payroll accrues expense and payroll payable for the accounting month. Each payment debits payable and credits wallet; partial payments leave the remainder. Advances are employee receivables and reduce net payable only through approved payroll calculation.

### Partners

Capital, loans, current accounts, profit distributions, withdrawals, and expense reimbursements use distinct accounts. Withdrawals and distributions do not affect P&L. Reimbursement clears an evidenced payable/receivable rather than creating an undocumented withdrawal.

## Posting events

| Event | When entry is created | Debit | Credit | No entry when |
|---|---|---|---|---|
| Pre-delivery payment | Cleared payment is recorded | Wallet/clearing asset | Customer deposit/credit liability | Draft/unverified reference only |
| Post-delivery direct payment | Cleared payment is recorded | Wallet | Customer receivable | Draft/unverified reference only |
| Payment refund | Approved refund executes | Refund payable/customer credit | Wallet | Request is pending |
| Printer receipt/QC | Accepted quantity/cost is fixed | Inventory/WIP/production asset | GRNI/accrued production | Sent, unreceived, or rejected quantity |
| Supplier invoice | Final invoice is posted | GRNI plus approved variance | Supplier payable | Draft invoice |
| Supplier payment | Approved payment executes | Supplier payable | Wallet | Payment scheduled only |
| Shipment-item delivery | Trusted delivery command succeeds | Deposit liability, courier/customer receivable, sales-discount contra-revenue | Gross product/service/shipping revenue | Undelivered item or replay |
| Delivery COGS and courier fee | Same delivery transaction | COGS/direct cost and courier delivery expense | Inventory/production clearing and courier payable | Undelivered/cancelled item |
| Delivered item return | Approved return command | Sales returns/refund path and recoverable inventory as applicable | Receivable/refund payable and COGS reversal as applicable | Pre-delivery return |
| Courier settlement | Approved remittance posts | Wallet, courier payable, approved true-up debit | Courier receivable and approved true-up credit | Draft/mismatched unapproved settlement |
| Wallet transfer | Transfer command posts | Destination wallet and fee expense | Source wallet | Draft transfer |
| Expense | Approved incurred/paid command | Expense/asset | Wallet/payable | Unapproved request |
| Payroll accrual | Payroll approved | Payroll/bonus expense | Payroll payable | Draft score/payroll |
| Payroll payment | Payment executes | Payroll payable | Wallet | Approval only |
| Partner capital/loan | Cleared receipt | Wallet | Partner capital or loan | Promise only |
| Partner withdrawal | Approved and paid | Partner current/distribution/loan payable | Wallet | Request pending or liquidity blocked |
| Month close | Close command succeeds | Current-year income clearing as designed | Retained/current earnings as designed | Checklist incomplete |
| Profit distribution | Distribution approved | Retained/distributable earnings | Partner distributions payable/current | Close not approved |

## Example entries

Customer pays EGP 315 Custom deposit:

```text
Dr Vodafone Cash                         31,500
  Cr Customer deposits                  31,500
```

Order items delivered with EGP 500 gross products, EGP 50 discount, EGP 65 shipping, EGP 315 deposit, and EGP 200 COD:

```text
Dr Customer deposits                    31,500
Dr Courier receivable                   20,000
Dr Sales discounts                       5,000
  Cr Product revenue                    50,000
  Cr Shipping revenue                    6,500
```

Order cost EGP 270 and courier fee EGP 65:

```text
Dr Cost of goods/direct order cost      27,000
  Cr Inventory/production clearing      27,000
Dr Courier delivery expense              6,500
  Cr Courier payable                     6,500
```

Courier remits EGP 135 after offsetting EGP 65 payable against EGP 200 receivable:

```text
Dr Vodafone Cash                        13,500
Dr Courier payable                       6,500
  Cr Courier receivable                 20,000
```

Partner withdrawal EGP 500:

```text
Dr Partner current/distribution         50,000
  Cr Vodafone Cash                      50,000
```

## Journal controls

- Draft entries may be edited by authorized finance roles; posted entries cannot.
- Application roles have no direct entry/line DML. The posting function constructs or consumes draft lines, validates line count, positive debit/credit side, exact aggregate balance, account availability, source uniqueness, idempotency, actor, and approval, then atomically changes status.
- Posting and close derive the Cairo accounting date and lock the same accounting-period row before the open-period check. Constraint triggers reject mutation of posted entries/lines and enforce one reversal per original; an ordinary row `CHECK` is not treated as sufficient for aggregate balance.
- A source event can have only the documented posting set. Unique source/posting-purpose constraints prevent duplicate revenue and COGS.
- Reversal references the original, mirrors every line, and can occur once. Corrected entries reference both source and reversal correlation.
- Direct client DML on accounting tables is revoked.

## Month close

Required reconciliations: wallets, customer deposits/credits/AR, courier AR/payable, supplier GRNI/AP, inventory/COGS, payroll, expenses, partner accounts, suspense, and trial balance. The close snapshots period profit/loss, cumulative retained earnings/loss carryforward, prior distributions, reserves, totals, checklist evidence, settings/rules, and approvers. Closing locks dates through period end. Later discoveries post approved adjustments in an open period and reference the affected close.

Distributable profit is cumulative positive retained profit after losses, prior distributions, approved reserve/retention, and other policy-protected amounts. Each 50% allocation uses integer floor; an indivisible one-minor-unit remainder remains retained. A unique close/distribution-purpose constraint prevents repeat distribution. Cash availability is checked separately; accounting profit never implies withdrawable cash.

Reserve formula version 1 is explicit and snapshotted at close: positive retained
profit equals cumulative posted P&L through period end less prior posted profit
distributions. The protected reserve is the greater of approved minimum operating
capital and `floor(positive retained profit * reserve_requirement_bps / 10000)`.
Distributable profit is the nonnegative remainder. A close fails when either
policy input is absent. This accounting retention is separate from withdrawal
liquidity protection and its liability horizon.

Partner withdrawal execution, including future-profit advances, is disabled until approved minimum operating capital, protected-liability horizon, reserve treatment, and advance cap exist. Safe amount uses cleared unrestricted wallet cash only, less submitted/approved payment commitments and withdrawals, protected liabilities due in the horizon, reserve, and minimum capital. Receivables and unverified cash are excluded. Inputs and result are snapshotted and audited.

## Reconciliation and reporting

Subledgers for customer deposits, courier, suppliers, payroll, wallets, and partners must reconcile to control accounts. Reports always state accounting period/as-of time and derive financial totals from posted journal lines, with operational tables used for dimensions and drill-down.
