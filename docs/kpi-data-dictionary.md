# KPI Data Dictionary

| KPI | Field | Source and rule |
|---|---|---|
| Net revenue | `net_revenue_minor` | Gross revenue less contra revenue from posted journal lines. |
| Expenses | `expense_minor` | Posted expense-account movement for the period. |
| Profit/loss | `profit_loss_minor` | Net revenue less expenses; supplied by the report RPC. |
| Wallet book balance | `wallet_book_balance_minor` | Posted wallet-dimension cash movement. |
| Protected liabilities | `protected_liabilities_minor` | Control liabilities that cannot fund discretionary withdrawals. |
| Protected reserve | `protected_reserve_minor` | Current approved reserve policy. |
| Safe cash | `safe_cash_minor` | Conservative server-side liquidity result after protected amounts and pending withdrawals. |
| Open approvals | `open_approval_count` | Current actionable approval requests in scope. |

Every `_minor` value is signed EGP minor units: 100 equals EGP 1. No KPI is calculated with browser floating point.
