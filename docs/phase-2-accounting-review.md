# Phase 2 Accounting Review

## Policy Alignment

The database model follows delivery-basis revenue recognition, separate payment settlement, double entry, immutable posted journals, dated reversals, period locks, item-level partial fulfillment/returns, GRNI on accepted QC receipt, contractual courier accruals, and partner withdrawals outside profit and loss.

## High-Risk Assertions

| Assertion | Design control | Verification state |
|---|---|---|
| No unbalanced posted journal | deferred balance validation in posting boundary | SQL authored; database run pending |
| No edits to posted entries | immutable triggers on journal headers/lines | SQL authored; database run pending |
| No posting after close | shared period row lock and state check | SQL authored; concurrency run pending |
| No duplicate delivery revenue | unique posting event + idempotent delivery owner command | implementation review pending final migration integration |
| Deposits are liabilities | account-role posting map | fixture run pending |
| Discounts remain contra revenue | allocated item snapshots + posting map | fixture run pending |
| Courier report cannot define economic right | frozen contractual COD/fee fields | schema review implemented |
| Supplier receipt uses accepted QC only | receipt/QC and GRNI model | fixture run pending |
| Withdrawal never becomes expense | partner current-account posting | fixture run pending |
| Odd profit-distribution minor unit retained | deterministic allocation policy | fixture run pending |

## Professional Review Boundary

This is an engineering control review, not Egyptian statutory, tax, or professional-accountant sign-off. Opening balances, tax configuration, payroll obligations, and the final chart-of-accounts mapping require reconciliation and approval by Falcon's accountant before production use.

## Independent Review Outcome

The repair pass closed manual posting to control accounts, manual business-event preclaiming, reversal P&L distortion, missing local period seed, supplier reversal overstatement, partner close FK, aggregate shipment/return limits, and negative inventory enforcement. Major posting lifecycles, allocation accounting, monthly-close calculations, and behavioral tests remain incomplete; the accounting engine is not production-ready.
