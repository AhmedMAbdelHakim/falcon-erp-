create type public.production_attempt_status as enum (
  'planned', 'queued', 'sent', 'partially_received', 'received',
  'qc_complete', 'reprint_planned', 'closed', 'cancelled'
);
create type public.supplier_invoice_status as enum (
  'draft', 'submitted', 'approved', 'posted', 'partially_paid',
  'paid', 'disputed', 'cancelled', 'reversed'
);
create type public.inventory_movement_type as enum (
  'purchase_receipt', 'transfer', 'reservation', 'reservation_release',
  'production_issue', 'production_receipt', 'sale', 'customer_return',
  'damage', 'loss', 'adjustment', 'gift_consumption', 'packaging_consumption'
);
create type public.shipment_kind as enum ('primary', 'split', 'replacement', 'return_to_customer');
create type public.courier_settlement_line_type as enum (
  'contractual_cod_receivable', 'prepaid_delivery_payable', 'delivery_fee_payable',
  'return_fee_payable', 'approved_deduction', 'adjustment', 'prior_carry_forward',
  'remittance', 'claim', 'dispute'
);

create table public.print_batches (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  supplier_id uuid not null,
  batch_no text not null,
  status public.print_batch_status not null default 'draft',
  business_date date not null,
  currency_code text not null default 'EGP',
  sent_at timestamptz,
  acknowledged_at timestamptz,
  closed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  notes text,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint print_batches_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint print_batches_supplier_fk foreign key (supplier_id) references public.suppliers (id),
  constraint print_batches_batch_no_not_blank check (btrim(batch_no) <> ''),
  constraint print_batches_currency_egp check (currency_code = 'EGP'),
  constraint print_batches_version_positive check (version > 0),
  constraint print_batches_sent_timestamp_check check (sent_at is null or status <> 'draft'),
  constraint print_batches_closed_timestamp_check check ((status = 'closed') = (closed_at is not null)),
  constraint print_batches_cancelled_fields_check check (
    status <> 'cancelled' or (cancelled_at is not null and nullif(btrim(cancellation_reason), '') is not null)
  ),
  constraint print_batches_unique_no unique (organization_id, batch_no)
);

comment on table public.print_batches is 'Printer work aggregates; receipt, QC, invoicing, and payment remain separate events.';

create table public.print_batch_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  print_batch_id uuid not null,
  order_item_id uuid not null,
  attempt_no integer not null,
  replaces_print_batch_item_id uuid,
  supply_method public.supply_method not null,
  status public.production_attempt_status not null default 'planned',
  requested_quantity integer not null,
  sent_quantity integer not null default 0,
  received_quantity integer not null default 0,
  accepted_quantity integer not null default 0,
  rejected_quantity integer not null default 0,
  lost_quantity integer not null default 0,
  supplier_price_rule_id uuid,
  expected_case_unit_cost_minor bigint not null default 0,
  expected_print_unit_cost_minor bigint not null default 0,
  expected_total_unit_cost_minor bigint not null,
  actual_accepted_unit_cost_minor bigint,
  responsibility text,
  issue_reason text,
  queued_at timestamptz,
  sent_at timestamptz,
  qc_completed_at timestamptz,
  closed_at timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint print_batch_items_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint print_batch_items_batch_fk foreign key (print_batch_id) references public.print_batches (id),
  constraint print_batch_items_order_item_fk foreign key (order_item_id) references public.order_items (id),
  constraint print_batch_items_replaced_attempt_fk foreign key (replaces_print_batch_item_id) references public.print_batch_items (id),
  constraint print_batch_items_attempt_positive check (attempt_no > 0),
  constraint print_batch_items_requested_positive check (requested_quantity > 0),
  constraint print_batch_items_quantity_flow check (
    sent_quantity between 0 and requested_quantity
    and received_quantity between 0 and sent_quantity
    and accepted_quantity >= 0
    and rejected_quantity >= 0
    and lost_quantity >= 0
    and accepted_quantity + rejected_quantity <= received_quantity
    and received_quantity + lost_quantity <= sent_quantity
  ),
  constraint print_batch_items_expected_costs_nonnegative check (
    expected_case_unit_cost_minor >= 0 and expected_print_unit_cost_minor >= 0
    and expected_total_unit_cost_minor >= 0
  ),
  constraint print_batch_items_expected_cost_sum check (
    expected_total_unit_cost_minor = expected_case_unit_cost_minor + expected_print_unit_cost_minor
  ),
  constraint print_batch_items_actual_cost_nonnegative check (
    actual_accepted_unit_cost_minor is null or actual_accepted_unit_cost_minor >= 0
  ),
  constraint print_batch_items_reprint_not_self check (replaces_print_batch_item_id is distinct from id),
  constraint print_batch_items_version_positive check (version > 0),
  constraint print_batch_items_attempt_unique unique (organization_id, order_item_id, attempt_no)
);

comment on table public.print_batch_items is 'One production attempt for an order item; an order item may have multiple sequential attempts.';
comment on column public.print_batch_items.expected_total_unit_cost_minor is 'Frozen EGP minor-unit cost at queue time.';

create unique index print_batch_items_one_active_attempt_idx
  on public.print_batch_items (organization_id, order_item_id)
  where status in ('queued', 'sent', 'partially_received', 'received');

create table public.print_batch_receipts (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  print_batch_id uuid not null,
  receipt_no text not null,
  received_at timestamptz not null,
  received_by uuid not null,
  supplier_document_ref text,
  notes text,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint print_batch_receipts_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint print_batch_receipts_batch_fk foreign key (print_batch_id) references public.print_batches (id),
  constraint print_batch_receipts_no_not_blank check (btrim(receipt_no) <> ''),
  constraint print_batch_receipts_unique_no unique (organization_id, receipt_no)
);

comment on table public.print_batch_receipts is 'Append-only physical receipt headers for printer batches.';

create table public.print_batch_receipt_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  print_batch_receipt_id uuid not null,
  print_batch_item_id uuid not null,
  received_quantity integer not null,
  observed_lost_quantity integer not null default 0,
  condition_notes text,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint print_batch_receipt_items_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint print_batch_receipt_items_receipt_fk foreign key (print_batch_receipt_id) references public.print_batch_receipts (id),
  constraint print_batch_receipt_items_batch_item_fk foreign key (print_batch_item_id) references public.print_batch_items (id),
  constraint print_batch_receipt_items_quantity_positive check (received_quantity > 0),
  constraint print_batch_receipt_items_lost_nonnegative check (observed_lost_quantity >= 0),
  constraint print_batch_receipt_items_unique_item unique (print_batch_receipt_id, print_batch_item_id)
);

comment on table public.print_batch_receipt_items is 'Immutable receipt quantities for individual production attempts.';

create table public.print_batch_qc_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  print_batch_receipt_item_id uuid not null,
  print_batch_item_id uuid not null,
  status public.qc_status not null,
  inspected_quantity integer not null,
  accepted_quantity integer not null default 0,
  rejected_quantity integer not null default 0,
  rejection_reason text,
  responsibility text,
  inspected_at timestamptz not null,
  inspected_by uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint print_batch_qc_events_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint print_batch_qc_events_receipt_item_fk foreign key (print_batch_receipt_item_id) references public.print_batch_receipt_items (id),
  constraint print_batch_qc_events_batch_item_fk foreign key (print_batch_item_id) references public.print_batch_items (id),
  constraint print_batch_qc_events_inspected_positive check (inspected_quantity > 0),
  constraint print_batch_qc_events_quantity_balance check (
    accepted_quantity >= 0 and rejected_quantity >= 0
    and accepted_quantity + rejected_quantity = inspected_quantity
  ),
  constraint print_batch_qc_events_status_consistent check (
    (status = 'accepted' and accepted_quantity = inspected_quantity)
    or (status = 'rejected' and rejected_quantity = inspected_quantity)
    or (status = 'partially_accepted' and accepted_quantity > 0 and rejected_quantity > 0)
  ),
  constraint print_batch_qc_events_rejection_reason_check check (
    rejected_quantity = 0 or nullif(btrim(rejection_reason), '') is not null
  )
);

comment on table public.print_batch_qc_events is 'Append-only QC decisions; accepted quantities are eligible for GRNI accrual.';

create table public.grni_accruals (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  print_batch_qc_event_id uuid not null,
  print_batch_item_id uuid not null,
  entry_kind text not null default 'accrual',
  accepted_quantity integer not null,
  unit_cost_minor bigint not null,
  accrued_amount_minor bigint not null,
  accounting_date date not null,
  journal_entry_id uuid,
  reverses_grni_accrual_id uuid,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint grni_accruals_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint grni_accruals_qc_event_fk foreign key (print_batch_qc_event_id) references public.print_batch_qc_events (id),
  constraint grni_accruals_batch_item_fk foreign key (print_batch_item_id) references public.print_batch_items (id),
  constraint grni_accruals_reversal_fk foreign key (reverses_grni_accrual_id) references public.grni_accruals (id),
  constraint grni_accruals_quantity_positive check (accepted_quantity > 0),
  constraint grni_accruals_entry_kind_check check (entry_kind in ('accrual', 'reversal')),
  constraint grni_accruals_unit_cost_nonnegative check (unit_cost_minor >= 0),
  constraint grni_accruals_amount_nonnegative check (accrued_amount_minor >= 0),
  constraint grni_accruals_amount_matches check (
    accrued_amount_minor::numeric = accepted_quantity::numeric * unit_cost_minor::numeric
  ),
  constraint grni_accruals_not_self_reversal check (reverses_grni_accrual_id is distinct from id),
  constraint grni_accruals_reversal_shape_check check (
    (entry_kind = 'accrual' and reverses_grni_accrual_id is null)
    or (entry_kind = 'reversal' and reverses_grni_accrual_id is not null)
  )
);

comment on table public.grni_accruals is 'Append-only accepted-QC cost accruals awaiting supplier invoice matching.';

create unique index grni_accruals_qc_unique_idx
  on public.grni_accruals (print_batch_qc_event_id)
  where entry_kind = 'accrual';
create unique index grni_accruals_one_reversal_idx
  on public.grni_accruals (reverses_grni_accrual_id)
  where entry_kind = 'reversal';

create table public.supplier_invoices (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  supplier_id uuid not null,
  print_batch_id uuid,
  invoice_no text not null,
  invoice_date date not null,
  due_date date,
  status public.supplier_invoice_status not null default 'draft',
  currency_code text not null default 'EGP',
  subtotal_minor bigint not null,
  tax_minor bigint not null default 0,
  credit_minor bigint not null default 0,
  total_minor bigint not null,
  approved_variance_minor bigint not null default 0,
  posted_at timestamptz,
  posted_by uuid,
  approval_request_id uuid,
  journal_entry_id uuid,
  cancellation_reason text,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint supplier_invoices_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint supplier_invoices_supplier_fk foreign key (supplier_id) references public.suppliers (id),
  constraint supplier_invoices_batch_fk foreign key (print_batch_id) references public.print_batches (id),
  constraint supplier_invoices_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint supplier_invoices_number_not_blank check (btrim(invoice_no) <> ''),
  constraint supplier_invoices_currency_egp check (currency_code = 'EGP'),
  constraint supplier_invoices_amounts_nonnegative check (
    subtotal_minor >= 0 and tax_minor >= 0 and credit_minor >= 0 and total_minor >= 0
  ),
  constraint supplier_invoices_total_matches check (
    total_minor::numeric = subtotal_minor::numeric + tax_minor::numeric - credit_minor::numeric
  ),
  constraint supplier_invoices_due_date_check check (due_date is null or due_date >= invoice_date),
  constraint supplier_invoices_posting_fields_check check (
    status not in ('posted', 'partially_paid', 'paid') or (posted_at is not null and posted_by is not null and journal_entry_id is not null)
  ),
  constraint supplier_invoices_cancel_reason_check check (
    status <> 'cancelled' or nullif(btrim(cancellation_reason), '') is not null
  ),
  constraint supplier_invoices_version_positive check (version > 0),
  constraint supplier_invoices_supplier_number_unique unique (organization_id, supplier_id, invoice_no)
);

comment on table public.supplier_invoices is 'Supplier invoice headers matched against accepted QC and GRNI, not direct operating expense.';

create table public.supplier_invoice_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  supplier_invoice_id uuid not null,
  print_batch_item_id uuid not null,
  grni_accrual_id uuid,
  description text not null,
  invoiced_quantity integer not null,
  invoiced_unit_cost_minor bigint not null,
  line_amount_minor bigint not null,
  matched_grni_minor bigint not null default 0,
  variance_minor bigint not null default 0,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint supplier_invoice_items_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint supplier_invoice_items_invoice_fk foreign key (supplier_invoice_id) references public.supplier_invoices (id),
  constraint supplier_invoice_items_batch_item_fk foreign key (print_batch_item_id) references public.print_batch_items (id),
  constraint supplier_invoice_items_grni_fk foreign key (grni_accrual_id) references public.grni_accruals (id),
  constraint supplier_invoice_items_description_not_blank check (btrim(description) <> ''),
  constraint supplier_invoice_items_quantity_positive check (invoiced_quantity > 0),
  constraint supplier_invoice_items_unit_cost_nonnegative check (invoiced_unit_cost_minor >= 0),
  constraint supplier_invoice_items_line_amount_nonnegative check (line_amount_minor >= 0),
  constraint supplier_invoice_items_line_amount_matches check (
    line_amount_minor::numeric = invoiced_quantity::numeric * invoiced_unit_cost_minor::numeric
  ),
  constraint supplier_invoice_items_grni_nonnegative check (matched_grni_minor >= 0),
  constraint supplier_invoice_items_variance_matches check (
    variance_minor::numeric = line_amount_minor::numeric - matched_grni_minor::numeric
  ),
  constraint supplier_invoice_items_attempt_unique unique (supplier_invoice_id, print_batch_item_id, grni_accrual_id)
);

comment on table public.supplier_invoice_items is 'Invoice lines tied to production attempts and, when available, a specific GRNI accrual.';

create table public.supplier_payments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  supplier_invoice_id uuid not null,
  wallet_id uuid not null,
  amount_minor bigint not null,
  payment_date date not null,
  provider_reference text,
  evidence_attachment_id uuid,
  journal_entry_id uuid,
  reverses_supplier_payment_id uuid,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint supplier_payments_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint supplier_payments_invoice_fk foreign key (supplier_invoice_id) references public.supplier_invoices (id),
  constraint supplier_payments_wallet_fk foreign key (wallet_id) references public.wallets (id),
  constraint supplier_payments_reversal_fk foreign key (reverses_supplier_payment_id) references public.supplier_payments (id),
  constraint supplier_payments_amount_positive check (amount_minor > 0),
  constraint supplier_payments_not_self_reversal check (reverses_supplier_payment_id is distinct from id)
);

comment on table public.supplier_payments is 'Append-only supplier AP payments; aggregate overpayment controls are enforced by the payment RPC.';

create table public.inventory_locations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  code text not null,
  name text not null,
  location_kind text not null,
  permits_negative_on_hand boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid,
  constraint inventory_locations_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint inventory_locations_code_not_blank check (btrim(code) <> ''),
  constraint inventory_locations_name_not_blank check (btrim(name) <> ''),
  constraint inventory_locations_kind_check check (
    location_kind in ('falcon_storage', 'printer', 'packing', 'courier', 'return_inspection', 'resellable_returns', 'damaged', 'consumed')
  ),
  constraint inventory_locations_code_unique unique (organization_id, code)
);

comment on table public.inventory_locations is 'Physical or custody locations used to derive inventory balances from movements.';

create table public.inventory_reservations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  product_variant_id uuid not null,
  location_id uuid not null,
  order_item_id uuid not null,
  quantity integer not null,
  released_quantity integer not null default 0,
  consumed_quantity integer not null default 0,
  unit_cost_minor bigint not null,
  status text not null default 'active',
  reserved_at timestamptz not null default statement_timestamp(),
  expires_at timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint inventory_reservations_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint inventory_reservations_variant_fk foreign key (product_variant_id) references public.product_variants (id),
  constraint inventory_reservations_location_fk foreign key (location_id) references public.inventory_locations (id),
  constraint inventory_reservations_order_item_fk foreign key (order_item_id) references public.order_items (id),
  constraint inventory_reservations_quantity_positive check (quantity > 0),
  constraint inventory_reservations_quantity_flow check (
    released_quantity >= 0 and consumed_quantity >= 0
    and released_quantity + consumed_quantity <= quantity
  ),
  constraint inventory_reservations_cost_nonnegative check (unit_cost_minor >= 0),
  constraint inventory_reservations_status_check check (status in ('active', 'partially_consumed', 'consumed', 'released', 'expired', 'cancelled')),
  constraint inventory_reservations_expiry_check check (expires_at is null or expires_at > reserved_at),
  constraint inventory_reservations_version_positive check (version > 0)
);

comment on table public.inventory_reservations is 'Order-item stock commitments; on-hand remains derived from append-only movements.';

create table public.inventory_movements (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  movement_type public.inventory_movement_type not null,
  product_variant_id uuid not null,
  from_location_id uuid,
  to_location_id uuid,
  quantity integer not null,
  unit_cost_minor bigint not null,
  total_cost_minor bigint not null,
  inventory_reservation_id uuid,
  print_batch_item_id uuid,
  order_item_id uuid,
  source_type text not null,
  source_id uuid not null,
  correlation_id uuid not null,
  responsibility text,
  reason text not null,
  approval_request_id uuid,
  accounting_date date not null,
  journal_entry_id uuid,
  occurred_at timestamptz not null,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint inventory_movements_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint inventory_movements_variant_fk foreign key (product_variant_id) references public.product_variants (id),
  constraint inventory_movements_from_location_fk foreign key (from_location_id) references public.inventory_locations (id),
  constraint inventory_movements_to_location_fk foreign key (to_location_id) references public.inventory_locations (id),
  constraint inventory_movements_reservation_fk foreign key (inventory_reservation_id) references public.inventory_reservations (id),
  constraint inventory_movements_batch_item_fk foreign key (print_batch_item_id) references public.print_batch_items (id),
  constraint inventory_movements_order_item_fk foreign key (order_item_id) references public.order_items (id),
  constraint inventory_movements_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint inventory_movements_quantity_positive check (quantity > 0),
  constraint inventory_movements_unit_cost_nonnegative check (unit_cost_minor >= 0),
  constraint inventory_movements_total_cost_nonnegative check (total_cost_minor >= 0),
  constraint inventory_movements_total_cost_matches check (
    total_cost_minor::numeric = quantity::numeric * unit_cost_minor::numeric
  ),
  constraint inventory_movements_locations_distinct check (from_location_id is distinct from to_location_id),
  constraint inventory_movements_location_presence check (from_location_id is not null or to_location_id is not null),
  constraint inventory_movements_source_type_not_blank check (btrim(source_type) <> ''),
  constraint inventory_movements_reason_not_blank check (btrim(reason) <> ''),
  constraint inventory_movements_adjustment_approval check (
    movement_type <> 'adjustment' or approval_request_id is not null
  ),
  constraint inventory_movements_source_unique unique (organization_id, source_type, source_id, movement_type)
);

comment on table public.inventory_movements is 'Append-only inventory events; balances are projections of location inflows less outflows.';

create or replace function private.enforce_nonnegative_inventory()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_permits_negative boolean;
  v_on_hand bigint;
begin
  if new.from_location_id is null then
    return new;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    new.organization_id::text || ':' || new.product_variant_id::text || ':' || new.from_location_id::text,
    0
  ));

  select location.permits_negative_on_hand into strict v_permits_negative
  from public.inventory_locations as location
  where location.organization_id = new.organization_id and location.id = new.from_location_id;

  if not v_permits_negative then
    select coalesce(sum(delta.quantity_delta), 0) into v_on_hand
    from (
      select movement.quantity::bigint as quantity_delta
      from public.inventory_movements as movement
      where movement.organization_id = new.organization_id
        and movement.product_variant_id = new.product_variant_id
        and movement.to_location_id = new.from_location_id
      union all
      select -movement.quantity::bigint
      from public.inventory_movements as movement
      where movement.organization_id = new.organization_id
        and movement.product_variant_id = new.product_variant_id
        and movement.from_location_id = new.from_location_id
    ) as delta;

    if v_on_hand < new.quantity then
      raise exception using errcode = '23514', message = 'INSUFFICIENT_INVENTORY';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_nonnegative_inventory() from public, anon, authenticated;

create trigger inventory_movements_enforce_nonnegative
before insert on public.inventory_movements
for each row execute function private.enforce_nonnegative_inventory();

create table public.shipments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  order_id uuid not null,
  courier_id uuid not null,
  shipment_kind public.shipment_kind not null default 'primary',
  tracking_number text,
  status public.shipment_status not null default 'draft',
  settlement_status text not null default 'unsettled',
  shipping_zone_snapshot text not null,
  customer_shipping_charge_minor bigint not null default 0,
  courier_delivery_fee_minor bigint not null default 0,
  courier_return_fee_minor bigint not null default 0,
  expected_cod_minor bigint not null default 0,
  reported_collected_cod_minor bigint,
  dispatch_evidence_attachment_id uuid,
  delivery_evidence_attachment_id uuid,
  return_evidence_attachment_id uuid,
  dispatched_at timestamptz,
  delivered_at timestamptz,
  returned_at timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint shipments_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint shipments_order_fk foreign key (order_id) references public.orders (id),
  constraint shipments_courier_fk foreign key (courier_id) references public.couriers (id),
  constraint shipments_zone_not_blank check (btrim(shipping_zone_snapshot) <> ''),
  constraint shipments_amounts_nonnegative check (
    customer_shipping_charge_minor >= 0 and courier_delivery_fee_minor >= 0
    and courier_return_fee_minor >= 0 and expected_cod_minor >= 0
    and (reported_collected_cod_minor is null or reported_collected_cod_minor >= 0)
  ),
  constraint shipments_settlement_status_check check (settlement_status in ('unsettled', 'partially_settled', 'settled', 'disputed')),
  constraint shipments_dispatch_time_check check (status in ('draft', 'cancelled') or dispatched_at is not null),
  constraint shipments_delivery_time_check check (
    status not in ('partially_delivered', 'delivered') or delivered_at is not null
  ),
  constraint shipments_return_time_check check (status <> 'returned' or returned_at is not null),
  constraint shipments_version_positive check (version > 0)
);

comment on table public.shipments is 'Courier consignments with frozen commercial and courier-rate snapshots.';
comment on column public.shipments.expected_cod_minor is 'Contractual COD obligation, independent of courier-reported collection.';

create unique index shipments_tracking_unique_idx
  on public.shipments (organization_id, courier_id, tracking_number)
  where tracking_number is not null;

create table public.shipment_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  shipment_id uuid not null,
  order_item_id uuid not null,
  quantity integer not null,
  delivered_quantity integer not null default 0,
  returned_quantity integer not null default 0,
  unit_sale_price_minor bigint not null,
  gross_product_amount_minor bigint not null,
  discount_amount_minor bigint not null default 0,
  net_product_amount_minor bigint not null,
  shipping_revenue_allocation_minor bigint not null default 0,
  deposit_allocation_minor bigint not null default 0,
  cod_obligation_minor bigint not null default 0,
  unit_cost_minor bigint not null,
  delivery_fee_allocation_minor bigint not null default 0,
  delivered_at timestamptz,
  revenue_journal_entry_id uuid,
  return_journal_entry_id uuid,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint shipment_items_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint shipment_items_shipment_fk foreign key (shipment_id) references public.shipments (id),
  constraint shipment_items_order_item_fk foreign key (order_item_id) references public.order_items (id),
  constraint shipment_items_quantity_positive check (quantity > 0),
  constraint shipment_items_quantity_flow check (
    delivered_quantity between 0 and quantity
    and returned_quantity between 0 and delivered_quantity
  ),
  constraint shipment_items_amounts_nonnegative check (
    unit_sale_price_minor >= 0 and gross_product_amount_minor >= 0
    and discount_amount_minor >= 0 and net_product_amount_minor >= 0
    and shipping_revenue_allocation_minor >= 0 and deposit_allocation_minor >= 0
    and cod_obligation_minor >= 0 and unit_cost_minor >= 0
    and delivery_fee_allocation_minor >= 0
  ),
  constraint shipment_items_gross_matches check (
    gross_product_amount_minor::numeric = quantity::numeric * unit_sale_price_minor::numeric
  ),
  constraint shipment_items_net_matches check (
    net_product_amount_minor = gross_product_amount_minor - discount_amount_minor
  ),
  constraint shipment_items_discount_within_gross check (discount_amount_minor <= gross_product_amount_minor),
  constraint shipment_items_delivery_timestamp_check check (delivered_quantity = 0 or delivered_at is not null),
  constraint shipment_items_version_positive check (version > 0),
  constraint shipment_items_order_item_unique unique (shipment_id, order_item_id)
);

comment on table public.shipment_items is 'Item-level quantities and frozen allocations used for partial delivery and return posting.';

create table public.shipment_status_history (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  shipment_id uuid not null,
  from_status public.shipment_status,
  to_status public.shipment_status not null,
  reason text,
  evidence_attachment_id uuid,
  occurred_at timestamptz not null,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint shipment_status_history_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint shipment_status_history_shipment_fk foreign key (shipment_id) references public.shipments (id),
  constraint shipment_status_history_transition_check check (from_status is null or from_status <> to_status)
);

comment on table public.shipment_status_history is 'Append-only courier shipment state evidence.';

create table public.returns (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  shipment_id uuid not null,
  return_no text not null,
  status text not null default 'requested',
  requested_at timestamptz not null,
  received_at timestamptz,
  inspected_at timestamptz,
  courier_return_fee_minor bigint not null default 0,
  total_business_loss_minor bigint not null default 0,
  reason text not null,
  evidence_attachment_id uuid,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint returns_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint returns_shipment_fk foreign key (shipment_id) references public.shipments (id),
  constraint returns_number_not_blank check (btrim(return_no) <> ''),
  constraint returns_status_check check (status in ('requested', 'in_transit', 'received', 'inspected', 'resolved', 'cancelled')),
  constraint returns_amounts_nonnegative check (courier_return_fee_minor >= 0 and total_business_loss_minor >= 0),
  constraint returns_reason_not_blank check (btrim(reason) <> ''),
  constraint returns_received_time_check check (status not in ('received', 'inspected', 'resolved') or received_at is not null),
  constraint returns_inspected_time_check check (status not in ('inspected', 'resolved') or inspected_at is not null),
  constraint returns_version_positive check (version > 0),
  constraint returns_number_unique unique (organization_id, return_no)
);

comment on table public.returns is 'Return headers separating courier fee from Falcon total business loss.';

create table public.return_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  return_id uuid not null,
  shipment_item_id uuid not null,
  quantity integer not null,
  disposition public.return_disposition not null default 'pending_inspection',
  product_loss_minor bigint not null default 0,
  packaging_loss_minor bigint not null default 0,
  reprint_cost_minor bigint not null default 0,
  operational_error_cost_minor bigint not null default 0,
  refundable_amount_minor bigint not null default 0,
  inventory_movement_id uuid,
  reason text not null,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint return_items_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint return_items_return_fk foreign key (return_id) references public.returns (id),
  constraint return_items_shipment_item_fk foreign key (shipment_item_id) references public.shipment_items (id),
  constraint return_items_inventory_movement_fk foreign key (inventory_movement_id) references public.inventory_movements (id),
  constraint return_items_quantity_positive check (quantity > 0),
  constraint return_items_amounts_nonnegative check (
    product_loss_minor >= 0 and packaging_loss_minor >= 0 and reprint_cost_minor >= 0
    and operational_error_cost_minor >= 0 and refundable_amount_minor >= 0
  ),
  constraint return_items_reason_not_blank check (btrim(reason) <> ''),
  constraint return_items_unique_shipment_item unique (return_id, shipment_item_id)
);

comment on table public.return_items is 'Specific delivered quantities reversed or dispositioned by a return.';

create or replace function private.enforce_shipment_item_quantity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ordered_quantity integer;
  v_other_quantity bigint;
  v_shipment_cancelled boolean;
begin
  select oi.quantity into strict v_ordered_quantity
  from public.order_items as oi
  where oi.organization_id = new.organization_id and oi.id = new.order_item_id
  for update;

  select s.status = 'cancelled' into strict v_shipment_cancelled
  from public.shipments as s
  where s.organization_id = new.organization_id and s.id = new.shipment_id;

  select coalesce(sum(si.quantity), 0) into v_other_quantity
  from public.shipment_items as si
  join public.shipments as s on s.id = si.shipment_id and s.organization_id = si.organization_id
  where si.organization_id = new.organization_id
    and si.order_item_id = new.order_item_id
    and si.id is distinct from new.id
    and s.status <> 'cancelled';

  if not v_shipment_cancelled and v_other_quantity + new.quantity > v_ordered_quantity then
    raise exception using errcode = '23514', message = 'SHIPMENT_QUANTITY_EXCEEDS_ORDER_ITEM';
  end if;
  return new;
end;
$$;

create or replace function private.enforce_return_item_quantity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_delivered_quantity integer;
  v_other_quantity bigint;
  v_return_cancelled boolean;
begin
  select si.delivered_quantity into strict v_delivered_quantity
  from public.shipment_items as si
  where si.organization_id = new.organization_id and si.id = new.shipment_item_id
  for update;

  select r.status = 'cancelled' into strict v_return_cancelled
  from public.returns as r
  where r.organization_id = new.organization_id and r.id = new.return_id;

  select coalesce(sum(ri.quantity), 0) into v_other_quantity
  from public.return_items as ri
  join public.returns as r on r.id = ri.return_id and r.organization_id = ri.organization_id
  where ri.organization_id = new.organization_id
    and ri.shipment_item_id = new.shipment_item_id
    and ri.id is distinct from new.id
    and r.status <> 'cancelled';

  if not v_return_cancelled and v_other_quantity + new.quantity > v_delivered_quantity then
    raise exception using errcode = '23514', message = 'RETURN_QUANTITY_EXCEEDS_DELIVERED_QUANTITY';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_shipment_item_quantity() from public, anon, authenticated;
revoke all on function private.enforce_return_item_quantity() from public, anon, authenticated;

create trigger shipment_items_enforce_aggregate_quantity
before insert or update of organization_id, shipment_id, order_item_id, quantity on public.shipment_items
for each row execute function private.enforce_shipment_item_quantity();

create trigger return_items_enforce_aggregate_quantity
before insert or update of organization_id, return_id, shipment_item_id, quantity on public.return_items
for each row execute function private.enforce_return_item_quantity();

create table public.courier_settlements (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  courier_id uuid not null,
  settlement_no text not null,
  period_start date not null,
  period_end date not null,
  expected_settlement_date date not null,
  actual_settlement_date date,
  status public.settlement_status not null default 'draft',
  contractual_cod_minor bigint not null default 0,
  delivery_fees_minor bigint not null default 0,
  return_fees_minor bigint not null default 0,
  approved_deductions_minor bigint not null default 0,
  adjustments_minor bigint not null default 0,
  prior_carry_forward_minor bigint not null default 0,
  expected_net_settlement_minor bigint not null default 0,
  actual_transfer_minor bigint,
  difference_minor bigint,
  difference_classification text,
  difference_explanation text,
  evidence_attachment_id uuid,
  approval_request_id uuid,
  is_off_cycle boolean not null default false,
  off_cycle_reason text,
  wallet_id uuid,
  journal_entry_id uuid,
  posted_at timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint courier_settlements_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint courier_settlements_courier_fk foreign key (courier_id) references public.couriers (id),
  constraint courier_settlements_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint courier_settlements_wallet_fk foreign key (wallet_id) references public.wallets (id),
  constraint courier_settlements_number_not_blank check (btrim(settlement_no) <> ''),
  constraint courier_settlements_period_check check (period_end >= period_start),
  constraint courier_settlements_components_nonnegative check (
    contractual_cod_minor >= 0 and delivery_fees_minor >= 0
    and return_fees_minor >= 0 and approved_deductions_minor >= 0
  ),
  constraint courier_settlements_expected_net_matches check (
    expected_net_settlement_minor::numeric = contractual_cod_minor::numeric
      - delivery_fees_minor::numeric - return_fees_minor::numeric
      - approved_deductions_minor::numeric + adjustments_minor::numeric
      + prior_carry_forward_minor::numeric
  ),
  constraint courier_settlements_difference_matches check (
    (actual_transfer_minor is null and difference_minor is null)
    or (
      actual_transfer_minor is not null and difference_minor is not null
      and difference_minor::numeric = actual_transfer_minor::numeric - expected_net_settlement_minor::numeric
    )
  ),
  constraint courier_settlements_difference_controls check (
    difference_minor is null or difference_minor = 0
    or (
      nullif(btrim(difference_classification), '') is not null
      and nullif(btrim(difference_explanation), '') is not null
      and evidence_attachment_id is not null
      and approval_request_id is not null
    )
  ),
  constraint courier_settlements_off_cycle_reason_check check (
    not is_off_cycle or nullif(btrim(off_cycle_reason), '') is not null
  ),
  constraint courier_settlements_posted_fields_check check (
    status <> 'posted' or (posted_at is not null and wallet_id is not null and journal_entry_id is not null)
  ),
  constraint courier_settlements_version_positive check (version > 0),
  constraint courier_settlements_number_unique unique (organization_id, settlement_no)
);

comment on table public.courier_settlements is 'Courier reconciliation aggregate; totals derive from immutable settlement lines.';

create table public.courier_settlement_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  courier_settlement_id uuid not null,
  line_type public.courier_settlement_line_type not null,
  shipment_id uuid,
  shipment_item_id uuid,
  return_id uuid,
  source_event_key text not null,
  amount_minor bigint not null,
  courier_reported_amount_minor bigint,
  is_active boolean not null default true,
  description text not null,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint courier_settlement_items_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint courier_settlement_items_settlement_fk foreign key (courier_settlement_id) references public.courier_settlements (id),
  constraint courier_settlement_items_shipment_fk foreign key (shipment_id) references public.shipments (id),
  constraint courier_settlement_items_shipment_item_fk foreign key (shipment_item_id) references public.shipment_items (id),
  constraint courier_settlement_items_return_fk foreign key (return_id) references public.returns (id),
  constraint courier_settlement_items_source_key_not_blank check (btrim(source_event_key) <> ''),
  constraint courier_settlement_items_amount_nonzero check (amount_minor <> 0),
  constraint courier_settlement_items_description_not_blank check (btrim(description) <> ''),
  constraint courier_settlement_items_source_present check (
    shipment_id is not null or shipment_item_id is not null or return_id is not null
    or line_type in ('adjustment', 'prior_carry_forward', 'remittance', 'claim', 'dispute')
  )
);

comment on table public.courier_settlement_items is 'Financially immutable settlement detail; only an active source claim may be released when its settlement is cancelled.';

create unique index courier_settlement_items_active_source_idx
  on public.courier_settlement_items (organization_id, source_event_key)
  where is_active;

create unique index supplier_payments_one_reversal_idx
  on public.supplier_payments (reverses_supplier_payment_id)
  where reverses_supplier_payment_id is not null;

create table public.expense_categories (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  code text not null,
  name text not null,
  requires_approval boolean not null default false,
  requires_evidence boolean not null default true,
  permits_order_allocation boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid,
  constraint expense_categories_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint expense_categories_code_not_blank check (btrim(code) <> ''),
  constraint expense_categories_name_not_blank check (btrim(name) <> ''),
  constraint expense_categories_code_unique unique (organization_id, code)
);

comment on table public.expense_categories is 'Configurable operating-expense categories and control requirements.';

create table public.expenses (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  expense_no text not null,
  expense_category_id uuid not null,
  business_date date not null,
  due_date date,
  status public.expense_status not null default 'draft',
  description text not null,
  subtotal_minor bigint not null,
  tax_minor bigint not null default 0,
  total_minor bigint not null,
  paid_minor bigint not null default 0,
  payable_counterparty_type text,
  payable_counterparty_id uuid,
  payable_name_snapshot text,
  order_id uuid,
  order_item_id uuid,
  approval_request_id uuid,
  evidence_required boolean not null default true,
  evidence_attachment_id uuid,
  journal_entry_id uuid,
  cancellation_reason text,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint expenses_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint expenses_category_fk foreign key (expense_category_id) references public.expense_categories (id),
  constraint expenses_order_fk foreign key (order_id) references public.orders (id),
  constraint expenses_order_item_fk foreign key (order_item_id) references public.order_items (id),
  constraint expenses_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint expenses_number_not_blank check (btrim(expense_no) <> ''),
  constraint expenses_description_not_blank check (btrim(description) <> ''),
  constraint expenses_amounts_nonnegative check (
    subtotal_minor >= 0 and tax_minor >= 0 and total_minor > 0 and paid_minor >= 0
  ),
  constraint expenses_total_matches check (total_minor = subtotal_minor + tax_minor),
  constraint expenses_paid_within_total check (paid_minor <= total_minor),
  constraint expenses_due_date_check check (due_date is null or due_date >= business_date),
  constraint expenses_payable_identity_check check (
    (payable_counterparty_type is null and payable_counterparty_id is null and payable_name_snapshot is null)
    or (nullif(btrim(payable_counterparty_type), '') is not null and nullif(btrim(payable_name_snapshot), '') is not null)
  ),
  constraint expenses_evidence_check check (
    status in ('draft', 'submitted') or not evidence_required or evidence_attachment_id is not null
  ),
  constraint expenses_cancel_reason_check check (
    status <> 'cancelled' or nullif(btrim(cancellation_reason), '') is not null
  ),
  constraint expenses_version_positive check (version > 0),
  constraint expenses_number_unique unique (organization_id, expense_no)
);

comment on table public.expenses is 'Expense and expense-payable obligations; order-direct costs remain separately allocatable.';

create table public.expense_payments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  expense_id uuid not null,
  wallet_id uuid not null,
  amount_minor bigint not null,
  payment_date date not null,
  provider_reference text,
  evidence_attachment_id uuid,
  journal_entry_id uuid,
  reverses_expense_payment_id uuid,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint expense_payments_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint expense_payments_expense_fk foreign key (expense_id) references public.expenses (id),
  constraint expense_payments_wallet_fk foreign key (wallet_id) references public.wallets (id),
  constraint expense_payments_reversal_fk foreign key (reverses_expense_payment_id) references public.expense_payments (id),
  constraint expense_payments_amount_positive check (amount_minor > 0),
  constraint expense_payments_not_self_reversal check (reverses_expense_payment_id is distinct from id)
);

comment on table public.expense_payments is 'Append-only partial or final settlement of an approved expense payable.';

create unique index expense_payments_one_reversal_idx
  on public.expense_payments (reverses_expense_payment_id)
  where reverses_expense_payment_id is not null;

create index print_batches_supplier_idx on public.print_batches (supplier_id);
create index print_batches_status_date_idx on public.print_batches (organization_id, status, business_date);
create index print_batch_items_batch_idx on public.print_batch_items (print_batch_id);
create index print_batch_items_order_item_idx on public.print_batch_items (order_item_id);
create index print_batch_items_replaced_attempt_idx on public.print_batch_items (replaces_print_batch_item_id);
create index print_batch_items_price_rule_idx on public.print_batch_items (supplier_price_rule_id) where supplier_price_rule_id is not null;
create index print_batch_receipts_batch_idx on public.print_batch_receipts (print_batch_id);
create index print_batch_receipt_items_receipt_idx on public.print_batch_receipt_items (print_batch_receipt_id);
create index print_batch_receipt_items_batch_item_idx on public.print_batch_receipt_items (print_batch_item_id);
create index print_batch_qc_events_receipt_item_idx on public.print_batch_qc_events (print_batch_receipt_item_id);
create index print_batch_qc_events_batch_item_idx on public.print_batch_qc_events (print_batch_item_id);
create index grni_accruals_batch_item_idx on public.grni_accruals (print_batch_item_id);
create index supplier_invoices_supplier_idx on public.supplier_invoices (supplier_id);
create index supplier_invoices_batch_idx on public.supplier_invoices (print_batch_id) where print_batch_id is not null;
create index supplier_invoices_approval_idx on public.supplier_invoices (approval_request_id) where approval_request_id is not null;
create index supplier_invoices_status_due_idx on public.supplier_invoices (organization_id, status, due_date);
create index supplier_invoice_items_invoice_idx on public.supplier_invoice_items (supplier_invoice_id);
create index supplier_invoice_items_batch_item_idx on public.supplier_invoice_items (print_batch_item_id);
create index supplier_invoice_items_grni_idx on public.supplier_invoice_items (grni_accrual_id) where grni_accrual_id is not null;
create index supplier_payments_invoice_idx on public.supplier_payments (supplier_invoice_id);
create index supplier_payments_wallet_idx on public.supplier_payments (wallet_id);
create index inventory_reservations_variant_location_idx on public.inventory_reservations (product_variant_id, location_id);
create index inventory_reservations_order_item_idx on public.inventory_reservations (order_item_id);
create index inventory_reservations_active_idx on public.inventory_reservations (organization_id, status) where status in ('active', 'partially_consumed');
create index inventory_movements_variant_date_idx on public.inventory_movements (organization_id, product_variant_id, accounting_date);
create index inventory_movements_from_location_idx on public.inventory_movements (from_location_id) where from_location_id is not null;
create index inventory_movements_to_location_idx on public.inventory_movements (to_location_id) where to_location_id is not null;
create index inventory_movements_reservation_idx on public.inventory_movements (inventory_reservation_id) where inventory_reservation_id is not null;
create index inventory_movements_batch_item_idx on public.inventory_movements (print_batch_item_id) where print_batch_item_id is not null;
create index inventory_movements_order_item_idx on public.inventory_movements (order_item_id) where order_item_id is not null;
create index inventory_movements_approval_idx on public.inventory_movements (approval_request_id) where approval_request_id is not null;
create index shipments_order_idx on public.shipments (order_id);
create index shipments_courier_status_idx on public.shipments (organization_id, courier_id, status);
create index shipment_items_shipment_idx on public.shipment_items (shipment_id);
create index shipment_items_order_item_idx on public.shipment_items (order_item_id);
create index shipment_status_history_shipment_time_idx on public.shipment_status_history (shipment_id, occurred_at);
create index returns_shipment_idx on public.returns (shipment_id);
create index returns_status_idx on public.returns (organization_id, status, requested_at);
create index return_items_return_idx on public.return_items (return_id);
create index return_items_shipment_item_idx on public.return_items (shipment_item_id);
create index return_items_inventory_movement_idx on public.return_items (inventory_movement_id) where inventory_movement_id is not null;
create index courier_settlements_courier_period_idx on public.courier_settlements (organization_id, courier_id, period_end);
create index courier_settlements_approval_idx on public.courier_settlements (approval_request_id) where approval_request_id is not null;
create index courier_settlements_wallet_idx on public.courier_settlements (wallet_id) where wallet_id is not null;
create index courier_settlement_items_settlement_idx on public.courier_settlement_items (courier_settlement_id);
create index courier_settlement_items_shipment_idx on public.courier_settlement_items (shipment_id) where shipment_id is not null;
create index courier_settlement_items_shipment_item_idx on public.courier_settlement_items (shipment_item_id) where shipment_item_id is not null;
create index courier_settlement_items_return_idx on public.courier_settlement_items (return_id) where return_id is not null;
create index expenses_category_idx on public.expenses (expense_category_id);
create index expenses_order_idx on public.expenses (order_id) where order_id is not null;
create index expenses_order_item_idx on public.expenses (order_item_id) where order_item_id is not null;
create index expenses_approval_idx on public.expenses (approval_request_id) where approval_request_id is not null;
create index expenses_status_due_idx on public.expenses (organization_id, status, due_date);
create index expense_payments_expense_idx on public.expense_payments (expense_id);
create index expense_payments_wallet_idx on public.expense_payments (wallet_id);

create or replace function private.reject_append_only_change()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = format('%I.%I is append-only', tg_table_schema, tg_table_name);
end;
$$;

comment on function private.reject_append_only_change() is 'Rejects update and delete on immutable operational and financial event rows.';
revoke all on function private.reject_append_only_change() from public, anon, authenticated;

create or replace function private.allow_settlement_item_deactivation_only()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using errcode = '55000', message = 'courier settlement items cannot be deleted';
  end if;

  if not (old.is_active and not new.is_active)
     or (to_jsonb(new) - 'is_active' - 'updated_at') is distinct from
        (to_jsonb(old) - 'is_active' - 'updated_at') then
    raise exception using errcode = '55000', message = 'only active settlement claim deactivation is permitted';
  end if;
  return new;
end;
$$;

revoke all on function private.allow_settlement_item_deactivation_only() from public, anon, authenticated;

create trigger print_batch_receipts_updated_at before update on public.print_batch_receipts
  for each row execute function private.set_updated_at();
create trigger print_batch_receipt_items_updated_at before update on public.print_batch_receipt_items
  for each row execute function private.set_updated_at();
create trigger print_batch_qc_events_updated_at before update on public.print_batch_qc_events
  for each row execute function private.set_updated_at();
create trigger grni_accruals_updated_at before update on public.grni_accruals
  for each row execute function private.set_updated_at();
create trigger supplier_payments_updated_at before update on public.supplier_payments
  for each row execute function private.set_updated_at();
create trigger inventory_movements_updated_at before update on public.inventory_movements
  for each row execute function private.set_updated_at();
create trigger shipment_status_history_updated_at before update on public.shipment_status_history
  for each row execute function private.set_updated_at();
create trigger courier_settlement_items_updated_at before update on public.courier_settlement_items
  for each row execute function private.set_updated_at();
create trigger expense_payments_updated_at before update on public.expense_payments
  for each row execute function private.set_updated_at();

create trigger print_batch_receipts_append_only before update or delete on public.print_batch_receipts
  for each row execute function private.reject_append_only_change();
create trigger print_batch_receipt_items_append_only before update or delete on public.print_batch_receipt_items
  for each row execute function private.reject_append_only_change();
create trigger print_batch_qc_events_append_only before update or delete on public.print_batch_qc_events
  for each row execute function private.reject_append_only_change();
create trigger grni_accruals_append_only before update or delete on public.grni_accruals
  for each row execute function private.reject_append_only_change();
create trigger supplier_payments_append_only before update or delete on public.supplier_payments
  for each row execute function private.reject_append_only_change();
create trigger inventory_movements_append_only before update or delete on public.inventory_movements
  for each row execute function private.reject_append_only_change();
create trigger shipment_status_history_append_only before update or delete on public.shipment_status_history
  for each row execute function private.reject_append_only_change();
create trigger courier_settlement_items_immutable_fields before update or delete on public.courier_settlement_items
  for each row execute function private.allow_settlement_item_deactivation_only();
create trigger expense_payments_append_only before update or delete on public.expense_payments
  for each row execute function private.reject_append_only_change();

create trigger print_batches_updated_at before update on public.print_batches
  for each row execute function private.set_updated_at();
create trigger print_batch_items_updated_at before update on public.print_batch_items
  for each row execute function private.set_updated_at();
create trigger supplier_invoices_updated_at before update on public.supplier_invoices
  for each row execute function private.set_updated_at();
create trigger supplier_invoice_items_updated_at before update on public.supplier_invoice_items
  for each row execute function private.set_updated_at();
create trigger inventory_locations_updated_at before update on public.inventory_locations
  for each row execute function private.set_updated_at();
create trigger inventory_reservations_updated_at before update on public.inventory_reservations
  for each row execute function private.set_updated_at();
create trigger shipments_updated_at before update on public.shipments
  for each row execute function private.set_updated_at();
create trigger shipment_items_updated_at before update on public.shipment_items
  for each row execute function private.set_updated_at();
create trigger returns_updated_at before update on public.returns
  for each row execute function private.set_updated_at();
create trigger return_items_updated_at before update on public.return_items
  for each row execute function private.set_updated_at();
create trigger courier_settlements_updated_at before update on public.courier_settlements
  for each row execute function private.set_updated_at();
create trigger expense_categories_updated_at before update on public.expense_categories
  for each row execute function private.set_updated_at();
create trigger expenses_updated_at before update on public.expenses
  for each row execute function private.set_updated_at();

alter table public.print_batches add constraint print_batches_organization_id_id_key unique (organization_id, id);
alter table public.print_batch_items add constraint print_batch_items_organization_id_id_key unique (organization_id, id);
alter table public.print_batch_receipts add constraint print_batch_receipts_organization_id_id_key unique (organization_id, id);
alter table public.print_batch_receipt_items add constraint print_batch_receipt_items_organization_id_id_key unique (organization_id, id);
alter table public.print_batch_qc_events add constraint print_batch_qc_events_organization_id_id_key unique (organization_id, id);
alter table public.grni_accruals add constraint grni_accruals_organization_id_id_key unique (organization_id, id);
alter table public.supplier_invoices add constraint supplier_invoices_organization_id_id_key unique (organization_id, id);
alter table public.supplier_invoice_items add constraint supplier_invoice_items_organization_id_id_key unique (organization_id, id);
alter table public.supplier_payments add constraint supplier_payments_organization_id_id_key unique (organization_id, id);
alter table public.inventory_locations add constraint inventory_locations_organization_id_id_key unique (organization_id, id);
alter table public.inventory_reservations add constraint inventory_reservations_organization_id_id_key unique (organization_id, id);
alter table public.inventory_movements add constraint inventory_movements_organization_id_id_key unique (organization_id, id);
alter table public.shipments add constraint shipments_organization_id_id_key unique (organization_id, id);
alter table public.shipment_items add constraint shipment_items_organization_id_id_key unique (organization_id, id);
alter table public.shipment_status_history add constraint shipment_status_history_organization_id_id_key unique (organization_id, id);
alter table public.returns add constraint returns_organization_id_id_key unique (organization_id, id);
alter table public.return_items add constraint return_items_organization_id_id_key unique (organization_id, id);
alter table public.courier_settlements add constraint courier_settlements_organization_id_id_key unique (organization_id, id);
alter table public.courier_settlement_items add constraint courier_settlement_items_organization_id_id_key unique (organization_id, id);
alter table public.expense_categories add constraint expense_categories_organization_id_id_key unique (organization_id, id);
alter table public.expenses add constraint expenses_organization_id_id_key unique (organization_id, id);
alter table public.expense_payments add constraint expense_payments_organization_id_id_key unique (organization_id, id);

alter table public.print_batches add constraint print_batches_supplier_org_fk
  foreign key (organization_id, supplier_id) references public.suppliers (organization_id, id);
alter table public.print_batch_items add constraint print_batch_items_batch_org_fk
  foreign key (organization_id, print_batch_id) references public.print_batches (organization_id, id);
alter table public.print_batch_items add constraint print_batch_items_order_item_org_fk
  foreign key (organization_id, order_item_id) references public.order_items (organization_id, id);
alter table public.print_batch_items add constraint print_batch_items_replaced_attempt_org_fk
  foreign key (organization_id, replaces_print_batch_item_id) references public.print_batch_items (organization_id, id);
alter table public.print_batch_items add constraint print_batch_items_price_rule_fk
  foreign key (supplier_price_rule_id) references public.supplier_price_rules (id);
alter table public.print_batch_receipts add constraint print_batch_receipts_batch_org_fk
  foreign key (organization_id, print_batch_id) references public.print_batches (organization_id, id);
alter table public.print_batch_receipt_items add constraint print_batch_receipt_items_receipt_org_fk
  foreign key (organization_id, print_batch_receipt_id) references public.print_batch_receipts (organization_id, id);
alter table public.print_batch_receipt_items add constraint print_batch_receipt_items_batch_item_org_fk
  foreign key (organization_id, print_batch_item_id) references public.print_batch_items (organization_id, id);
alter table public.print_batch_qc_events add constraint print_batch_qc_events_receipt_item_org_fk
  foreign key (organization_id, print_batch_receipt_item_id) references public.print_batch_receipt_items (organization_id, id);
alter table public.print_batch_qc_events add constraint print_batch_qc_events_batch_item_org_fk
  foreign key (organization_id, print_batch_item_id) references public.print_batch_items (organization_id, id);
alter table public.grni_accruals add constraint grni_accruals_qc_event_org_fk
  foreign key (organization_id, print_batch_qc_event_id) references public.print_batch_qc_events (organization_id, id);
alter table public.grni_accruals add constraint grni_accruals_batch_item_org_fk
  foreign key (organization_id, print_batch_item_id) references public.print_batch_items (organization_id, id);
alter table public.grni_accruals add constraint grni_accruals_reversal_org_fk
  foreign key (organization_id, reverses_grni_accrual_id) references public.grni_accruals (organization_id, id);
alter table public.supplier_invoices add constraint supplier_invoices_supplier_org_fk
  foreign key (organization_id, supplier_id) references public.suppliers (organization_id, id);
alter table public.supplier_invoices add constraint supplier_invoices_batch_org_fk
  foreign key (organization_id, print_batch_id) references public.print_batches (organization_id, id);
alter table public.supplier_invoices add constraint supplier_invoices_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.supplier_invoice_items add constraint supplier_invoice_items_invoice_org_fk
  foreign key (organization_id, supplier_invoice_id) references public.supplier_invoices (organization_id, id);
alter table public.supplier_invoice_items add constraint supplier_invoice_items_batch_item_org_fk
  foreign key (organization_id, print_batch_item_id) references public.print_batch_items (organization_id, id);
alter table public.supplier_invoice_items add constraint supplier_invoice_items_grni_org_fk
  foreign key (organization_id, grni_accrual_id) references public.grni_accruals (organization_id, id);
alter table public.supplier_payments add constraint supplier_payments_invoice_org_fk
  foreign key (organization_id, supplier_invoice_id) references public.supplier_invoices (organization_id, id);
alter table public.supplier_payments add constraint supplier_payments_wallet_org_fk
  foreign key (organization_id, wallet_id) references public.wallets (organization_id, id);
alter table public.supplier_payments add constraint supplier_payments_reversal_org_fk
  foreign key (organization_id, reverses_supplier_payment_id) references public.supplier_payments (organization_id, id);
alter table public.inventory_reservations add constraint inventory_reservations_variant_org_fk
  foreign key (organization_id, product_variant_id) references public.product_variants (organization_id, id);
alter table public.inventory_reservations add constraint inventory_reservations_location_org_fk
  foreign key (organization_id, location_id) references public.inventory_locations (organization_id, id);
alter table public.inventory_reservations add constraint inventory_reservations_order_item_org_fk
  foreign key (organization_id, order_item_id) references public.order_items (organization_id, id);
alter table public.inventory_movements add constraint inventory_movements_variant_org_fk
  foreign key (organization_id, product_variant_id) references public.product_variants (organization_id, id);
alter table public.inventory_movements add constraint inventory_movements_from_location_org_fk
  foreign key (organization_id, from_location_id) references public.inventory_locations (organization_id, id);
alter table public.inventory_movements add constraint inventory_movements_to_location_org_fk
  foreign key (organization_id, to_location_id) references public.inventory_locations (organization_id, id);
alter table public.inventory_movements add constraint inventory_movements_reservation_org_fk
  foreign key (organization_id, inventory_reservation_id) references public.inventory_reservations (organization_id, id);
alter table public.inventory_movements add constraint inventory_movements_batch_item_org_fk
  foreign key (organization_id, print_batch_item_id) references public.print_batch_items (organization_id, id);
alter table public.inventory_movements add constraint inventory_movements_order_item_org_fk
  foreign key (organization_id, order_item_id) references public.order_items (organization_id, id);
alter table public.inventory_movements add constraint inventory_movements_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.shipments add constraint shipments_order_org_fk
  foreign key (organization_id, order_id) references public.orders (organization_id, id);
alter table public.shipments add constraint shipments_courier_org_fk
  foreign key (organization_id, courier_id) references public.couriers (organization_id, id);
alter table public.shipment_items add constraint shipment_items_shipment_org_fk
  foreign key (organization_id, shipment_id) references public.shipments (organization_id, id);
alter table public.shipment_items add constraint shipment_items_order_item_org_fk
  foreign key (organization_id, order_item_id) references public.order_items (organization_id, id);
alter table public.shipment_status_history add constraint shipment_status_history_shipment_org_fk
  foreign key (organization_id, shipment_id) references public.shipments (organization_id, id);
alter table public.returns add constraint returns_shipment_org_fk
  foreign key (organization_id, shipment_id) references public.shipments (organization_id, id);
alter table public.return_items add constraint return_items_return_org_fk
  foreign key (organization_id, return_id) references public.returns (organization_id, id);
alter table public.return_items add constraint return_items_shipment_item_org_fk
  foreign key (organization_id, shipment_item_id) references public.shipment_items (organization_id, id);
alter table public.return_items add constraint return_items_inventory_movement_org_fk
  foreign key (organization_id, inventory_movement_id) references public.inventory_movements (organization_id, id);
alter table public.courier_settlements add constraint courier_settlements_courier_org_fk
  foreign key (organization_id, courier_id) references public.couriers (organization_id, id);
alter table public.courier_settlements add constraint courier_settlements_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.courier_settlements add constraint courier_settlements_wallet_org_fk
  foreign key (organization_id, wallet_id) references public.wallets (organization_id, id);
alter table public.courier_settlement_items add constraint courier_settlement_items_settlement_org_fk
  foreign key (organization_id, courier_settlement_id) references public.courier_settlements (organization_id, id);
alter table public.courier_settlement_items add constraint courier_settlement_items_shipment_org_fk
  foreign key (organization_id, shipment_id) references public.shipments (organization_id, id);
alter table public.courier_settlement_items add constraint courier_settlement_items_shipment_item_org_fk
  foreign key (organization_id, shipment_item_id) references public.shipment_items (organization_id, id);
alter table public.courier_settlement_items add constraint courier_settlement_items_return_org_fk
  foreign key (organization_id, return_id) references public.returns (organization_id, id);
alter table public.expenses add constraint expenses_category_org_fk
  foreign key (organization_id, expense_category_id) references public.expense_categories (organization_id, id);
alter table public.expenses add constraint expenses_order_org_fk
  foreign key (organization_id, order_id) references public.orders (organization_id, id);
alter table public.expenses add constraint expenses_order_item_org_fk
  foreign key (organization_id, order_item_id) references public.order_items (organization_id, id);
alter table public.expenses add constraint expenses_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.expense_payments add constraint expense_payments_expense_org_fk
  foreign key (organization_id, expense_id) references public.expenses (organization_id, id);
alter table public.expense_payments add constraint expense_payments_wallet_org_fk
  foreign key (organization_id, wallet_id) references public.wallets (organization_id, id);
alter table public.expense_payments add constraint expense_payments_reversal_org_fk
  foreign key (organization_id, reverses_expense_payment_id) references public.expense_payments (organization_id, id);
