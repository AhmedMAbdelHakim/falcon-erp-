# Database Relationship Map

The model is organization-scoped even though Phase 2 seeds one Falcon organization. UUID primary keys are used for business entities; accounting lines use UUIDs as well for uniform audit references. All financial amounts are signed or non-negative `bigint` EGP minor units as constrained by context.

```mermaid
erDiagram
  organizations ||--o{ profiles : has
  organizations ||--o{ organization_settings : configures
  profiles ||--o{ user_roles : receives
  roles ||--o{ user_roles : grants
  roles ||--o{ role_permissions : includes
  permissions ||--o{ role_permissions : maps

  organizations ||--o{ customers : serves
  customers ||--o{ orders : places
  orders ||--|{ order_items : contains
  orders ||--o{ order_status_history : records
  orders ||--o{ payment_allocations : consumes
  customer_payments ||--o{ payment_allocations : allocates
  wallets ||--o{ customer_payments : receives
  wallets ||--o{ wallet_transfers : source
  wallets ||--o{ wallet_transfers : destination

  suppliers ||--o{ print_batches : produces
  print_batches ||--|{ print_batch_items : groups
  order_items ||--o{ print_batch_items : attempts
  print_batch_items ||--o{ print_batch_receipt_items : receives
  print_batch_receipts ||--|{ print_batch_receipt_items : contains
  inventory_locations ||--o{ inventory_movements : locates
  order_items ||--o{ inventory_movements : traces

  couriers ||--o{ shipments : carries
  orders ||--o{ shipments : splits
  shipments ||--|{ shipment_items : contains
  order_items ||--o{ shipment_items : fulfills
  shipments ||--o{ returns : returns
  returns ||--|{ return_items : contains
  couriers ||--o{ courier_settlements : settles
  courier_settlements ||--|{ courier_settlement_items : reconciles

  employees ||--o{ payroll_entries : paid
  payroll_periods ||--|{ payroll_entries : contains
  partners ||--o{ partner_withdrawals : requests
  partners ||--o{ partner_distribution_lines : receives
  profit_distributions ||--|{ partner_distribution_lines : allocates

  accounting_periods ||--o{ journal_entries : permits
  journal_entries ||--|{ journal_lines : balances
  accounts ||--o{ journal_lines : classifies
  journal_entries ||--o{ posting_events : traces
  command_executions ||--o{ posting_events : caused
  approval_requests ||--o{ approval_actions : decides
  command_executions ||--o{ audit_events : audits
```

## Ownership Boundaries

- `public`: organization-filtered operational records. Direct financial writes are withheld.
- `accounting`: periods, chart of accounts, journals, posting events, close and distribution accounting records. Not exposed by Data API.
- `private`: authorization helpers, command execution, idempotency, outbox, and implementation functions. Never exposed.
- `audit`: append-only security and financial event trail. Not directly exposed.
- `api`: narrow, explicitly granted command wrappers and safe reporting access; no source-of-truth tables.

## Critical Cardinalities

- An order item can have many production attempts, shipment items, return items, and inventory movements.
- An order can have many payments through allocation rows, and a payment can be allocated across orders.
- A shipment and return are itemized, allowing partial delivery and partial return without inferring from order header state.
- One business event maps to at most one posting event for an event key, while one command may create multiple journals.
- A posted journal has at least two lines and belongs to exactly one accounting period.
