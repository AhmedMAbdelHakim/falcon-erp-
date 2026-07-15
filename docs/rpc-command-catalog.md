# RPC Command Catalog

Phase 2 status: **VERIFIED** on 2026-07-14. The live catalog contains 60 `api` functions. The executable verification mapping is maintained in `rpc-verification-matrix.md`; generated signatures are in `src/types/database.generated.ts`.

## Contract

Externally retryable business commands accept organization scope, command payload, a scoped idempotency key, a canonical request fingerprint, and a correlation ID. Financial commands return a stable envelope containing success, command/entity IDs, journal IDs, warnings, error code, message key, and current state.

Commands authenticate `auth.uid()`, authorize through database role mappings, lock domain rows in deterministic order, claim a unique `(organization_id, command_type, idempotency_key)` row, reject changed fingerprints, and replay stored outcomes. Retryable serialization/deadlock failures release their claim for retry. Business transitions and journals commit atomically.

## API Families

| Family | Commands |
|---|---|
| Approval | `submit_approval_request`, `decide_approval` |
| Orders | `grant_order_discount`, `confirm_order`, `cancel_order` |
| Fulfillment | `create_shipment`, `mark_order_delivered`, `record_order_return` |
| Customer money | `record_customer_payment`, `confirm_customer_payment`, `allocate_customer_payment`, `apply_customer_credit` |
| Refund/reversal | `request_customer_refund`, `approve_customer_refund`, `execute_customer_refund`, `reverse_customer_refund`, `reverse_customer_payment` |
| Wallets | `request_wallet_transfer`, `transfer_between_wallets`, `prepare_wallet_reconciliation`, `finalize_wallet_reconciliation` |
| Printing/suppliers | `create_print_batch`, `receive_print_batch`, `close_print_batch`, `create_supplier_invoice`, `approve_supplier_invoice`, `pay_supplier_invoice` |
| Courier | `prepare_courier_settlement`, `approve_courier_settlement`, `finalize_courier_settlement` |
| Expenses | `record_expense`, `approve_expense`, `pay_expense`, `request_expense_reversal`, `reverse_expense` |
| Payroll | `calculate_payroll_period`, `approve_payroll_period`, `pay_payroll_entry`, `request_employee_advance`, `record_employee_advance` |
| Partners | `record_partner_capital`, `record_partner_loan`, `request_partner_withdrawal`, `approve_partner_withdrawal`, `execute_partner_withdrawal` |
| Distribution | `calculate_profit_distribution`, `approve_profit_distribution`, `post_profit_distribution` |
| Ledger | `post_journal_entry`, `request_journal_reversal`, `reverse_journal_entry` |
| Close | `start_monthly_close`, `attest_monthly_close_item`, `validate_monthly_close`, `close_accounting_period`, `cancel_monthly_close`, `recover_monthly_close`, `request_accounting_period_reopen`, `reopen_accounting_period` |
| Utility | `compute_request_fingerprint` |

## Runtime Result

Every family above is `VERIFIED`. The final suite passed 260 assertions in 19 files; the separate two-session harness passed duplicate-command serialization and close-versus-post locking. No API family remains open or merely implemented.

Financial actions remain fail-closed when organization policy, approval, evidence, account mapping, or executable state is absent. Seed data is synthetic and supplies test configuration only.
