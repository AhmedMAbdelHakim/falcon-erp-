create or replace function private.command_replay_response(
  p_status public.command_status,
  p_result_reference jsonb,
  p_error_code text,
  p_command_execution_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select case
    when p_status = 'succeeded' then p_result_reference
    when p_status = 'failed_terminal' then jsonb_build_object(
      'success', false,
      'command_id', p_command_execution_id,
      'entity_id', null,
      'journal_entry_ids', '[]'::jsonb,
      'warnings', '[]'::jsonb,
      'error_code', p_error_code,
      'message_key', 'command.previously_failed',
      'current_state', 'failed_terminal'
    )
    else jsonb_build_object(
      'success', false,
      'command_id', p_command_execution_id,
      'entity_id', null,
      'journal_entry_ids', '[]'::jsonb,
      'warnings', jsonb_build_array('COMMAND_IN_PROGRESS'),
      'error_code', 'COMMAND_IN_PROGRESS',
      'message_key', 'command.in_progress',
      'current_state', 'in_progress'
    )
  end
$$;

revoke all on function private.command_replay_response(public.command_status, jsonb, text, uuid)
  from public, anon, authenticated;

create or replace function private.record_financial_command_audit(
  p_organization_id uuid,
  p_action text,
  p_subject_type text,
  p_subject_id uuid,
  p_result text,
  p_reason text,
  p_correlation_id uuid,
  p_command_execution_id uuid,
  p_idempotency_reference text,
  p_event_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  insert into audit.events (
    organization_id, event_category, action, subject_type, subject_id,
    actor_user_id, result, reason, correlation_id, command_execution_id,
    idempotency_reference, event_metadata
  ) values (
    p_organization_id, 'financial_command', p_action, p_subject_type, p_subject_id,
    auth.uid(), p_result, p_reason, p_correlation_id, p_command_execution_id,
    p_idempotency_reference, coalesce(p_event_metadata, '{}'::jsonb)
  );
end;
$$;

revoke all on function private.record_financial_command_audit(
  uuid, text, text, uuid, text, text, uuid, uuid, text, jsonb
) from public, anon, authenticated;

create or replace function private.consume_approval(
  p_organization_id uuid,
  p_approval_request_id uuid,
  p_expected_request_type text,
  p_expected_entity_type text,
  p_expected_entity_id uuid,
  p_expected_fingerprint text,
  p_command_execution_id uuid,
  p_amount_minor bigint default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_approval public.approval_requests;
begin
  select ar.* into strict v_approval
  from public.approval_requests as ar
  where ar.id = p_approval_request_id
    and ar.organization_id = p_organization_id
  for update;

  if v_approval.status <> 'approved'
     or (v_approval.expires_at is not null and v_approval.expires_at <= statement_timestamp())
     or v_approval.request_type <> p_expected_request_type
     or v_approval.entity_type <> p_expected_entity_type
     or v_approval.entity_id <> p_expected_entity_id
     or v_approval.subject_fingerprint <> p_expected_fingerprint then
    raise exception using errcode = '55000', message = 'APPROVAL_SCOPE_INVALID';
  end if;

  if p_amount_minor is not null and (
    (v_approval.approved_min_amount_minor is not null and p_amount_minor < v_approval.approved_min_amount_minor)
    or (v_approval.approved_max_amount_minor is not null and p_amount_minor > v_approval.approved_max_amount_minor)
  ) then
    raise exception using errcode = '55000', message = 'APPROVAL_AMOUNT_OUT_OF_SCOPE';
  end if;

  update public.approval_requests
  set status = 'consumed',
      consumed_at = statement_timestamp(),
      consumed_by_command_execution_id = p_command_execution_id
  where id = v_approval.id;
end;
$$;

comment on function private.consume_approval(uuid, uuid, text, text, uuid, text, uuid, bigint) is
  'Locks and consumes one approved, unexpired, fingerprint-bound approval in the same transaction as execution.';
revoke all on function private.consume_approval(uuid, uuid, text, text, uuid, text, uuid, bigint)
  from public, anon, authenticated;

create or replace function private.execute_mapped_financial_command(
  p_organization_id uuid,
  p_command_type text,
  p_required_permission text,
  p_source_type text,
  p_source_id uuid,
  p_posting_purpose text,
  p_description text,
  p_lines jsonb,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_fingerprint_version smallint default 1,
  p_correlation_id uuid default extensions.gen_random_uuid(),
  p_accounting_date date default null,
  p_approval_request_id uuid default null,
  p_corrects_entry_id uuid default null,
  p_affected_closed_period_id uuid default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_claim record;
  v_journal_entry_id uuid;
  v_result jsonb;
  v_error_code text;
begin
  perform private.require_permission(p_organization_id, p_required_permission);

  select * into v_claim
  from private.claim_command(
    p_organization_id, p_command_type, p_idempotency_key,
    p_request_fingerprint, p_fingerprint_version, p_correlation_id
  );

  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    v_journal_entry_id := private.post_journal_entry(
      p_organization_id => p_organization_id,
      p_source_type => p_source_type,
      p_source_id => p_source_id,
      p_posting_purpose => p_posting_purpose,
      p_description => p_description,
      p_lines => p_lines,
      p_idempotency_key => p_idempotency_key,
      p_request_hash => p_request_fingerprint,
      p_request_hash_version => p_fingerprint_version,
      p_correlation_id => p_correlation_id,
      p_accounting_date => p_accounting_date,
      p_approval_request_id => p_approval_request_id,
      p_corrects_entry_id => p_corrects_entry_id,
      p_affected_closed_period_id => p_affected_closed_period_id,
      p_command_type => p_command_type,
      p_command_execution_id => v_claim.command_execution_id,
      p_require_manual_permission => false
    );

    v_result := jsonb_build_object(
      'success', true,
      'command_id', v_claim.command_execution_id,
      'entity_id', p_source_id,
      'journal_entry_ids', jsonb_build_array(v_journal_entry_id),
      'warnings', '[]'::jsonb,
      'error_code', null,
      'message_key', 'command.succeeded',
      'current_state', 'posted'
    );

    perform private.complete_command_success(v_claim.command_execution_id, v_result);

    insert into audit.events (
      organization_id, event_category, action, subject_type, subject_id,
      actor_user_id, result, correlation_id, command_execution_id,
      idempotency_reference, after_state
    ) values (
      p_organization_id, 'financial_command', p_command_type, p_source_type, p_source_id,
      auth.uid(), 'succeeded', p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key, jsonb_build_object('journal_entry_id', v_journal_entry_id)
    );

    return v_result;
  exception when others then
    v_error_code := case
      when sqlstate = '23505' then 'DUPLICATE_POSTING'
      when sqlstate = '23514' then 'ACCOUNTING_INVARIANT_FAILED'
      when sqlstate = '42501' then 'PERMISSION_DENIED'
      else 'COMMAND_REJECTED'
    end;
    perform private.complete_command_failure(v_claim.command_execution_id, v_error_code, null);

    insert into audit.events (
      organization_id, event_category, action, subject_type, subject_id,
      actor_user_id, result, reason, correlation_id, command_execution_id,
      idempotency_reference, event_metadata
    ) values (
      p_organization_id, 'financial_command', p_command_type, p_source_type, p_source_id,
      auth.uid(), 'failed', v_error_code, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key, jsonb_build_object('sqlstate_class', left(sqlstate, 2))
    );

    return private.command_replay_response(
      'failed_terminal', null, v_error_code, v_claim.command_execution_id
    );
  end;
end;
$$;

comment on function private.execute_mapped_financial_command(
  uuid, text, text, text, uuid, text, text, jsonb, text, text, smallint,
  uuid, date, uuid, uuid, uuid
) is 'Private reusable idempotent business posting executor. Only server-owned command implementations may supply its permission and mapped lines.';
revoke all on function private.execute_mapped_financial_command(
  uuid, text, text, text, uuid, text, text, jsonb, text, text, smallint,
  uuid, date, uuid, uuid, uuid
) from public, anon, authenticated;

create or replace function private.command_post_journal_entry(
  p_organization_id uuid,
  p_source_type text,
  p_source_id uuid,
  p_posting_purpose text,
  p_description text,
  p_lines jsonb,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid(),
  p_accounting_date date default null,
  p_approval_request_id uuid default null,
  p_corrects_entry_id uuid default null,
  p_affected_closed_period_id uuid default null
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select private.execute_mapped_financial_command(
    p_organization_id, 'ledger.post', 'ledger.post', p_source_type, p_source_id,
    p_posting_purpose, p_description, p_lines, p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id, p_accounting_date,
    p_approval_request_id, p_corrects_entry_id, p_affected_closed_period_id
  )
$$;

revoke all on function private.command_post_journal_entry(
  uuid, text, uuid, text, text, jsonb, text, text, uuid, date, uuid, uuid, uuid
) from public, anon, authenticated;

create or replace function private.command_reverse_journal_entry(
  p_organization_id uuid,
  p_original_entry_id uuid,
  p_reason text,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid(),
  p_approval_request_id uuid default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_claim record;
  v_reversal_id uuid;
  v_result jsonb;
  v_error_code text;
begin
  perform private.require_permission(p_organization_id, 'ledger.reverse');
  select * into v_claim
  from private.claim_command(
    p_organization_id, 'ledger.reverse', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );

  if v_claim.is_replay then
    return private.command_replay_response(v_claim.command_status, v_claim.result_reference, v_claim.error_code, v_claim.command_execution_id);
  end if;

  begin
    if p_approval_request_id is null then
      raise exception using errcode = '55000', message = 'REVERSAL_APPROVAL_REQUIRED';
    end if;
    perform private.consume_approval(
      p_organization_id, p_approval_request_id, 'journal.reverse', 'journal_entry',
      p_original_entry_id, p_request_fingerprint, v_claim.command_execution_id, null
    );

    v_reversal_id := private.reverse_journal_entry(
      p_organization_id, p_original_entry_id, p_reason, p_idempotency_key,
      p_request_fingerprint, p_correlation_id, p_approval_request_id,
      v_claim.command_execution_id
    );

    v_result := jsonb_build_object(
      'success', true, 'command_id', v_claim.command_execution_id,
      'entity_id', p_original_entry_id,
      'journal_entry_ids', jsonb_build_array(v_reversal_id),
      'warnings', '[]'::jsonb, 'error_code', null,
      'message_key', 'journal.reversed', 'current_state', 'reversed'
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'ledger.reverse', 'journal_entry', p_original_entry_id,
      'succeeded', p_reason, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key, jsonb_build_object('reversal_entry_id', v_reversal_id)
    );
    return v_result;
  exception when others then
    v_error_code := case when sqlstate = '42501' then 'PERMISSION_DENIED' else 'REVERSAL_REJECTED' end;
    perform private.complete_command_failure(v_claim.command_execution_id, v_error_code, null);
    perform private.record_financial_command_audit(
      p_organization_id, 'ledger.reverse', 'journal_entry', p_original_entry_id,
      'failed', v_error_code, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key
    );
    return private.command_replay_response('failed_terminal', null, v_error_code, v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_reverse_journal_entry(uuid, uuid, text, text, text, uuid, uuid)
  from public, anon, authenticated;

create or replace function private.command_start_monthly_close(
  p_organization_id uuid,
  p_period_start date,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid(),
  p_approval_request_id uuid default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_claim record;
  v_period accounting.accounting_periods;
  v_closing_id uuid;
  v_result jsonb;
  v_item_key text;
begin
  perform private.require_permission(p_organization_id, 'accounting.close_period');
  select * into v_claim
  from private.claim_command(
    p_organization_id, 'accounting.start_close', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );

  if v_claim.is_replay then
    return private.command_replay_response(v_claim.command_status, v_claim.result_reference, v_claim.error_code, v_claim.command_execution_id);
  end if;

  begin
    v_period := private.lock_accounting_period(p_organization_id, p_period_start, false);
    if v_period.period_start <> p_period_start then
      raise exception using errcode = '22023', message = 'PERIOD_START_REQUIRED';
    end if;

    update accounting.accounting_periods
    set status = 'closing', close_requested_by = auth.uid(),
        close_requested_at = statement_timestamp(), version = version + 1
    where id = v_period.id;

    insert into accounting.monthly_closings (
      organization_id, accounting_period_id, requested_by, approval_request_id, correlation_id
    ) values (
      p_organization_id, v_period.id, auth.uid(), p_approval_request_id, p_correlation_id
    ) returning id into v_closing_id;

    foreach v_item_key in array array[
      'trial_balance', 'customer_deposits_credits_ar', 'courier_ar_payable',
      'supplier_grni_ap', 'wallet_reconciliations', 'inventory_cogs',
      'payroll', 'expenses', 'partner_accounts', 'suspense_zero',
      'delivered_orders_posted', 'returns_classified', 'pending_approvals',
      'protected_reserve', 'ownership_snapshot'
    ] loop
      insert into accounting.closing_checklist_items (monthly_closing_id, item_key)
      values (v_closing_id, v_item_key);
    end loop;

    v_result := jsonb_build_object(
      'success', true, 'command_id', v_claim.command_execution_id,
      'entity_id', v_closing_id, 'journal_entry_ids', '[]'::jsonb,
      'warnings', '[]'::jsonb, 'error_code', null,
      'message_key', 'accounting.close_started', 'current_state', 'closing'
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'accounting.start_close', 'monthly_closing', v_closing_id,
      'succeeded', null, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key, jsonb_build_object('accounting_period_id', v_period.id)
    );
    return v_result;
  exception when others then
    perform private.complete_command_failure(v_claim.command_execution_id, 'CLOSE_START_REJECTED', null);
    perform private.record_financial_command_audit(
      p_organization_id, 'accounting.start_close', 'accounting_period', null,
      'failed', 'CLOSE_START_REJECTED', p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key
    );
    return private.command_replay_response('failed_terminal', null, 'CLOSE_START_REJECTED', v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_start_monthly_close(uuid, date, text, text, uuid, uuid)
  from public, anon, authenticated;

create or replace function private.command_validate_monthly_close(
  p_organization_id uuid,
  p_monthly_closing_id uuid,
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
  v_validation jsonb;
  v_result jsonb;
begin
  perform private.require_permission(p_organization_id, 'accounting.close_period');
  select * into v_claim from private.claim_command(
    p_organization_id, 'accounting.validate_close', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(v_claim.command_status, v_claim.result_reference, v_claim.error_code, v_claim.command_execution_id);
  end if;

  begin
    if not exists (
      select 1 from accounting.monthly_closings as mc
      where mc.id = p_monthly_closing_id and mc.organization_id = p_organization_id
    ) then
      raise exception using errcode = 'P0002', message = 'MONTHLY_CLOSE_NOT_FOUND';
    end if;
    v_validation := private.validate_monthly_close(p_monthly_closing_id);
    v_result := jsonb_build_object(
      'success', true, 'command_id', v_claim.command_execution_id,
      'entity_id', p_monthly_closing_id, 'journal_entry_ids', '[]'::jsonb,
      'warnings', case when coalesce((v_validation ->> 'ready')::boolean, false) then '[]'::jsonb else jsonb_build_array('CLOSE_NOT_READY') end,
      'error_code', null, 'message_key', 'accounting.close_validated',
      'current_state', case when coalesce((v_validation ->> 'ready')::boolean, false) then 'ready' else 'draft' end,
      'validation', v_validation
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'accounting.validate_close', 'monthly_closing', p_monthly_closing_id,
      'succeeded', null, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key, jsonb_build_object('ready', coalesce((v_validation ->> 'ready')::boolean, false))
    );
    return v_result;
  exception when others then
    perform private.complete_command_failure(v_claim.command_execution_id, 'CLOSE_VALIDATION_REJECTED', null);
    perform private.record_financial_command_audit(
      p_organization_id, 'accounting.validate_close', 'monthly_closing', p_monthly_closing_id,
      'failed', 'CLOSE_VALIDATION_REJECTED', p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key
    );
    return private.command_replay_response('failed_terminal', null, 'CLOSE_VALIDATION_REJECTED', v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_validate_monthly_close(uuid, uuid, text, text, uuid)
  from public, anon, authenticated;

create or replace function private.command_close_accounting_period(
  p_organization_id uuid,
  p_monthly_closing_id uuid,
  p_approval_request_id uuid,
  p_settings_snapshot jsonb,
  p_reconciliation_snapshot jsonb,
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
  v_close jsonb;
  v_result jsonb;
begin
  perform private.require_permission(p_organization_id, 'accounting.close_period');
  select * into v_claim from private.claim_command(
    p_organization_id, 'accounting.close_period', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(v_claim.command_status, v_claim.result_reference, v_claim.error_code, v_claim.command_execution_id);
  end if;

  begin
    if not exists (
      select 1 from accounting.monthly_closings as mc
      where mc.id = p_monthly_closing_id and mc.organization_id = p_organization_id
    ) then
      raise exception using errcode = 'P0002', message = 'MONTHLY_CLOSE_NOT_FOUND';
    end if;
    perform private.consume_approval(
      p_organization_id, p_approval_request_id, 'period.close', 'monthly_closing',
      p_monthly_closing_id, p_request_fingerprint, v_claim.command_execution_id, null
    );
    v_close := private.close_accounting_period(
      p_monthly_closing_id, p_settings_snapshot, p_reconciliation_snapshot
    );
    v_result := jsonb_build_object(
      'success', true, 'command_id', v_claim.command_execution_id,
      'entity_id', p_monthly_closing_id, 'journal_entry_ids', '[]'::jsonb,
      'warnings', '[]'::jsonb, 'error_code', null,
      'message_key', 'accounting.period_closed', 'current_state', 'closed',
      'close', v_close
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'accounting.close_period', 'monthly_closing', p_monthly_closing_id,
      'succeeded', null, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key
    );
    return v_result;
  exception when others then
    perform private.complete_command_failure(v_claim.command_execution_id, 'PERIOD_CLOSE_REJECTED', null);
    perform private.record_financial_command_audit(
      p_organization_id, 'accounting.close_period', 'monthly_closing', p_monthly_closing_id,
      'failed', 'PERIOD_CLOSE_REJECTED', p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key
    );
    return private.command_replay_response('failed_terminal', null, 'PERIOD_CLOSE_REJECTED', v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_close_accounting_period(uuid, uuid, uuid, jsonb, jsonb, text, text, uuid)
  from public, anon, authenticated;

create or replace function private.command_confirm_customer_payment(
  p_organization_id uuid,
  p_customer_payment_id uuid,
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
  v_wallet public.wallets;
  v_order_status public.order_status;
  v_credit_role text;
  v_lines jsonb;
  v_journal_entry_id uuid;
  v_result jsonb;
begin
  perform private.require_permission(p_organization_id, 'payments.review');
  select * into v_claim from private.claim_command(
    p_organization_id, 'payments.confirm', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(v_claim.command_status, v_claim.result_reference, v_claim.error_code, v_claim.command_execution_id);
  end if;

  begin
    perform private.lock_accounting_period(p_organization_id, private.cairo_accounting_date(), false);
    select cp.* into strict v_payment
    from public.customer_payments as cp
    where cp.id = p_customer_payment_id and cp.organization_id = p_organization_id
    for update;

    if v_payment.recorded_by = auth.uid() then
      raise exception using errcode = '42501', message = 'PAYMENT_SELF_REVIEW_DENIED';
    end if;

    if v_payment.status <> 'pending_review' or v_payment.request_fingerprint <> p_request_fingerprint then
      raise exception using errcode = '55000', message = 'PAYMENT_NOT_CONFIRMABLE';
    end if;

    select w.* into strict v_wallet
    from public.wallets as w
    where w.id = v_payment.wallet_id and w.organization_id = p_organization_id and w.is_active
    for update;

    if v_payment.primary_order_id is not null then
      select o.status into strict v_order_status
      from public.orders as o
      where o.id = v_payment.primary_order_id and o.organization_id = p_organization_id
      for update;
    end if;

    if v_order_status in ('partially_delivered', 'partially_returned', 'returned') then
      raise exception using errcode = '55000', message = 'PAYMENT_ALLOCATION_REQUIRED';
    end if;

    v_credit_role := case
      when v_payment.primary_order_id is null then 'customer_credits'
      when v_order_status in ('delivered', 'financially_settled')
        then 'customer_receivables'
      else 'customer_deposits'
    end;
    v_lines := jsonb_build_array(
      jsonb_build_object(
        'account_role', 'wallet_' || lower(regexp_replace(v_wallet.code, '[^a-zA-Z0-9]+', '_', 'g')),
        'debit_minor', v_payment.amount_minor::text, 'credit_minor', '0',
        'customer_id', v_payment.customer_id, 'order_id', v_payment.primary_order_id,
        'wallet_id', v_wallet.id, 'subledger_type', 'customer_payment',
        'subledger_id', v_payment.id
      ),
      jsonb_build_object(
        'account_role', v_credit_role,
        'debit_minor', '0', 'credit_minor', v_payment.amount_minor::text,
        'customer_id', v_payment.customer_id, 'order_id', v_payment.primary_order_id,
        'subledger_type', case
          when v_credit_role = 'customer_receivables' then 'customer_receivable'
          when v_credit_role = 'customer_credits' then 'customer_credit'
          else 'customer_deposit'
        end,
        'subledger_id', coalesce(v_payment.primary_order_id, v_payment.id)
      )
    );

    v_journal_entry_id := private.post_journal_entry(
      p_organization_id => p_organization_id, p_source_type => 'customer_payment',
      p_source_id => v_payment.id, p_posting_purpose => 'receipt',
      p_description => 'Confirmed customer receipt', p_lines => v_lines,
      p_idempotency_key => p_idempotency_key, p_request_hash => p_request_fingerprint,
      p_correlation_id => p_correlation_id, p_command_type => 'payments.confirm',
      p_command_execution_id => v_claim.command_execution_id,
      p_require_manual_permission => false
    );

    update public.customer_payments
    set status = 'confirmed', reviewed_by = auth.uid(), reviewed_at = statement_timestamp(),
        confirmed_at = statement_timestamp(), review_reason = 'confirmed_by_finance'
    where id = v_payment.id;

    v_result := jsonb_build_object(
      'success', true, 'command_id', v_claim.command_execution_id,
      'entity_id', v_payment.id, 'journal_entry_ids', jsonb_build_array(v_journal_entry_id),
      'warnings', '[]'::jsonb, 'error_code', null,
      'message_key', 'payment.confirmed', 'current_state', 'confirmed'
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'payments.confirm', 'customer_payment', v_payment.id,
      'succeeded', null, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key, jsonb_build_object('journal_entry_id', v_journal_entry_id)
    );
    return v_result;
  exception when others then
    perform private.complete_command_failure(v_claim.command_execution_id, 'PAYMENT_CONFIRMATION_REJECTED', null);
    perform private.record_financial_command_audit(
      p_organization_id, 'payments.confirm', 'customer_payment', p_customer_payment_id,
      'failed', 'PAYMENT_CONFIRMATION_REJECTED', p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key
    );
    return private.command_replay_response('failed_terminal', null, 'PAYMENT_CONFIRMATION_REJECTED', v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_confirm_customer_payment(uuid, uuid, text, text, uuid)
  from public, anon, authenticated;

create or replace function private.command_transfer_between_wallets(
  p_organization_id uuid,
  p_wallet_transfer_id uuid,
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
  v_transfer public.wallet_transfers;
  v_source public.wallets;
  v_destination public.wallets;
  v_lines jsonb;
  v_journal_entry_id uuid;
  v_result jsonb;
begin
  perform private.require_permission(p_organization_id, 'wallets.transfer');
  select * into v_claim from private.claim_command(
    p_organization_id, 'wallets.transfer', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(v_claim.command_status, v_claim.result_reference, v_claim.error_code, v_claim.command_execution_id);
  end if;

  begin
    perform private.lock_accounting_period(p_organization_id, private.cairo_accounting_date(), false);
    select wt.* into strict v_transfer
    from public.wallet_transfers as wt
    where wt.id = p_wallet_transfer_id and wt.organization_id = p_organization_id
    for update;

    if v_transfer.status <> 'approved'
       or v_transfer.request_fingerprint <> p_request_fingerprint
       or v_transfer.idempotency_key <> p_idempotency_key then
      raise exception using errcode = '55000', message = 'WALLET_TRANSFER_NOT_EXECUTABLE';
    end if;

    perform 1 from public.wallets as w
    where w.id in (v_transfer.source_wallet_id, v_transfer.destination_wallet_id)
      and w.organization_id = p_organization_id
    order by w.id
    for update;

    select w.* into strict v_source from public.wallets as w
    where w.id = v_transfer.source_wallet_id and w.organization_id = p_organization_id and w.is_active;
    select w.* into strict v_destination from public.wallets as w
    where w.id = v_transfer.destination_wallet_id and w.organization_id = p_organization_id and w.is_active;

    perform private.consume_approval(
      p_organization_id, v_transfer.approval_request_id, 'wallet.transfer', 'wallet_transfer',
      v_transfer.id, p_request_fingerprint, v_claim.command_execution_id, v_transfer.amount_minor
    );

    v_lines := jsonb_build_array(
      jsonb_build_object(
        'account_role', 'wallet_' || lower(regexp_replace(v_destination.code, '[^a-zA-Z0-9]+', '_', 'g')),
        'debit_minor', v_transfer.amount_minor::text, 'credit_minor', '0',
        'wallet_id', v_destination.id, 'subledger_type', 'wallet_transfer', 'subledger_id', v_transfer.id
      ),
      jsonb_build_object(
        'account_role', 'wallet_' || lower(regexp_replace(v_source.code, '[^a-zA-Z0-9]+', '_', 'g')),
        'debit_minor', '0', 'credit_minor', (v_transfer.amount_minor + v_transfer.fee_minor)::text,
        'wallet_id', v_source.id, 'subledger_type', 'wallet_transfer', 'subledger_id', v_transfer.id
      )
    );
    if v_transfer.fee_minor > 0 then
      v_lines := v_lines || jsonb_build_array(jsonb_build_object(
        'account_role', 'financial_transfer_fees',
        'debit_minor', v_transfer.fee_minor::text, 'credit_minor', '0',
        'subledger_type', 'wallet_transfer_fee', 'subledger_id', v_transfer.id
      ));
    end if;

    v_journal_entry_id := private.post_journal_entry(
      p_organization_id => p_organization_id, p_source_type => 'wallet_transfer',
      p_source_id => v_transfer.id, p_posting_purpose => 'execution',
      p_description => 'Wallet transfer', p_lines => v_lines,
      p_idempotency_key => p_idempotency_key, p_request_hash => p_request_fingerprint,
      p_correlation_id => p_correlation_id, p_command_type => 'wallets.transfer',
      p_command_execution_id => v_claim.command_execution_id,
      p_require_manual_permission => false
    );

    update public.wallet_transfers
    set status = 'executed', executed_by = auth.uid(), executed_at = statement_timestamp(),
        correlation_id = p_correlation_id
    where id = v_transfer.id;

    v_result := jsonb_build_object(
      'success', true, 'command_id', v_claim.command_execution_id,
      'entity_id', v_transfer.id, 'journal_entry_ids', jsonb_build_array(v_journal_entry_id),
      'warnings', '[]'::jsonb, 'error_code', null,
      'message_key', 'wallet.transfer_executed', 'current_state', 'executed'
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'wallets.transfer', 'wallet_transfer', v_transfer.id,
      'succeeded', null, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key, jsonb_build_object('journal_entry_id', v_journal_entry_id)
    );
    return v_result;
  exception when others then
    perform private.complete_command_failure(v_claim.command_execution_id, 'WALLET_TRANSFER_REJECTED', null);
    perform private.record_financial_command_audit(
      p_organization_id, 'wallets.transfer', 'wallet_transfer', p_wallet_transfer_id,
      'failed', 'WALLET_TRANSFER_REJECTED', p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key
    );
    return private.command_replay_response('failed_terminal', null, 'WALLET_TRANSFER_REJECTED', v_claim.command_execution_id);
  end;
end;
$$;

revoke all on function private.command_transfer_between_wallets(uuid, uuid, text, text, uuid)
  from public, anon, authenticated;

create or replace function api.post_journal_entry(
  p_organization_id uuid, p_source_type text, p_source_id uuid,
  p_posting_purpose text, p_description text, p_lines jsonb,
  p_idempotency_key text, p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid(),
  p_accounting_date date default null, p_approval_request_id uuid default null,
  p_corrects_entry_id uuid default null, p_affected_closed_period_id uuid default null
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_post_journal_entry(
  p_organization_id, p_source_type, p_source_id, p_posting_purpose, p_description,
  p_lines, p_idempotency_key, p_request_fingerprint, p_correlation_id,
  p_accounting_date, p_approval_request_id, p_corrects_entry_id, p_affected_closed_period_id
) $$;

create or replace function api.reverse_journal_entry(
  p_organization_id uuid, p_original_entry_id uuid, p_reason text,
  p_idempotency_key text, p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid(), p_approval_request_id uuid default null
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_reverse_journal_entry(
  p_organization_id, p_original_entry_id, p_reason, p_idempotency_key,
  p_request_fingerprint, p_correlation_id, p_approval_request_id
) $$;

create or replace function api.start_monthly_close(
  p_organization_id uuid, p_period_start date, p_idempotency_key text,
  p_request_fingerprint text, p_correlation_id uuid default extensions.gen_random_uuid(),
  p_approval_request_id uuid default null
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_start_monthly_close(
  p_organization_id, p_period_start, p_idempotency_key, p_request_fingerprint,
  p_correlation_id, p_approval_request_id
) $$;

create or replace function api.validate_monthly_close(
  p_organization_id uuid, p_monthly_closing_id uuid, p_idempotency_key text,
  p_request_fingerprint text, p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_validate_monthly_close(
  p_organization_id, p_monthly_closing_id, p_idempotency_key,
  p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.close_accounting_period(
  p_organization_id uuid, p_monthly_closing_id uuid, p_approval_request_id uuid,
  p_settings_snapshot jsonb, p_reconciliation_snapshot jsonb,
  p_idempotency_key text, p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_close_accounting_period(
  p_organization_id, p_monthly_closing_id, p_approval_request_id,
  p_settings_snapshot, p_reconciliation_snapshot, p_idempotency_key,
  p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.confirm_customer_payment(
  p_organization_id uuid, p_customer_payment_id uuid, p_idempotency_key text,
  p_request_fingerprint text, p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_confirm_customer_payment(
  p_organization_id, p_customer_payment_id, p_idempotency_key,
  p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.transfer_between_wallets(
  p_organization_id uuid, p_wallet_transfer_id uuid, p_idempotency_key text,
  p_request_fingerprint text, p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_transfer_between_wallets(
  p_organization_id, p_wallet_transfer_id, p_idempotency_key,
  p_request_fingerprint, p_correlation_id
) $$;

revoke all on all functions in schema api from public, anon, authenticated;

comment on function api.post_journal_entry(uuid, text, uuid, text, text, jsonb, text, text, uuid, date, uuid, uuid, uuid) is
  'Thin invoker wrapper for an authorized idempotent manual journal command.';
comment on function api.reverse_journal_entry(uuid, uuid, text, text, text, uuid, uuid) is
  'Thin invoker wrapper for an approved mirrored reversal command.';
comment on function api.start_monthly_close(uuid, date, text, text, uuid, uuid) is
  'Thin invoker wrapper that acquires the common period lock and starts close.';
comment on function api.validate_monthly_close(uuid, uuid, text, text, uuid) is
  'Thin invoker wrapper for close validation and snapshot totals.';
comment on function api.close_accounting_period(uuid, uuid, uuid, jsonb, jsonb, text, text, uuid) is
  'Thin invoker wrapper for approval consumption and final period close.';
comment on function api.confirm_customer_payment(uuid, uuid, text, text, uuid) is
  'Thin invoker wrapper for confirmed receipt posting to wallet and deposit or receivable control.';
comment on function api.transfer_between_wallets(uuid, uuid, text, text, uuid) is
  'Thin invoker wrapper for a profit-neutral wallet transfer with separately posted fee.';

grant execute on function private.command_post_journal_entry(
  uuid, text, uuid, text, text, jsonb, text, text, uuid, date, uuid, uuid, uuid
) to authenticated;
grant execute on function private.command_reverse_journal_entry(uuid, uuid, text, text, text, uuid, uuid)
  to authenticated;
grant execute on function private.command_start_monthly_close(uuid, date, text, text, uuid, uuid)
  to authenticated;
grant execute on function private.command_validate_monthly_close(uuid, uuid, text, text, uuid)
  to authenticated;
grant execute on function private.command_close_accounting_period(uuid, uuid, uuid, jsonb, jsonb, text, text, uuid)
  to authenticated;
grant execute on function private.command_confirm_customer_payment(uuid, uuid, text, text, uuid)
  to authenticated;
grant execute on function private.command_transfer_between_wallets(uuid, uuid, text, text, uuid)
  to authenticated;

create or replace function private.command_submit_approval_request(
  p_organization_id uuid,
  p_request_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_required_permission text,
  p_reason text,
  p_payload_snapshot jsonb,
  p_subject_fingerprint text,
  p_requested_amount_minor bigint default null,
  p_requester_partner_id uuid default null,
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_permission_id uuid;
  v_request_id uuid;
  v_server_fingerprint text;
begin
  if v_actor is null or p_organization_id is distinct from private.current_organization_id() then
    raise exception using errcode = '42501', message = 'APPROVAL_REQUEST_ORGANIZATION_DENIED';
  end if;
  if jsonb_typeof(p_payload_snapshot) <> 'object' then
    raise exception using errcode = '22023', message = 'APPROVAL_PAYLOAD_MUST_BE_OBJECT';
  end if;

  v_server_fingerprint := encode(extensions.digest(convert_to(p_payload_snapshot::text, 'UTF8'), 'sha256'), 'hex');
  if p_subject_fingerprint <> v_server_fingerprint then
    raise exception using errcode = '22023', message = 'APPROVAL_FINGERPRINT_MISMATCH';
  end if;

  select permission.id into strict v_permission_id
  from private.permissions as permission
  where permission.permission_key = p_required_permission and permission.is_active;

  if p_requester_partner_id is not null and not exists (
    select 1 from public.partners as partner
    where partner.organization_id = p_organization_id
      and partner.id = p_requester_partner_id
      and partner.profile_id = v_actor
      and partner.is_active
  ) then
    raise exception using errcode = '42501', message = 'REQUESTER_PARTNER_IDENTITY_MISMATCH';
  end if;

  insert into public.approval_requests (
    organization_id, request_type, entity_type, entity_id, requested_by,
    requester_partner_id, submitted_at, status, required_permission_id,
    requires_separation_of_duties, required_approval_count, reason,
    subject_fingerprint, requested_amount_minor, approved_min_amount_minor,
    approved_max_amount_minor, payload_snapshot, expires_at
  ) values (
    p_organization_id, p_request_type, p_entity_type, p_entity_id, v_actor,
    p_requester_partner_id, statement_timestamp(), 'submitted', v_permission_id,
    true, 1, p_reason, p_subject_fingerprint, p_requested_amount_minor,
    p_requested_amount_minor, p_requested_amount_minor, p_payload_snapshot, p_expires_at
  ) returning id into v_request_id;
  return v_request_id;
end;
$$;

create or replace function private.command_decide_approval(
  p_organization_id uuid,
  p_approval_request_id uuid,
  p_action public.approval_action_type,
  p_comment text default null,
  p_approver_partner_id uuid default null,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns public.approval_status
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_request public.approval_requests;
  v_prior_approvals integer;
  v_result public.approval_status;
begin
  if v_actor is null or p_organization_id is distinct from private.current_organization_id() then
    raise exception using errcode = '42501', message = 'APPROVAL_DECISION_ORGANIZATION_DENIED';
  end if;

  select request.* into strict v_request
  from public.approval_requests as request
  where request.organization_id = p_organization_id and request.id = p_approval_request_id
  for update;

  select count(*) into v_prior_approvals
  from public.approval_actions as action
  where action.approval_request_id = v_request.id and action.action_type = 'approve';

  v_result := case
    when p_action = 'approve' and v_prior_approvals + 1 >= v_request.required_approval_count then 'approved'::public.approval_status
    when p_action = 'approve' then 'submitted'::public.approval_status
    when p_action = 'reject' then 'rejected'::public.approval_status
    else 'cancelled'::public.approval_status
  end;

  insert into public.approval_actions (
    organization_id, approval_request_id, action_type, acted_by,
    approver_partner_id, comment, previous_status, resulting_status,
    subject_fingerprint, correlation_id
  ) values (
    p_organization_id, v_request.id, p_action, v_actor,
    p_approver_partner_id, p_comment, v_request.status, v_result,
    v_request.subject_fingerprint, p_correlation_id
  );

  if v_result <> 'submitted' then
    update public.approval_requests
    set status = v_result,
        resolved_at = statement_timestamp(),
        resolved_by = v_actor,
        resolution_reason = case when v_result in ('rejected', 'cancelled') then p_comment else null end
    where id = v_request.id;
  end if;
  return v_result;
end;
$$;

revoke all on function private.command_submit_approval_request(uuid, text, text, uuid, text, text, jsonb, text, bigint, uuid, timestamptz)
  from public, anon, authenticated;
revoke all on function private.command_decide_approval(uuid, uuid, public.approval_action_type, text, uuid, uuid)
  from public, anon, authenticated;

create or replace function api.submit_approval_request(
  p_organization_id uuid, p_request_type text, p_entity_type text, p_entity_id uuid,
  p_required_permission text, p_reason text, p_payload_snapshot jsonb,
  p_subject_fingerprint text, p_requested_amount_minor bigint default null,
  p_requester_partner_id uuid default null, p_expires_at timestamptz default null
)
returns uuid language sql volatile security invoker set search_path = ''
as $$ select private.command_submit_approval_request(
  p_organization_id, p_request_type, p_entity_type, p_entity_id,
  p_required_permission, p_reason, p_payload_snapshot, p_subject_fingerprint,
  p_requested_amount_minor, p_requester_partner_id, p_expires_at
) $$;

create or replace function api.decide_approval(
  p_organization_id uuid, p_approval_request_id uuid,
  p_action public.approval_action_type, p_comment text default null,
  p_approver_partner_id uuid default null,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns public.approval_status language sql volatile security invoker set search_path = ''
as $$ select private.command_decide_approval(
  p_organization_id, p_approval_request_id, p_action, p_comment,
  p_approver_partner_id, p_correlation_id
) $$;

revoke all on function api.submit_approval_request(uuid, text, text, uuid, text, text, jsonb, text, bigint, uuid, timestamptz)
  from public, anon, authenticated;
revoke all on function api.decide_approval(uuid, uuid, public.approval_action_type, text, uuid, uuid)
  from public, anon, authenticated;
grant execute on function private.command_submit_approval_request(uuid, text, text, uuid, text, text, jsonb, text, bigint, uuid, timestamptz)
  to authenticated;
grant execute on function private.command_decide_approval(uuid, uuid, public.approval_action_type, text, uuid, uuid)
  to authenticated;
