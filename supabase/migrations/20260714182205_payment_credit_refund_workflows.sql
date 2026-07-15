-- Payment allocation, customer-credit application, and approved refund lifecycle.

insert into private.permissions (id, permission_key, description, is_sensitive)
select md5('falcon-permission:' || permission_key)::uuid, permission_key, description, true
from (values
  ('payments.allocate', 'Allocate a confirmed receipt across orders and customer credit'),
  ('payments.reverse', 'Reverse a confirmed customer receipt'),
  ('credits.apply', 'Apply customer credit to an order'),
  ('refunds.reverse', 'Reverse an executed customer refund')
) as p(permission_key, description)
on conflict (permission_key) do nothing;

insert into accounting.accounts (
  id, organization_id, code, name, account_type, normal_balance,
  is_control_account, allows_manual_posting, metadata
)
select md5(o.id::text || ':account:refund_payable')::uuid, o.id, '2120',
       'Customer refunds payable', 'liability', 'credit', true, false,
       jsonb_build_object('system_role', 'refund_payable')
from public.organizations as o
on conflict (organization_id, code) do nothing;

insert into accounting.account_roles (
  id, organization_id, role_key, description, expected_account_type,
  is_required_for_close
)
select md5(o.id::text || ':role:refund_payable')::uuid, o.id,
       'refund_payable', 'Approved customer refunds awaiting payment',
       'liability', true
from public.organizations as o
on conflict (organization_id, role_key) do nothing;

insert into accounting.account_role_mappings (
  id, organization_id, account_role_id, account_id, valid_from, metadata
)
select md5(o.id::text || ':mapping:refund_payable')::uuid, o.id, ar.id, a.id,
       date '2020-01-01', jsonb_build_object('source', 'phase2_workflow')
from public.organizations as o
join accounting.account_roles as ar
  on ar.organization_id = o.id and ar.role_key = 'refund_payable'
join accounting.accounts as a
  on a.organization_id = o.id and a.code = '2120'
on conflict do nothing;

create table public.payment_allocation_batches (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  customer_payment_id uuid not null,
  allocated_to_orders_minor bigint not null,
  allocated_to_credit_minor bigint not null default 0,
  journal_entry_id uuid,
  idempotency_key text not null,
  request_fingerprint text not null,
  correlation_id uuid not null,
  created_by uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  constraint payment_allocation_batches_org_id_key unique (organization_id, id),
  constraint payment_allocation_batches_payment_fk
    foreign key (organization_id, customer_payment_id)
    references public.customer_payments(organization_id, id) on delete restrict,
  constraint payment_allocation_batches_journal_fk
    foreign key (organization_id, journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  constraint payment_allocation_batches_created_by_fk
    foreign key (organization_id, created_by)
    references public.profiles(organization_id, id) on delete restrict,
  constraint payment_allocation_batches_amount_check check (
    allocated_to_orders_minor >= 0 and allocated_to_credit_minor >= 0
    and allocated_to_orders_minor + allocated_to_credit_minor > 0
  ),
  constraint payment_allocation_batches_idempotency_key
    unique (organization_id, idempotency_key),
  constraint payment_allocation_batches_fingerprint_check
    check (request_fingerprint ~ '^[0-9a-f]{64}$')
);

create index payment_allocation_batches_payment_idx
  on public.payment_allocation_batches(organization_id, customer_payment_id);

alter table public.customer_credit_movements
  add column journal_entry_id uuid,
  add constraint customer_credit_movements_journal_fk
    foreign key (organization_id, journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict;

create index customer_credit_movements_journal_idx
  on public.customer_credit_movements(organization_id, journal_entry_id)
  where journal_entry_id is not null;

alter table public.refunds
  add column approval_journal_entry_id uuid,
  add column execution_journal_entry_id uuid,
  add column reversal_journal_entry_id uuid,
  add constraint refunds_approval_journal_fk
    foreign key (organization_id, approval_journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  add constraint refunds_execution_journal_fk
    foreign key (organization_id, execution_journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  add constraint refunds_reversal_journal_fk
    foreign key (organization_id, reversal_journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict;

create or replace function private.refresh_order_payment_projection(
  p_organization_id uuid,
  p_order_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_total bigint;
  v_required bigint;
  v_allocated bigint;
begin
  select o.order_total_minor, o.required_deposit_minor
  into strict v_total, v_required
  from public.orders as o
  where o.organization_id = p_organization_id and o.id = p_order_id
  for update;

  select coalesce(sum(x.amount_minor), 0) into v_allocated
  from (
    select pa.amount_minor
    from public.payment_allocations as pa
    join public.customer_payments as cp
      on cp.organization_id = pa.organization_id and cp.id = pa.customer_payment_id
    where pa.organization_id = p_organization_id and pa.order_id = p_order_id
      and pa.reversed_at is null and cp.status = 'confirmed'
    union all
    select -ccm.amount_minor
    from public.customer_credit_movements as ccm
    where ccm.organization_id = p_organization_id and ccm.order_id = p_order_id
      and ccm.movement_type = 'applied' and ccm.amount_minor < 0
  ) as x;

  update public.orders
  set confirmed_payment_minor = least(v_allocated, v_total),
      balance_due_minor = greatest(v_total - v_allocated, 0),
      payment_status = (case
        when v_allocated = 0 then 'no_payment'
        when v_allocated < v_required then 'partial'
        when v_allocated < v_total then 'required_deposit_paid'
        when v_allocated = v_total then 'fully_prepaid'
        else 'overpaid'
      end)::public.payment_status,
      version = version + 1
  where organization_id = p_organization_id and id = p_order_id;
end;
$$;

revoke all on function private.refresh_order_payment_projection(uuid, uuid)
  from public, anon, authenticated;

create or replace function private.command_allocate_customer_payment(
  p_organization_id uuid,
  p_customer_payment_id uuid,
  p_allocations jsonb,
  p_credit_remainder boolean,
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
  v_payment public.customer_payments;
  v_batch_id uuid;
  v_credit_id uuid;
  v_source_account_id uuid;
  v_requested bigint;
  v_already_allocated bigint;
  v_available bigint;
  v_credit_amount bigint;
  v_lines jsonb;
  v_journal_entry_id uuid;
  v_result jsonb;
  v_sqlstate text;
  v_row record;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'customer_payment_id', p_customer_payment_id,
    'allocations', p_allocations,
    'credit_remainder', p_credit_remainder
  );
begin
  perform private.require_permission(p_organization_id, 'payments.allocate');
  perform private.assert_request_fingerprint(
    'payments.allocate', v_payload, p_request_fingerprint, 1::smallint
  );
  if jsonb_typeof(p_allocations) <> 'array' then
    raise exception using errcode = '22023', message = 'ALLOCATIONS_MUST_BE_ARRAY';
  end if;
  select * into v_claim from private.claim_command(
    p_organization_id, 'payments.allocate', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    select cp.* into strict v_payment
    from public.customer_payments as cp
    where cp.organization_id = p_organization_id and cp.id = p_customer_payment_id
    for update;
    if v_payment.status <> 'confirmed' then
      raise exception using errcode = '55000', message = 'PAYMENT_NOT_CONFIRMED';
    end if;

    perform 1
    from public.orders as o
    join (
      select distinct x.order_id
      from jsonb_to_recordset(p_allocations) as x(order_id uuid, allocation_type text, amount_minor bigint)
    ) as requested on requested.order_id = o.id
    where o.organization_id = p_organization_id
    order by o.id
    for update of o;

    if exists (
      select 1
      from jsonb_to_recordset(p_allocations) as x(order_id uuid, allocation_type text, amount_minor bigint)
      left join public.orders as o
        on o.organization_id = p_organization_id and o.id = x.order_id
      where x.order_id is null or x.amount_minor is null or x.amount_minor <= 0
        or x.allocation_type not in (
          'product_deposit','shipping_prepayment','remaining_product_balance',
          'full_prepayment','customer_receivable'
        )
        or o.id is null or o.customer_id <> v_payment.customer_id
        or o.status in ('cancelled','returned')
    ) then
      raise exception using errcode = '23514', message = 'INVALID_PAYMENT_ALLOCATION';
    end if;

    select coalesce(sum(x.amount_minor), 0) into v_requested
    from jsonb_to_recordset(p_allocations) as x(order_id uuid, allocation_type text, amount_minor bigint);
    select coalesce(sum(pa.amount_minor), 0) into v_already_allocated
    from public.payment_allocations as pa
    where pa.organization_id = p_organization_id
      and pa.customer_payment_id = p_customer_payment_id
      and pa.reversed_at is null;
    v_available := v_payment.amount_minor - v_already_allocated;
    if v_available <= 0 or v_requested > v_available then
      raise exception using errcode = '23514', message = 'PAYMENT_ALLOCATION_EXCEEDS_AVAILABLE';
    end if;
    v_credit_amount := case when p_credit_remainder then v_available - v_requested else 0 end;
    if v_requested + v_credit_amount <= 0 then
      raise exception using errcode = '23514', message = 'EMPTY_PAYMENT_ALLOCATION';
    end if;

    insert into public.payment_allocation_batches (
      organization_id, customer_payment_id, allocated_to_orders_minor,
      allocated_to_credit_minor, idempotency_key, request_fingerprint,
      correlation_id, created_by
    ) values (
      p_organization_id, p_customer_payment_id, v_requested, v_credit_amount,
      p_idempotency_key, p_request_fingerprint, p_correlation_id, auth.uid()
    ) returning id into v_batch_id;

    insert into public.payment_allocations (
      organization_id, customer_id, customer_payment_id, order_id,
      allocation_type, amount_minor, allocated_by, allocation_fingerprint,
      correlation_id
    )
    select p_organization_id, v_payment.customer_id, v_payment.id, x.order_id,
           x.allocation_type, x.amount_minor, auth.uid(),
           private.canonical_request_fingerprint(
             'payments.allocate.line',
             jsonb_build_object('batch_id', v_batch_id, 'order_id', x.order_id,
               'allocation_type', x.allocation_type, 'amount_minor', x.amount_minor),
             1::smallint
           ), p_correlation_id
    from jsonb_to_recordset(p_allocations) as x(order_id uuid, allocation_type text, amount_minor bigint);

    if v_credit_amount > 0 then
      insert into public.customer_credits (
        organization_id, customer_id, source_payment_id, original_amount_minor,
        remaining_amount_minor, status, reason, created_by
      ) values (
        p_organization_id, v_payment.customer_id, v_payment.id, v_credit_amount,
        v_credit_amount, 'available', 'Unallocated confirmed receipt', auth.uid()
      ) returning id into v_credit_id;
      insert into public.payment_allocations (
        organization_id, customer_id, customer_payment_id, customer_credit_id,
        allocation_type, amount_minor, allocated_by, allocation_fingerprint,
        correlation_id
      ) values (
        p_organization_id, v_payment.customer_id, v_payment.id, v_credit_id,
        'customer_credit', v_credit_amount, auth.uid(),
        private.canonical_request_fingerprint(
          'payments.allocate.credit', jsonb_build_object('batch_id', v_batch_id,
            'credit_id', v_credit_id, 'amount_minor', v_credit_amount), 1::smallint
        ), p_correlation_id
      );
      insert into public.customer_credit_movements (
        organization_id, customer_id, customer_credit_id, movement_type,
        amount_minor, reason, correlation_id, created_by
      ) values (
        p_organization_id, v_payment.customer_id, v_credit_id, 'issued',
        v_credit_amount, 'Confirmed payment remainder', p_correlation_id, auth.uid()
      );
    end if;

    select jl.account_id into strict v_source_account_id
    from accounting.journal_entries as je
    join accounting.journal_lines as jl on jl.journal_entry_id = je.id
    where je.organization_id = p_organization_id
      and je.source_type = 'customer_payment' and je.source_id = v_payment.id
      and je.posting_purpose = 'receipt' and je.status = 'posted'
      and jl.credit_minor > 0
    order by jl.line_number limit 1;

    v_lines := jsonb_build_array(jsonb_build_object(
      'account_id', v_source_account_id,
      'debit_minor', (v_requested + v_credit_amount)::text,
      'credit_minor', '0', 'customer_id', v_payment.customer_id,
      'subledger_type', 'payment_allocation_batch', 'subledger_id', v_batch_id
    ));
    for v_row in
      select x.order_id, x.amount_minor, o.status
      from jsonb_to_recordset(p_allocations) as x(order_id uuid, allocation_type text, amount_minor bigint)
      join public.orders as o on o.id = x.order_id and o.organization_id = p_organization_id
      order by x.order_id
    loop
      v_lines := v_lines || jsonb_build_array(jsonb_build_object(
        'account_role', case when v_row.status in ('delivered','financially_settled')
          then 'customer_receivables' else 'customer_deposits' end,
        'debit_minor', '0', 'credit_minor', v_row.amount_minor::text,
        'customer_id', v_payment.customer_id, 'order_id', v_row.order_id,
        'subledger_type', 'order_payment', 'subledger_id', v_row.order_id
      ));
    end loop;
    if v_credit_amount > 0 then
      v_lines := v_lines || jsonb_build_array(jsonb_build_object(
        'account_role', 'customer_credits', 'debit_minor', '0',
        'credit_minor', v_credit_amount::text, 'customer_id', v_payment.customer_id,
        'subledger_type', 'customer_credit', 'subledger_id', v_credit_id
      ));
    end if;

    v_journal_entry_id := private.post_journal_entry(
      p_organization_id => p_organization_id, p_source_type => 'payment_allocation_batch',
      p_source_id => v_batch_id, p_posting_purpose => 'allocation',
      p_description => 'Allocate confirmed customer payment', p_lines => v_lines,
      p_idempotency_key => p_idempotency_key, p_request_hash => p_request_fingerprint,
      p_correlation_id => p_correlation_id, p_command_type => 'payments.allocate',
      p_command_execution_id => v_claim.command_execution_id,
      p_require_manual_permission => false
    );
    update public.payment_allocation_batches
    set journal_entry_id = v_journal_entry_id where id = v_batch_id;
    for v_row in select distinct x.order_id from jsonb_to_recordset(p_allocations) as x(order_id uuid, allocation_type text, amount_minor bigint)
    loop
      perform private.refresh_order_payment_projection(p_organization_id, v_row.order_id);
    end loop;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_batch_id, 'allocated', 'payment.allocated',
      jsonb_build_array(v_journal_entry_id),
      jsonb_build_object('customer_credit_id', v_credit_id,
        'allocated_minor', v_requested, 'credited_minor', v_credit_amount)
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(v_claim.command_execution_id, v_sqlstate,
        'payments.allocate', 'customer_payment', p_customer_payment_id,
        p_idempotency_key, p_correlation_id);
    end if;
    perform private.complete_command_failure(v_claim.command_execution_id, 'PAYMENT_ALLOCATION_REJECTED', null);
    return private.command_replay_response('failed_terminal', null,
      'PAYMENT_ALLOCATION_REJECTED', v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_allocate_customer_payment(uuid, uuid, jsonb, boolean, text, text, uuid)
  from public, anon, authenticated;

create or replace function private.command_apply_customer_credit(
  p_organization_id uuid,
  p_customer_credit_id uuid,
  p_order_id uuid,
  p_amount_minor bigint,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_claim record; v_credit public.customer_credits; v_order public.orders;
  v_movement_id uuid; v_journal_id uuid; v_result jsonb; v_sqlstate text;
  v_payload jsonb := jsonb_build_object('organization_id',p_organization_id,
    'customer_credit_id',p_customer_credit_id,'order_id',p_order_id,'amount_minor',p_amount_minor);
begin
  perform private.require_permission(p_organization_id, 'credits.apply');
  perform private.assert_request_fingerprint('credits.apply',v_payload,p_request_fingerprint,1::smallint);
  select * into v_claim from private.claim_command(p_organization_id,'credits.apply',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);
  if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id); end if;
  begin
    perform 1 from public.customer_credits where organization_id=p_organization_id and id=p_customer_credit_id for update;
    perform 1 from public.orders where organization_id=p_organization_id and id=p_order_id for update;
    select * into strict v_credit from public.customer_credits where organization_id=p_organization_id and id=p_customer_credit_id;
    select * into strict v_order from public.orders where organization_id=p_organization_id and id=p_order_id;
    if p_amount_minor <= 0 or p_amount_minor > v_credit.remaining_amount_minor
      or v_credit.status not in ('available','partially_used')
      or v_credit.customer_id <> v_order.customer_id or v_order.status in ('cancelled','returned') then
      raise exception using errcode='23514',message='CREDIT_APPLICATION_INVALID';
    end if;
    insert into public.customer_credit_movements(organization_id,customer_id,customer_credit_id,movement_type,amount_minor,order_id,reason,correlation_id,created_by)
    values(p_organization_id,v_credit.customer_id,v_credit.id,'applied',-p_amount_minor,p_order_id,'Applied to order',p_correlation_id,auth.uid()) returning id into v_movement_id;
    v_journal_id := private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'customer_credit_movement',p_source_id=>v_movement_id,p_posting_purpose=>'application',p_description=>'Apply customer credit to order',p_lines=>jsonb_build_array(
      jsonb_build_object('account_role','customer_credits','debit_minor',p_amount_minor::text,'credit_minor','0','customer_id',v_credit.customer_id,'subledger_type','customer_credit','subledger_id',v_credit.id),
      jsonb_build_object('account_role',case when v_order.status in ('delivered','financially_settled') then 'customer_receivables' else 'customer_deposits' end,'debit_minor','0','credit_minor',p_amount_minor::text,'customer_id',v_credit.customer_id,'order_id',v_order.id,'subledger_type','order_payment','subledger_id',v_order.id)
    ),p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_command_type=>'credits.apply',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);
    update public.customer_credit_movements set journal_entry_id=v_journal_id where id=v_movement_id;
    update public.customer_credits set remaining_amount_minor=remaining_amount_minor-p_amount_minor,status=case when remaining_amount_minor-p_amount_minor=0 then 'fully_used' else 'partially_used' end,closed_at=case when remaining_amount_minor-p_amount_minor=0 then statement_timestamp() else null end where id=v_credit.id;
    perform private.refresh_order_payment_projection(p_organization_id,p_order_id);
    v_result:=private.command_success_response(v_claim.command_execution_id,v_movement_id,'applied','credit.applied',jsonb_build_array(v_journal_id));
    perform private.complete_command_success(v_claim.command_execution_id,v_result); return v_result;
  exception when others then
    v_sqlstate:=sqlstate; if private.is_retryable_sqlstate(v_sqlstate) then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'credits.apply','customer_credit',p_customer_credit_id,p_idempotency_key,p_correlation_id); end if;
    perform private.complete_command_failure(v_claim.command_execution_id,'CREDIT_APPLICATION_REJECTED',null); return private.command_replay_response('failed_terminal',null,'CREDIT_APPLICATION_REJECTED',v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_apply_customer_credit(uuid,uuid,uuid,bigint,text,text,uuid) from public,anon,authenticated;

create or replace function api.allocate_customer_payment(p_organization_id uuid,p_customer_payment_id uuid,p_allocations jsonb,p_credit_remainder boolean,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language sql volatile security invoker set search_path=''
as $$ select private.command_allocate_customer_payment(p_organization_id,p_customer_payment_id,p_allocations,p_credit_remainder,p_idempotency_key,p_request_fingerprint,p_correlation_id) $$;

create or replace function api.apply_customer_credit(p_organization_id uuid,p_customer_credit_id uuid,p_order_id uuid,p_amount_minor bigint,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language sql volatile security invoker set search_path=''
as $$ select private.command_apply_customer_credit(p_organization_id,p_customer_credit_id,p_order_id,p_amount_minor,p_idempotency_key,p_request_fingerprint,p_correlation_id) $$;

revoke all on function api.allocate_customer_payment(uuid,uuid,jsonb,boolean,text,text,uuid) from public,anon,authenticated;
revoke all on function api.apply_customer_credit(uuid,uuid,uuid,bigint,text,text,uuid) from public,anon,authenticated;
grant execute on function api.allocate_customer_payment(uuid,uuid,jsonb,boolean,text,text,uuid) to authenticated;
grant execute on function api.apply_customer_credit(uuid,uuid,uuid,bigint,text,text,uuid) to authenticated;

alter table public.payment_allocation_batches enable row level security;
create policy payment_allocation_batches_select on public.payment_allocation_batches for select to authenticated
using (organization_id=private.current_organization_id() and private.has_permission(organization_id,'payments.review'));
revoke all on table public.payment_allocation_batches from public,anon,authenticated;
grant select on table public.payment_allocation_batches to authenticated;
