-- Transactional order cancellation, shipment, delivery, and return ownership.

insert into private.permissions (id, permission_key, description, is_sensitive)
select md5('falcon-permission:' || permission_key)::uuid, permission_key, description, true
from (values
  ('orders.return', 'Record and account for item-level customer returns'),
  ('orders.reverse_delivery', 'Reverse an incorrectly recorded delivery'),
  ('orders.reverse_return', 'Reverse an incorrectly recorded return')
) as p(permission_key, description)
on conflict (permission_key) do nothing;

alter table public.shipments
  add column delivery_journal_entry_id uuid,
  add constraint shipments_delivery_journal_fk
    foreign key (organization_id, delivery_journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict;

alter table public.returns
  add column journal_entry_id uuid,
  add column customer_credit_id uuid,
  add constraint returns_journal_fk
    foreign key (organization_id, journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  add constraint returns_customer_credit_fk
    foreign key (organization_id, customer_credit_id)
    references public.customer_credits(organization_id, id) on delete restrict;

create index shipments_delivery_journal_idx
  on public.shipments(organization_id, delivery_journal_entry_id)
  where delivery_journal_entry_id is not null;
create index returns_journal_idx
  on public.returns(organization_id, journal_entry_id)
  where journal_entry_id is not null;

create or replace function private.command_cancel_order(
  p_organization_id uuid,
  p_order_id uuid,
  p_reason text,
  p_expected_version bigint,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_claim record;
  v_order public.orders;
  v_result jsonb;
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id, 'order_id', p_order_id,
    'reason', p_reason, 'expected_version', p_expected_version
  );
begin
  perform private.require_permission(p_organization_id, 'orders.cancel');
  perform private.assert_request_fingerprint(
    'orders.cancel', v_payload, p_request_fingerprint, 1::smallint
  );
  if nullif(btrim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'CANCELLATION_REASON_REQUIRED';
  end if;
  select * into v_claim from private.claim_command(
    p_organization_id, 'orders.cancel', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;
  begin
    select o.* into strict v_order from public.orders as o
    where o.organization_id = p_organization_id and o.id = p_order_id
    for update;
    if v_order.version <> p_expected_version
       or v_order.status in ('cancelled','partially_delivered','delivered',
         'partially_returned','returned','financially_settled') then
      raise exception using errcode = '40001', message = 'ORDER_CANCELLATION_STATE_CONFLICT';
    end if;
    if exists (
      select 1 from public.payment_allocations as pa
      join public.customer_payments as cp
        on cp.organization_id = pa.organization_id and cp.id = pa.customer_payment_id
      where pa.organization_id = p_organization_id and pa.order_id = p_order_id
        and pa.reversed_at is null and cp.status = 'confirmed'
    ) then
      raise exception using errcode = '55000', message = 'ORDER_REFUND_REQUIRED_BEFORE_CANCELLATION';
    end if;
    if exists (
      select 1 from public.shipments as s
      where s.organization_id = p_organization_id and s.order_id = p_order_id
        and s.status <> 'cancelled'
    ) then
      raise exception using errcode = '55000', message = 'ACTIVE_SHIPMENT_PREVENTS_CANCELLATION';
    end if;

    update public.inventory_reservations as ir
    set released_quantity = quantity - consumed_quantity,
        status = 'released', version = version + 1
    from public.order_items as oi
    where oi.organization_id = p_organization_id and oi.order_id = p_order_id
      and ir.organization_id = oi.organization_id and ir.order_item_id = oi.id
      and ir.status in ('active','partially_consumed');
    update public.order_items
    set fulfillment_status = 'cancelled', version = version + 1
    where organization_id = p_organization_id and order_id = p_order_id;
    update public.orders
    set status = 'cancelled', cancelled_at = statement_timestamp(),
        cancellation_reason = p_reason, version = version + 1
    where id = p_order_id;
    insert into public.order_status_history (
      organization_id, order_id, previous_status, new_status, order_version,
      changed_by, reason, correlation_id
    ) values (
      p_organization_id, p_order_id, v_order.status, 'cancelled',
      v_order.version + 1, auth.uid(), p_reason, p_correlation_id
    );
    v_result := private.command_success_response(
      v_claim.command_execution_id, p_order_id, 'cancelled', 'order.cancelled'
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'orders.cancel',
        'order', p_order_id, p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(v_claim.command_execution_id, 'ORDER_CANCELLATION_REJECTED', null);
    return private.command_replay_response('failed_terminal', null, 'ORDER_CANCELLATION_REJECTED', v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_cancel_order(
  uuid, uuid, text, bigint, text, text, uuid
) from public, anon, authenticated;

create or replace function private.command_create_shipment(
  p_organization_id uuid,
  p_order_id uuid,
  p_courier_id uuid,
  p_shipping_rate_rule_id uuid,
  p_tracking_number text,
  p_shipment_kind public.shipment_kind,
  p_items jsonb,
  p_customer_shipping_charge_minor bigint,
  p_dispatch_evidence_attachment_id uuid,
  p_expected_order_version bigint,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_claim record;
  v_order public.orders;
  v_rate public.shipping_rate_rules;
  v_zone text;
  v_shipment_id uuid;
  v_consideration bigint;
  v_prior_deposit bigint;
  v_deposit_to_allocate bigint;
  v_expected_cod bigint;
  v_result jsonb;
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id, 'order_id', p_order_id,
    'courier_id', p_courier_id, 'shipping_rate_rule_id', p_shipping_rate_rule_id,
    'tracking_number', p_tracking_number, 'shipment_kind', p_shipment_kind,
    'items', p_items,
    'customer_shipping_charge_minor', p_customer_shipping_charge_minor,
    'dispatch_evidence_attachment_id', p_dispatch_evidence_attachment_id,
    'expected_order_version', p_expected_order_version
  );
begin
  perform private.require_permission(p_organization_id, 'shipments.create');
  perform private.assert_request_fingerprint(
    'shipments.create', v_payload, p_request_fingerprint, 1::smallint
  );
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0
     or nullif(btrim(p_tracking_number), '') is null
     or p_customer_shipping_charge_minor < 0 then
    raise exception using errcode = '22023', message = 'INVALID_SHIPMENT_REQUEST';
  end if;
  select * into v_claim from private.claim_command(
    p_organization_id, 'shipments.create', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;
  begin
    select o.* into strict v_order from public.orders as o
    where o.organization_id = p_organization_id and o.id = p_order_id
    for update;
    if v_order.version <> p_expected_order_version
       or v_order.status not in ('confirmed','received_from_printer','quality_check','ready_to_ship','partially_delivered') then
      raise exception using errcode = '40001', message = 'ORDER_NOT_SHIPPABLE';
    end if;
    select r.* into strict v_rate
    from public.shipping_rate_rules as r
    where r.organization_id = p_organization_id and r.id = p_shipping_rate_rule_id
      and r.courier_id = p_courier_id and r.is_active
      and r.effective_from <= private.cairo_accounting_date()
      and (r.effective_to is null or r.effective_to >= private.cairo_accounting_date())
    for update;
    select z.display_name into strict v_zone
    from public.shipping_zones as z
    where z.organization_id = p_organization_id and z.id = v_rate.shipping_zone_id
      and z.is_active;
    if p_customer_shipping_charge_minor + coalesce((
      select sum(s.customer_shipping_charge_minor) from public.shipments as s
      where s.organization_id = p_organization_id and s.order_id = p_order_id
        and s.status <> 'cancelled'
    ), 0) > v_order.shipping_charge_minor then
      raise exception using errcode = '23514', message = 'SHIPMENT_SHIPPING_CHARGE_EXCEEDS_ORDER';
    end if;

    perform 1 from public.order_items as oi
    join (
      select x.order_item_id from jsonb_to_recordset(p_items) as x(order_item_id uuid, quantity integer)
    ) as requested on requested.order_item_id = oi.id
    where oi.organization_id = p_organization_id and oi.order_id = p_order_id
    order by oi.id for update of oi;
    if exists (
      select 1
      from jsonb_to_recordset(p_items) as x(order_item_id uuid, quantity integer)
      left join public.order_items as oi
        on oi.organization_id = p_organization_id and oi.order_id = p_order_id
       and oi.id = x.order_item_id
      where x.order_item_id is null or x.quantity is null or x.quantity <= 0
        or oi.id is null
        or x.quantity + coalesce((
          select sum(si.quantity) from public.shipment_items as si
          join public.shipments as s on s.id = si.shipment_id and s.organization_id = si.organization_id
          where si.organization_id = p_organization_id and si.order_item_id = x.order_item_id
            and s.status <> 'cancelled'
        ), 0) > oi.quantity
    ) or exists (
      select x.order_item_id from jsonb_to_recordset(p_items) as x(order_item_id uuid, quantity integer)
      group by x.order_item_id having count(*) > 1
    ) then
      raise exception using errcode = '23514', message = 'SHIPMENT_ITEM_QUANTITY_INVALID';
    end if;

    insert into public.shipments (
      organization_id, order_id, courier_id, shipment_kind, tracking_number,
      status, settlement_status, shipping_zone_snapshot,
      customer_shipping_charge_minor, courier_delivery_fee_minor,
      courier_return_fee_minor, expected_cod_minor,
      dispatch_evidence_attachment_id, dispatched_at,
      created_by, updated_by
    ) values (
      p_organization_id, p_order_id, p_courier_id, p_shipment_kind,
      p_tracking_number, 'dispatched', 'unsettled', v_zone,
      p_customer_shipping_charge_minor, v_rate.delivery_fee_minor,
      v_rate.return_fee_minor, 0, p_dispatch_evidence_attachment_id,
      statement_timestamp(), auth.uid(), auth.uid()
    ) returning id into v_shipment_id;

    with requested as (
      select x.order_item_id, x.quantity, oi.quantity as order_quantity,
             oi.unit_sale_price_minor, oi.line_discount_minor,
             case when oi.costing_status in ('actual_complete','actual_partial') and oi.actual_cost_minor > 0
               then oi.actual_cost_minor / oi.quantity else oi.unit_expected_cost_minor end as unit_cost_minor,
             coalesce((select sum(si.quantity) from public.shipment_items si join public.shipments s on s.id=si.shipment_id
               where si.organization_id=p_organization_id and si.order_item_id=oi.id and s.status<>'cancelled'),0) as prior_quantity,
             coalesce((select sum(si.discount_amount_minor) from public.shipment_items si join public.shipments s on s.id=si.shipment_id
               where si.organization_id=p_organization_id and si.order_item_id=oi.id and s.status<>'cancelled'),0) as prior_discount
      from jsonb_to_recordset(p_items) as x(order_item_id uuid, quantity integer)
      join public.order_items oi on oi.organization_id=p_organization_id and oi.id=x.order_item_id
    ), economics as (
      select r.*,
        r.unit_sale_price_minor * r.quantity::bigint as gross_minor,
        case when r.prior_quantity + r.quantity = r.order_quantity
          then r.line_discount_minor - r.prior_discount
          else (r.line_discount_minor * r.quantity::bigint) / r.order_quantity end as discount_minor
      from requested r
    ), weights as (
      select e.*, (e.gross_minor-e.discount_minor) as net_minor,
        sum(e.gross_minor-e.discount_minor) over () as total_net
      from economics e
    ), shipping_raw as (
      select w.*,
        case when w.total_net=0 then 0 else (p_customer_shipping_charge_minor*w.net_minor)/w.total_net end as shipping_floor,
        case when w.total_net=0 then 0 else (p_customer_shipping_charge_minor*w.net_minor)%w.total_net end as shipping_remainder
      from weights w
    ), shipping_ranked as (
      select sr.*, row_number() over(order by shipping_remainder desc,order_item_id) as shipping_rank,
        p_customer_shipping_charge_minor-sum(shipping_floor) over() as shipping_units
      from shipping_raw sr
    )
    insert into public.shipment_items (
      organization_id, shipment_id, order_item_id, quantity,
      unit_sale_price_minor, gross_product_amount_minor, discount_amount_minor,
      net_product_amount_minor, shipping_revenue_allocation_minor,
      deposit_allocation_minor, cod_obligation_minor, unit_cost_minor,
      delivery_fee_allocation_minor, created_by, updated_by
    )
    select p_organization_id, v_shipment_id, order_item_id, quantity,
      unit_sale_price_minor, gross_minor, discount_minor, net_minor,
      shipping_floor + case when shipping_rank<=shipping_units then 1 else 0 end,
      0, 0, unit_cost_minor, 0, auth.uid(), auth.uid()
    from shipping_ranked;

    select sum(net_product_amount_minor + shipping_revenue_allocation_minor)
    into v_consideration from public.shipment_items where shipment_id=v_shipment_id;
    select coalesce(sum(si.deposit_allocation_minor),0) into v_prior_deposit
    from public.shipment_items si join public.shipments s on s.id=si.shipment_id
    where s.organization_id=p_organization_id and s.order_id=p_order_id
      and s.id<>v_shipment_id and s.status<>'cancelled';
    v_deposit_to_allocate := least(greatest(v_order.confirmed_payment_minor-v_prior_deposit,0),v_consideration);

    with raw as (
      select si.id, (si.net_product_amount_minor+si.shipping_revenue_allocation_minor) as weight,
        (v_deposit_to_allocate*(si.net_product_amount_minor+si.shipping_revenue_allocation_minor))/v_consideration as floor_amount,
        (v_deposit_to_allocate*(si.net_product_amount_minor+si.shipping_revenue_allocation_minor))%v_consideration as remainder_value
      from public.shipment_items si where si.shipment_id=v_shipment_id
    ), ranked as (
      select r.*,row_number() over(order by remainder_value desc,id) as remainder_rank,
        v_deposit_to_allocate-sum(floor_amount) over() as units_to_distribute
      from raw r
    ), fee_raw as (
      select ranked.*,(v_rate.delivery_fee_minor*weight)/v_consideration as fee_floor,
        (v_rate.delivery_fee_minor*weight)%v_consideration as fee_remainder
      from ranked
    ), fee_ranked as (
      select f.*,row_number() over(order by fee_remainder desc,id) as fee_rank,
        v_rate.delivery_fee_minor-sum(fee_floor) over() as fee_units
      from fee_raw f
    )
    update public.shipment_items si
    set deposit_allocation_minor=f.floor_amount+case when f.remainder_rank<=f.units_to_distribute then 1 else 0 end,
        cod_obligation_minor=f.weight-(f.floor_amount+case when f.remainder_rank<=f.units_to_distribute then 1 else 0 end),
        delivery_fee_allocation_minor=f.fee_floor+case when f.fee_rank<=f.fee_units then 1 else 0 end
    from fee_ranked f where si.id=f.id;
    select sum(cod_obligation_minor) into v_expected_cod from public.shipment_items where shipment_id=v_shipment_id;
    update public.shipments set expected_cod_minor=v_expected_cod where id=v_shipment_id;
    update public.orders set status='shipped',version=version+1 where id=p_order_id;
    insert into public.shipment_status_history(
      organization_id,shipment_id,from_status,to_status,reason,evidence_attachment_id,
      occurred_at,created_by,updated_by
    ) values(p_organization_id,v_shipment_id,'draft','dispatched','Shipment dispatched',
      p_dispatch_evidence_attachment_id,statement_timestamp(),auth.uid(),auth.uid());

    v_result:=private.command_success_response(v_claim.command_execution_id,v_shipment_id,'dispatched','shipment.created','[]'::jsonb,
      jsonb_build_object('expected_cod_minor',v_expected_cod));
    perform private.complete_command_success(v_claim.command_execution_id,v_result);
    return v_result;
  exception when others then
    v_sqlstate:=sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'shipments.create','shipment',null,p_idempotency_key,p_correlation_id);
    end if;
    perform private.complete_command_failure(v_claim.command_execution_id,'SHIPMENT_CREATION_REJECTED',null);
    return private.command_replay_response('failed_terminal',null,'SHIPMENT_CREATION_REJECTED',v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_create_shipment(
  uuid,uuid,uuid,uuid,text,public.shipment_kind,jsonb,bigint,uuid,bigint,text,text,uuid
) from public,anon,authenticated;

create or replace function private.command_mark_order_delivered(
  p_organization_id uuid,
  p_shipment_id uuid,
  p_delivery_evidence_attachment_id uuid,
  p_delivered_at timestamptz,
  p_reported_collected_cod_minor bigint,
  p_expected_shipment_version integer,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare
  v_claim record;
  v_shipment public.shipments;
  v_order public.orders;
  v_deposit bigint; v_cod bigint; v_gross bigint; v_discount bigint;
  v_shipping bigint; v_cost bigint; v_fee bigint;
  v_lines jsonb:='[]'::jsonb;
  v_journal_id uuid; v_order_state public.order_status;
  v_main_location_id uuid; v_result jsonb; v_sqlstate text; v_item record;
  v_payload jsonb:=jsonb_build_object(
    'organization_id',p_organization_id,'shipment_id',p_shipment_id,
    'delivery_evidence_attachment_id',p_delivery_evidence_attachment_id,
    'delivered_at',p_delivered_at,
    'reported_collected_cod_minor',p_reported_collected_cod_minor,
    'expected_shipment_version',p_expected_shipment_version
  );
begin
  perform private.require_permission(p_organization_id,'orders.deliver');
  perform private.assert_request_fingerprint('orders.deliver',v_payload,p_request_fingerprint,1::smallint);
  if p_delivered_at>statement_timestamp()+interval '5 minutes' or p_reported_collected_cod_minor<0 then
    raise exception using errcode='22023',message='INVALID_DELIVERY_FACTS';
  end if;
  select * into v_claim from private.claim_command(p_organization_id,'orders.deliver',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);
  if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id); end if;
  begin
    if not exists(select 1 from private.organization_finance_settings s where s.organization_id=p_organization_id
      and s.delivery_recognition_enabled and s.effective_from<=statement_timestamp()
      and (s.effective_to is null or s.effective_to>statement_timestamp())) then
      raise exception using errcode='55000',message='DELIVERY_RECOGNITION_DISABLED';
    end if;
    select s.* into strict v_shipment from public.shipments s where s.organization_id=p_organization_id and s.id=p_shipment_id for update;
    select o.* into strict v_order from public.orders o where o.organization_id=p_organization_id and o.id=v_shipment.order_id for update;
    if v_shipment.version<>p_expected_shipment_version or v_shipment.status<>'dispatched' then
      raise exception using errcode='40001',message='SHIPMENT_NOT_DELIVERABLE';
    end if;
    if p_delivery_evidence_attachment_id is null then raise exception using errcode='23514',message='DELIVERY_EVIDENCE_REQUIRED'; end if;
    perform 1 from public.shipment_items si where si.organization_id=p_organization_id and si.shipment_id=p_shipment_id order by si.id for update;
    select coalesce(sum(deposit_allocation_minor),0),coalesce(sum(cod_obligation_minor),0),
      coalesce(sum(gross_product_amount_minor),0),coalesce(sum(discount_amount_minor),0),
      coalesce(sum(shipping_revenue_allocation_minor),0),coalesce(sum(unit_cost_minor*quantity::bigint),0),
      coalesce(sum(delivery_fee_allocation_minor),0)
    into v_deposit,v_cod,v_gross,v_discount,v_shipping,v_cost,v_fee
    from public.shipment_items where organization_id=p_organization_id and shipment_id=p_shipment_id;
    if v_gross+v_shipping<=0 or v_deposit+v_cod<>v_gross-v_discount+v_shipping
       or v_fee<>v_shipment.courier_delivery_fee_minor then
      raise exception using errcode='23514',message='DELIVERY_ALLOCATION_NOT_CONSERVED';
    end if;
    if v_deposit>0 then v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_role','customer_deposits','debit_minor',v_deposit::text,'credit_minor','0','customer_id',v_order.customer_id,'order_id',v_order.id,'shipment_id',v_shipment.id,'subledger_type','shipment_delivery','subledger_id',v_shipment.id)); end if;
    if v_cod>0 then v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_role','courier_receivables','debit_minor',v_cod::text,'credit_minor','0','customer_id',v_order.customer_id,'order_id',v_order.id,'shipment_id',v_shipment.id,'subledger_type','courier_cod','subledger_id',v_shipment.id)); end if;
    if v_discount>0 then v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_role','sales_discounts','debit_minor',v_discount::text,'credit_minor','0','customer_id',v_order.customer_id,'order_id',v_order.id,'shipment_id',v_shipment.id,'subledger_type','shipment_discount','subledger_id',v_shipment.id)); end if;
    v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_role','gross_sales_revenue','debit_minor','0','credit_minor',(v_gross+v_shipping)::text,'customer_id',v_order.customer_id,'order_id',v_order.id,'shipment_id',v_shipment.id,'subledger_type','shipment_revenue','subledger_id',v_shipment.id));
    if v_cost>0 then v_lines:=v_lines||jsonb_build_array(
      jsonb_build_object('account_role','cost_of_goods_sold','debit_minor',v_cost::text,'credit_minor','0','order_id',v_order.id,'shipment_id',v_shipment.id,'subledger_type','shipment_cogs','subledger_id',v_shipment.id),
      jsonb_build_object('account_role','inventory','debit_minor','0','credit_minor',v_cost::text,'order_id',v_order.id,'shipment_id',v_shipment.id,'subledger_type','shipment_inventory','subledger_id',v_shipment.id)); end if;
    if v_fee>0 then v_lines:=v_lines||jsonb_build_array(
      jsonb_build_object('account_role','delivery_expense','debit_minor',v_fee::text,'credit_minor','0','shipment_id',v_shipment.id,'subledger_type','courier_fee','subledger_id',v_shipment.id),
      jsonb_build_object('account_role','courier_payables','debit_minor','0','credit_minor',v_fee::text,'shipment_id',v_shipment.id,'subledger_type','courier_fee','subledger_id',v_shipment.id)); end if;
    v_journal_id:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'shipment',p_source_id=>v_shipment.id,p_posting_purpose=>'delivery',p_description=>'Recognize delivered shipment',p_lines=>v_lines,p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_command_type=>'orders.deliver',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);

    select id into strict v_main_location_id from public.inventory_locations where organization_id=p_organization_id and code='FALCON_MAIN';
    for v_item in select si.*,oi.product_variant_id from public.shipment_items si join public.order_items oi on oi.id=si.order_item_id and oi.organization_id=si.organization_id where si.shipment_id=p_shipment_id order by si.id
    loop
      if v_item.product_variant_id is not null then
        insert into public.inventory_movements(organization_id,movement_type,product_variant_id,from_location_id,quantity,unit_cost_minor,total_cost_minor,order_item_id,source_type,source_id,correlation_id,reason,accounting_date,journal_entry_id,created_by,updated_by)
        values(p_organization_id,'sale',v_item.product_variant_id,v_main_location_id,v_item.quantity,v_item.unit_cost_minor,v_item.unit_cost_minor*v_item.quantity::bigint,v_item.order_item_id,'shipment_item',v_item.id,p_correlation_id,'Delivered to customer',private.cairo_accounting_date(),v_journal_id,auth.uid(),auth.uid());
      end if;
    end loop;
    update public.shipment_items set delivered_quantity=quantity,delivered_at=p_delivered_at,revenue_journal_entry_id=v_journal_id,version=version+1 where shipment_id=p_shipment_id;
    update public.shipments set status='delivered',delivery_evidence_attachment_id=p_delivery_evidence_attachment_id,delivered_at=p_delivered_at,reported_collected_cod_minor=p_reported_collected_cod_minor,delivery_journal_entry_id=v_journal_id,version=version+1 where id=p_shipment_id;
    v_order_state:=case when exists(
      select 1 from public.order_items oi where oi.organization_id=p_organization_id and oi.order_id=v_order.id and coalesce((select sum(si.delivered_quantity) from public.shipment_items si join public.shipments s on s.id=si.shipment_id where si.order_item_id=oi.id and s.status in('partially_delivered','delivered','returned')),0)<oi.quantity
    ) then 'partially_delivered' else 'delivered' end;
    update public.orders set status=v_order_state,delivered_at=case when v_order_state='delivered' then p_delivered_at else delivered_at end,actual_cost_minor=actual_cost_minor+v_cost,actual_margin_minor=actual_margin_minor+(v_gross-v_discount+v_shipping-v_cost-v_fee),version=version+1 where id=v_order.id;
    insert into public.shipment_status_history(organization_id,shipment_id,from_status,to_status,reason,evidence_attachment_id,occurred_at,created_by,updated_by)
    values(p_organization_id,v_shipment.id,'dispatched','delivered','Delivery evidence accepted',p_delivery_evidence_attachment_id,p_delivered_at,auth.uid(),auth.uid());
    v_result:=private.command_success_response(v_claim.command_execution_id,v_shipment.id,'delivered','shipment.delivered',jsonb_build_array(v_journal_id),jsonb_build_object('order_state',v_order_state,'contractual_cod_minor',v_cod));
    perform private.complete_command_success(v_claim.command_execution_id,v_result); return v_result;
  exception when others then
    v_sqlstate:=sqlstate; if private.is_retryable_sqlstate(v_sqlstate) then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'orders.deliver','shipment',p_shipment_id,p_idempotency_key,p_correlation_id); end if;
    perform private.complete_command_failure(v_claim.command_execution_id,'DELIVERY_REJECTED',null); return private.command_replay_response('failed_terminal',null,'DELIVERY_REJECTED',v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_mark_order_delivered(uuid,uuid,uuid,timestamptz,bigint,integer,text,text,uuid) from public,anon,authenticated;

create or replace function private.command_record_order_return(
  p_organization_id uuid,
  p_shipment_id uuid,
  p_return_number text,
  p_items jsonb,
  p_reason text,
  p_evidence_attachment_id uuid,
  p_expected_shipment_version integer,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql volatile security definer set search_path=''
as $$
declare
  v_claim record; v_shipment public.shipments; v_order public.orders;
  v_return_id uuid; v_credit_id uuid; v_journal_id uuid;
  v_refund bigint; v_resellable_cost bigint; v_return_fee bigint;
  v_lines jsonb; v_location_id uuid; v_row record; v_result jsonb; v_sqlstate text;
  v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'shipment_id',p_shipment_id,'return_number',p_return_number,'items',p_items,'reason',p_reason,'evidence_attachment_id',p_evidence_attachment_id,'expected_shipment_version',p_expected_shipment_version);
begin
  perform private.require_permission(p_organization_id,'orders.return');
  perform private.assert_request_fingerprint('orders.return',v_payload,p_request_fingerprint,1::smallint);
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 or nullif(btrim(p_return_number),'') is null or nullif(btrim(p_reason),'') is null or p_evidence_attachment_id is null then raise exception using errcode='22023',message='INVALID_RETURN_REQUEST'; end if;
  select * into v_claim from private.claim_command(p_organization_id,'orders.return',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);
  if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id); end if;
  begin
    select s.* into strict v_shipment from public.shipments s where s.organization_id=p_organization_id and s.id=p_shipment_id for update;
    select o.* into strict v_order from public.orders o where o.organization_id=p_organization_id and o.id=v_shipment.order_id for update;
    if v_shipment.version<>p_expected_shipment_version or v_shipment.status not in('delivered','partially_delivered') then raise exception using errcode='40001',message='SHIPMENT_NOT_RETURNABLE'; end if;
    perform 1 from public.shipment_items si join (select x.shipment_item_id from jsonb_to_recordset(p_items) x(shipment_item_id uuid,quantity integer,disposition text,reason text)) q on q.shipment_item_id=si.id where si.organization_id=p_organization_id and si.shipment_id=p_shipment_id order by si.id for update of si;
    if exists(select 1 from jsonb_to_recordset(p_items) x(shipment_item_id uuid,quantity integer,disposition text,reason text) left join public.shipment_items si on si.organization_id=p_organization_id and si.shipment_id=p_shipment_id and si.id=x.shipment_item_id where si.id is null or x.quantity is null or x.quantity<=0 or x.quantity>si.delivered_quantity-si.returned_quantity or x.disposition not in('resellable','damaged','reprint','discarded','not_returned') or nullif(btrim(x.reason),'') is null)
       or exists(select x.shipment_item_id from jsonb_to_recordset(p_items) x(shipment_item_id uuid,quantity integer,disposition text,reason text) group by x.shipment_item_id having count(*)>1) then raise exception using errcode='23514',message='RETURN_ITEM_QUANTITY_INVALID'; end if;
    insert into public.returns(organization_id,shipment_id,return_no,status,requested_at,received_at,inspected_at,courier_return_fee_minor,total_business_loss_minor,reason,evidence_attachment_id,created_by,updated_by)
    values(p_organization_id,p_shipment_id,p_return_number,'inspected',statement_timestamp(),statement_timestamp(),statement_timestamp(),v_shipment.courier_return_fee_minor,0,p_reason,p_evidence_attachment_id,auth.uid(),auth.uid()) returning id into v_return_id;
    insert into public.return_items(organization_id,return_id,shipment_item_id,quantity,disposition,product_loss_minor,packaging_loss_minor,reprint_cost_minor,operational_error_cost_minor,refundable_amount_minor,reason,created_by,updated_by)
    select p_organization_id,v_return_id,si.id,x.quantity,x.disposition::public.return_disposition,
      case when x.disposition in('damaged','discarded','not_returned') then si.unit_cost_minor*x.quantity::bigint else 0 end,
      0,case when x.disposition='reprint' then si.unit_cost_minor*x.quantity::bigint else 0 end,0,
      ((si.net_product_amount_minor+si.shipping_revenue_allocation_minor)*x.quantity::bigint)/si.delivered_quantity,
      x.reason,auth.uid(),auth.uid()
    from jsonb_to_recordset(p_items) x(shipment_item_id uuid,quantity integer,disposition text,reason text)
    join public.shipment_items si on si.id=x.shipment_item_id and si.organization_id=p_organization_id;
    select coalesce(sum(ri.refundable_amount_minor),0),coalesce(sum(case when ri.disposition='resellable' then si.unit_cost_minor*ri.quantity::bigint else 0 end),0),v_shipment.courier_return_fee_minor
    into v_refund,v_resellable_cost,v_return_fee from public.return_items ri join public.shipment_items si on si.id=ri.shipment_item_id where ri.return_id=v_return_id group by v_shipment.courier_return_fee_minor;
    if v_refund<=0 then raise exception using errcode='23514',message='RETURN_REFUND_AMOUNT_REQUIRED'; end if;
    insert into public.customer_credits(organization_id,customer_id,original_amount_minor,remaining_amount_minor,status,reason,created_by)
    values(p_organization_id,v_order.customer_id,v_refund,v_refund,'available','Credit from resolved order return',auth.uid()) returning id into v_credit_id;
    v_lines:=jsonb_build_array(
      jsonb_build_object('account_role','sales_returns','debit_minor',v_refund::text,'credit_minor','0','customer_id',v_order.customer_id,'order_id',v_order.id,'shipment_id',v_shipment.id,'subledger_type','order_return','subledger_id',v_return_id),
      jsonb_build_object('account_role','customer_credits','debit_minor','0','credit_minor',v_refund::text,'customer_id',v_order.customer_id,'order_id',v_order.id,'shipment_id',v_shipment.id,'subledger_type','customer_credit','subledger_id',v_credit_id));
    if v_resellable_cost>0 then v_lines:=v_lines||jsonb_build_array(
      jsonb_build_object('account_role','inventory','debit_minor',v_resellable_cost::text,'credit_minor','0','order_id',v_order.id,'shipment_id',v_shipment.id,'subledger_type','return_inventory','subledger_id',v_return_id),
      jsonb_build_object('account_role','cost_of_goods_sold','debit_minor','0','credit_minor',v_resellable_cost::text,'order_id',v_order.id,'shipment_id',v_shipment.id,'subledger_type','return_cogs','subledger_id',v_return_id)); end if;
    if v_return_fee>0 then v_lines:=v_lines||jsonb_build_array(
      jsonb_build_object('account_role','delivery_expense','debit_minor',v_return_fee::text,'credit_minor','0','shipment_id',v_shipment.id,'subledger_type','courier_return_fee','subledger_id',v_return_id),
      jsonb_build_object('account_role','courier_payables','debit_minor','0','credit_minor',v_return_fee::text,'shipment_id',v_shipment.id,'subledger_type','courier_return_fee','subledger_id',v_return_id)); end if;
    v_journal_id:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'customer_return',p_source_id=>v_return_id,p_posting_purpose=>'resolution',p_description=>'Resolve customer return',p_lines=>v_lines,p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_command_type=>'orders.return',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);
    insert into public.customer_credit_movements(organization_id,customer_id,customer_credit_id,movement_type,amount_minor,reason,correlation_id,created_by,journal_entry_id)
    values(p_organization_id,v_order.customer_id,v_credit_id,'issued',v_refund,'Resolved order return',p_correlation_id,auth.uid(),v_journal_id);
    select id into strict v_location_id from public.inventory_locations where organization_id=p_organization_id and code='RETURN_INSPECTION';
    for v_row in select ri.*,oi.product_variant_id,si.unit_cost_minor from public.return_items ri join public.shipment_items si on si.id=ri.shipment_item_id join public.order_items oi on oi.id=si.order_item_id where ri.return_id=v_return_id order by ri.id
    loop
      if v_row.disposition='resellable' and v_row.product_variant_id is not null then
        insert into public.inventory_movements(organization_id,movement_type,product_variant_id,to_location_id,quantity,unit_cost_minor,total_cost_minor,order_item_id,source_type,source_id,correlation_id,reason,accounting_date,journal_entry_id,created_by,updated_by)
        values(p_organization_id,'customer_return',v_row.product_variant_id,v_location_id,v_row.quantity,v_row.unit_cost_minor,v_row.quantity::bigint*v_row.unit_cost_minor,(select order_item_id from public.shipment_items where id=v_row.shipment_item_id),'return_item',v_row.id,p_correlation_id,v_row.reason,private.cairo_accounting_date(),v_journal_id,auth.uid(),auth.uid()) returning id into v_location_id;
        update public.return_items set inventory_movement_id=v_location_id where id=v_row.id;
        select id into v_location_id from public.inventory_locations where organization_id=p_organization_id and code='RETURN_INSPECTION';
      end if;
    end loop;
    update public.shipment_items si set returned_quantity=returned_quantity+ri.quantity,return_journal_entry_id=v_journal_id,version=version+1 from public.return_items ri where ri.return_id=v_return_id and ri.shipment_item_id=si.id;
    update public.returns set status='resolved',total_business_loss_minor=(select coalesce(sum(product_loss_minor+packaging_loss_minor+reprint_cost_minor+operational_error_cost_minor),0) from public.return_items where return_id=v_return_id),journal_entry_id=v_journal_id,customer_credit_id=v_credit_id,version=version+1 where id=v_return_id;
    update public.shipments set status=case when not exists(select 1 from public.shipment_items where shipment_id=p_shipment_id and returned_quantity<delivered_quantity) then 'returned' else status end,returned_at=case when not exists(select 1 from public.shipment_items where shipment_id=p_shipment_id and returned_quantity<delivered_quantity) then statement_timestamp() else returned_at end,return_evidence_attachment_id=p_evidence_attachment_id,version=version+1 where id=p_shipment_id;
    update public.orders set status=case when not exists(select 1 from public.shipment_items si join public.shipments s on s.id=si.shipment_id where s.order_id=v_order.id and si.returned_quantity<si.delivered_quantity) then 'returned' else 'partially_returned' end,payment_status='refund_due',version=version+1 where id=v_order.id;
    v_result:=private.command_success_response(v_claim.command_execution_id,v_return_id,'resolved','return.resolved',jsonb_build_array(v_journal_id),jsonb_build_object('customer_credit_id',v_credit_id,'refundable_amount_minor',v_refund));
    perform private.complete_command_success(v_claim.command_execution_id,v_result); return v_result;
  exception when others then
    v_sqlstate:=sqlstate; if private.is_retryable_sqlstate(v_sqlstate) then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'orders.return','return',null,p_idempotency_key,p_correlation_id); end if;
    perform private.complete_command_failure(v_claim.command_execution_id,'ORDER_RETURN_REJECTED',null); return private.command_replay_response('failed_terminal',null,'ORDER_RETURN_REJECTED',v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_record_order_return(uuid,uuid,text,jsonb,text,uuid,integer,text,text,uuid) from public,anon,authenticated;

create or replace function api.cancel_order(p_organization_id uuid,p_order_id uuid,p_reason text,p_expected_version bigint,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language sql volatile security invoker set search_path=''
as $$ select private.command_cancel_order(p_organization_id,p_order_id,p_reason,p_expected_version,p_idempotency_key,p_request_fingerprint,p_correlation_id) $$;

create or replace function api.create_shipment(p_organization_id uuid,p_order_id uuid,p_courier_id uuid,p_shipping_rate_rule_id uuid,p_tracking_number text,p_shipment_kind public.shipment_kind,p_items jsonb,p_customer_shipping_charge_minor bigint,p_dispatch_evidence_attachment_id uuid,p_expected_order_version bigint,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language sql volatile security invoker set search_path=''
as $$ select private.command_create_shipment(p_organization_id,p_order_id,p_courier_id,p_shipping_rate_rule_id,p_tracking_number,p_shipment_kind,p_items,p_customer_shipping_charge_minor,p_dispatch_evidence_attachment_id,p_expected_order_version,p_idempotency_key,p_request_fingerprint,p_correlation_id) $$;

create or replace function api.mark_order_delivered(p_organization_id uuid,p_shipment_id uuid,p_delivery_evidence_attachment_id uuid,p_delivered_at timestamptz,p_reported_collected_cod_minor bigint,p_expected_shipment_version integer,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language sql volatile security invoker set search_path=''
as $$ select private.command_mark_order_delivered(p_organization_id,p_shipment_id,p_delivery_evidence_attachment_id,p_delivered_at,p_reported_collected_cod_minor,p_expected_shipment_version,p_idempotency_key,p_request_fingerprint,p_correlation_id) $$;

create or replace function api.record_order_return(p_organization_id uuid,p_shipment_id uuid,p_return_number text,p_items jsonb,p_reason text,p_evidence_attachment_id uuid,p_expected_shipment_version integer,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language sql volatile security invoker set search_path=''
as $$ select private.command_record_order_return(p_organization_id,p_shipment_id,p_return_number,p_items,p_reason,p_evidence_attachment_id,p_expected_shipment_version,p_idempotency_key,p_request_fingerprint,p_correlation_id) $$;

revoke all on function api.cancel_order(uuid,uuid,text,bigint,text,text,uuid) from public,anon,authenticated;
revoke all on function api.create_shipment(uuid,uuid,uuid,uuid,text,public.shipment_kind,jsonb,bigint,uuid,bigint,text,text,uuid) from public,anon,authenticated;
revoke all on function api.mark_order_delivered(uuid,uuid,uuid,timestamptz,bigint,integer,text,text,uuid) from public,anon,authenticated;
revoke all on function api.record_order_return(uuid,uuid,text,jsonb,text,uuid,integer,text,text,uuid) from public,anon,authenticated;
grant execute on function api.cancel_order(uuid,uuid,text,bigint,text,text,uuid) to authenticated;
grant execute on function api.create_shipment(uuid,uuid,uuid,uuid,text,public.shipment_kind,jsonb,bigint,uuid,bigint,text,text,uuid) to authenticated;
grant execute on function api.mark_order_delivered(uuid,uuid,uuid,timestamptz,bigint,integer,text,text,uuid) to authenticated;
grant execute on function api.record_order_return(uuid,uuid,text,jsonb,text,uuid,integer,text,text,uuid) to authenticated;
grant execute on function private.command_cancel_order(uuid,uuid,text,bigint,text,text,uuid) to authenticated;
grant execute on function private.command_create_shipment(uuid,uuid,uuid,uuid,text,public.shipment_kind,jsonb,bigint,uuid,bigint,text,text,uuid) to authenticated;
grant execute on function private.command_mark_order_delivered(uuid,uuid,uuid,timestamptz,bigint,integer,text,text,uuid) to authenticated;
grant execute on function private.command_record_order_return(uuid,uuid,text,jsonb,text,uuid,integer,text,text,uuid) to authenticated;
