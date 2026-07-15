# RPC Verification Matrix

Evidence date: 2026-07-15. Every row below exists after a clean reset and has executable evidence. `VERIFIED` includes the command or read wrapper, its protected implementation, authorization, canonical fingerprint where applicable, idempotent claim where applicable, and domain assertions listed in the evidence column.

| Domain | RPCs | Status | Runtime evidence |
|---|---|---|---|
| Approval primitives | `submit_approval_request`, `decide_approval` | VERIFIED | `040`, `060`, `070`, `080`, `090`, `100`, `110`, `120` |
| Fingerprints | `compute_request_fingerprint` | VERIFIED | canonical/tamper assertions in `030`, `040`, `110`, `130` |
| Order terms | `grant_order_discount`, `confirm_order`, `cancel_order` | VERIFIED | `050`, `130` |
| Fulfillment | `create_shipment`, `mark_order_delivered`, `record_order_return` | VERIFIED | `050` |
| Payment intake | `record_customer_payment`, `confirm_customer_payment` | VERIFIED | `040` |
| Allocation and credit | `allocate_customer_payment`, `apply_customer_credit` | VERIFIED | `040` |
| Refunds | `request_customer_refund`, `approve_customer_refund`, `execute_customer_refund`, `reverse_customer_refund` | VERIFIED | `040` |
| Receipt reversal | `reverse_customer_payment` | VERIFIED | `040` |
| Wallet transfer | `request_wallet_transfer`, `transfer_between_wallets` | VERIFIED | `120` |
| Wallet reconciliation | `prepare_wallet_reconciliation`, `finalize_wallet_reconciliation` | VERIFIED | `100` |
| Printing | `create_print_batch`, `receive_print_batch`, `close_print_batch` | VERIFIED | `070` |
| Supplier AP | `create_supplier_invoice`, `approve_supplier_invoice`, `pay_supplier_invoice` | VERIFIED | `070` |
| Courier settlement | `prepare_courier_settlement`, `approve_courier_settlement`, `finalize_courier_settlement` | VERIFIED | `050` |
| Expenses | `record_expense`, `approve_expense`, `pay_expense`, `request_expense_reversal`, `reverse_expense` | VERIFIED | `060` |
| Payroll | `calculate_payroll_period`, `approve_payroll_period`, `pay_payroll_entry` | VERIFIED | `060` |
| Employee advances | `request_employee_advance`, `record_employee_advance` | VERIFIED | `060` |
| Partner funding | `record_partner_capital`, `record_partner_loan` | VERIFIED | `080`, `100` |
| Withdrawals | `request_partner_withdrawal`, `approve_partner_withdrawal`, `execute_partner_withdrawal` | VERIFIED | `080` |
| Profit distribution | `calculate_profit_distribution`, `approve_profit_distribution`, `post_profit_distribution` | VERIFIED | `080` |
| Journal posting | `post_journal_entry` | VERIFIED | `090`, `110`, concurrency harness |
| Journal reversal | `request_journal_reversal`, `reverse_journal_entry` | VERIFIED | `110` |
| Monthly close | `start_monthly_close`, `attest_monthly_close_item`, `validate_monthly_close`, `close_accounting_period` | VERIFIED | `090`, concurrency harness |
| Close recovery | `cancel_monthly_close`, `recover_monthly_close`, `request_accounting_period_reopen`, `reopen_accounting_period` | VERIFIED | `090` |
| Dashboard/reporting | `read_dashboard_summary`, `read_profit_and_loss`, `read_trial_balance`, `read_control_account_reconciliation`, `read_liquidity_summary` | VERIFIED | `140` ledger equality, role isolation, draft exclusion, closed-period and privacy assertions |
| Ledger reads | `list_journal_entries`, `list_journal_lines` | VERIFIED | `140` filters, keyset page limits, line balance, private-table denial |
| Monthly-close reads | `list_monthly_closes`, `list_monthly_close_checklist` | VERIFIED | `140` close status, computed results, empty result and evidence masking |
| Audit reads | `search_audit_events` | VERIFIED | `140` auditor/super-admin access, all disallowed roles, filters, pagination and raw-field omission |

## Cross-Cutting Results

| Control | Result |
|---|---|
| Anonymous/public execution | revoked; command and read access is narrowly granted to `authenticated` per function |
| Authorization | database role and permission checks, not user-editable metadata |
| Canonical request binding | hostile changed-payload fingerprints rejected |
| Concurrent duplicate claim | one command row, one journal row, original result replayed |
| Retryable SQLSTATE | serialization/deadlock classified retryable and claim release implemented |
| Terminal failure | stable error envelope; no internal stack details returned |
| Financial atomicity | operational transition and journal occur in one transaction |
| Approval separation | request, decision, and execution actors enforced by workflow |
| Read-contract isolation | live database permissions, organization scope, role denial, and no-role denial execute in `140` |
| Read-contract privacy | raw audit states/IP/user-agent, attachment paths/tokens, journal hashes, payroll identities, and partner identities are omitted at SQL return type |

Detailed function signatures remain generated in `src/types/database.generated.ts`. The command inventory is also summarized in `rpc-command-catalog.md`.
