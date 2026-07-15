# Accounting Posting Map

Phase 2 posting status: **VERIFIED**. The event-by-event verification and test references are in `accounting-coverage-matrix.md`.

All EGP values are signed `bigint` minor units. Commands resolve accounts through effective organization account-role mappings, lock the Cairo accounting period, post balanced journals, and commit the operational transition in the same transaction. Posted entries and lines are immutable.

| Event | Debit | Credit |
|---|---|---|
| Customer receipt | wallet cash | customer deposits |
| Delivery revenue | customer deposits / courier receivable | gross sales revenue |
| Delivery discount | sales discount contra-revenue | customer consideration |
| Inventory consumption | cost of sales | inventory |
| Courier delivery fee | delivery expense | courier payable |
| Accepted print receipt | inventory/WIP | GRNI |
| Supplier invoice | GRNI and controlled variance | supplier payable |
| Supplier payment | supplier payable | wallet cash |
| Customer return | sales return and inventory | receivable/refund liability and cost of sales |
| Refund execution | refund payable | wallet cash |
| Courier settlement | wallet cash and courier payable | courier receivable |
| Expense approval | expense/asset | expense payable |
| Expense payment | expense payable | wallet cash |
| Payroll approval | payroll/bonus expense | payroll payable |
| Payroll payment | payroll payable | wallet cash |
| Employee advance | employee receivable | wallet cash |
| Partner capital | wallet cash | partner capital |
| Partner loan | wallet cash | partner loan payable |
| Partner withdrawal | partner current account | wallet cash |
| Profit distribution | retained earnings | partner current accounts |
| Wallet transfer | destination cash and fee expense | source cash |
| Wallet reconciliation gain/loss | wallet cash or variance | variance or wallet cash |
| Reversal | exact inverse | exact inverse |

## Recognition Rules

- Customer money received before delivery is a liability, not revenue.
- Delivery is the sole revenue-recognition owner. Courier settlement is a later clearing event.
- Accepted QC quantities create inventory and GRNI; supplier invoices clear GRNI and controlled variance.
- Partner withdrawals and wallet-transfer principal never enter operating expense or profit.
- Corrections use approved reversal entries. The original entry remains posted and immutable.
- Closed periods reject direct posting. Adjustments use an open period and reference the affected closed period.
- Profit distribution uses a closed-period basis, cumulative losses, protected reserve, prior distributions, ownership snapshots, floor allocation, and retained minor-unit remainder.
