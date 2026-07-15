-- Orders, payments, customer credits, refunds, and Falcon wallet operations.
-- Cross-row financial conservation and state transitions are enforced by later
-- transactional command RPCs; this migration establishes row-local invariants.
-- Evidence attachment UUIDs are intentionally soft references until the later
-- attachment/storage metadata migration creates public.attachments.

create table public.orders (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  order_number text not null,
  customer_id uuid not null references public.customers(id),
  customer_address_id uuid references public.customer_addresses(id),
  assigned_moderator_id uuid references public.profiles(id),
  created_by uuid not null references public.profiles(id),
  order_source text not null,
  order_type text not null,
  status public.order_status not null default 'new',
  payment_status public.payment_status not null default 'no_payment',
  currency character(3) not null default 'EGP',
  shipping_recipient_name_snapshot text,
  shipping_phone_snapshot text,
  shipping_address_snapshot jsonb,
  payment_policy_code_snapshot text,
  payment_policy_version_snapshot text,
  deposit_bps_snapshot integer,
  shipping_prepaid_required_snapshot boolean,
  products_subtotal_minor bigint not null default 0,
  discount_total_minor bigint not null default 0,
  shipping_charge_minor bigint not null default 0,
  order_total_minor bigint not null default 0,
  required_deposit_minor bigint not null default 0,
  confirmed_payment_minor bigint not null default 0,
  balance_due_minor bigint not null default 0,
  expected_cost_minor bigint not null default 0,
  actual_cost_minor bigint not null default 0,
  expected_margin_minor bigint not null default 0,
  actual_margin_minor bigint not null default 0,
  terms_frozen_at timestamptz,
  confirmed_at timestamptz,
  delivered_at timestamptz,
  financially_settled_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  version bigint not null default 0,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint orders_organization_id_id_key unique (organization_id, id),
  constraint orders_organization_id_customer_key unique (organization_id, id, customer_id),
  constraint orders_organization_order_number_key unique (organization_id, order_number),
  constraint orders_order_number_not_blank_check check (btrim(order_number) <> ''),
  constraint orders_order_source_not_blank_check check (btrim(order_source) <> ''),
  constraint orders_order_type_check check (order_type in ('custom', 'ready_stock', 'replacement', 'reprint', 'other')),
  constraint orders_currency_check check (currency = 'EGP'),
  constraint orders_shipping_address_object_check check (
    shipping_address_snapshot is null or jsonb_typeof(shipping_address_snapshot) = 'object'
  ),
  constraint orders_deposit_bps_check check (deposit_bps_snapshot is null or deposit_bps_snapshot between 0 and 10000),
  constraint orders_amounts_nonnegative_check check (
    products_subtotal_minor >= 0
    and discount_total_minor >= 0
    and shipping_charge_minor >= 0
    and order_total_minor >= 0
    and required_deposit_minor >= 0
    and confirmed_payment_minor >= 0
    and balance_due_minor >= 0
    and expected_cost_minor >= 0
    and actual_cost_minor >= 0
  ),
  constraint orders_discount_within_subtotal_check check (discount_total_minor <= products_subtotal_minor),
  constraint orders_total_projection_check check (
    order_total_minor = products_subtotal_minor - discount_total_minor + shipping_charge_minor
  ),
  constraint orders_required_deposit_within_total_check check (required_deposit_minor <= order_total_minor),
  constraint orders_version_nonnegative_check check (version >= 0),
  constraint orders_cancel_metadata_check check (
    (cancelled_at is null and cancellation_reason is null)
    or (cancelled_at is not null and nullif(btrim(cancellation_reason), '') is not null)
  ),
  constraint orders_timestamp_order_check check (
    (confirmed_at is null or confirmed_at >= created_at)
    and (delivered_at is null or delivered_at >= created_at)
    and (financially_settled_at is null or financially_settled_at >= created_at)
    and (cancelled_at is null or cancelled_at >= created_at)
  )
);

comment on table public.orders is 'Order aggregate header. Monetary totals are command-maintained projections; items, allocations, payments, shipments, and ledger rows remain authoritative.';
comment on column public.orders.shipping_address_snapshot is 'Frozen delivery address payload used after confirmation; the mutable customer address is only its source.';
comment on column public.orders.payment_policy_code_snapshot is 'Frozen contractual payment policy selected for this order.';
comment on column public.orders.products_subtotal_minor is 'Cached gross product and service subtotal in EGP minor units before discount.';
comment on column public.orders.confirmed_payment_minor is 'Cached sum of confirmed allocations, never authority for payment eligibility.';
comment on column public.orders.balance_due_minor is 'Cached contractual balance; delivery commands derive settlement obligations from frozen item and allocation rows.';

create index orders_customer_id_idx on public.orders (customer_id);
create index orders_customer_address_id_idx on public.orders (customer_address_id) where customer_address_id is not null;
create index orders_assigned_moderator_id_idx on public.orders (assigned_moderator_id) where assigned_moderator_id is not null;
create index orders_created_by_idx on public.orders (created_by);
create index orders_organization_status_idx on public.orders (organization_id, status, created_at desc);
create index orders_organization_payment_status_idx on public.orders (organization_id, payment_status, created_at desc);

create table public.order_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  order_id uuid not null,
  line_number integer not null,
  product_id uuid references public.products(id),
  product_variant_id uuid references public.product_variants(id),
  phone_model_id uuid references public.phone_models(id),
  original_order_item_id uuid,
  item_type public.item_type not null,
  supply_method public.supply_method not null,
  fulfillment_status public.fulfillment_status not null default 'draft',
  costing_status text not null default 'estimated',
  quantity integer not null,
  currency character(3) not null default 'EGP',
  sku_snapshot text,
  item_name_snapshot text not null,
  phone_model_snapshot text,
  unit_sale_price_minor bigint not null,
  unit_expected_cost_minor bigint not null,
  line_gross_minor bigint not null,
  line_discount_minor bigint not null default 0,
  line_revenue_minor bigint not null,
  actual_cost_minor bigint not null default 0,
  custom_design_required boolean not null default false,
  printing_required boolean not null default false,
  price_source_snapshot jsonb not null default '{}'::jsonb,
  cost_source_snapshot jsonb not null default '{}'::jsonb,
  terms_frozen_at timestamptz,
  version bigint not null default 0,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint order_items_organization_id_id_key unique (organization_id, id),
  constraint order_items_organization_order_id_key unique (organization_id, order_id, id),
  constraint order_items_order_line_key unique (organization_id, order_id, line_number),
  constraint order_items_order_fk foreign key (organization_id, order_id)
    references public.orders(organization_id, id),
  constraint order_items_original_item_fk foreign key (organization_id, original_order_item_id)
    references public.order_items(organization_id, id),
  constraint order_items_line_number_positive_check check (line_number > 0),
  constraint order_items_quantity_positive_check check (quantity > 0),
  constraint order_items_currency_check check (currency = 'EGP'),
  constraint order_items_name_not_blank_check check (btrim(item_name_snapshot) <> ''),
  constraint order_items_costing_status_check check (costing_status in ('estimated', 'frozen', 'actual_partial', 'actual_complete', 'variance_review')),
  constraint order_items_amounts_nonnegative_check check (
    unit_sale_price_minor >= 0
    and unit_expected_cost_minor >= 0
    and line_gross_minor >= 0
    and line_discount_minor >= 0
    and line_revenue_minor >= 0
    and actual_cost_minor >= 0
  ),
  constraint order_items_gross_projection_check check (line_gross_minor = unit_sale_price_minor * quantity::bigint),
  constraint order_items_discount_within_gross_check check (line_discount_minor <= line_gross_minor),
  constraint order_items_revenue_projection_check check (line_revenue_minor = line_gross_minor - line_discount_minor),
  constraint order_items_gift_price_check check (item_type <> 'gift' or unit_sale_price_minor = 0),
  constraint order_items_replacement_origin_check check (
    item_type not in ('replacement', 'free_reprint', 'paid_reprint') or original_order_item_id is not null
  ),
  constraint order_items_snapshot_object_check check (
    jsonb_typeof(price_source_snapshot) = 'object' and jsonb_typeof(cost_source_snapshot) = 'object'
  ),
  constraint order_items_version_nonnegative_check check (version >= 0)
);

comment on table public.order_items is 'Independent order lines with frozen sale, expected cost, supply method, product, and phone model terms.';
comment on column public.order_items.unit_sale_price_minor is 'Contractual unit sale price snapshot in EGP minor units.';
comment on column public.order_items.unit_expected_cost_minor is 'Expected unit cost snapshot fixed by the applicable cost source; actual cost is accumulated separately.';
comment on column public.order_items.actual_cost_minor is 'Command-maintained cumulative actual direct cost projection; immutable source events remain authoritative.';

create index order_items_order_id_idx on public.order_items (order_id);
create index order_items_product_id_idx on public.order_items (product_id) where product_id is not null;
create index order_items_product_variant_id_idx on public.order_items (product_variant_id) where product_variant_id is not null;
create index order_items_phone_model_id_idx on public.order_items (phone_model_id) where phone_model_id is not null;
create index order_items_original_order_item_id_idx on public.order_items (original_order_item_id) where original_order_item_id is not null;
create index order_items_organization_fulfillment_idx on public.order_items (organization_id, fulfillment_status);

create table public.order_status_history (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  order_id uuid not null,
  previous_status public.order_status,
  new_status public.order_status not null,
  order_version bigint not null,
  changed_by uuid not null references public.profiles(id),
  reason text,
  correlation_id uuid not null,
  occurred_at timestamptz not null default statement_timestamp(),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint order_status_history_organization_id_id_key unique (organization_id, id),
  constraint order_status_history_order_fk foreign key (organization_id, order_id)
    references public.orders(organization_id, id),
  constraint order_status_history_version_nonnegative_check check (order_version >= 0),
  constraint order_status_history_transition_check check (previous_status is null or previous_status <> new_status),
  constraint order_status_history_order_version_key unique (organization_id, order_id, order_version)
);

comment on table public.order_status_history is 'Append-only evidence of order state transitions; sensitive transitions are written only by later command RPCs.';

create index order_status_history_order_id_idx on public.order_status_history (order_id, occurred_at);
create index order_status_history_changed_by_idx on public.order_status_history (changed_by);
create index order_status_history_correlation_id_idx on public.order_status_history (correlation_id);

create table public.order_exceptions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  order_id uuid not null,
  exception_type text not null,
  status text not null default 'requested',
  requested_value jsonb not null,
  baseline_value jsonb not null default '{}'::jsonb,
  subject_fingerprint text not null,
  reason text not null,
  requested_by uuid not null references public.profiles(id),
  approval_request_id uuid references public.approval_requests(id),
  decided_by uuid references public.profiles(id),
  requested_at timestamptz not null default statement_timestamp(),
  decided_at timestamptz,
  expires_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint order_exceptions_organization_id_id_key unique (organization_id, id),
  constraint order_exceptions_order_fk foreign key (organization_id, order_id)
    references public.orders(organization_id, id),
  constraint order_exceptions_type_check check (
    exception_type in ('payment_policy', 'deposit', 'discount', 'negative_margin', 'price', 'cost', 'shipping', 'cancellation', 'other')
  ),
  constraint order_exceptions_status_check check (status in ('requested', 'approved', 'rejected', 'expired', 'cancelled', 'consumed')),
  constraint order_exceptions_requested_object_check check (jsonb_typeof(requested_value) = 'object'),
  constraint order_exceptions_baseline_object_check check (jsonb_typeof(baseline_value) = 'object'),
  constraint order_exceptions_reason_not_blank_check check (btrim(reason) <> ''),
  constraint order_exceptions_fingerprint_not_blank_check check (btrim(subject_fingerprint) <> ''),
  constraint order_exceptions_decision_metadata_check check (
    (status in ('requested', 'expired', 'cancelled') and decided_at is null)
    or (status in ('approved', 'rejected', 'consumed') and decided_by is not null and decided_at is not null)
  ),
  constraint order_exceptions_expiry_check check (expires_at is null or expires_at > requested_at),
  constraint order_exceptions_consumed_check check ((status = 'consumed') = (consumed_at is not null))
);

comment on table public.order_exceptions is 'Order-scoped exceptional terms bound to an approval subject fingerprint and one-time consumption lifecycle.';

create index order_exceptions_order_id_idx on public.order_exceptions (order_id);
create index order_exceptions_requested_by_idx on public.order_exceptions (requested_by);
create index order_exceptions_approval_request_id_idx on public.order_exceptions (approval_request_id) where approval_request_id is not null;
create index order_exceptions_decided_by_idx on public.order_exceptions (decided_by) where decided_by is not null;
create index order_exceptions_organization_status_idx on public.order_exceptions (organization_id, status, requested_at desc);

create table public.order_discounts (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  order_id uuid not null,
  discount_type text not null,
  source text not null,
  discount_bps integer,
  amount_minor bigint not null,
  eligible_base_minor bigint not null,
  includes_shipping boolean not null default false,
  expected_cost_snapshot_minor bigint not null,
  expected_margin_after_discount_minor bigint not null,
  allocation_method text not null default 'largest_remainder',
  allocation_fingerprint text not null,
  approval_request_id uuid references public.approval_requests(id),
  granted_by uuid not null references public.profiles(id),
  reason text,
  frozen_at timestamptz not null default statement_timestamp(),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint order_discounts_organization_id_id_key unique (organization_id, id),
  constraint order_discounts_organization_order_id_key unique (organization_id, id, order_id),
  constraint order_discounts_order_fk foreign key (organization_id, order_id)
    references public.orders(organization_id, id),
  constraint order_discounts_type_check check (discount_type in ('percentage', 'fixed_amount', 'manual_adjustment')),
  constraint order_discounts_source_check check (source in ('moderator', 'partner_approved', 'campaign', 'correction')),
  constraint order_discounts_bps_check check (discount_bps is null or discount_bps between 0 and 10000),
  constraint order_discounts_amount_check check (amount_minor > 0 and amount_minor <= eligible_base_minor),
  constraint order_discounts_cost_nonnegative_check check (expected_cost_snapshot_minor >= 0),
  constraint order_discounts_allocation_method_check check (allocation_method = 'largest_remainder'),
  constraint order_discounts_fingerprint_not_blank_check check (btrim(allocation_fingerprint) <> ''),
  constraint order_discounts_percentage_value_check check (
    (discount_type = 'percentage' and discount_bps is not null)
    or discount_type <> 'percentage'
  )
);

comment on table public.order_discounts is 'Frozen granted discount, cost completeness, margin result, approval, and deterministic allocation basis.';

create index order_discounts_order_id_idx on public.order_discounts (order_id);
create index order_discounts_approval_request_id_idx on public.order_discounts (approval_request_id) where approval_request_id is not null;
create index order_discounts_granted_by_idx on public.order_discounts (granted_by);

create table public.order_discount_allocations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  order_discount_id uuid not null,
  order_id uuid not null,
  order_item_id uuid,
  allocation_target text not null,
  allocation_base_minor bigint not null,
  allocated_amount_minor bigint not null,
  remainder_rank integer not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint order_discount_allocations_organization_id_id_key unique (organization_id, id),
  constraint order_discount_allocations_discount_fk foreign key (organization_id, order_discount_id, order_id)
    references public.order_discounts(organization_id, id, order_id),
  constraint order_discount_allocations_order_fk foreign key (organization_id, order_id)
    references public.orders(organization_id, id),
  constraint order_discount_allocations_item_fk foreign key (organization_id, order_id, order_item_id)
    references public.order_items(organization_id, order_id, id),
  constraint order_discount_allocations_target_check check (allocation_target in ('order_item', 'shipping')),
  constraint order_discount_allocations_target_item_check check (
    (allocation_target = 'order_item' and order_item_id is not null)
    or (allocation_target = 'shipping' and order_item_id is null)
  ),
  constraint order_discount_allocations_amount_check check (
    allocation_base_minor >= 0 and allocated_amount_minor >= 0 and allocated_amount_minor <= allocation_base_minor
  ),
  constraint order_discount_allocations_rank_check check (remainder_rank >= 0)
);

comment on table public.order_discount_allocations is 'Largest-remainder allocation of a frozen order discount to item or shipping contractual units.';

create unique index order_discount_allocations_item_key
  on public.order_discount_allocations (organization_id, order_discount_id, order_item_id)
  where allocation_target = 'order_item';
create unique index order_discount_allocations_shipping_key
  on public.order_discount_allocations (organization_id, order_discount_id)
  where allocation_target = 'shipping';
create index order_discount_allocations_discount_id_idx on public.order_discount_allocations (order_discount_id);
create index order_discount_allocations_order_id_idx on public.order_discount_allocations (order_id);
create index order_discount_allocations_order_item_id_idx on public.order_discount_allocations (order_item_id) where order_item_id is not null;

create table public.order_problems (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  order_id uuid not null,
  order_item_id uuid,
  problem_type text not null,
  severity text not null default 'medium',
  status text not null default 'open',
  responsibility text,
  summary text not null,
  details text,
  reported_by uuid not null references public.profiles(id),
  assigned_to uuid references public.profiles(id),
  evidence_attachment_id uuid,
  opened_at timestamptz not null default statement_timestamp(),
  resolved_at timestamptz,
  resolution text,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint order_problems_organization_id_id_key unique (organization_id, id),
  constraint order_problems_organization_order_id_key unique (organization_id, id, order_id),
  constraint order_problems_order_fk foreign key (organization_id, order_id)
    references public.orders(organization_id, id),
  constraint order_problems_item_fk foreign key (organization_id, order_id, order_item_id)
    references public.order_items(organization_id, order_id, id),
  constraint order_problems_type_not_blank_check check (btrim(problem_type) <> ''),
  constraint order_problems_severity_check check (severity in ('low', 'medium', 'high', 'critical')),
  constraint order_problems_status_check check (status in ('open', 'investigating', 'awaiting_external', 'resolved', 'cancelled')),
  constraint order_problems_summary_not_blank_check check (btrim(summary) <> ''),
  constraint order_problems_resolution_check check (
    (status = 'resolved' and resolved_at is not null and nullif(btrim(resolution), '') is not null)
    or status <> 'resolved'
  )
);

comment on table public.order_problems is 'Operational order or item issue, responsibility, evidence, and resolution lifecycle.';

create index order_problems_order_id_idx on public.order_problems (order_id);
create index order_problems_order_item_id_idx on public.order_problems (order_item_id) where order_item_id is not null;
create index order_problems_reported_by_idx on public.order_problems (reported_by);
create index order_problems_assigned_to_idx on public.order_problems (assigned_to) where assigned_to is not null;
create index order_problems_evidence_attachment_id_idx on public.order_problems (evidence_attachment_id) where evidence_attachment_id is not null;
create index order_problems_organization_status_idx on public.order_problems (organization_id, status, severity);

create table public.order_problem_costs (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  order_problem_id uuid not null,
  order_id uuid not null,
  order_item_id uuid,
  cost_type text not null,
  amount_minor bigint not null,
  currency character(3) not null default 'EGP',
  responsibility text,
  recoverable boolean not null default false,
  approved boolean not null default false,
  approval_request_id uuid references public.approval_requests(id),
  evidence_attachment_id uuid,
  incurred_at timestamptz not null,
  reason text not null,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint order_problem_costs_organization_id_id_key unique (organization_id, id),
  constraint order_problem_costs_problem_fk foreign key (organization_id, order_problem_id, order_id)
    references public.order_problems(organization_id, id, order_id),
  constraint order_problem_costs_order_fk foreign key (organization_id, order_id)
    references public.orders(organization_id, id),
  constraint order_problem_costs_item_fk foreign key (organization_id, order_id, order_item_id)
    references public.order_items(organization_id, order_id, id),
  constraint order_problem_costs_type_check check (cost_type in ('courier', 'packaging', 'damage', 'rework', 'replacement', 'refund', 'other')),
  constraint order_problem_costs_amount_positive_check check (amount_minor > 0),
  constraint order_problem_costs_currency_check check (currency = 'EGP'),
  constraint order_problem_costs_reason_not_blank_check check (btrim(reason) <> ''),
  constraint order_problem_costs_approval_check check (not approved or approval_request_id is not null)
);

comment on table public.order_problem_costs is 'Explicit business-loss components linked to an order problem; courier return fee remains separate from broader loss.';

create index order_problem_costs_problem_id_idx on public.order_problem_costs (order_problem_id);
create index order_problem_costs_order_id_idx on public.order_problem_costs (order_id);
create index order_problem_costs_order_item_id_idx on public.order_problem_costs (order_item_id) where order_item_id is not null;
create index order_problem_costs_approval_request_id_idx on public.order_problem_costs (approval_request_id) where approval_request_id is not null;
create index order_problem_costs_evidence_attachment_id_idx on public.order_problem_costs (evidence_attachment_id) where evidence_attachment_id is not null;
create index order_problem_costs_created_by_idx on public.order_problem_costs (created_by);

create table public.wallets (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  code text not null,
  name text not null,
  provider text not null,
  wallet_type text not null,
  registered_owner_name text not null,
  registered_owner_profile_id uuid references public.profiles(id),
  economic_owner_name text not null default 'Falcon',
  external_identifier_last4 text,
  currency character(3) not null default 'EGP',
  is_active boolean not null default true,
  opened_at timestamptz,
  closed_at timestamptz,
  notes text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint wallets_organization_id_id_key unique (organization_id, id),
  constraint wallets_organization_code_key unique (organization_id, code),
  constraint wallets_code_not_blank_check check (btrim(code) <> ''),
  constraint wallets_name_not_blank_check check (btrim(name) <> ''),
  constraint wallets_provider_not_blank_check check (btrim(provider) <> ''),
  constraint wallets_type_check check (wallet_type in ('personal_wallet_dedicated_to_business', 'business_wallet', 'bank_account', 'cash', 'clearing')),
  constraint wallets_registered_owner_not_blank_check check (btrim(registered_owner_name) <> ''),
  constraint wallets_economic_owner_not_blank_check check (btrim(economic_owner_name) <> ''),
  constraint wallets_identifier_last4_check check (external_identifier_last4 is null or external_identifier_last4 ~ '^[0-9A-Za-z]{4}$'),
  constraint wallets_currency_check check (currency = 'EGP'),
  constraint wallets_close_state_check check (
    (is_active and closed_at is null) or (not is_active and closed_at is not null)
  ),
  constraint wallets_date_order_check check (closed_at is null or opened_at is null or closed_at >= opened_at)
);

comment on table public.wallets is 'Falcon-controlled economic wallets. No opening or current balance is stored here; reconciled ledger movements are authoritative.';
comment on column public.wallets.registered_owner_name is 'Sensitive legal registration snapshot; economic ownership remains independently recorded.';

create index wallets_registered_owner_profile_id_idx on public.wallets (registered_owner_profile_id) where registered_owner_profile_id is not null;
create index wallets_created_by_idx on public.wallets (created_by) where created_by is not null;
create index wallets_organization_active_idx on public.wallets (organization_id, is_active);

create table public.customer_payments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  customer_id uuid not null references public.customers(id),
  primary_order_id uuid,
  wallet_id uuid not null,
  amount_minor bigint not null,
  currency character(3) not null default 'EGP',
  payment_method text not null,
  external_transaction_reference text,
  provider_name_snapshot text,
  paid_at timestamptz not null,
  recorded_by uuid not null references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  evidence_attachment_id uuid,
  status public.payment_review_status not null default 'pending_review',
  idempotency_key text not null,
  request_fingerprint text not null,
  correlation_id uuid not null,
  review_reason text,
  reviewed_at timestamptz,
  confirmed_at timestamptz,
  rejected_at timestamptz,
  reversed_at timestamptz,
  reversal_payment_id uuid,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint customer_payments_organization_id_id_key unique (organization_id, id),
  constraint customer_payments_organization_customer_id_key unique (organization_id, id, customer_id),
  constraint customer_payments_idempotency_key unique (organization_id, idempotency_key),
  constraint customer_payments_order_fk foreign key (organization_id, primary_order_id, customer_id)
    references public.orders(organization_id, id, customer_id),
  constraint customer_payments_wallet_fk foreign key (organization_id, wallet_id)
    references public.wallets(organization_id, id),
  constraint customer_payments_reversal_fk foreign key (organization_id, reversal_payment_id)
    references public.customer_payments(organization_id, id),
  constraint customer_payments_amount_positive_check check (amount_minor > 0),
  constraint customer_payments_currency_check check (currency = 'EGP'),
  constraint customer_payments_method_check check (payment_method in ('wallet', 'instapay', 'fawry', 'cash', 'bank_transfer', 'courier_cod', 'other')),
  constraint customer_payments_idempotency_not_blank_check check (btrim(idempotency_key) <> ''),
  constraint customer_payments_fingerprint_not_blank_check check (btrim(request_fingerprint) <> ''),
  constraint customer_payments_external_reference_check check (
    payment_method in ('cash', 'courier_cod') or nullif(btrim(external_transaction_reference), '') is not null
  ),
  constraint customer_payments_review_metadata_check check (
    (status = 'pending_review' and reviewed_at is null and reviewed_by is null)
    or (status <> 'pending_review' and reviewed_at is not null and reviewed_by is not null)
  ),
  constraint customer_payments_status_timestamp_check check (
    (status in ('confirmed', 'reversed')) = (confirmed_at is not null)
    and (status = 'rejected') = (rejected_at is not null)
    and (status = 'reversed') = (reversed_at is not null)
  ),
  constraint customer_payments_reversal_check check (
    (status = 'reversed' and reversal_payment_id is not null) or status <> 'reversed'
  )
);

comment on table public.customer_payments is 'Customer receipt evidence and review lifecycle. Only confirmed receipts may be allocated or posted by later commands.';
comment on column public.customer_payments.amount_minor is 'Gross received amount in EGP minor units; allocation does not alter this immutable contractual amount.';

create unique index customer_payments_external_reference_key
  on public.customer_payments (organization_id, wallet_id, external_transaction_reference)
  where external_transaction_reference is not null and status <> 'rejected';
create index customer_payments_customer_id_idx on public.customer_payments (customer_id);
create index customer_payments_primary_order_id_idx on public.customer_payments (primary_order_id) where primary_order_id is not null;
create index customer_payments_wallet_id_idx on public.customer_payments (wallet_id);
create index customer_payments_recorded_by_idx on public.customer_payments (recorded_by);
create index customer_payments_reviewed_by_idx on public.customer_payments (reviewed_by) where reviewed_by is not null;
create index customer_payments_evidence_attachment_id_idx on public.customer_payments (evidence_attachment_id) where evidence_attachment_id is not null;
create index customer_payments_reversal_payment_id_idx on public.customer_payments (reversal_payment_id) where reversal_payment_id is not null;
create index customer_payments_organization_status_paid_idx on public.customer_payments (organization_id, status, paid_at desc);
create index customer_payments_correlation_id_idx on public.customer_payments (correlation_id);

create table public.customer_credits (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  customer_id uuid not null references public.customers(id),
  source_payment_id uuid,
  currency character(3) not null default 'EGP',
  original_amount_minor bigint not null,
  remaining_amount_minor bigint not null,
  status text not null default 'available',
  reason text not null,
  expires_at timestamptz,
  closed_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint customer_credits_organization_id_id_key unique (organization_id, id),
  constraint customer_credits_organization_customer_id_key unique (organization_id, id, customer_id),
  constraint customer_credits_source_payment_key unique (organization_id, source_payment_id),
  constraint customer_credits_source_payment_fk foreign key (organization_id, source_payment_id, customer_id)
    references public.customer_payments(organization_id, id, customer_id),
  constraint customer_credits_currency_check check (currency = 'EGP'),
  constraint customer_credits_amount_check check (
    original_amount_minor > 0 and remaining_amount_minor between 0 and original_amount_minor
  ),
  constraint customer_credits_status_check check (status in ('available', 'partially_used', 'fully_used', 'refund_pending', 'refunded', 'expired', 'cancelled')),
  constraint customer_credits_reason_not_blank_check check (btrim(reason) <> ''),
  constraint customer_credits_remaining_status_check check (
    (remaining_amount_minor = 0 and status in ('fully_used', 'refunded', 'expired', 'cancelled'))
    or (remaining_amount_minor > 0 and status in ('available', 'partially_used', 'refund_pending'))
  ),
  constraint customer_credits_close_status_check check (
    (status in ('fully_used', 'refunded', 'expired', 'cancelled')) = (closed_at is not null)
  )
);

comment on table public.customer_credits is 'Customer liability lot created from confirmed overpayment or approved adjustment; remaining amount is command-maintained and reconciled to immutable movements.';

create index customer_credits_customer_id_idx on public.customer_credits (customer_id);
create index customer_credits_source_payment_id_idx on public.customer_credits (source_payment_id) where source_payment_id is not null;
create index customer_credits_created_by_idx on public.customer_credits (created_by);
create index customer_credits_organization_status_idx on public.customer_credits (organization_id, status, created_at);

create table public.refunds (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  customer_id uuid not null references public.customers(id),
  order_id uuid,
  customer_payment_id uuid,
  customer_credit_id uuid,
  source_wallet_id uuid,
  requested_amount_minor bigint not null,
  approved_amount_minor bigint,
  executed_amount_minor bigint not null default 0,
  currency character(3) not null default 'EGP',
  status text not null default 'requested',
  reason text not null,
  destination_method text,
  destination_reference_snapshot text,
  external_transaction_reference text,
  requested_by uuid not null references public.profiles(id),
  approval_request_id uuid references public.approval_requests(id),
  approved_by uuid references public.profiles(id),
  executed_by uuid references public.profiles(id),
  evidence_attachment_id uuid,
  idempotency_key text not null,
  request_fingerprint text not null,
  correlation_id uuid not null,
  requested_at timestamptz not null default statement_timestamp(),
  approved_at timestamptz,
  executed_at timestamptz,
  cancelled_at timestamptz,
  reversed_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint refunds_organization_id_id_key unique (organization_id, id),
  constraint refunds_organization_customer_id_key unique (organization_id, id, customer_id),
  constraint refunds_idempotency_key unique (organization_id, idempotency_key),
  constraint refunds_order_fk foreign key (organization_id, order_id, customer_id)
    references public.orders(organization_id, id, customer_id),
  constraint refunds_payment_fk foreign key (organization_id, customer_payment_id, customer_id)
    references public.customer_payments(organization_id, id, customer_id),
  constraint refunds_credit_fk foreign key (organization_id, customer_credit_id, customer_id)
    references public.customer_credits(organization_id, id, customer_id),
  constraint refunds_wallet_fk foreign key (organization_id, source_wallet_id)
    references public.wallets(organization_id, id),
  constraint refunds_requested_amount_positive_check check (requested_amount_minor > 0),
  constraint refunds_amount_progress_check check (
    (approved_amount_minor is null or approved_amount_minor between 1 and requested_amount_minor)
    and executed_amount_minor >= 0
    and executed_amount_minor <= coalesce(approved_amount_minor, 0)
  ),
  constraint refunds_currency_check check (currency = 'EGP'),
  constraint refunds_status_check check (status in ('requested', 'approved', 'partially_executed', 'executed', 'rejected', 'cancelled', 'reversed')),
  constraint refunds_reason_not_blank_check check (btrim(reason) <> ''),
  constraint refunds_source_check check (num_nonnulls(order_id, customer_payment_id, customer_credit_id) >= 1),
  constraint refunds_idempotency_not_blank_check check (btrim(idempotency_key) <> ''),
  constraint refunds_fingerprint_not_blank_check check (btrim(request_fingerprint) <> ''),
  constraint refunds_approval_metadata_check check (
    (status in ('approved', 'partially_executed', 'executed', 'reversed')
      and approval_request_id is not null and approved_by is not null and approved_at is not null and approved_amount_minor is not null)
    or status in ('requested', 'rejected', 'cancelled')
  ),
  constraint refunds_execution_metadata_check check (
    (executed_amount_minor > 0 and source_wallet_id is not null and executed_by is not null and executed_at is not null)
    or executed_amount_minor = 0
  ),
  constraint refunds_status_amount_check check (
    (status = 'partially_executed' and executed_amount_minor > 0 and executed_amount_minor < approved_amount_minor)
    or (status in ('executed', 'reversed') and executed_amount_minor = approved_amount_minor)
    or status in ('requested', 'approved', 'rejected', 'cancelled')
  )
);

comment on table public.refunds is 'Approval-bound customer refund liability and execution record; payment from a wallet is distinct from the request.';

create unique index refunds_external_reference_key
  on public.refunds (organization_id, source_wallet_id, external_transaction_reference)
  where external_transaction_reference is not null;
create index refunds_customer_id_idx on public.refunds (customer_id);
create index refunds_order_id_idx on public.refunds (order_id) where order_id is not null;
create index refunds_customer_payment_id_idx on public.refunds (customer_payment_id) where customer_payment_id is not null;
create index refunds_customer_credit_id_idx on public.refunds (customer_credit_id) where customer_credit_id is not null;
create index refunds_source_wallet_id_idx on public.refunds (source_wallet_id) where source_wallet_id is not null;
create index refunds_requested_by_idx on public.refunds (requested_by);
create index refunds_approval_request_id_idx on public.refunds (approval_request_id) where approval_request_id is not null;
create index refunds_approved_by_idx on public.refunds (approved_by) where approved_by is not null;
create index refunds_executed_by_idx on public.refunds (executed_by) where executed_by is not null;
create index refunds_evidence_attachment_id_idx on public.refunds (evidence_attachment_id) where evidence_attachment_id is not null;
create index refunds_organization_status_idx on public.refunds (organization_id, status, requested_at desc);
create index refunds_correlation_id_idx on public.refunds (correlation_id);

create table public.payment_allocations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  customer_id uuid not null references public.customers(id),
  customer_payment_id uuid not null,
  order_id uuid,
  customer_credit_id uuid,
  refund_id uuid,
  allocation_type text not null,
  amount_minor bigint not null,
  currency character(3) not null default 'EGP',
  allocated_by uuid not null references public.profiles(id),
  allocation_fingerprint text not null,
  correlation_id uuid not null,
  allocated_at timestamptz not null default statement_timestamp(),
  reversed_at timestamptz,
  reversal_allocation_id uuid,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint payment_allocations_organization_id_id_key unique (organization_id, id),
  constraint payment_allocations_organization_customer_id_key unique (organization_id, id, customer_id),
  constraint payment_allocations_payment_fk foreign key (organization_id, customer_payment_id, customer_id)
    references public.customer_payments(organization_id, id, customer_id),
  constraint payment_allocations_order_fk foreign key (organization_id, order_id, customer_id)
    references public.orders(organization_id, id, customer_id),
  constraint payment_allocations_credit_fk foreign key (organization_id, customer_credit_id, customer_id)
    references public.customer_credits(organization_id, id, customer_id),
  constraint payment_allocations_refund_fk foreign key (organization_id, refund_id, customer_id)
    references public.refunds(organization_id, id, customer_id),
  constraint payment_allocations_reversal_fk foreign key (organization_id, reversal_allocation_id)
    references public.payment_allocations(organization_id, id),
  constraint payment_allocations_type_check check (
    allocation_type in ('product_deposit', 'shipping_prepayment', 'remaining_product_balance', 'full_prepayment', 'customer_receivable', 'customer_credit', 'refund_offset', 'other_approved')
  ),
  constraint payment_allocations_amount_positive_check check (amount_minor > 0),
  constraint payment_allocations_currency_check check (currency = 'EGP'),
  constraint payment_allocations_target_check check (
    (allocation_type in ('product_deposit', 'shipping_prepayment', 'remaining_product_balance', 'full_prepayment', 'customer_receivable')
      and order_id is not null and customer_credit_id is null and refund_id is null)
    or (allocation_type = 'customer_credit' and customer_credit_id is not null and order_id is null and refund_id is null)
    or (allocation_type = 'refund_offset' and refund_id is not null)
    or allocation_type = 'other_approved'
  ),
  constraint payment_allocations_fingerprint_not_blank_check check (btrim(allocation_fingerprint) <> ''),
  constraint payment_allocations_reversal_metadata_check check ((reversed_at is null) = (reversal_allocation_id is null)),
  constraint payment_allocations_not_self_reversal_check check (reversal_allocation_id is null or reversal_allocation_id <> id)
);

comment on table public.payment_allocations is 'Explicit application of confirmed receipts to contractual order components, receivables, customer credit, or refund offsets.';
comment on column public.payment_allocations.amount_minor is 'Positive allocated amount; reversals use a linked compensating allocation rather than mutation.';

create unique index payment_allocations_active_fingerprint_key
  on public.payment_allocations (organization_id, customer_payment_id, allocation_fingerprint)
  where reversed_at is null;
create index payment_allocations_customer_payment_id_idx on public.payment_allocations (customer_payment_id);
create index payment_allocations_customer_id_idx on public.payment_allocations (customer_id);
create index payment_allocations_order_id_idx on public.payment_allocations (order_id) where order_id is not null;
create index payment_allocations_customer_credit_id_idx on public.payment_allocations (customer_credit_id) where customer_credit_id is not null;
create index payment_allocations_refund_id_idx on public.payment_allocations (refund_id) where refund_id is not null;
create index payment_allocations_allocated_by_idx on public.payment_allocations (allocated_by);
create index payment_allocations_reversal_allocation_id_idx on public.payment_allocations (reversal_allocation_id) where reversal_allocation_id is not null;
create index payment_allocations_correlation_id_idx on public.payment_allocations (correlation_id);

create table public.customer_credit_movements (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  customer_id uuid not null references public.customers(id),
  customer_credit_id uuid not null,
  movement_type text not null,
  amount_minor bigint not null,
  order_id uuid,
  payment_allocation_id uuid,
  refund_id uuid,
  reason text not null,
  correlation_id uuid not null,
  created_by uuid not null references public.profiles(id),
  occurred_at timestamptz not null default statement_timestamp(),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint customer_credit_movements_organization_id_id_key unique (organization_id, id),
  constraint customer_credit_movements_credit_fk foreign key (organization_id, customer_credit_id, customer_id)
    references public.customer_credits(organization_id, id, customer_id),
  constraint customer_credit_movements_order_fk foreign key (organization_id, order_id, customer_id)
    references public.orders(organization_id, id, customer_id),
  constraint customer_credit_movements_allocation_fk foreign key (organization_id, payment_allocation_id, customer_id)
    references public.payment_allocations(organization_id, id, customer_id),
  constraint customer_credit_movements_refund_fk foreign key (organization_id, refund_id, customer_id)
    references public.refunds(organization_id, id, customer_id),
  constraint customer_credit_movements_type_check check (movement_type in ('issued', 'applied', 'released', 'refund_reserved', 'refunded', 'expired', 'cancelled', 'adjustment')),
  constraint customer_credit_movements_amount_nonzero_check check (amount_minor <> 0),
  constraint customer_credit_movements_reason_not_blank_check check (btrim(reason) <> '')
);

comment on table public.customer_credit_movements is 'Append-only signed customer-credit lifecycle movements; their sum reconciles to the credit lot remaining amount.';

create index customer_credit_movements_credit_id_idx on public.customer_credit_movements (customer_credit_id, occurred_at);
create index customer_credit_movements_customer_id_idx on public.customer_credit_movements (customer_id);
create index customer_credit_movements_order_id_idx on public.customer_credit_movements (order_id) where order_id is not null;
create index customer_credit_movements_payment_allocation_id_idx on public.customer_credit_movements (payment_allocation_id) where payment_allocation_id is not null;
create index customer_credit_movements_refund_id_idx on public.customer_credit_movements (refund_id) where refund_id is not null;
create index customer_credit_movements_created_by_idx on public.customer_credit_movements (created_by);
create index customer_credit_movements_correlation_id_idx on public.customer_credit_movements (correlation_id);

create table public.wallet_transfers (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  source_wallet_id uuid not null,
  destination_wallet_id uuid not null,
  amount_minor bigint not null,
  fee_minor bigint not null default 0,
  currency character(3) not null default 'EGP',
  status text not null default 'draft',
  transfer_reference text,
  fee_reference text,
  reason text not null,
  requested_by uuid not null references public.profiles(id),
  approval_request_id uuid references public.approval_requests(id),
  approved_by uuid references public.profiles(id),
  executed_by uuid references public.profiles(id),
  evidence_attachment_id uuid,
  idempotency_key text not null,
  request_fingerprint text not null,
  correlation_id uuid not null,
  requested_at timestamptz not null default statement_timestamp(),
  approved_at timestamptz,
  executed_at timestamptz,
  cancelled_at timestamptz,
  reversed_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint wallet_transfers_organization_id_id_key unique (organization_id, id),
  constraint wallet_transfers_idempotency_key unique (organization_id, idempotency_key),
  constraint wallet_transfers_source_wallet_fk foreign key (organization_id, source_wallet_id)
    references public.wallets(organization_id, id),
  constraint wallet_transfers_destination_wallet_fk foreign key (organization_id, destination_wallet_id)
    references public.wallets(organization_id, id),
  constraint wallet_transfers_distinct_wallets_check check (source_wallet_id <> destination_wallet_id),
  constraint wallet_transfers_amount_positive_check check (amount_minor > 0),
  constraint wallet_transfers_fee_nonnegative_check check (fee_minor >= 0),
  constraint wallet_transfers_currency_check check (currency = 'EGP'),
  constraint wallet_transfers_status_check check (status in ('draft', 'submitted', 'approved', 'executed', 'cancelled', 'reversed')),
  constraint wallet_transfers_reason_not_blank_check check (btrim(reason) <> ''),
  constraint wallet_transfers_idempotency_not_blank_check check (btrim(idempotency_key) <> ''),
  constraint wallet_transfers_fingerprint_not_blank_check check (btrim(request_fingerprint) <> ''),
  constraint wallet_transfers_approval_metadata_check check (
    (status in ('approved', 'executed', 'reversed') and approval_request_id is not null and approved_by is not null and approved_at is not null)
    or status in ('draft', 'submitted', 'cancelled')
  ),
  constraint wallet_transfers_execution_metadata_check check (
    (status in ('executed', 'reversed') and executed_by is not null and executed_at is not null)
    or status in ('draft', 'submitted', 'approved', 'cancelled')
  )
);

comment on table public.wallet_transfers is 'Profit-neutral movement between Falcon wallets; fee is captured separately for expense posting in the same command.';

create unique index wallet_transfers_reference_key
  on public.wallet_transfers (organization_id, source_wallet_id, transfer_reference)
  where transfer_reference is not null and status <> 'cancelled';
create index wallet_transfers_source_wallet_id_idx on public.wallet_transfers (source_wallet_id);
create index wallet_transfers_destination_wallet_id_idx on public.wallet_transfers (destination_wallet_id);
create index wallet_transfers_requested_by_idx on public.wallet_transfers (requested_by);
create index wallet_transfers_approval_request_id_idx on public.wallet_transfers (approval_request_id) where approval_request_id is not null;
create index wallet_transfers_approved_by_idx on public.wallet_transfers (approved_by) where approved_by is not null;
create index wallet_transfers_executed_by_idx on public.wallet_transfers (executed_by) where executed_by is not null;
create index wallet_transfers_evidence_attachment_id_idx on public.wallet_transfers (evidence_attachment_id) where evidence_attachment_id is not null;
create index wallet_transfers_organization_status_idx on public.wallet_transfers (organization_id, status, requested_at desc);
create index wallet_transfers_correlation_id_idx on public.wallet_transfers (correlation_id);

create table public.wallet_reconciliations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  wallet_id uuid not null,
  period_started_at timestamptz not null,
  period_ended_at timestamptz not null,
  reconciliation_date date not null,
  opening_book_balance_minor bigint not null,
  system_movements_minor bigint not null,
  expected_closing_balance_minor bigint not null,
  actual_closing_balance_minor bigint not null,
  difference_minor bigint not null,
  currency character(3) not null default 'EGP',
  status text not null default 'draft',
  difference_explanation text,
  prepared_by uuid not null references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  approval_request_id uuid references public.approval_requests(id),
  evidence_attachment_id uuid,
  adjustment_reference_type text,
  adjustment_reference_id uuid,
  correlation_id uuid not null,
  prepared_at timestamptz not null default statement_timestamp(),
  reviewed_at timestamptz,
  finalized_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint wallet_reconciliations_organization_id_id_key unique (organization_id, id),
  constraint wallet_reconciliations_organization_wallet_id_key unique (organization_id, id, wallet_id),
  constraint wallet_reconciliations_period_key unique (organization_id, wallet_id, period_started_at, period_ended_at),
  constraint wallet_reconciliations_wallet_fk foreign key (organization_id, wallet_id)
    references public.wallets(organization_id, id),
  constraint wallet_reconciliations_period_check check (period_ended_at > period_started_at),
  constraint wallet_reconciliations_currency_check check (currency = 'EGP'),
  constraint wallet_reconciliations_expected_projection_check check (
    expected_closing_balance_minor = opening_book_balance_minor + system_movements_minor
  ),
  constraint wallet_reconciliations_difference_projection_check check (
    difference_minor = actual_closing_balance_minor - expected_closing_balance_minor
  ),
  constraint wallet_reconciliations_status_check check (status in ('draft', 'prepared', 'reviewed', 'finalized', 'cancelled')),
  constraint wallet_reconciliations_review_metadata_check check (
    (status in ('reviewed', 'finalized') and reviewed_by is not null and reviewed_at is not null)
    or status in ('draft', 'prepared', 'cancelled')
  ),
  constraint wallet_reconciliations_finalized_metadata_check check (
    (status = 'finalized' and finalized_at is not null) or status <> 'finalized'
  ),
  constraint wallet_reconciliations_difference_resolution_check check (
    difference_minor = 0
    or status <> 'finalized'
    or (
      nullif(btrim(difference_explanation), '') is not null
      and approval_request_id is not null
      and adjustment_reference_type is not null
      and adjustment_reference_id is not null
    )
  ),
  constraint wallet_reconciliations_adjustment_pair_check check (
    (adjustment_reference_type is null) = (adjustment_reference_id is null)
  )
);

comment on table public.wallet_reconciliations is 'Wallet book-to-provider reconciliation; a nonzero finalized difference requires explanation, approval, and linked correction.';

create index wallet_reconciliations_wallet_id_idx on public.wallet_reconciliations (wallet_id, period_ended_at desc);
create index wallet_reconciliations_prepared_by_idx on public.wallet_reconciliations (prepared_by);
create index wallet_reconciliations_reviewed_by_idx on public.wallet_reconciliations (reviewed_by) where reviewed_by is not null;
create index wallet_reconciliations_approval_request_id_idx on public.wallet_reconciliations (approval_request_id) where approval_request_id is not null;
create index wallet_reconciliations_evidence_attachment_id_idx on public.wallet_reconciliations (evidence_attachment_id) where evidence_attachment_id is not null;
create index wallet_reconciliations_organization_status_idx on public.wallet_reconciliations (organization_id, status, reconciliation_date desc);
create index wallet_reconciliations_correlation_id_idx on public.wallet_reconciliations (correlation_id);

create table public.wallet_reconciliation_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  wallet_reconciliation_id uuid not null,
  wallet_id uuid not null,
  sequence_number integer not null,
  movement_type text not null,
  source_type text not null,
  source_id uuid not null,
  movement_amount_minor bigint not null,
  book_balance_after_minor bigint,
  occurred_at timestamptz not null,
  description text not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint wallet_reconciliation_items_organization_id_id_key unique (organization_id, id),
  constraint wallet_reconciliation_items_sequence_key unique (organization_id, wallet_reconciliation_id, sequence_number),
  constraint wallet_reconciliation_items_source_key unique (organization_id, wallet_reconciliation_id, source_type, source_id),
  constraint wallet_reconciliation_items_reconciliation_fk foreign key (organization_id, wallet_reconciliation_id, wallet_id)
    references public.wallet_reconciliations(organization_id, id, wallet_id),
  constraint wallet_reconciliation_items_wallet_fk foreign key (organization_id, wallet_id)
    references public.wallets(organization_id, id),
  constraint wallet_reconciliation_items_sequence_positive_check check (sequence_number > 0),
  constraint wallet_reconciliation_items_movement_type_check check (movement_type in ('receipt', 'payment', 'transfer_in', 'transfer_out', 'fee', 'refund', 'adjustment')),
  constraint wallet_reconciliation_items_source_type_check check (
    source_type in ('customer_payment', 'customer_refund', 'wallet_transfer', 'courier_settlement', 'supplier_payment', 'expense_payment', 'payroll_payment', 'partner_withdrawal', 'journal_adjustment')
  ),
  constraint wallet_reconciliation_items_amount_nonzero_check check (movement_amount_minor <> 0),
  constraint wallet_reconciliation_items_description_not_blank_check check (btrim(description) <> '')
);

comment on table public.wallet_reconciliation_items is 'Frozen wallet movement population included in a reconciliation. Polymorphic source IDs support later financial domains.';

create index wallet_reconciliation_items_reconciliation_id_idx on public.wallet_reconciliation_items (wallet_reconciliation_id, sequence_number);
create index wallet_reconciliation_items_wallet_id_idx on public.wallet_reconciliation_items (wallet_id, occurred_at);
create index wallet_reconciliation_items_source_idx on public.wallet_reconciliation_items (source_type, source_id);

create trigger orders_set_updated_at
before update on public.orders
for each row execute function private.set_updated_at();

create trigger order_items_set_updated_at
before update on public.order_items
for each row execute function private.set_updated_at();

create trigger order_status_history_set_updated_at
before update on public.order_status_history
for each row execute function private.set_updated_at();

create trigger order_exceptions_set_updated_at
before update on public.order_exceptions
for each row execute function private.set_updated_at();

create trigger order_discounts_set_updated_at
before update on public.order_discounts
for each row execute function private.set_updated_at();

create trigger order_discount_allocations_set_updated_at
before update on public.order_discount_allocations
for each row execute function private.set_updated_at();

create trigger order_problems_set_updated_at
before update on public.order_problems
for each row execute function private.set_updated_at();

create trigger order_problem_costs_set_updated_at
before update on public.order_problem_costs
for each row execute function private.set_updated_at();

create trigger wallets_set_updated_at
before update on public.wallets
for each row execute function private.set_updated_at();

create trigger customer_payments_set_updated_at
before update on public.customer_payments
for each row execute function private.set_updated_at();

create trigger customer_credits_set_updated_at
before update on public.customer_credits
for each row execute function private.set_updated_at();

create trigger refunds_set_updated_at
before update on public.refunds
for each row execute function private.set_updated_at();

create trigger payment_allocations_set_updated_at
before update on public.payment_allocations
for each row execute function private.set_updated_at();

create trigger customer_credit_movements_set_updated_at
before update on public.customer_credit_movements
for each row execute function private.set_updated_at();

create trigger wallet_transfers_set_updated_at
before update on public.wallet_transfers
for each row execute function private.set_updated_at();

create trigger wallet_reconciliations_set_updated_at
before update on public.wallet_reconciliations
for each row execute function private.set_updated_at();

create trigger wallet_reconciliation_items_set_updated_at
before update on public.wallet_reconciliation_items
for each row execute function private.set_updated_at();
