# Accounting Coverage Matrix

All postings use signed EGP minor-unit `bigint` values. Account UUIDs are resolved from effective organization account-role mappings. Every posting command locks the Cairo accounting period and creates balanced, immutable journal lines in the same transaction as its operational state change.

| Business event | Debit | Credit | Operational conservation | Status / evidence |
|---|---|---|---|---|
| Order discount and confirmation | No journal before delivery | No journal before delivery | largest-remainder discount equals header; terms and costs freeze | VERIFIED, `130` |
| Customer receipt confirmation | wallet cash | customer deposits | confirmed amount preserved independently of revenue | VERIFIED, `040` |
| Payment allocation/customer credit | customer deposit subledger | allocated deposit/credit liability subledger | allocated plus credit remainder equals receipt | VERIFIED, `040` |
| Customer refund approval | customer deposit/credit liability | refund payable | refund bounded by available customer amount | VERIFIED, `040` |
| Customer refund execution | refund payable | wallet cash | exact approved amount; separate executor | VERIFIED, `040` |
| Payment/refund reversal | exact inverse of original entries | exact inverse of original entries | state, allocations, credits, and approvals restored/closed consistently | VERIFIED, `040` |
| Delivery revenue | customer deposits and courier receivable | gross sales revenue | one revenue owner; contractual COD separate from courier report | VERIFIED, `050` |
| Delivery discount | sales discount contra-revenue | customer consideration | frozen allocation total preserved | VERIFIED, `050`, `130` |
| Inventory consumption | cost of sales | inventory | quantity and frozen unit cost preserved | VERIFIED, `050` |
| Courier fee accrual | delivery expense | courier payable | contractual fee independent of settlement report | VERIFIED, `050` |
| Customer return | sales returns/refund liability and inventory | receivable/deposit and cost of sales | return quantity cannot exceed delivered quantity | VERIFIED, `050` |
| Courier settlement | wallet cash and courier payable | courier receivable | prepared difference, approval, and final cash reconcile | VERIFIED, `050` |
| Accepted print receipt / GRNI | inventory/WIP | GRNI | only accepted QC quantity capitalized | VERIFIED, `070` |
| Supplier invoice | GRNI and controlled variance | supplier payable | matched quantities/costs and credit snapshot | VERIFIED, `070` |
| Supplier payment | supplier payable | wallet cash | cannot exceed approved open payable | VERIFIED, `070` |
| Expense approval | operating expense/asset | expense payable | total server-derived from subtotal and tax | VERIFIED, `060` |
| Expense payment | expense payable | wallet cash | exact approved unpaid amount | VERIFIED, `060` |
| Expense reversal | exact inverse of approval journal | exact inverse | unpaid approved expense only; approval consumed | VERIFIED, `060` |
| Payroll approval | payroll/bonus expense | payroll payable | period inputs frozen | VERIFIED, `060` |
| Payroll payment | payroll payable | wallet cash | exact net payroll | VERIFIED, `060` |
| Employee advance | employee receivable | wallet cash | never payroll expense; approved amount fixed | VERIFIED, `060` |
| Partner capital | wallet cash | partner capital | partner-specific equity subledger | VERIFIED, `080`, `100` |
| Partner loan | wallet cash | partner loan payable | liability, not revenue/equity | VERIFIED, `080` |
| Partner withdrawal | partner current account | wallet cash | rolling-window amount; never expense | VERIFIED, `080` |
| Profit distribution | retained earnings | partner current accounts | closed basis, ownership snapshot, floor allocation, remainder retained | VERIFIED, `080` |
| Wallet transfer | destination wallet cash and transfer fee expense | source wallet cash | principal P&L-neutral; fee separate | VERIFIED, `120` |
| Wallet reconciliation variance | wallet cash or reconciliation variance | reconciliation variance or wallet cash | ledger movement plus adjustment equals provider closing amount | VERIFIED, `100` |
| Manual journal | approved non-control accounts | approved non-control accounts | balanced, source-purpose allowlist, open period | VERIFIED, `110` |
| Journal reversal | exact inverse | exact inverse | original remains immutable; approval consumed once | VERIFIED, `110` |
| Monthly close | no placeholder/manual journal | no placeholder/manual journal | 15 source checks, reserve/distributable snapshots, shared period lock | VERIFIED, `090`, concurrency harness |

## Invariants

- Posted journals and lines are append-only; corrections use dated reversal entries.
- Customer deposits remain liabilities until delivery.
- Delivery and courier settlement are separate accounting events.
- Partner withdrawals and wallet-transfer principal do not affect profit.
- Closed periods reject direct mutation; open-period adjustments reference the affected closed period.
- No tested workflow or reporting fixture produced an unbalanced journal in the 328-assertion aggregate run.

## Reporting Reconciliation

The authenticated dashboard, profit-and-loss, trial-balance, liquidity, and control-account reconciliation contracts derive from posted/reversed journal lines. `database/140_read_contracts.sql` verifies report-to-ledger equality, reversal netting, exclusion of customer deposits, wallet-transfer principal and partner withdrawals from profit, exclusion of draft/future journals, closed-period readability, and aggregate privacy for payroll and partner controls.
