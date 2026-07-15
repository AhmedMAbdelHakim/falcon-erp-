# Requirements Catalog

Status values for later phases: `planned`, `implemented`, `verified`, `deferred`, `blocked`. All Phase 1 requirements are `planned` unless marked otherwise. Acceptance tests use the stable IDs defined in `docs/07-testing-strategy.md` and the traceability matrix.

## Business requirements

| ID | Requirement | Acceptance criterion |
|---|---|---|
| BR-ORG-001 | V1 operates for one Falcon organization in EGP and Cairo time. | Every business row belongs to the seeded Falcon organization; financial currency is EGP. |
| BR-PRT-001 | Ahmed and Maaz each own 50%. | Effective ownership rows total 10,000 bps and each partner has 5,000 bps. |
| BR-PRT-002 | Distributable profit is allocated 50/50 after close. | Approved distribution produces equal allocations using the close-date ownership snapshot. |
| BR-PRT-003 | Partner salary is separate from ownership and distributions. | Payroll posts to payroll accounts; distributions/withdrawals never post as operating expense. |
| BR-PRT-004 | Withdrawals aggregate per partner over a rolling 24 hours. | EGP 300 followed by EGP 300 requires other-partner approval on the second request. |
| BR-PRT-005 | Withdrawal types include earned profit, future-profit advance, reimbursed expense, and loan repayment. | A withdrawal cannot proceed without one supported type and its required source balance/evidence. |
| BR-PRT-006 | Safe withdrawal liquidity is evaluated before execution and execution is disabled while required liquidity settings are unset. | Command rejects unset policy, future-profit advance above cap, or withdrawal breaching cleared unrestricted cash, pending commitments, protected liabilities, reserve, or minimum capital. |
| BR-WAL-001 | Vodafone Cash named to Maaz is currently a Falcon wallet. | Seed creates accounting ownership for Falcon and legal-holder metadata for Maaz without treating funds as personal. |
| BR-WAL-002 | Falcon wallet transfers do not affect profit. | Transfer creates balanced asset-to-asset posting; fees post separately. |
| BR-WAL-003 | Physical and book wallet balances must be reconciled. | Reconciliation records statement balance, ledger balance, difference, evidence, and reviewer. |
| BR-ORD-001 | Orders support multiple independent items and models. | One order can persist mixed paid products, accessories, gifts, services, replacements, and reprints. |
| BR-ORD-002 | Supported order/payment modes include normal, Custom, prepaid, COD, exceptional, replacement, and reprint. | Valid policy/state combinations are enforced and historical policy snapshots remain unchanged. |
| BR-ORD-003 | Gifts have zero sale price and actual cost. | Gift line with nonzero quantity and missing cost cannot become deliverable. |
| BR-ORD-004 | Custom deposit is 50% of deposit-eligible paid-product lines plus all shipping. Default Custom policy marks all paid-product lines eligible; mixed exceptions are approved and snapshotted. | Required deposit is derived in minor units and each affected production line is blocked until cleared allocations cover its requirement plus order shipping requirement. |
| BR-ORD-005 | Exceptional payment policy requires reason, requester, approver, amounts, date, and evidence/note. | Approval cannot complete with any required evidence field absent or with requester self-approval. |
| BR-ORD-006 | Delivered and financially settled are separate states. | Delivery can post revenue while courier receivable remains open; settlement closes it later. |
| BR-DSC-001 | Ahmed, Maaz, and moderators may discount paid products up to 20%. | Discount above 2,000 bps is rejected unless an authorized exceptional approval exists. |
| BR-DSC-002 | Discount excludes shipping by default. | Default discount base contains paid products only; shipping requires partner-level exception. |
| BR-DSC-003 | Moderator cannot approve negative margin; approval requires complete conservative cost inputs and a fingerprint of quantities, prices, discounts, gifts, packaging, production, and shipping. | Missing/stale cost rejects approval; any material change invalidates it; printing and delivery recompute against the approved fingerprint. |
| BR-DSC-004 | iPhone 17 variants require cost-risk warning. | Discount evaluation returns a warning flag for configured iPhone 17 variants. |
| BR-PRN-001 | Printer accounting is per print batch. | Every supplier invoice item links to a received batch item/order item. |
| BR-PRN-002 | Printer payment follows receipt, QC, and finalized invoice. | Payment command rejects draft/unreceived/uninspected batches and unposted invoices. |
| BR-PRN-003 | Mixed supply methods track Falcon inventory custody and separate case/print cost. | Falcon-supplied item creates location movements and preserves case and print snapshots. |
| BR-PRN-004 | Printer prices are effective-dated with iPhone 17 exceptions. | Exactly one applicable rule is selected at batching and later edits do not change the snapshot. |
| BR-SHP-001 | Courier settlement cadence is Monday and Thursday. | Expected settlement date derives from the configured Cairo schedule; off-cycle settlements record a reason. |
| BR-SHP-002 | Expected settlement is derived from immutable contractual delivery obligations, not courier-reported collection. | Expected equals frozen COD receivable minus accrued delivery/return payables and approved deductions; reported collection/remittance remain comparison evidence. |
| BR-SHP-003 | Settlement differences require explanation, evidence, review, and approval. | Nonzero difference cannot close while any required control is absent. |
| BR-SHP-004 | Courier return fee is distinct from total business return loss. | Both values are stored/reported separately and reconcile to their underlying events. |
| BR-PAYR-001 | Salary is due day 1, payable through day 10, and overdue afterward. | Cairo-date status transitions correctly and supports partial payment. |
| BR-PAYR-002 | Net payroll equals base plus bonus and allowances minus advances and approved deductions. | Generated payroll equals the formula and rejects out-of-period/missing components. |
| BR-PAYR-003 | Moderator bonus is EGP 500-3,000; operations bonus is EGP 500-2,000. | Approved scores map to the snapshotted slab; score below 60 yields zero. |
| BR-PAYR-004 | Bonus sales exclude shipping, gifts, cancelled, returned, and undelivered orders using a documented cutoff. | Review snapshots source rows/attribution; known returns are excluded, and late returns create approved next-period adjustment rather than rewriting posted payroll. |
| BR-CLS-001 | Monthly close reconciles deposits, suppliers, courier, wallets, payroll, inventory, expenses, equity, and reserves. | Close command refuses while mandatory checklist/reconciliations or approvals are incomplete. |
| BR-CLS-002 | Closed periods reject direct financial mutation. | Insert/update/delete affecting a closed accounting date fails; approved next-period adjustment remains possible. |
| BR-CLS-003 | Profit cannot be distributed before approved close. | Distribution command requires an approved close with positive distributable balance. |
| BR-AUD-001 | Financial records are cancelled/reversed, never hard-deleted. | Direct delete is denied and a linked audit/reversal record remains queryable. |

Business requirement count: **36**.

## Functional requirements

| ID | Requirement | Acceptance criterion |
|---|---|---|
| FR-IAM-001 | Provision profiles, roles, and effective user-role assignments. | A user may hold multiple effective-dated roles; inactive/expired assignments authorize nothing. |
| FR-IAM-002 | Execute generic request/action approval workflows with separation of duties. | Required approver can approve/reject; requester cannot self-approve when SoD is required. |
| FR-CST-001 | Manage customers and multiple addresses without hard deletion. | Orders retain address snapshots after customer/address changes. |
| FR-CAT-001 | Manage products, variants, phone models, and effective supplier/shipping prices. | Historical order and shipment snapshots are unaffected by catalog/rate changes. |
| FR-ORD-001 | Create orders and independent order items with unique human-readable order numbers. | UUID is PK; unique `order_no` is generated and totals derive from lines. |
| FR-ORD-002 | Recalculate totals, deposit, paid allocation, remaining balance, cost, and margin deterministically. | Same inputs yield same minor-unit outputs and database constraints prevent inconsistent snapshots. |
| FR-ORD-003 | Transition order state through authorized commands and append status history. | Invalid transition/direct sensitive update fails and history records actor/reason/time. |
| FR-ORD-004 | Request/approve exceptional payment and negative-margin policies. | Approved exception is linked, effective, auditable, and consumed once by the command. |
| FR-PMT-001 | Record idempotent customer payments and allocate them across obligations/orders. | Allocation sum cannot exceed cleared payment or target balance; replay returns original result. |
| FR-PMT-002 | Cancel/refund payments through controlled commands and reversal postings. | Refund cannot exceed refundable amount and leaves original payment immutable. |
| FR-PRN-001 | Create, receive, QC, reprint, invoice, pay, and close print batches with multiple production attempts per order item. | Requested/sent/received/accepted/rejected/lost quantities, failed-attempt linkage, responsibility, and cost snapshots are database-enforced. |
| FR-INV-001 | Record inventory movements between Falcon, printer, packaging, courier, returns, and damage locations. | Movement balances by variant/location; no negative on-hand unless explicitly permitted and approved. |
| FR-SHP-001 | Create shipments with rate snapshots, tracking, COD, delivery/return evidence, and state history. | Delivery/return commands validate current state and required values. |
| FR-SHP-002 | Build courier settlements from eligible shipment items and reconcile expected versus actual. | A shipment item belongs to at most one non-cancelled settlement. |
| FR-WAL-001 | Manage Falcon wallets, idempotent transfers, expenses, and reconciliations. | Every posted wallet event maps to ledger lines; transfers preserve total assets excluding fee. |
| FR-ACC-001 | Post balanced journal entries only through authorized commands. | Unbalanced, duplicate, closed-period, or unauthorized posting is rejected atomically. |
| FR-ACC-002 | Reverse posted entries with full linkage and opposite lines. | Reversal totals negate original; repeated reversal is rejected. |
| FR-ACC-003 | Produce account balances and trial balance from journal lines. | Trial balance debits equal credits for any period. |
| FR-PAYR-001 | Create payroll periods/entries, performance reviews, bonus scores, accruals, and partial payments. | Accrual and payments reconcile to employee liability; sensitive access is restricted. |
| FR-PRT-001 | Manage partner capital, loans, current accounts, withdrawal approvals, and payments. | Command enforces type, available source, threshold, aggregation, SoD, and liquidity controls. |
| FR-CLS-001 | Prepare, approve, lock, and report monthly close. | Only open period can close; checklist and accounting invariants pass in one transaction. |
| FR-CLS-002 | Create approved profit distributions from a close snapshot. | Allocations equal distributable amount and ownership bps; replay is idempotent. |
| FR-AUD-001 | Store append-only audit/security/command events with correlation IDs. | Mutating/deleting audit rows is denied to application roles. |
| FR-ATT-001 | Store private receipt/evidence metadata and object references. | Access follows parent permission; object bucket is private and signed access expires. |
| FR-RPT-001 | Provide operational/financial views without creating an alternate financial truth. | Reports derive from authoritative tables/ledger and expose freshness/as-of information. |
| FR-ALT-001 | Provide deduplicated exception work queues for missing Custom deposits, unmatched payments, print/settlement delays, wallet differences, overdue payroll, score overrides, and excessive advances. | Each alert has trigger, age, severity, owner, acknowledgement, resolution evidence, escalation, and stable deduplication key. |

Functional requirement count: **26**.

## Non-functional requirements

| ID | Requirement | Acceptance criterion |
|---|---|---|
| NFR-REL-001 | Complex financial commands are atomic. | Injected failure leaves no partial operational, ledger, audit, or outbox records. |
| NFR-REL-002 | Local database can reset from zero deterministically. | One documented command applies all migrations/seeds/tests on a clean local stack. |
| NFR-PERF-001 | Common list/lookups and RLS predicates use supporting indexes. | Representative query plans avoid sequential scans on growing FK/policy paths. |
| NFR-CON-001 | Concurrent commands use row locks and version checks. | Two competing settlements/withdrawals cannot double-consume the same balance/event. |
| NFR-TIME-001 | Events use `timestamptz`; accounting/payroll periods use `date` interpreted in Cairo. | DST/timezone boundary tests produce the expected Cairo business date. |
| NFR-OBS-001 | Commands have correlation IDs and structured audit outcomes. | Failed/successful sensitive commands can be traced without recording secrets. |
| NFR-UX-001 | Future UI is Arabic, true RTL, responsive, mobile-first, and accessible. | At 320, 360, 390, 768, and desktop widths, critical order/QC/evidence/shipment/settlement/approval workflows have no page-level horizontal scroll, 44px touch targets, correct RTL numeric entry, keyboard/focus support, interruption recovery, and usable slow-network states. |
| NFR-SEC-001 | Dependencies are pinned, lockfile retained, and deprecated prereleases avoided. | Manifest has exact selected versions and audit records source/date. |
| NFR-BCK-001 | Backup/restore assumptions and smoke test are documented before production. | Staging restore can reconstruct schema and synthetic data within approved RPO/RTO. |
| NFR-MNT-001 | Migrations are small, ordered, reviewable, and forward-repairable. | Each migration has scoped tests and no applied migration is edited. |

## Security requirements

| ID | Requirement | Acceptance criterion |
|---|---|---|
| SEC-RLS-001 | Enable RLS on every exposed table. | Catalog test finds zero exposed tables with RLS disabled. |
| SEC-RLS-002 | Policies enforce organization and role/work scope, not authentication alone. | Cross-role and cross-assignment API tests return no unauthorized rows. |
| SEC-IAM-001 | Supported roles are `super_admin`, `partner`, `finance_manager`, `operations`, `moderator`, `auditor`, `read_only`. | Permission tests cover each role and deny unlisted actions. |
| SEC-IAM-002 | Authorization never trusts user-editable metadata. | No policy/function reads `raw_user_meta_data`; role changes require privileged database action. |
| SEC-SOD-001 | Requester cannot approve own controlled request. | Self-approval fails for withdrawal, negative margin, close, sensitive refund, and override. |
| SEC-RPC-001 | Sensitive state and ledger changes occur through narrowly granted RPCs. | Direct DML fails for client roles while authorized RPC succeeds. |
| SEC-RPC-002 | Privileged functions live outside exposed schemas, set safe `search_path`, and revoke `PUBLIC` execute. | Catalog review finds no callable unsafe definer function. |
| SEC-KEY-001 | Service-role/secret keys never reach browser or Git. | Secret scan and bundle scan find no privileged key; `.env` is untracked/ignored. |
| SEC-VIEW-001 | Exposed views obey invoker security or are inaccessible to API roles. | View privilege test demonstrates underlying RLS cannot be bypassed. |
| SEC-PAYR-001 | Moderators/operations cannot view payroll, partner balances, or ledger details beyond duty. | Negative RLS tests deny sensitive rows and fields. |
| SEC-AUD-001 | Auditor reads but cannot mutate operational/financial data. | Auditor DML and RPC mutation calls fail. |
| SEC-ATT-001 | Financial attachments are private and parent-authorized. | Unauthorized object/list/signed-URL requests fail. |
| SEC-EXP-001 | Sensitive export is separately permissioned and audited. | Only approved roles export; event records filter, actor, reason, and timestamp. |
| SEC-SES-001 | Sensitive commands re-evaluate current database authorization. | Revoked role cannot execute command using stale client state. |
| SEC-LOG-001 | Security events are append-only and redact secrets/PII where unnecessary. | Tamper attempts fail and log payload checks reject configured secret patterns. |

Security requirement count: **15**.

## Accounting requirements

| ID | Requirement | Acceptance criterion |
|---|---|---|
| ACC-MNY-001 | Store EGP money as `bigint` minor units; percentages as basis points. | Schema has no floating money columns and boundary arithmetic tests pass. |
| ACC-LED-001 | Every posted entry balances debit and credit. | Database rejects unbalanced post and trial balance remains zero-difference. |
| ACC-LED-002 | Posted entries are immutable and reversible once. | Direct update/delete fails; linked reversal succeeds once. |
| ACC-LED-003 | Entry carries source, accounting date, idempotency key, actor, approval, correlation, and reversal reference. | Posting fails when mandatory provenance is absent. |
| ACC-REV-001 | Revenue is recognized once on validated delivery. | Other statuses/cash receipt create no revenue; delivery replay returns original entry. |
| ACC-DEP-001 | Customer deposits are liabilities until delivery. | Receipt debits wallet and credits deposit liability; delivery consumes allocated liability. |
| ACC-AR-001 | Delivered COD creates courier receivable; other post-delivery unpaid amounts create customer receivable until collected. | Delivery and later receipts/remittance reconcile by customer/shipment. |
| ACC-AR-002 | Unallocated overpayments remain customer-credit liabilities and refunds follow an explicit liability/payable lifecycle. | Delivery never consumes more deposit than the recognized obligation; payment/refund subledger reconciles. |
| ACC-COGS-001 | Delivered items recognize snapshotted product/print/inventory cost. | COGS equals eligible delivered item costs and gifts remain included. |
| ACC-SHP-001 | Shipping revenue and courier fees are distinct gross amounts; courier fees accrue when delivery/return service occurs. | Delivery/return and settlement entries clear courier receivable/payable separately. |
| ACC-RET-001 | Valid item-level returns reverse only related recognized sale/cost and separately record evidenced losses, including cross-period adjustments. | Partial delivered return leaves unaffected items intact; pre-delivery return creates no revenue reversal. |
| ACC-AP-001 | Accepted printer receipt/QC creates GRNI; finalized invoice reclassifies to supplier AP with approved variance; payment clears AP. | Partial receipts, defects, credits, invoice variance, and payments reconcile to controls. |
| ACC-PAYR-001 | Payroll accrual and payment are separate events. | Payroll liability equals approved net less payments. |
| ACC-EXP-001 | Expenses require category, business date, payer/wallet, evidence policy, and approval state. | Posted expense has balanced entry and no direct journal edits. |
| ACC-WAL-001 | Wallet subledger reconciles to ledger account and statement. | Reconciliation difference is explicit and cannot be silently posted away. |
| ACC-PRT-001 | Partner capital, loans, current account, distributions, and withdrawals have separate accounts. | No partner withdrawal appears in P&L. |
| ACC-CLS-001 | Close calculates profit from posted ledger and locks accounting dates. | Close snapshot reconciles to trial balance and lock tests pass. |
| ACC-DST-001 | Distribution uses approved cumulative distributable profit and ownership snapshot; an indivisible minor-unit remainder remains retained. | Partner allocations plus retained remainder equal approved amount; each partner receives floor of exact 50% share. |
| ACC-RND-001 | Percentage multiplication uses integer half-up rounding except required Custom deposit rounds upward. | Positive/negative/odd-minor boundary tests match documented algorithm. |
| ACC-SNP-001 | Historical price/cost/rate/policy/rule/share snapshots are immutable. | Effective-data changes do not alter historical journal/report results. |
| ACC-IDM-001 | Each financial command is idempotent within organization/command scope. | Same key+fingerprint returns original result; same key+different fingerprint fails. |
| ACC-DEL-001 | Revenue, discount, COGS, deposit, and shipping recognition occurs per delivered shipment item and quantity. | Partial delivery recognizes only delivered quantity; all allocations remain within order snapshots. |
| ACC-CLS-002 | Close snapshots period and cumulative profit/loss, prior distributions, reserves, and retained earnings. | Loss carryforward/prior distributions prevent duplicate or excessive allocation. |

Accounting requirement count: **23**.

## Reporting requirements

| ID | Requirement | Acceptance criterion |
|---|---|---|
| RPT-LIQ-001 | Report physical/book cash, protected liabilities, minimum capital, and safe withdrawal amount. | Components reconcile to ledger/settings as of a stated time. |
| RPT-ORD-001 | Report order/item revenue, cost, shipping result, discount, gift/error cost, and margin. | Delivered/returned status and ledger values reconcile per order. |
| RPT-SHP-001 | Report courier receivable, expected/actual settlements, differences, and aging. | Sum of open shipment items equals courier control balance. |
| RPT-SUP-001 | Report print batches, supplier invoices/payments, defects, and payable aging. | Supplier detail reconciles to AP control. |
| RPT-PAYR-001 | Authorized payroll report shows accruals, bonus, advances, deductions, payments, and overdue status. | Report access and totals reconcile to payroll liability. |
| RPT-PRT-001 | Authorized partner report shows capital, loans, current account, distributions, withdrawals, and available balance. | Partner subledger reconciles to equity/liability controls. |
| RPT-CLS-001 | Close pack includes P&L, trial balance, reconciliations, exceptions, and distributable profit. | Approved close stores immutable as-of references and totals. |
| RPT-AUD-001 | Audit report traces command, approval, source record, journal entry, and reversal. | Correlation search returns a complete event chain. |

## Data requirements

| ID | Requirement | Acceptance criterion |
|---|---|---|
| DATA-ID-001 | Public business keys use UUID; display numbers are separate unique values. | No order/tracking/display number is a primary key. |
| DATA-ORG-001 | Organization-scoped uniqueness prevents cross-organization collisions. | Unique constraints include `organization_id` where appropriate. |
| DATA-TIME-001 | Event timestamps use `timestamptz`; accounting periods use `date`. | Schema/type tests pass and Cairo conversion is centralized. |
| DATA-MNY-001 | Money fields end `_minor`; rate fields end `_bps`. | Schema naming test reports no exception without ADR. |
| DATA-REF-001 | FKs have explicit names and intentional delete behavior. | No financial FK cascades to delete posted history. |
| DATA-AUD-001 | Core mutable rows have creator/updater/version metadata. | Concurrent stale update is rejected where versioned. |
| DATA-SNP-001 | Snapshots include source rule ID/version and effective date where relevant. | Historical record remains explainable after master-data changes. |
| DATA-RET-001 | Financial/audit records are retained; attachment retention is configurable. | Retention job cannot delete protected records/evidence under hold. |
| DATA-SEED-001 | Seeds use synthetic Falcon configuration and no real people/customer transactions. | Secret/PII scan of seed passes. |
| DATA-TYPE-001 | Generated TypeScript database types match migrations. | Regeneration produces no uncommitted diff after build. |

## Compliance boundaries

| ID | Boundary | Acceptance criterion |
|---|---|---|
| CMP-EGY-001 | No claim of Egyptian tax/e-invoice/legal compliance without specialist review. | Product/docs label tax/legal readiness as out of scope. |
| CMP-PCI-001 | System stores payment references/evidence, not card credentials. | Schema and logs contain no PAN/CVV fields. |
| CMP-PII-001 | Customer/employee data follows least access and export audit. | RLS/export tests cover sensitive columns. |
| CMP-PROD-001 | Production deployment and real data are outside Phase 2 without explicit approval. | No remote command/deploy is executed. |

## Future requirements

Direct Vodafone Cash/InstaPay/Fawry integration, courier API/webhooks, OCR, native mobile app, multi-tenant SaaS, Egyptian e-invoicing/tax engine, AI forecasting, bank feeds, public commerce, and customer self-service remain out of V1. Extension points are organization IDs, provider/reference fields, outbox events, private attachments, effective-dated configuration, and idempotent command interfaces.
