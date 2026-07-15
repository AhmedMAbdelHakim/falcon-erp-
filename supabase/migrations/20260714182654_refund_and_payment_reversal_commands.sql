-- Complete customer-refund and customer-payment reversal workflows.

alter table public.refunds
  add column approval_subject_fingerprint text,
  add column approval_reversal_journal_entry_id uuid,
  add column execution_reversal_journal_entry_id uuid,
  add constraint refunds_approval_subject_fingerprint_check
    check (approval_subject_fingerprint is null or approval_subject_fingerprint ~ '^[0-9a-f]{64}$'),
  add constraint refunds_approval_reversal_journal_fk
    foreign key (organization_id, approval_reversal_journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  add constraint refunds_execution_reversal_journal_fk
    foreign key (organization_id, execution_reversal_journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict;

create table public.payment_reversal_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  customer_payment_id uuid not null,
  receipt_reversal_journal_entry_id uuid not null,
  reason text not null,
  idempotency_key text not null,
  request_fingerprint text not null,
  correlation_id uuid not null,
  reversed_by uuid not null,
  reversed_at timestamptz not null default statement_timestamp(),
  constraint payment_reversal_events_org_id_key unique (organization_id, id),
  constraint payment_reversal_events_payment_key unique (organization_id, customer_payment_id),
  constraint payment_reversal_events_idempotency_key unique (organization_id, idempotency_key),
  constraint payment_reversal_events_payment_fk
    foreign key (organization_id, customer_payment_id)
    references public.customer_payments(organization_id, id) on delete restrict,
  constraint payment_reversal_events_journal_fk
    foreign key (organization_id, receipt_reversal_journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  constraint payment_reversal_events_actor_fk
    foreign key (organization_id, reversed_by)
    references public.profiles(organization_id, id) on delete restrict,
  constraint payment_reversal_events_reason_check check (btrim(reason) <> ''),
  constraint payment_reversal_events_idempotency_check check (btrim(idempotency_key) <> ''),
  constraint payment_reversal_events_fingerprint_check check (request_fingerprint ~ '^[0-9a-f]{64}$')
);

alter table public.customer_payments
  add column reversal_event_id uuid,
  add constraint customer_payments_reversal_event_fk
    foreign key (organization_id, reversal_event_id)
    references public.payment_reversal_events(organization_id, id) on delete restrict;

alter table public.customer_payments drop constraint customer_payments_reversal_check;
alter table public.customer_payments
  add constraint customer_payments_reversal_check check (
    (status = 'reversed' and reversal_event_id is not null) or status <> 'reversed'
  );

alter table public.payment_allocation_batches
  add column reversal_journal_entry_id uuid,
  add column reversed_at timestamptz,
  add constraint payment_allocation_batches_reversal_journal_fk
    foreign key (organization_id, reversal_journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  add constraint payment_allocation_batches_reversal_state_check check (
    (reversed_at is null) = (reversal_journal_entry_id is null)
  );

create index payment_reversal_events_payment_idx
  on public.payment_reversal_events(organization_id, customer_payment_id);
create index refunds_approval_reversal_journal_idx
  on public.refunds(organization_id, approval_reversal_journal_entry_id)
  where approval_reversal_journal_entry_id is not null;
create index refunds_execution_reversal_journal_idx
  on public.refunds(organization_id, execution_reversal_journal_entry_id)
  where execution_reversal_journal_entry_id is not null;

insert into private.role_permissions (organization_id, role_id, permission_id)
select r.organization_id, r.id, p.id
from private.roles as r
join private.permissions as p on p.permission_key in (
  'payments.allocate', 'payments.reverse', 'credits.apply', 'refunds.reverse'
)
where r.role_key in ('super_admin', 'finance_manager')
on conflict do nothing;

alter table public.payment_reversal_events enable row level security;
create policy payment_reversal_events_select on public.payment_reversal_events
for select to authenticated
using (
  organization_id = private.current_organization_id()
  and private.has_permission(organization_id, 'payments.review')
);
revoke all on table public.payment_reversal_events from public, anon, authenticated;
grant select on table public.payment_reversal_events to authenticated;

create or replace function private.command_request_customer_refund(
  p_organization_id uuid,
  p_customer_id uuid,
  p_order_id uuid,
  p_customer_payment_id uuid,
  p_customer_credit_id uuid,
  p_requested_amount_minor bigint,
  p_reason text,
  p_destination_method text,
  p_destination_reference_snapshot text,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_claim record;
  v_refund_id uuid;
  v_approval_id uuid;
  v_approval_fingerprint text;
  v_available bigint;
  v_result jsonb;
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'customer_id', p_customer_id,
    'order_id', p_order_id,
    'customer_payment_id', p_customer_payment_id,
    'customer_credit_id', p_customer_credit_id,
    'requested_amount_minor', p_requested_amount_minor,
    'reason', p_reason,
    'destination_method', p_destination_method,
    'destination_reference_snapshot', p_destination_reference_snapshot
  );
begin
  perform private.require_permission(p_organization_id, 'refunds.request');
  perform private.assert_request_fingerprint(
    'refunds.request', v_payload, p_request_fingerprint, 1::smallint
  );
  if num_nonnulls(p_order_id, p_customer_payment_id, p_customer_credit_id) <> 1
     or p_requested_amount_minor <= 0
     or nullif(btrim(p_reason), '') is null
     or p_destination_method not in ('wallet', 'instapay', 'fawry', 'cash', 'bank_transfer', 'other') then
    raise exception using errcode = '22023', message = 'INVALID_REFUND_REQUEST';
  end if;

  select * into v_claim from private.claim_command(
    p_organization_id, 'refunds.request', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    if p_order_id is not null then
      perform 1 from public.orders
      where organization_id = p_organization_id and id = p_order_id
      order by id for update;
      select greatest(o.confirmed_payment_minor - coalesce((
        select sum(r.requested_amount_minor)
        from public.refunds as r
        where r.organization_id = p_organization_id
          and r.order_id = p_order_id
          and r.status not in ('rejected', 'cancelled', 'reversed')
      ), 0), 0)
      into strict v_available
      from public.orders as o
      where o.organization_id = p_organization_id and o.id = p_order_id
        and o.customer_id = p_customer_id and o.status <> 'cancelled';
    elsif p_customer_payment_id is not null then
      perform 1 from public.customer_payments
      where organization_id = p_organization_id and id = p_customer_payment_id
      order by id for update;
      select greatest(cp.amount_minor
        - coalesce((select sum(pa.amount_minor) from public.payment_allocations as pa
          where pa.organization_id = p_organization_id
            and pa.customer_payment_id = cp.id and pa.reversed_at is null), 0)
        - coalesce((select sum(r.requested_amount_minor) from public.refunds as r
          where r.organization_id = p_organization_id
            and r.customer_payment_id = cp.id
            and r.status not in ('rejected', 'cancelled', 'reversed')), 0), 0)
      into strict v_available
      from public.customer_payments as cp
      where cp.organization_id = p_organization_id and cp.id = p_customer_payment_id
        and cp.customer_id = p_customer_id and cp.status = 'confirmed';
    else
      perform 1 from public.customer_credits
      where organization_id = p_organization_id and id = p_customer_credit_id
      order by id for update;
      select cc.remaining_amount_minor into strict v_available
      from public.customer_credits as cc
      where cc.organization_id = p_organization_id and cc.id = p_customer_credit_id
        and cc.customer_id = p_customer_id
        and cc.status in ('available', 'partially_used');
      if p_requested_amount_minor <> v_available then
        raise exception using errcode = '23514', message = 'CREDIT_REFUND_MUST_USE_REMAINING_BALANCE';
      end if;
    end if;

    if p_requested_amount_minor > v_available then
      raise exception using errcode = '23514', message = 'REFUND_EXCEEDS_AVAILABLE_AMOUNT';
    end if;

    insert into public.refunds (
      organization_id, customer_id, order_id, customer_payment_id,
      customer_credit_id, requested_amount_minor, status, reason,
      destination_method, destination_reference_snapshot, requested_by,
      idempotency_key, request_fingerprint, correlation_id
    ) values (
      p_organization_id, p_customer_id, p_order_id, p_customer_payment_id,
      p_customer_credit_id, p_requested_amount_minor, 'requested', p_reason,
      p_destination_method, p_destination_reference_snapshot, auth.uid(),
      p_idempotency_key, p_request_fingerprint, p_correlation_id
    ) returning id into v_refund_id;

    v_approval_fingerprint := encode(
      extensions.digest(convert_to(v_payload::text, 'UTF8'), 'sha256'), 'hex'
    );
    v_approval_id := private.command_submit_approval_request(
      p_organization_id, 'refund.approve', 'refund', v_refund_id,
      'refunds.approve', p_reason, v_payload, v_approval_fingerprint,
      p_requested_amount_minor, null, statement_timestamp() + interval '7 days'
    );
    update public.refunds
    set approval_request_id = v_approval_id,
        approval_subject_fingerprint = v_approval_fingerprint
    where id = v_refund_id;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_refund_id, 'requested',
      'refund.requested', '[]'::jsonb,
      jsonb_build_object('approval_request_id', v_approval_id)
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'refunds.request',
        'refund', p_order_id, p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'REFUND_REQUEST_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'REFUND_REQUEST_REJECTED', v_claim.command_execution_id
    );
  end;
end;
$$;

revoke all on function private.command_request_customer_refund(
  uuid, uuid, uuid, uuid, uuid, bigint, text, text, text, text, text, uuid
) from public, anon, authenticated;

create or replace function private.command_approve_customer_refund(
  p_organization_id uuid,
  p_refund_id uuid,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_claim record;
  v_refund public.refunds;
  v_order public.orders;
  v_source_account_id uuid;
  v_journal_id uuid;
  v_lines jsonb;
  v_result jsonb;
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'refund_id', p_refund_id
  );
begin
  perform private.require_permission(p_organization_id, 'refunds.approve');
  perform private.assert_request_fingerprint(
    'refunds.approve', v_payload, p_request_fingerprint, 1::smallint
  );
  select * into v_claim from private.claim_command(
    p_organization_id, 'refunds.approve', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    select r.* into strict v_refund
    from public.refunds as r
    where r.organization_id = p_organization_id and r.id = p_refund_id
    for update;
    if v_refund.status <> 'requested' or v_refund.requested_by = auth.uid() then
      raise exception using errcode = '42501', message = 'REFUND_APPROVAL_SOD_OR_STATE_INVALID';
    end if;
    perform private.consume_approval(
      p_organization_id, v_refund.approval_request_id,
      'refund.approve', 'refund', v_refund.id,
      v_refund.approval_subject_fingerprint,
      v_claim.command_execution_id, v_refund.requested_amount_minor
    );

    if v_refund.customer_credit_id is not null then
      perform 1 from public.customer_credits
      where organization_id = p_organization_id and id = v_refund.customer_credit_id
      for update;
      if not exists (
        select 1 from public.customer_credits as cc
        where cc.organization_id = p_organization_id
          and cc.id = v_refund.customer_credit_id
          and cc.status in ('available', 'partially_used')
          and cc.remaining_amount_minor = v_refund.requested_amount_minor
      ) then
        raise exception using errcode = '55000', message = 'CREDIT_REFUND_BALANCE_CHANGED';
      end if;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'account_role', 'customer_credits',
          'debit_minor', v_refund.requested_amount_minor::text,
          'credit_minor', '0', 'customer_id', v_refund.customer_id,
          'subledger_type', 'customer_credit',
          'subledger_id', v_refund.customer_credit_id
        ),
        jsonb_build_object(
          'account_role', 'refund_payable', 'debit_minor', '0',
          'credit_minor', v_refund.requested_amount_minor::text,
          'customer_id', v_refund.customer_id,
          'subledger_type', 'refund', 'subledger_id', v_refund.id
        )
      );
    elsif v_refund.order_id is not null then
      select o.* into strict v_order from public.orders as o
      where o.organization_id = p_organization_id and o.id = v_refund.order_id
      for update;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'account_role', case when v_order.status in (
            'partially_delivered', 'delivered', 'partially_returned',
            'returned', 'financially_settled'
          ) then 'sales_returns' else 'customer_deposits' end,
          'debit_minor', v_refund.requested_amount_minor::text,
          'credit_minor', '0', 'customer_id', v_refund.customer_id,
          'order_id', v_refund.order_id,
          'subledger_type', 'refund', 'subledger_id', v_refund.id
        ),
        jsonb_build_object(
          'account_role', 'refund_payable', 'debit_minor', '0',
          'credit_minor', v_refund.requested_amount_minor::text,
          'customer_id', v_refund.customer_id, 'order_id', v_refund.order_id,
          'subledger_type', 'refund', 'subledger_id', v_refund.id
        )
      );
    else
      select jl.account_id into strict v_source_account_id
      from accounting.journal_entries as je
      join accounting.journal_lines as jl on jl.journal_entry_id = je.id
      where je.organization_id = p_organization_id
        and je.source_type = 'customer_payment'
        and je.source_id = v_refund.customer_payment_id
        and je.posting_purpose = 'receipt' and je.status = 'posted'
        and jl.credit_minor > 0
      order by jl.line_number limit 1;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'account_id', v_source_account_id,
          'debit_minor', v_refund.requested_amount_minor::text,
          'credit_minor', '0', 'customer_id', v_refund.customer_id,
          'subledger_type', 'refund', 'subledger_id', v_refund.id
        ),
        jsonb_build_object(
          'account_role', 'refund_payable', 'debit_minor', '0',
          'credit_minor', v_refund.requested_amount_minor::text,
          'customer_id', v_refund.customer_id,
          'subledger_type', 'refund', 'subledger_id', v_refund.id
        )
      );
    end if;

    v_journal_id := private.post_journal_entry(
      p_organization_id => p_organization_id,
      p_source_type => 'refund', p_source_id => v_refund.id,
      p_posting_purpose => 'approval',
      p_description => 'Approve customer refund liability', p_lines => v_lines,
      p_idempotency_key => p_idempotency_key,
      p_request_hash => p_request_fingerprint,
      p_correlation_id => p_correlation_id,
      p_approval_request_id => v_refund.approval_request_id,
      p_command_type => 'refunds.approve',
      p_command_execution_id => v_claim.command_execution_id,
      p_require_manual_permission => false
    );
    if v_refund.customer_credit_id is not null then
      update public.customer_credits
      set status = 'refund_pending'
      where id = v_refund.customer_credit_id;
    end if;
    update public.refunds
    set status = 'approved', approved_amount_minor = requested_amount_minor,
        approved_by = auth.uid(), approved_at = statement_timestamp(),
        approval_journal_entry_id = v_journal_id
    where id = v_refund.id;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_refund.id, 'approved',
      'refund.approved', jsonb_build_array(v_journal_id)
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'refunds.approve',
        'refund', p_refund_id, p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'REFUND_APPROVAL_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'REFUND_APPROVAL_REJECTED', v_claim.command_execution_id
    );
  end;
end;
$$;

revoke all on function private.command_approve_customer_refund(
  uuid, uuid, text, text, uuid
) from public, anon, authenticated;

create or replace function private.command_execute_customer_refund(
  p_organization_id uuid,
  p_refund_id uuid,
  p_source_wallet_id uuid,
  p_external_transaction_reference text,
  p_evidence_attachment_id uuid,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_claim record;
  v_refund public.refunds;
  v_wallet public.wallets;
  v_journal_id uuid;
  v_movement_id uuid;
  v_refunded_total bigint;
  v_result jsonb;
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'refund_id', p_refund_id,
    'source_wallet_id', p_source_wallet_id,
    'external_transaction_reference', p_external_transaction_reference,
    'evidence_attachment_id', p_evidence_attachment_id
  );
begin
  perform private.require_permission(p_organization_id, 'refunds.execute');
  perform private.assert_request_fingerprint(
    'refunds.execute', v_payload, p_request_fingerprint, 1::smallint
  );
  if nullif(btrim(p_external_transaction_reference), '') is null then
    raise exception using errcode = '22023', message = 'REFUND_TRANSACTION_REFERENCE_REQUIRED';
  end if;
  select * into v_claim from private.claim_command(
    p_organization_id, 'refunds.execute', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    select r.* into strict v_refund
    from public.refunds as r
    where r.organization_id = p_organization_id and r.id = p_refund_id
    for update;
    if v_refund.status <> 'approved' or v_refund.approved_by = auth.uid() then
      raise exception using errcode = '42501', message = 'REFUND_EXECUTION_SOD_OR_STATE_INVALID';
    end if;
    select w.* into strict v_wallet
    from public.wallets as w
    where w.organization_id = p_organization_id and w.id = p_source_wallet_id
      and w.is_active
    for update;

    v_journal_id := private.post_journal_entry(
      p_organization_id => p_organization_id,
      p_source_type => 'refund', p_source_id => v_refund.id,
      p_posting_purpose => 'execution',
      p_description => 'Execute approved customer refund',
      p_lines => jsonb_build_array(
        jsonb_build_object(
          'account_role', 'refund_payable',
          'debit_minor', v_refund.approved_amount_minor::text,
          'credit_minor', '0', 'customer_id', v_refund.customer_id,
          'order_id', v_refund.order_id,
          'subledger_type', 'refund', 'subledger_id', v_refund.id
        ),
        jsonb_build_object(
          'account_role', 'wallet_' || lower(regexp_replace(v_wallet.code, '[^a-zA-Z0-9]+', '_', 'g')),
          'debit_minor', '0',
          'credit_minor', v_refund.approved_amount_minor::text,
          'customer_id', v_refund.customer_id, 'order_id', v_refund.order_id,
          'wallet_id', v_wallet.id,
          'subledger_type', 'refund', 'subledger_id', v_refund.id
        )
      ),
      p_idempotency_key => p_idempotency_key,
      p_request_hash => p_request_fingerprint,
      p_correlation_id => p_correlation_id,
      p_command_type => 'refunds.execute',
      p_command_execution_id => v_claim.command_execution_id,
      p_require_manual_permission => false
    );

    if v_refund.customer_credit_id is not null then
      insert into public.customer_credit_movements (
        organization_id, customer_id, customer_credit_id, movement_type,
        amount_minor, refund_id, reason, correlation_id, created_by,
        journal_entry_id
      ) values (
        p_organization_id, v_refund.customer_id, v_refund.customer_credit_id,
        'refunded', -v_refund.approved_amount_minor, v_refund.id,
        'Approved customer-credit refund executed', p_correlation_id,
        auth.uid(), v_journal_id
      ) returning id into v_movement_id;
      update public.customer_credits
      set remaining_amount_minor = 0, status = 'refunded',
          closed_at = statement_timestamp()
      where id = v_refund.customer_credit_id;
    end if;

    update public.refunds
    set status = 'executed', executed_amount_minor = approved_amount_minor,
        source_wallet_id = v_wallet.id,
        external_transaction_reference = p_external_transaction_reference,
        evidence_attachment_id = p_evidence_attachment_id,
        executed_by = auth.uid(), executed_at = statement_timestamp(),
        execution_journal_entry_id = v_journal_id
    where id = v_refund.id;

    if v_refund.order_id is not null then
      select coalesce(sum(r.executed_amount_minor), 0) into v_refunded_total
      from public.refunds as r
      where r.organization_id = p_organization_id
        and r.order_id = v_refund.order_id
        and r.status = 'executed';
      update public.orders
      set payment_status = (case
        when v_refunded_total >= confirmed_payment_minor then 'fully_refunded'
        else 'partially_refunded'
      end)::public.payment_status,
      version = version + 1
      where organization_id = p_organization_id and id = v_refund.order_id;
    end if;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_refund.id, 'executed',
      'refund.executed', jsonb_build_array(v_journal_id)
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'refunds.execute',
        'refund', p_refund_id, p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'REFUND_EXECUTION_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'REFUND_EXECUTION_REJECTED', v_claim.command_execution_id
    );
  end;
end;
$$;

revoke all on function private.command_execute_customer_refund(
  uuid, uuid, uuid, text, uuid, text, text, uuid
) from public, anon, authenticated;

create or replace function private.command_reverse_customer_refund(
  p_organization_id uuid,
  p_refund_id uuid,
  p_reason text,
  p_approval_request_id uuid,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_claim record;
  v_refund public.refunds;
  v_execution_reversal_id uuid;
  v_approval_reversal_id uuid;
  v_result jsonb;
  v_sqlstate text;
  v_approval_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'refund_id', p_refund_id,
    'reason', p_reason
  );
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'refund_id', p_refund_id,
    'reason', p_reason,
    'approval_request_id', p_approval_request_id
  );
begin
  perform private.require_permission(p_organization_id, 'refunds.reverse');
  perform private.require_permission(p_organization_id, 'ledger.reverse');
  perform private.assert_request_fingerprint(
    'refunds.reverse', v_payload, p_request_fingerprint, 1::smallint
  );
  if nullif(btrim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'REFUND_REVERSAL_REASON_REQUIRED';
  end if;
  select * into v_claim from private.claim_command(
    p_organization_id, 'refunds.reverse', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    select r.* into strict v_refund
    from public.refunds as r
    where r.organization_id = p_organization_id and r.id = p_refund_id
    for update;
    if v_refund.status <> 'executed' or v_refund.executed_by = auth.uid() then
      raise exception using errcode = '42501', message = 'REFUND_REVERSAL_SOD_OR_STATE_INVALID';
    end if;
    perform private.consume_approval(
      p_organization_id, p_approval_request_id, 'refund.reverse',
      'refund', v_refund.id,
      encode(extensions.digest(convert_to(v_approval_payload::text, 'UTF8'), 'sha256'), 'hex'),
      v_claim.command_execution_id, v_refund.executed_amount_minor
    );
    v_execution_reversal_id := private.reverse_journal_entry(
      p_organization_id, v_refund.execution_journal_entry_id, p_reason,
      p_idempotency_key || ':execution', p_request_fingerprint,
      p_correlation_id, null, v_claim.command_execution_id
    );
    v_approval_reversal_id := private.reverse_journal_entry(
      p_organization_id, v_refund.approval_journal_entry_id, p_reason,
      p_idempotency_key || ':approval', p_request_fingerprint,
      p_correlation_id, null, v_claim.command_execution_id
    );

    if v_refund.customer_credit_id is not null then
      perform 1 from public.customer_credits
      where organization_id = p_organization_id and id = v_refund.customer_credit_id
      for update;
      insert into public.customer_credit_movements (
        organization_id, customer_id, customer_credit_id, movement_type,
        amount_minor, refund_id, reason, correlation_id, created_by,
        journal_entry_id
      ) values (
        p_organization_id, v_refund.customer_id, v_refund.customer_credit_id,
        'released', v_refund.executed_amount_minor, v_refund.id,
        p_reason, p_correlation_id, auth.uid(), v_approval_reversal_id
      );
      update public.customer_credits
      set remaining_amount_minor = v_refund.executed_amount_minor,
          status = case
            when v_refund.executed_amount_minor = original_amount_minor then 'available'
            else 'partially_used'
          end,
          closed_at = null
      where id = v_refund.customer_credit_id;
    end if;

    update public.refunds
    set status = 'reversed', reversed_at = statement_timestamp(),
        reversal_journal_entry_id = v_execution_reversal_id,
        execution_reversal_journal_entry_id = v_execution_reversal_id,
        approval_reversal_journal_entry_id = v_approval_reversal_id
    where id = v_refund.id;
    if v_refund.order_id is not null then
      perform private.refresh_order_payment_projection(
        p_organization_id, v_refund.order_id
      );
    end if;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_refund.id, 'reversed',
      'refund.reversed',
      jsonb_build_array(v_execution_reversal_id, v_approval_reversal_id)
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'refunds.reverse',
        'refund', p_refund_id, p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'REFUND_REVERSAL_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'REFUND_REVERSAL_REJECTED', v_claim.command_execution_id
    );
  end;
end;
$$;

revoke all on function private.command_reverse_customer_refund(
  uuid, uuid, text, uuid, text, text, uuid
) from public, anon, authenticated;

create or replace function private.command_reverse_customer_payment(
  p_organization_id uuid,
  p_customer_payment_id uuid,
  p_reason text,
  p_approval_request_id uuid,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql volatile security definer set search_path = ''
as $$
declare
  v_claim record;
  v_payment public.customer_payments;
  v_receipt_journal_id uuid;
  v_receipt_reversal_id uuid;
  v_reversal_event_id uuid;
  v_batch record;
  v_allocation record;
  v_credit record;
  v_order_id uuid;
  v_reversal_allocation_id uuid;
  v_allocation_ids uuid[];
  v_journal_ids jsonb := '[]'::jsonb;
  v_result jsonb;
  v_sqlstate text;
  v_approval_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'customer_payment_id', p_customer_payment_id,
    'reason', p_reason
  );
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'customer_payment_id', p_customer_payment_id,
    'reason', p_reason,
    'approval_request_id', p_approval_request_id
  );
begin
  perform private.require_permission(p_organization_id, 'payments.reverse');
  perform private.require_permission(p_organization_id, 'ledger.reverse');
  perform private.assert_request_fingerprint(
    'payments.reverse', v_payload, p_request_fingerprint, 1::smallint
  );
  if nullif(btrim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'PAYMENT_REVERSAL_REASON_REQUIRED';
  end if;
  select * into v_claim from private.claim_command(
    p_organization_id, 'payments.reverse', p_idempotency_key,
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
    if v_payment.status <> 'confirmed' or v_payment.reviewed_by = auth.uid() then
      raise exception using errcode = '42501', message = 'PAYMENT_REVERSAL_SOD_OR_STATE_INVALID';
    end if;
    if exists (
      select 1 from public.refunds as r
      where r.organization_id = p_organization_id
        and r.customer_payment_id = v_payment.id
        and r.status not in ('rejected', 'cancelled', 'reversed')
    ) then
      raise exception using errcode = '55000', message = 'PAYMENT_HAS_ACTIVE_REFUND';
    end if;
    if exists (
      select 1
      from public.customer_credits as cc
      join public.customer_credit_movements as ccm
        on ccm.organization_id = cc.organization_id
       and ccm.customer_credit_id = cc.id
      where cc.organization_id = p_organization_id
        and cc.source_payment_id = v_payment.id
        and ccm.movement_type <> 'issued'
    ) then
      raise exception using errcode = '55000', message = 'PAYMENT_CREDIT_ALREADY_CONSUMED';
    end if;
    perform private.consume_approval(
      p_organization_id, p_approval_request_id, 'payment.reverse',
      'customer_payment', v_payment.id,
      encode(extensions.digest(convert_to(v_approval_payload::text, 'UTF8'), 'sha256'), 'hex'),
      v_claim.command_execution_id, v_payment.amount_minor
    );

    perform 1 from public.orders as o
    join public.payment_allocations as pa
      on pa.organization_id = o.organization_id and pa.order_id = o.id
    where pa.organization_id = p_organization_id
      and pa.customer_payment_id = v_payment.id and pa.reversed_at is null
    order by o.id for update of o;

    for v_batch in
      select pab.* from public.payment_allocation_batches as pab
      where pab.organization_id = p_organization_id
        and pab.customer_payment_id = v_payment.id
        and pab.reversed_at is null
      order by pab.id for update
    loop
      v_batch.reversal_journal_entry_id := private.reverse_journal_entry(
        p_organization_id, v_batch.journal_entry_id, p_reason,
        p_idempotency_key || ':allocation:' || v_batch.id::text,
        p_request_fingerprint, p_correlation_id, p_approval_request_id,
        v_claim.command_execution_id
      );
      update public.payment_allocation_batches
      set reversal_journal_entry_id = v_batch.reversal_journal_entry_id,
          reversed_at = statement_timestamp()
      where id = v_batch.id;
      v_journal_ids := v_journal_ids || jsonb_build_array(v_batch.reversal_journal_entry_id);
    end loop;

    select array_agg(pa.id order by pa.id) into v_allocation_ids
    from public.payment_allocations as pa
    where pa.organization_id = p_organization_id
      and pa.customer_payment_id = v_payment.id
      and pa.reversed_at is null;
    for v_allocation in
      select pa.* from public.payment_allocations as pa
      where pa.id = any(coalesce(v_allocation_ids, '{}'::uuid[]))
      order by pa.id for update
    loop
      insert into public.payment_allocations (
        organization_id, customer_id, customer_payment_id,
        allocation_type, amount_minor, allocated_by,
        allocation_fingerprint, correlation_id
      ) values (
        p_organization_id, v_payment.customer_id, v_payment.id,
        'other_approved', v_allocation.amount_minor, auth.uid(),
        private.canonical_request_fingerprint(
          'payments.reverse.allocation',
          jsonb_build_object('allocation_id', v_allocation.id, 'reason', p_reason),
          1::smallint
        ), p_correlation_id
      ) returning id into v_reversal_allocation_id;
      update public.payment_allocations
      set reversed_at = statement_timestamp(), reversal_allocation_id = v_reversal_allocation_id
      where id = v_allocation.id;
    end loop;

    for v_credit in
      select cc.* from public.customer_credits as cc
      where cc.organization_id = p_organization_id
        and cc.source_payment_id = v_payment.id
      order by cc.id for update
    loop
      insert into public.customer_credit_movements (
        organization_id, customer_id, customer_credit_id, movement_type,
        amount_minor, reason, correlation_id, created_by
      ) values (
        p_organization_id, v_payment.customer_id, v_credit.id,
        'cancelled', -v_credit.remaining_amount_minor, p_reason,
        p_correlation_id, auth.uid()
      );
      update public.customer_credits
      set remaining_amount_minor = 0, status = 'cancelled',
          closed_at = statement_timestamp()
      where id = v_credit.id;
    end loop;

    select je.id into strict v_receipt_journal_id
    from accounting.journal_entries as je
    where je.organization_id = p_organization_id
      and je.source_type = 'customer_payment' and je.source_id = v_payment.id
      and je.posting_purpose = 'receipt' and je.status = 'posted'
    for update;
    v_receipt_reversal_id := private.reverse_journal_entry(
      p_organization_id, v_receipt_journal_id, p_reason,
      p_idempotency_key || ':receipt', p_request_fingerprint,
      p_correlation_id, p_approval_request_id, v_claim.command_execution_id
    );
    v_journal_ids := v_journal_ids || jsonb_build_array(v_receipt_reversal_id);

    insert into public.payment_reversal_events (
      organization_id, customer_payment_id, receipt_reversal_journal_entry_id,
      reason, idempotency_key, request_fingerprint, correlation_id, reversed_by
    ) values (
      p_organization_id, v_payment.id, v_receipt_reversal_id,
      p_reason, p_idempotency_key, p_request_fingerprint,
      p_correlation_id, auth.uid()
    ) returning id into v_reversal_event_id;
    update public.customer_payments
    set status = 'reversed', reversed_at = statement_timestamp(),
        reversal_event_id = v_reversal_event_id
    where id = v_payment.id;

    for v_order_id in
      select distinct pa.order_id from public.payment_allocations as pa
      where pa.id = any(coalesce(v_allocation_ids, '{}'::uuid[]))
        and pa.order_id is not null
      order by pa.order_id
    loop
      perform private.refresh_order_payment_projection(p_organization_id, v_order_id);
    end loop;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_reversal_event_id, 'reversed',
      'payment.reversed', v_journal_ids,
      jsonb_build_object('customer_payment_id', v_payment.id)
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'payments.reverse',
        'customer_payment', p_customer_payment_id,
        p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'PAYMENT_REVERSAL_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'PAYMENT_REVERSAL_REJECTED', v_claim.command_execution_id
    );
  end;
end;
$$;

revoke all on function private.command_reverse_customer_payment(
  uuid, uuid, text, uuid, text, text, uuid
) from public, anon, authenticated;

create or replace function api.request_customer_refund(
  p_organization_id uuid, p_customer_id uuid, p_order_id uuid,
  p_customer_payment_id uuid, p_customer_credit_id uuid,
  p_requested_amount_minor bigint, p_reason text, p_destination_method text,
  p_destination_reference_snapshot text, p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_request_customer_refund(
  p_organization_id, p_customer_id, p_order_id, p_customer_payment_id,
  p_customer_credit_id, p_requested_amount_minor, p_reason,
  p_destination_method, p_destination_reference_snapshot,
  p_idempotency_key, p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.approve_customer_refund(
  p_organization_id uuid, p_refund_id uuid, p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_approve_customer_refund(
  p_organization_id, p_refund_id, p_idempotency_key,
  p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.execute_customer_refund(
  p_organization_id uuid, p_refund_id uuid, p_source_wallet_id uuid,
  p_external_transaction_reference text, p_evidence_attachment_id uuid,
  p_idempotency_key text, p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_execute_customer_refund(
  p_organization_id, p_refund_id, p_source_wallet_id,
  p_external_transaction_reference, p_evidence_attachment_id,
  p_idempotency_key, p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.reverse_customer_refund(
  p_organization_id uuid, p_refund_id uuid, p_reason text,
  p_approval_request_id uuid, p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_reverse_customer_refund(
  p_organization_id, p_refund_id, p_reason, p_approval_request_id,
  p_idempotency_key, p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.reverse_customer_payment(
  p_organization_id uuid, p_customer_payment_id uuid, p_reason text,
  p_approval_request_id uuid, p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_reverse_customer_payment(
  p_organization_id, p_customer_payment_id, p_reason, p_approval_request_id,
  p_idempotency_key, p_request_fingerprint, p_correlation_id
) $$;

revoke all on function api.request_customer_refund(
  uuid, uuid, uuid, uuid, uuid, bigint, text, text, text, text, text, uuid
) from public, anon, authenticated;
revoke all on function api.approve_customer_refund(
  uuid, uuid, text, text, uuid
) from public, anon, authenticated;
revoke all on function api.execute_customer_refund(
  uuid, uuid, uuid, text, uuid, text, text, uuid
) from public, anon, authenticated;
revoke all on function api.reverse_customer_refund(
  uuid, uuid, text, uuid, text, text, uuid
) from public, anon, authenticated;
revoke all on function api.reverse_customer_payment(
  uuid, uuid, text, uuid, text, text, uuid
) from public, anon, authenticated;

grant execute on function api.request_customer_refund(
  uuid, uuid, uuid, uuid, uuid, bigint, text, text, text, text, text, uuid
) to authenticated;
grant execute on function api.approve_customer_refund(
  uuid, uuid, text, text, uuid
) to authenticated;
grant execute on function api.execute_customer_refund(
  uuid, uuid, uuid, text, uuid, text, text, uuid
) to authenticated;
grant execute on function api.reverse_customer_refund(
  uuid, uuid, text, uuid, text, text, uuid
) to authenticated;
grant execute on function api.reverse_customer_payment(
  uuid, uuid, text, uuid, text, text, uuid
) to authenticated;
