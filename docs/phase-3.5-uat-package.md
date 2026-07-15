# Phase 3.5 UAT Package

Run only in authorized staging with synthetic or approved sanitized data. Record actual journal IDs, correlation IDs, screenshots and reviewer identity. `Pass/Fail` and `Notes` are deliberately blank for human completion.

## Administrator

| Scenario | Expected result | Evidence required | Pass/Fail | Notes |
|---|---|---|---|---|
| Activate a test user and assign one approved role | Access context reflects only the approved organization and role | Audit event, access screenshot | | |
| Attempt an unauthorized finance action | Action is hidden or denied without data disclosure | Denial screenshot, audit/correlation | | |

## Moderator

| Scenario | Expected result | Evidence required | Pass/Fail | Notes |
|---|---|---|---|---|
| Create customer and order, apply permitted discount | Exact totals and assigned scope persist | Order ID, totals, screenshot | | |
| Open another moderator's order and Ledger | Both are denied | Two denial screenshots | | |

## Warehouse

| Scenario | Expected result | Evidence required | Pass/Fail | Notes |
|---|---|---|---|---|
| Receive/QC a print batch and record inventory movement | Batch and inventory states agree; retry is idempotent | Batch ID, movement rows, correlation | | |
| Process return/reversal | Inventory conservation remains true | Before/after quantities, reversal link | | |

## Printing

| Scenario | Expected result | Evidence required | Pass/Fail | Notes |
|---|---|---|---|---|
| Create and close a print batch | Eligible orders transition once; labels render correctly | Batch/order IDs, printed sample | | |
| Retry the close command | Stored outcome replays without duplicate movement or journal | Correlation and row counts | | |

## Shipping

| Scenario | Expected result | Evidence required | Pass/Fail | Notes |
|---|---|---|---|---|
| Create shipment, deliver, settle courier | Delivery and settlement are separate auditable events | Shipment, settlement and journal IDs | | |
| Reject invalid transition | State remains unchanged and error is clear | Before/after state, error screenshot | | |

## Accounting

| Scenario | Expected result | Evidence required | Pass/Fail | Notes |
|---|---|---|---|---|
| Post then reverse an approved manual journal | Both entries balance; original remains immutable | Entry/reversal IDs and lines | | |
| Close a month and attempt direct closed-period posting | Close reconciles; direct mutation is rejected | Close report, denial and audit event | | |

## Finance

| Scenario | Expected result | Evidence required | Pass/Fail | Notes |
|---|---|---|---|---|
| Confirm/allocate payment, issue credit and execute refund | Customer, wallet and ledger balances reconcile | Command outcomes and journal IDs | | |
| Reconcile wallet and transfer funds | Transfer is profit-neutral; fee posts separately | Reconciliation and journal lines | | |

## Partner

| Scenario | Expected result | Evidence required | Pass/Fail | Notes |
|---|---|---|---|---|
| Request withdrawal and obtain independent approval | Own request visible; self-approval blocked; threshold enforced | Request/approval audit chain | | |
| Approve profit distribution | Shares use snapshotted basis and total is conserved | Distribution lines and journal | | |

## Customer Service

| Scenario | Expected result | Evidence required | Pass/Fail | Notes |
|---|---|---|---|---|
| Find assigned customer/order and record a problem | Only authorized records appear; problem is auditable | Search/list screenshot and problem ID | | |
| Test narrow/mobile view | Core journey works without overlap or horizontal page scroll | Portrait screenshot | | |

## Owner Acceptance

| Scenario | Expected result | Evidence required | Pass/Fail | Notes |
|---|---|---|---|---|
| Reconcile dashboard, reports and ledger for one closed month | Signed totals match authoritative SQL/ledger evidence | Reconciliation workbook and signatures | | |
| Review backup, restore, rollback, alert and support drill | Named owners meet approved RPO/RTO and escalation targets | Drill records and approval | | |

## Required Sign-Off

UAT is complete only after Administrator, Operations, Finance, Accounting and Owner reviewers sign dated evidence, all Critical/High defects are closed, and accepted lower risks are named. This document contains no sign-off yet.
