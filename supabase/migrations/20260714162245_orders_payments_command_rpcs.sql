-- Transactional order and payment intake commands.

create or replace function private.command_confirm_order(
  p_organization_id uuid,
  p_order_id uuid,
  p_expected_version bigint,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_claim record;
  v_order public.orders;
  v_subtotal bigint;
  v_discount bigint;
  v_expected_cost bigint;
  v_allocated bigint;
  v_total bigint;
  v_result jsonb;
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'order_id', p_order_id,
    'expected_version', p_expected_version
  );
begin
  perform private.require_permission(p_organization_id, 'orders.confirm');
  perform private.assert_request_fingerprint('orders.confirm', v_payload, p_request_fingerprint, 1::smallint);

  if nullif(btrim(p_idempotency_key), '') is null then
    raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  select * into v_claim from private.claim_command(
    p_organization_id, 'orders.confirm', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    select o.* into strict v_order
    from public.orders as o
    where o.id = p_order_id and o.organization_id = p_organization_id
    for update;

    if v_order.version <> p_expected_version then
      raise exception using errcode = '40001', message = 'ORDER_VERSION_CONFLICT';
    end if;
    if v_order.status not in ('new', 'waiting_customer', 'waiting_deposit') then
      raise exception using errcode = '55000', message = 'ORDER_NOT_CONFIRMABLE';
    end if;
    if v_order.payment_policy_code_snapshot is null
       or v_order.payment_policy_version_snapshot is null
       or v_order.deposit_bps_snapshot is null
       or v_order.shipping_prepaid_required_snapshot is null then
      raise exception using errcode = '23514', message = 'ORDER_PAYMENT_POLICY_NOT_FROZEN';
    end if;

    select
      coalesce(sum(oi.line_gross_minor), 0),
      coalesce(sum(oi.line_discount_minor), 0),
      coalesce(sum(oi.unit_expected_cost_minor * oi.quantity::bigint), 0)
    into v_subtotal, v_discount, v_expected_cost
    from public.order_items as oi
    where oi.organization_id = p_organization_id and oi.order_id = p_order_id;

    if v_subtotal = 0 or not exists (
      select 1 from public.order_items as oi
      where oi.organization_id = p_organization_id and oi.order_id = p_order_id
    ) then
      raise exception using errcode = '23514', message = 'ORDER_ITEMS_REQUIRED';
    end if;

    v_total := v_subtotal - v_discount + v_order.shipping_charge_minor;
    select coalesce(sum(pa.amount_minor), 0) into v_allocated
    from public.payment_allocations as pa
    join public.customer_payments as cp
      on cp.organization_id = pa.organization_id
     and cp.id = pa.customer_payment_id
    where pa.organization_id = p_organization_id
      and pa.order_id = p_order_id
      and pa.reversed_at is null
      and cp.status = 'confirmed';

    if v_allocated < v_order.required_deposit_minor
       or (v_order.shipping_prepaid_required_snapshot
           and v_allocated < v_order.required_deposit_minor + v_order.shipping_charge_minor) then
      raise exception using errcode = '23514', message = 'REQUIRED_PREPAYMENT_NOT_MET';
    end if;

    update public.order_items
    set terms_frozen_at = coalesce(terms_frozen_at, statement_timestamp()),
        fulfillment_status = case when fulfillment_status = 'draft' then 'planned' else fulfillment_status end,
        costing_status = case when costing_status = 'estimated' then 'frozen' else costing_status end,
        version = version + 1
    where organization_id = p_organization_id and order_id = p_order_id;

    update public.orders
    set status = 'confirmed',
        products_subtotal_minor = v_subtotal,
        discount_total_minor = v_discount,
        order_total_minor = v_total,
        confirmed_payment_minor = least(v_allocated, v_total),
        balance_due_minor = greatest(v_total - v_allocated, 0),
        expected_cost_minor = v_expected_cost,
        expected_margin_minor = v_total - v_expected_cost,
        payment_status = case
          when v_allocated = 0 then 'no_payment'
          when v_allocated < v_order.required_deposit_minor then 'partial'
          when v_allocated < v_total then 'required_deposit_paid'
          when v_allocated = v_total then 'fully_prepaid'
          else 'overpaid'
        end,
        terms_frozen_at = statement_timestamp(),
        confirmed_at = statement_timestamp(),
        version = version + 1
    where id = p_order_id;

    insert into public.order_status_history (
      organization_id, order_id, previous_status, new_status, order_version,
      changed_by, reason, correlation_id
    ) values (
      p_organization_id, p_order_id, v_order.status, 'confirmed',
      v_order.version + 1, auth.uid(), 'order_terms_confirmed', p_correlation_id
    );

    v_result := private.command_success_response(
      v_claim.command_execution_id, p_order_id, 'confirmed', 'order.confirmed',
      '[]'::jsonb,
      jsonb_build_object(
        'order_total_minor', v_total,
        'balance_due_minor', greatest(v_total - v_allocated, 0),
        'version', v_order.version + 1
      )
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'orders.confirm', 'order', p_order_id, 'succeeded',
      null, p_correlation_id, v_claim.command_execution_id, p_idempotency_key,
      jsonb_build_object('order_total_minor', v_total, 'expected_cost_minor', v_expected_cost)
    );
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'orders.confirm', 'order',
        p_order_id, p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id,
      case when v_sqlstate = '42501' then 'PERMISSION_DENIED' else 'ORDER_CONFIRMATION_REJECTED' end,
      null
    );
    return private.command_replay_response(
      'failed_terminal', null,
      case when v_sqlstate = '42501' then 'PERMISSION_DENIED' else 'ORDER_CONFIRMATION_REJECTED' end,
      v_claim.command_execution_id
    );
  end;
end;
$$;

revoke all on function private.command_confirm_order(uuid, uuid, bigint, text, text, uuid)
  from public, anon, authenticated;

create or replace function private.command_grant_order_discount(
  p_organization_id uuid,
  p_order_id uuid,
  p_amount_minor bigint,
  p_includes_shipping boolean,
  p_source text,
  p_reason text,
  p_expected_version bigint,
  p_approval_request_id uuid,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_claim record;
  v_order public.orders;
  v_discount_id uuid;
  v_item_base bigint;
  v_shipping_discounted bigint;
  v_shipping_base bigint;
  v_eligible bigint;
  v_expected_cost bigint;
  v_margin_after bigint;
  v_max_bps integer;
  v_block_negative boolean;
  v_requires_approval boolean;
  v_result jsonb;
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'order_id', p_order_id,
    'amount_minor', p_amount_minor,
    'includes_shipping', p_includes_shipping,
    'source', p_source,
    'reason', p_reason,
    'expected_version', p_expected_version,
    'approval_request_id', p_approval_request_id
  );
begin
  perform private.require_permission(p_organization_id, 'discounts.grant');
  perform private.assert_request_fingerprint('orders.grant_discount', v_payload, p_request_fingerprint, 1::smallint);
  if p_amount_minor <= 0 or nullif(btrim(p_reason), '') is null
     or p_source not in ('moderator', 'partner_approved', 'campaign', 'correction') then
    raise exception using errcode = '22023', message = 'INVALID_DISCOUNT_REQUEST';
  end if;

  select * into v_claim from private.claim_command(
    p_organization_id, 'orders.grant_discount', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    select o.* into strict v_order
    from public.orders as o
    where o.id = p_order_id and o.organization_id = p_organization_id
    for update;
    if v_order.version <> p_expected_version then
      raise exception using errcode = '40001', message = 'ORDER_VERSION_CONFLICT';
    end if;
    if v_order.status not in ('new', 'waiting_customer', 'waiting_deposit') then
      raise exception using errcode = '55000', message = 'ORDER_DISCOUNT_TERMS_FROZEN';
    end if;

    select coalesce(sum(oi.line_revenue_minor), 0),
           coalesce(sum(oi.unit_expected_cost_minor * oi.quantity::bigint), 0)
    into v_item_base, v_expected_cost
    from public.order_items as oi
    where oi.organization_id = p_organization_id and oi.order_id = p_order_id;

    select coalesce(sum(oda.allocated_amount_minor), 0)
    into v_shipping_discounted
    from public.order_discount_allocations as oda
    where oda.organization_id = p_organization_id
      and oda.order_id = p_order_id
      and oda.allocation_target = 'shipping';

    v_shipping_base := case when p_includes_shipping
      then greatest(v_order.shipping_charge_minor - v_shipping_discounted, 0)
      else 0 end;
    v_eligible := v_item_base + v_shipping_base;
    if v_eligible <= 0 or p_amount_minor > v_eligible then
      raise exception using errcode = '23514', message = 'DISCOUNT_EXCEEDS_ELIGIBLE_BASE';
    end if;

    select s.moderator_max_discount_bps, s.block_negative_margin_for_moderator
    into strict v_max_bps, v_block_negative
    from private.organization_finance_settings as s
    where s.organization_id = p_organization_id
      and s.effective_from <= statement_timestamp()
      and (s.effective_to is null or s.effective_to > statement_timestamp())
    order by s.version_no desc
    limit 1;

    v_margin_after := v_order.order_total_minor - p_amount_minor - v_expected_cost;
    v_requires_approval := p_source = 'partner_approved'
      or p_amount_minor * 10000 > v_eligible * v_max_bps
      or (v_block_negative and v_margin_after < 0);

    if v_requires_approval then
      if p_approval_request_id is null then
        raise exception using errcode = '55000', message = 'DISCOUNT_APPROVAL_REQUIRED';
      end if;
      perform private.consume_approval(
        p_organization_id, p_approval_request_id, 'order.discount', 'order',
        p_order_id, p_request_fingerprint, v_claim.command_execution_id, p_amount_minor
      );
    end if;

    insert into public.order_discounts (
      organization_id, order_id, discount_type, source, amount_minor,
      eligible_base_minor, includes_shipping, expected_cost_snapshot_minor,
      expected_margin_after_discount_minor, allocation_fingerprint,
      approval_request_id, granted_by, reason
    ) values (
      p_organization_id, p_order_id, 'fixed_amount', p_source, p_amount_minor,
      v_eligible, p_includes_shipping, v_expected_cost, v_margin_after,
      p_request_fingerprint, p_approval_request_id, auth.uid(), p_reason
    ) returning id into v_discount_id;

    with targets as (
      select 'order_item'::text as target_type, oi.id as target_id,
             oi.line_revenue_minor as base_minor
      from public.order_items as oi
      where oi.organization_id = p_organization_id
        and oi.order_id = p_order_id
        and oi.line_revenue_minor > 0
      union all
      select 'shipping', null::uuid, v_shipping_base
      where v_shipping_base > 0
    ), raw as (
      select t.*,
             (p_amount_minor * t.base_minor) / v_eligible as floor_amount,
             (p_amount_minor * t.base_minor) % v_eligible as remainder_value
      from targets as t
    ), ranked as (
      select r.*,
             row_number() over (
               order by r.remainder_value desc, r.target_type, r.target_id nulls last
             ) as remainder_rank,
             p_amount_minor - sum(r.floor_amount) over () as units_to_distribute
      from raw as r
    )
    insert into public.order_discount_allocations (
      organization_id, order_discount_id, order_id, order_item_id,
      allocation_target, allocation_base_minor, allocated_amount_minor,
      remainder_rank
    )
    select p_organization_id, v_discount_id, p_order_id,
           case when target_type = 'order_item' then target_id end,
           target_type, base_minor,
           floor_amount + case when remainder_rank <= units_to_distribute then 1 else 0 end,
           remainder_rank
    from ranked;

    update public.order_items as oi
    set line_discount_minor = oi.line_discount_minor + a.allocated_amount_minor,
        line_revenue_minor = oi.line_revenue_minor - a.allocated_amount_minor,
        version = oi.version + 1
    from public.order_discount_allocations as a
    where a.order_discount_id = v_discount_id
      and a.allocation_target = 'order_item'
      and a.order_item_id = oi.id;

    update public.orders
    set discount_total_minor = discount_total_minor + p_amount_minor,
        order_total_minor = order_total_minor - p_amount_minor,
        balance_due_minor = greatest(balance_due_minor - p_amount_minor, 0),
        expected_margin_minor = expected_margin_minor - p_amount_minor,
        version = version + 1
    where id = p_order_id;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_discount_id, 'granted', 'order.discount_granted',
      '[]'::jsonb,
      jsonb_build_object(
        'order_id', p_order_id,
        'amount_minor', p_amount_minor,
        'expected_margin_after_discount_minor', v_margin_after,
        'version', v_order.version + 1
      )
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'orders.grant_discount', 'order_discount', v_discount_id,
      'succeeded', p_reason, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key,
      jsonb_build_object('order_id', p_order_id, 'amount_minor', p_amount_minor)
    );
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'orders.grant_discount',
        'order', p_order_id, p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'ORDER_DISCOUNT_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'ORDER_DISCOUNT_REJECTED', v_claim.command_execution_id
    );
  end;
end;
$$;

revoke all on function private.command_grant_order_discount(
  uuid, uuid, bigint, boolean, text, text, bigint, uuid, text, text, uuid
) from public, anon, authenticated;

create or replace function private.command_record_customer_payment(
  p_organization_id uuid,
  p_customer_id uuid,
  p_primary_order_id uuid,
  p_wallet_id uuid,
  p_amount_minor bigint,
  p_payment_method text,
  p_external_transaction_reference text,
  p_provider_name_snapshot text,
  p_paid_at timestamptz,
  p_evidence_attachment_id uuid,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_claim record;
  v_payment_id uuid;
  v_result jsonb;
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'customer_id', p_customer_id,
    'primary_order_id', p_primary_order_id,
    'wallet_id', p_wallet_id,
    'amount_minor', p_amount_minor,
    'payment_method', p_payment_method,
    'external_transaction_reference', p_external_transaction_reference,
    'provider_name_snapshot', p_provider_name_snapshot,
    'paid_at', p_paid_at,
    'evidence_attachment_id', p_evidence_attachment_id
  );
begin
  perform private.require_permission(p_organization_id, 'payments.record');
  perform private.assert_request_fingerprint('payments.record', v_payload, p_request_fingerprint, 1::smallint);
  if p_amount_minor <= 0 or p_paid_at > statement_timestamp() + interval '5 minutes' then
    raise exception using errcode = '22023', message = 'INVALID_PAYMENT_FACTS';
  end if;

  select * into v_claim from private.claim_command(
    p_organization_id, 'payments.record', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    perform 1 from public.customers as c
    where c.id = p_customer_id and c.organization_id = p_organization_id;
    if not found then
      raise exception using errcode = 'P0002', message = 'CUSTOMER_NOT_FOUND';
    end if;
    perform 1 from public.wallets as w
    where w.id = p_wallet_id and w.organization_id = p_organization_id and w.is_active
    for update;
    if not found then
      raise exception using errcode = 'P0002', message = 'ACTIVE_WALLET_NOT_FOUND';
    end if;
    if p_primary_order_id is not null and not exists (
      select 1 from public.orders as o
      where o.id = p_primary_order_id
        and o.organization_id = p_organization_id
        and o.customer_id = p_customer_id
    ) then
      raise exception using errcode = '23503', message = 'PAYMENT_ORDER_CUSTOMER_MISMATCH';
    end if;
    if p_evidence_attachment_id is not null and not exists (
      select 1 from public.attachments as a
      where a.id = p_evidence_attachment_id and a.organization_id = p_organization_id
    ) then
      raise exception using errcode = '23503', message = 'PAYMENT_EVIDENCE_SCOPE_MISMATCH';
    end if;

    insert into public.customer_payments (
      organization_id, customer_id, primary_order_id, wallet_id, amount_minor,
      payment_method, external_transaction_reference, provider_name_snapshot,
      paid_at, recorded_by, evidence_attachment_id, idempotency_key,
      request_fingerprint, correlation_id
    ) values (
      p_organization_id, p_customer_id, p_primary_order_id, p_wallet_id,
      p_amount_minor, p_payment_method, nullif(btrim(p_external_transaction_reference), ''),
      nullif(btrim(p_provider_name_snapshot), ''), p_paid_at, auth.uid(),
      p_evidence_attachment_id, p_idempotency_key, p_request_fingerprint,
      p_correlation_id
    ) returning id into v_payment_id;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_payment_id, 'pending_review',
      'payment.recorded'
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'payments.record', 'customer_payment', v_payment_id,
      'succeeded', null, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key, jsonb_build_object('amount_minor', p_amount_minor)
    );
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'payments.record',
        'customer_payment', null, p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'PAYMENT_RECORD_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'PAYMENT_RECORD_REJECTED', v_claim.command_execution_id
    );
  end;
end;
$$;

revoke all on function private.command_record_customer_payment(
  uuid, uuid, uuid, uuid, bigint, text, text, text, timestamptz, uuid,
  text, text, uuid
) from public, anon, authenticated;

create or replace function api.confirm_order(
  p_organization_id uuid,
  p_order_id uuid,
  p_expected_version bigint,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$
  select private.command_confirm_order(
    p_organization_id, p_order_id, p_expected_version, p_idempotency_key,
    p_request_fingerprint, p_correlation_id
  )
$$;

create or replace function api.grant_order_discount(
  p_organization_id uuid,
  p_order_id uuid,
  p_amount_minor bigint,
  p_includes_shipping boolean,
  p_source text,
  p_reason text,
  p_expected_version bigint,
  p_approval_request_id uuid,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$
  select private.command_grant_order_discount(
    p_organization_id, p_order_id, p_amount_minor, p_includes_shipping,
    p_source, p_reason, p_expected_version, p_approval_request_id,
    p_idempotency_key, p_request_fingerprint, p_correlation_id
  )
$$;

create or replace function api.record_customer_payment(
  p_organization_id uuid,
  p_customer_id uuid,
  p_primary_order_id uuid,
  p_wallet_id uuid,
  p_amount_minor bigint,
  p_payment_method text,
  p_external_transaction_reference text,
  p_provider_name_snapshot text,
  p_paid_at timestamptz,
  p_evidence_attachment_id uuid,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$
  select private.command_record_customer_payment(
    p_organization_id, p_customer_id, p_primary_order_id, p_wallet_id,
    p_amount_minor, p_payment_method, p_external_transaction_reference,
    p_provider_name_snapshot, p_paid_at, p_evidence_attachment_id,
    p_idempotency_key, p_request_fingerprint, p_correlation_id
  )
$$;

revoke all on function api.confirm_order(uuid, uuid, bigint, text, text, uuid)
  from public, anon, authenticated;
revoke all on function api.grant_order_discount(
  uuid, uuid, bigint, boolean, text, text, bigint, uuid, text, text, uuid
) from public, anon, authenticated;
revoke all on function api.record_customer_payment(
  uuid, uuid, uuid, uuid, bigint, text, text, text, timestamptz, uuid,
  text, text, uuid
) from public, anon, authenticated;

grant execute on function api.confirm_order(uuid, uuid, bigint, text, text, uuid)
  to authenticated;
grant execute on function api.grant_order_discount(
  uuid, uuid, bigint, boolean, text, text, bigint, uuid, text, text, uuid
) to authenticated;
grant execute on function api.record_customer_payment(
  uuid, uuid, uuid, uuid, bigint, text, text, text, timestamptz, uuid,
  text, text, uuid
) to authenticated;
