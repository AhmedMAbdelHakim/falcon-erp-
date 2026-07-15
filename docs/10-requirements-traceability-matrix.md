# Requirements Traceability Matrix

Phase legend: P2 backend/database, P3 UI/deployment. Owner is the accountable implementation/review role. Grouped IDs share the stated mapping; every catalog ID appears below.

## Source index

All IDs are normalized from `falcon_accounts_chat_full.md` and the mandatory controls in the Phase 1 constitution. Primary conversation ranges are:

| Requirement families | Source lines |
|---|---|
| Partners, ownership, withdrawals, distributions | 370-416, 1063-1087, 1441-1475, 1606-1668, 2314-2347 |
| Wallets, payments, deposits, refunds | 788-883, 1182-1378, 2035-2045, 2242-2259 |
| Orders, discounts, item types, state | 459-547, 1182-1378, 1952-2033, 2261-2284 |
| Printing, supplier pricing, mixed procurement, inventory | 572-664, 883-970, 2047-2106 |
| Shipping, returns, settlements | 548-570, 972-1028, 2108-2141 |
| Payroll, performance, bonuses | 1030-1061, 1380-1439, 1606-1755, 2286-2312 |
| Ledger, recognition, posting, closing | 665-709, 2143-2240, 2314-2347 |
| Roles, approvals, audit, alerts | 740-751, 1240-1251, 1460-1475, 1526-1537, 1776-1786, 2261-2284, 2349-2360 |
| Architecture/ERD and future extension points | 1853-2439 |

The Phase 1 constitution adds the stable-ID, double-entry, RLS, atomicity, idempotency, snapshot, precision, testing, and compliance-boundary requirements. Exact normalized decisions and conflicts are recorded in `docs/00-source-of-truth.md`.

## Business rules

| Requirement | Domain | Future table/function | Permission/owner | Test | Report | Phase |
|---|---|---|---|---|---|---|
| BR-ORG-001 | Foundation | `organizations`, finance settings | admin / architect | schema seed/config | all reports | P2 |
| BR-PRT-001, BR-PRT-002 | Partners/Close | `partners`, `profit_distributions`, distribute command | partner+finance / accountant | TEST-CLS-002 plus distribution invariant | RPT-PRT-001, RPT-CLS-001 | P2 |
| BR-PRT-003, BR-PRT-005 | Partners/Ledger | partner accounts/transaction type | finance / accountant | posting-map and P&L exclusion | RPT-PRT-001 | P2 |
| BR-PRT-004, BR-PRT-006 | Partners | withdrawal/approval/idempotent command | partner other-approval / security | TEST-PRT-001, TEST-PRT-002 | RPT-LIQ-001, RPT-PRT-001 | P2 |
| BR-WAL-001 | Wallets | `wallets`, account link | finance/partner / finance owner | seed/account-link | RPT-LIQ-001 | P2 |
| BR-WAL-002 | Wallets/Ledger | wallet transfer command | finance / accountant | TEST-WAL-001 | RPT-LIQ-001 | P2 |
| BR-WAL-003 | Wallets | `wallet_reconciliations` | finance+reviewer / finance owner | reconciliation suite | RPT-LIQ-001 | P2 |
| BR-ORD-001, BR-ORD-002 | Orders | `orders`, `order_items`, policy snapshots | moderator/operations / product owner | TEST-ORD-002 and schema/state tests | RPT-ORD-001 | P2 |
| BR-ORD-003 | Orders/Ledger | gift item checks, delivery COGS | operations / accountant | TEST-ORD-002 | RPT-ORD-001 | P2 |
| BR-ORD-004 | Orders/Payments | deposit calculator, print transition command | operations / product owner | TEST-ORD-001, TEST-ACC-001 | RPT-ORD-001 | P2 |
| BR-ORD-005 | Approvals | exceptional-policy request/action | partner approve / security | TEST-SOD-001 | RPT-AUD-001 | P2 |
| BR-ORD-006 | Orders/Shipping/Ledger | delivery and settlement commands | operations then finance / accountant | TEST-SHP-002 | RPT-ORD-001, RPT-SHP-001 | P2 |
| BR-DSC-001, BR-DSC-002 | Orders | discount calculator/snapshot | moderator/partner / product owner | TEST-DSC-001 | RPT-ORD-001 | P2 |
| BR-DSC-003, BR-DSC-004 | Orders/Approvals | margin evaluator, override approval | partner exception / accountant | TEST-DSC-002, snapshot warning | RPT-ORD-001, RPT-AUD-001 | P2/P3 warning |
| BR-PRN-001, BR-PRN-002 | Printing/AP | batches/invoices/payment command | operations+finance / operations owner | TEST-PRN-001 | RPT-SUP-001 | P2 |
| BR-PRN-003 | Printing/Inventory | batch items and inventory movement | operations / operations owner | mixed-supply movement tests | RPT-SUP-001, RPT-ORD-001 | P2 |
| BR-PRN-004 | Catalog/Printing | effective supplier price/snapshot | operations / finance reviewer | TEST-SNP-001 | RPT-SUP-001 | P2 |
| BR-SHP-001 | Shipping | settlement schedule settings | finance / operations owner | Cairo schedule test | RPT-SHP-001 | P2 |
| BR-SHP-002, BR-SHP-003 | Shipping | settlement/items/close command | finance+approver / finance owner | TEST-SHP-001 | RPT-SHP-001 | P2 |
| BR-SHP-004 | Returns/Ledger | return fee and loss fields/postings | operations+finance / accountant | TEST-RET-001 | RPT-SHP-001, RPT-ORD-001 | P2 |
| BR-PAYR-001, BR-PAYR-002 | Payroll | periods/entries/payment command | finance / payroll owner | TEST-PAYR-001 and formula tests | RPT-PAYR-001 | P2 |
| BR-PAYR-003, BR-PAYR-004 | Payroll/Orders | bonus rules/slabs/metrics snapshots | finance+partner approve / payroll owner | slab/exclusion tests | RPT-PAYR-001 | P2 |
| BR-CLS-001 | Close | checklist/reconciliations/close command | finance prepare, partner approve / accountant | close prerequisite suite | RPT-CLS-001 | P2 |
| BR-CLS-002 | Ledger/Close | periods and immutable guards | finance / database owner | TEST-CLS-001, TEST-CLS-002 | RPT-AUD-001 | P2 |
| BR-CLS-003 | Close/Partners | distribution command | partner approvals / accountant | distribution prerequisite | RPT-CLS-001, RPT-PRT-001 | P2 |
| BR-AUD-001 | All financial | cancel/reverse + audit | capability-specific / security | TEST-LED-002, TEST-LED-003 | RPT-AUD-001 | P2 |

## Functional requirements

| Requirement | Domain | Future table/function | Permission/owner | Test | Report | Phase |
|---|---|---|---|---|---|---|
| FR-IAM-001 | IAM | profiles/roles/user_roles | super_admin / security | role expiry/metadata/RLS | access audit | P2 |
| FR-IAM-002 | Approvals | requests/actions/consume command | role-specific / security | TEST-SOD-001 | RPT-AUD-001 | P2 |
| FR-CST-001 | Customer | customers/addresses/address snapshot | scoped staff / product | RLS/snapshot/FK | order detail | P2 |
| FR-CAT-001 | Catalog | products/variants/models/rates | operations/admin / product | TEST-SNP-001 | catalog/rate audit | P2 |
| FR-ORD-001, FR-ORD-002 | Orders | order/items/recalculate command | scoped staff / product | totals, uniqueness, money boundaries | RPT-ORD-001 | P2 |
| FR-ORD-003, FR-ORD-004 | Orders/Approvals | transition/exception commands | scoped role / security | state, TEST-SOD-001, TEST-DSC-002 | RPT-AUD-001 | P2 |
| FR-PMT-001, FR-PMT-002 | Payments | payments/allocations/refunds commands | finance / accountant | TEST-PMT-001/002, TEST-IDM-002 | deposit/receivable report | P2 |
| FR-PRN-001 | Printing | batch/QC/invoice/payment commands | operations+finance / operations | TEST-PRN-001 | RPT-SUP-001 | P2 |
| FR-INV-001 | Inventory | locations/movements | operations / operations | movement/concurrency | inventory/order cost | P2 |
| FR-SHP-001, FR-SHP-002 | Shipping | shipment/return/settlement commands | operations+finance / operations | TEST-SHP-001/002, TEST-CON-001 | RPT-SHP-001 | P2 |
| FR-WAL-001 | Wallets/Expenses | transfer/reconcile/expense commands | finance / finance | TEST-WAL-001, reconciliation | RPT-LIQ-001 | P2 |
| FR-ACC-001, FR-ACC-002 | Ledger | post/reverse commands | finance capability / accountant | TEST-LED-001/002/003 | RPT-AUD-001 | P2 |
| FR-ACC-003 | Ledger/Reporting | balances/trial view | finance/auditor / accountant | trial balance invariant | RPT-CLS-001 | P2 |
| FR-PAYR-001 | Payroll | performance/payroll/accrual/payment | finance / payroll | TEST-PAYR-001, RLS | RPT-PAYR-001 | P2 |
| FR-PRT-001 | Partners | partner accounts/withdraw command | partner+finance / partners | TEST-PRT-001/002 | RPT-PRT-001 | P2 |
| FR-CLS-001, FR-CLS-002 | Close | close/distribution commands | finance+partner / accountant | TEST-CLS-001/002 and distribution | RPT-CLS-001 | P2 |
| FR-AUD-001 | Audit | audit/security/command events | append-only / security | audit tamper/trace | RPT-AUD-001 | P2 |
| FR-ATT-001 | Attachments | metadata + private Storage | parent-scoped / security | attachment RLS/object tests | evidence listing | P2 |
| FR-RPT-001 | Reporting | invoker views/report RPCs | role-scoped / reporting | reconciliation/view bypass | all RPT IDs | P2 |
| FR-ALT-001 | Operations/Reporting | exception events/work-queue view | role-scoped owner / operations | TEST-ALT-001 | exception queue | P2/P3 UI |

## Security requirements

| Requirement | Domain/control | Permission/owner | Test | Phase |
|---|---|---|---|---|
| SEC-RLS-001, SEC-RLS-002 | RLS/grants/policy indexes | security/database | TEST-SEC-001, TEST-RLS-002 | P2 |
| SEC-IAM-001 | role/permission seed and assignments | super_admin / security | role matrix suite | P2 |
| SEC-IAM-002 | database authorization helpers | security | metadata-abuse scan/test | P2 |
| SEC-SOD-001 | approval constraints/consume checks | approver / security | TEST-SOD-001 | P2 |
| SEC-RPC-001, SEC-RPC-002 | private command functions and grants | database/security | direct DML, definer catalog, TEST-SEC-001 | P2 |
| SEC-KEY-001 | env/Git/bundle/secret store | security | secret and bundle scan | P2 production gate |
| SEC-VIEW-001 | invoker/private reports | reporting/security | view RLS bypass | P2 |
| SEC-PAYR-001 | restricted payroll/partner projections | finance/security | TEST-RLS-001 | P2 |
| SEC-AUD-001 | auditor read-only grants | security | auditor DML negative | P2 |
| SEC-ATT-001 | private bucket/parent policy | security | Storage positive/negative | P2 |
| SEC-EXP-001 | export RPC/event | partner/finance/auditor / security | export permission/audit | P2/P3 |
| SEC-SES-001 | current assignment/session checks | security | TEST-RLS-003 | P2 |
| SEC-LOG-001 | append-only redacted security events | security | tamper/secret payload | P2 |

## Accounting requirements

| Requirement | Domain/table/function | Permission/owner | Test | Report | Phase |
|---|---|---|---|---|---|
| ACC-MNY-001, ACC-RND-001 | money/rate types and helpers | database/accountant | boundary/property tests | all financial | P2 |
| ACC-LED-001, ACC-LED-003 | entries/lines/post command | finance / accountant | TEST-LED-001 and provenance | RPT-CLS-001 | P2 |
| ACC-LED-002 | immutable/reverse command | finance+approver / accountant | TEST-LED-002/003 | RPT-AUD-001 | P2 |
| ACC-REV-001 | delivery posting purpose | operations command / accountant | TEST-ACC-002, TEST-IDM-001 | RPT-ORD-001 | P2 |
| ACC-DEP-001 | payment/deposit control | finance / accountant | TEST-ACC-001 | deposit/liquidity | P2 |
| ACC-AR-001, ACC-AR-002 | payment/deposit/customer AR-credit postings | finance / accountant | TEST-AR-001/002 | RPT-LIQ-001, RPT-ORD-001 | P2 |
| ACC-SHP-001 | shipment/courier AR-payable accrual and settlement | operations+finance / accountant | TEST-SHP-002 | RPT-SHP-001 | P2 |
| ACC-COGS-001 | delivery item-cost posting | operations command / accountant | TEST-ORD-002, TEST-SNP-001 | RPT-ORD-001 | P2 |
| ACC-RET-001 | item return/reversal/loss posting | operations+finance / accountant | TEST-RET-001/002/003 | RPT-ORD-001, RPT-SHP-001 | P2 |
| ACC-AP-001 | receipt GRNI, supplier invoice/variance/payment control | finance / accountant | TEST-GRNI-001, TEST-PRN-001 | RPT-SUP-001 | P2 |
| ACC-PAYR-001 | payroll accrual/payment | finance / accountant | TEST-PAYR-001 | RPT-PAYR-001 | P2 |
| ACC-EXP-001 | expense post command | finance / accountant | approval/posting tests | close/P&L | P2 |
| ACC-WAL-001 | wallet ledger/reconciliation | finance / accountant | TEST-WAL-001 and reconciliation | RPT-LIQ-001 | P2 |
| ACC-PRT-001 | partner account postings | partner+finance / accountant | TEST-PRT-001 and P&L exclusion | RPT-PRT-001 | P2 |
| ACC-CLS-001, ACC-CLS-002, ACC-DST-001 | close/distribution | finance+partner / accountant | TEST-CLS-001/002, TEST-DST-001 | RPT-CLS-001 | P2 |
| ACC-DEL-001 | shipment-item delivery allocation/posting | operations / accountant | TEST-DEL-001/002 | RPT-ORD-001 | P2 |
| ACC-SNP-001 | snapshots across domains | domain owner / accountant | TEST-SNP-001 | order/payroll/partner | P2 |
| ACC-IDM-001 | command executions/source uniqueness | command role / database | TEST-IDM-001/002 | RPT-AUD-001 | P2 |

## NFR, reporting, data, and compliance

| Requirement | Implementation/owner | Test/evidence | Phase |
|---|---|---|---|
| NFR-REL-001 | transactional RPCs / database | TEST-ATX-001 | P2 |
| NFR-REL-002 | CLI config/migrations/seed / database | clean reset transcript | P2 |
| NFR-PERF-001 | FK/RLS/query indexes / database | query-plan/advisor review | P2 |
| NFR-CON-001 | row locks/versions/unique constraints / database | TEST-CON-001, TEST-PRT-002 | P2 |
| NFR-TIME-001 | timestamptz/date/Cairo helper / database | timezone boundary tests | P2 |
| NFR-OBS-001 | correlation/audit/outbox / security | trace completeness | P2 |
| NFR-UX-001 | Arabic RTL mobile accessible UI / product | E2E/accessibility/viewport | P3 |
| NFR-SEC-001 | exact dependencies/lock/version audit / security | manifest/audit | P2 |
| NFR-BCK-001 | backup/restore plan / DBA | restore smoke | P2 staging gate |
| NFR-MNT-001 | immutable scoped migrations / database | migration review/reset | P2 |
| RPT-LIQ-001, RPT-ORD-001 | ledger/subledger report views / reporting | reconciliation + role tests | P2/P3 UI |
| RPT-SHP-001, RPT-SUP-001 | settlement/AP views / reporting | control-account reconciliation | P2/P3 UI |
| RPT-PAYR-001, RPT-PRT-001 | restricted report RPCs / reporting+security | RLS/export tests | P2/P3 UI |
| RPT-CLS-001, RPT-AUD-001 | close/audit views / accountant+auditor | trial/trace tests | P2/P3 UI |
| DATA-ID-001, DATA-ORG-001 | UUID/scoped unique constraints / database | schema tests | P2 |
| DATA-TIME-001, DATA-MNY-001 | column types/naming / database | schema conventions | P2 |
| DATA-REF-001, DATA-AUD-001 | FKs/delete/version metadata / database | catalog/concurrency tests | P2 |
| DATA-SNP-001, DATA-RET-001 | immutable snapshots/retention / domain+security | TEST-SNP-001, deletion tests | P2 |
| DATA-SEED-001, DATA-TYPE-001 | synthetic seed/generated types / database+frontend | secret scan/type no-diff | P2 |
| CMP-EGY-001 | compliance disclaimer/sign-off / product/legal | release document review | P3 production gate |
| CMP-PCI-001 | no card credential model / security | schema/log scan | P2 |
| CMP-PII-001 | RLS/export audit / security | role/export tests | P2 |
| CMP-PROD-001 | no remote/deploy without approval / release owner | command/change review | P2 |
