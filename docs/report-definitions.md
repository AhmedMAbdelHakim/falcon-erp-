# Report Definitions

| Report | Authoritative contract | Definition |
|---|---|---|
| Dashboard | `api.read_dashboard_summary` | Posted/reversed journal totals, safe cash, protected liabilities/reserve, approval and reconciliation alerts for the selected Cairo period. |
| Profit and loss | `api.read_profit_and_loss` | Monthly revenue, contra revenue, expense, and result from posted ledger lines. Deposits are excluded from revenue. |
| Trial balance | `api.read_trial_balance` | Opening, period, and closing debit/credit by chart account; totals must balance. |
| Liquidity | `api.read_liquidity_summary` | Wallet book balance from ledger dimensions versus latest physical reconciliation. |
| Ledger | `api.list_journal_entries` / `list_journal_lines` | Immutable journal headers and authorized drill-down lines. |
| Monthly close | `api.list_monthly_closes` / `list_monthly_close_checklist` | Executable close state, checklist, approval, validation, and trial-balance snapshots. |
| Audit | `api.search_audit_events` | Masked event index with actor category, subject, result, reason, and correlation. |

All timestamps include freshness fields where supplied. The UI does not reconstruct financial totals.
