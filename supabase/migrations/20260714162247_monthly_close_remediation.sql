-- Executable monthly-close evidence, cancellation/recovery, and exceptional reopen.

create or replace function private.refresh_monthly_close_evidence(p_monthly_closing_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_close accounting.monthly_closings;
  v_period accounting.accounting_periods;
  v_totals jsonb;
  v_negative_inventory bigint;
  v_unposted_delivery bigint;
  v_unposted_expense bigint;
  v_pending_returns bigint;
  v_pending_approvals bigint;
  v_ownership_bps bigint;
  v_suspense_balance bigint;
begin
  select mc.* into strict v_close
  from accounting.monthly_closings as mc
  where mc.id = p_monthly_closing_id
  for update;
  perform private.require_permission(v_close.organization_id, 'accounting.close_period');

  select ap.* into strict v_period
  from accounting.accounting_periods as ap
  where ap.id = v_close.accounting_period_id
    and ap.organization_id = v_close.organization_id
  for update;

  if v_close.status = 'closed' or v_period.status <> 'closing' then
    raise exception using errcode = '55000', message = 'CLOSE_EVIDENCE_NOT_EDITABLE';
  end if;

  v_totals := private.calculate_period_close_totals(v_close.organization_id, v_period.id);

  select count(*) into v_negative_inventory
  from public.inventory_negative_balance_alerts as a
  where a.organization_id = v_close.organization_id;

  select count(*) into v_unposted_delivery
  from public.unposted_financial_events as e
  where e.organization_id = v_close.organization_id
    and e.event_type = 'shipment_item_delivery'
    and (e.occurred_at at time zone 'Africa/Cairo')::date <= v_period.period_end;

  select count(*) into v_unposted_expense
  from public.unposted_financial_events as e
  where e.organization_id = v_close.organization_id
    and e.event_type = 'approved_expense'
    and (e.occurred_at at time zone 'Africa/Cairo')::date <= v_period.period_end;

  select count(*) into v_pending_returns
  from public.return_items as ri
  join public.returns as r
    on r.organization_id = ri.organization_id and r.id = ri.return_id
  where ri.organization_id = v_close.organization_id
    and ri.disposition = 'pending_inspection'
    and r.requested_at::date <= v_period.period_end;

  select count(*) into v_pending_approvals
  from public.approval_requests as ar
  where ar.organization_id = v_close.organization_id
    and ar.status in ('draft', 'submitted', 'approved')
    and ar.requested_at::date <= v_period.period_end
    and ar.entity_id <> p_monthly_closing_id;

  select coalesce(sum(pop.profit_share_bps), 0) into v_ownership_bps
  from public.partner_ownership_periods as pop
  join public.partners as p
    on p.organization_id = pop.organization_id and p.id = pop.partner_id
  where pop.organization_id = v_close.organization_id
    and p.is_active
    and pop.effective_from <= v_period.period_end
    and (pop.effective_to is null or pop.effective_to > v_period.period_end);

  select coalesce(sum(jl.debit_minor - jl.credit_minor), 0) into v_suspense_balance
  from accounting.journal_entries as je
  join accounting.journal_lines as jl on jl.journal_entry_id = je.id
  join accounting.account_role_mappings as arm
    on arm.organization_id = je.organization_id and arm.account_id = jl.account_id
  join accounting.account_roles as ar
    on ar.organization_id = arm.organization_id and ar.id = arm.account_role_id
  where je.organization_id = v_close.organization_id
    and je.accounting_period_id = v_period.id
    and je.status in ('posted', 'reversed')
    and ar.role_key = 'suspense'
    and arm.effective_range @> je.accounting_date;

  update accounting.closing_checklist_items
  set status = case
        when (v_totals ->> 'trial_debit_minor') = (v_totals ->> 'trial_credit_minor') then 'passed'
        else 'failed'
      end,
      expected_minor = (v_totals ->> 'trial_debit_minor')::bigint,
      actual_minor = (v_totals ->> 'trial_credit_minor')::bigint,
      evidence = jsonb_build_object('calculation', 'posted_journal_trial_balance', 'totals', v_totals),
      checked_by = auth.uid(), checked_at = statement_timestamp()
  where monthly_closing_id = p_monthly_closing_id and item_key = 'trial_balance';

  update accounting.closing_checklist_items
  set status = case when v_negative_inventory = 0 and v_unposted_delivery = 0 then 'passed' else 'failed' end,
      expected_minor = 0, actual_minor = v_negative_inventory + v_unposted_delivery,
      evidence = jsonb_build_object(
        'negative_inventory_count', v_negative_inventory,
        'unposted_delivery_count', v_unposted_delivery
      ), checked_by = auth.uid(), checked_at = statement_timestamp()
  where monthly_closing_id = p_monthly_closing_id and item_key = 'inventory_cogs';

  update accounting.closing_checklist_items
  set status = case when v_unposted_expense = 0 then 'passed' else 'failed' end,
      expected_minor = 0, actual_minor = v_unposted_expense,
      evidence = jsonb_build_object('unposted_approved_expense_count', v_unposted_expense),
      checked_by = auth.uid(), checked_at = statement_timestamp()
  where monthly_closing_id = p_monthly_closing_id and item_key = 'expenses';

  update accounting.closing_checklist_items
  set status = case when v_suspense_balance = 0 then 'passed' else 'failed' end,
      expected_minor = 0, actual_minor = v_suspense_balance,
      evidence = jsonb_build_object('suspense_balance_minor', v_suspense_balance),
      checked_by = auth.uid(), checked_at = statement_timestamp()
  where monthly_closing_id = p_monthly_closing_id and item_key = 'suspense_zero';

  update accounting.closing_checklist_items
  set status = case when v_unposted_delivery = 0 then 'passed' else 'failed' end,
      expected_minor = 0, actual_minor = v_unposted_delivery,
      evidence = jsonb_build_object('unposted_delivery_count', v_unposted_delivery),
      checked_by = auth.uid(), checked_at = statement_timestamp()
  where monthly_closing_id = p_monthly_closing_id and item_key = 'delivered_orders_posted';

  update accounting.closing_checklist_items
  set status = case when v_pending_returns = 0 then 'passed' else 'failed' end,
      expected_minor = 0, actual_minor = v_pending_returns,
      evidence = jsonb_build_object('pending_return_disposition_count', v_pending_returns),
      checked_by = auth.uid(), checked_at = statement_timestamp()
  where monthly_closing_id = p_monthly_closing_id and item_key = 'returns_classified';

  update accounting.closing_checklist_items
  set status = case when v_pending_approvals = 0 then 'passed' else 'failed' end,
      expected_minor = 0, actual_minor = v_pending_approvals,
      evidence = jsonb_build_object('open_approval_count', v_pending_approvals),
      checked_by = auth.uid(), checked_at = statement_timestamp()
  where monthly_closing_id = p_monthly_closing_id and item_key = 'pending_approvals';

  update accounting.closing_checklist_items
  set status = case when v_ownership_bps = 10000 then 'passed' else 'failed' end,
      expected_minor = 10000, actual_minor = v_ownership_bps,
      evidence = jsonb_build_object(
        'profit_share_bps_at_period_end', v_ownership_bps,
        'snapshot_date', v_period.period_end
      ), checked_by = auth.uid(), checked_at = statement_timestamp()
  where monthly_closing_id = p_monthly_closing_id and item_key = 'ownership_snapshot';

  return jsonb_build_object(
    'monthly_closing_id', p_monthly_closing_id,
    'period_start', v_period.period_start,
    'period_end', v_period.period_end,
    'totals', v_totals,
    'negative_inventory_count', v_negative_inventory,
    'unposted_delivery_count', v_unposted_delivery,
    'unposted_expense_count', v_unposted_expense,
    'pending_return_count', v_pending_returns,
    'pending_approval_count', v_pending_approvals,
    'ownership_bps', v_ownership_bps,
    'suspense_balance_minor', v_suspense_balance
  );
end;
$$;

revoke all on function private.refresh_monthly_close_evidence(uuid)
  from public, anon, authenticated;

create or replace function private.validate_monthly_close(p_monthly_closing_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_closing accounting.monthly_closings;
  v_period accounting.accounting_periods;
  v_target_date date;
  v_totals jsonb;
  v_evidence jsonb;
  v_distribution_basis jsonb;
  v_blocking_count bigint;
  v_unbalanced_count bigint;
  v_ready boolean;
begin
  select mc.* into strict v_closing
  from accounting.monthly_closings as mc
  where mc.id = p_monthly_closing_id;
  perform private.require_permission(v_closing.organization_id, 'accounting.close_period');

  select ap.period_start into strict v_target_date
  from accounting.accounting_periods as ap
  where ap.id = v_closing.accounting_period_id
    and ap.organization_id = v_closing.organization_id;
  v_period := private.lock_accounting_period(v_closing.organization_id, v_target_date, true);
  v_evidence := private.refresh_monthly_close_evidence(p_monthly_closing_id);
  v_distribution_basis := private.refresh_monthly_close_distribution_basis(p_monthly_closing_id);

  select count(*) into v_unbalanced_count
  from accounting.journal_entries as je
  where je.accounting_period_id = v_period.id
    and je.status in ('posted', 'reversed')
    and (je.total_debit_minor <= 0 or je.total_debit_minor <> je.total_credit_minor);

  select count(*) into v_blocking_count
  from accounting.closing_checklist_items as cci
  where cci.monthly_closing_id = v_closing.id
    and cci.is_blocking
    and cci.status not in ('passed', 'waived');

  v_totals := private.calculate_period_close_totals(v_closing.organization_id, v_period.id);
  v_ready := v_unbalanced_count = 0
    and v_blocking_count = 0
    and (v_totals ->> 'trial_debit_minor') = (v_totals ->> 'trial_credit_minor');

  update accounting.monthly_closings
  set status = case when v_ready then 'ready' else 'draft' end,
      trial_balance_debit_minor = (v_totals ->> 'trial_debit_minor')::bigint,
      trial_balance_credit_minor = (v_totals ->> 'trial_credit_minor')::bigint,
      period_revenue_minor = (
        (v_totals ->> 'revenue_minor')::bigint
        - (v_totals ->> 'contra_revenue_minor')::bigint
      ),
      period_expense_minor = (v_totals ->> 'expense_minor')::bigint,
      period_profit_loss_minor = (v_totals ->> 'profit_loss_minor')::bigint,
      validation_result = jsonb_build_object(
        'ready', v_ready,
        'blocking_checklist_count', v_blocking_count,
        'unbalanced_entry_count', v_unbalanced_count,
        'evidence', v_evidence,
        'distribution_basis', v_distribution_basis,
        'validated_at', statement_timestamp()
      ),
      validated_by = auth.uid(), validated_at = statement_timestamp()
  where id = v_closing.id;

  return jsonb_build_object(
    'ready', v_ready,
    'monthly_closing_id', v_closing.id,
    'accounting_period_id', v_period.id,
    'blocking_checklist_count', v_blocking_count,
    'unbalanced_entry_count', v_unbalanced_count,
    'totals', v_totals,
    'evidence', v_evidence,
    'distribution_basis', v_distribution_basis
  );
end;
$$;

revoke all on function private.validate_monthly_close(uuid) from public, anon, authenticated;

create or replace function private.command_attest_monthly_close_item(
  p_organization_id uuid,
  p_monthly_closing_id uuid,
  p_item_key text,
  p_status text,
  p_expected_minor bigint,
  p_actual_minor bigint,
  p_evidence jsonb,
  p_notes text,
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
  v_period_start date;
  v_result jsonb;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'monthly_closing_id', p_monthly_closing_id,
    'item_key', p_item_key,
    'status', p_status,
    'expected_minor', p_expected_minor,
    'actual_minor', p_actual_minor,
    'evidence', p_evidence,
    'notes', p_notes,
    'approval_request_id', p_approval_request_id
  );
begin
  perform private.require_permission(p_organization_id, 'accounting.close_period');
  perform private.assert_request_fingerprint(
    'accounting.attest_close_item', v_payload, p_request_fingerprint, 1::smallint
  );
  if p_status not in ('passed', 'failed', 'waived')
     or jsonb_typeof(p_evidence) <> 'object'
     or p_evidence = '{}'::jsonb then
    raise exception using errcode = '22023', message = 'CLOSE_ITEM_EVIDENCE_REQUIRED';
  end if;

  select * into v_claim from private.claim_command(
    p_organization_id, 'accounting.attest_close_item', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
  select ap.period_start into strict v_period_start
  from accounting.monthly_closings as mc
  join accounting.accounting_periods as ap
    on ap.organization_id = mc.organization_id and ap.id = mc.accounting_period_id
  where mc.id = p_monthly_closing_id and mc.organization_id = p_organization_id;
  perform private.lock_accounting_period(p_organization_id, v_period_start, true);

  if p_status = 'waived' then
    if p_approval_request_id is null then
      raise exception using errcode = '55000', message = 'CLOSE_ITEM_WAIVER_APPROVAL_REQUIRED';
    end if;
    perform private.consume_approval(
      p_organization_id, p_approval_request_id, 'period.close_waiver',
      'monthly_closing', p_monthly_closing_id, p_request_fingerprint,
      v_claim.command_execution_id, abs(coalesce(p_actual_minor, 0) - coalesce(p_expected_minor, 0))
    );
  end if;

  update accounting.closing_checklist_items
  set status = p_status,
      expected_minor = p_expected_minor,
      actual_minor = p_actual_minor,
      evidence = p_evidence || jsonb_build_object(
        'attested_at', statement_timestamp(),
        'approval_request_id', p_approval_request_id
      ),
      notes = nullif(btrim(p_notes), ''),
      checked_by = auth.uid(), checked_at = statement_timestamp()
  where monthly_closing_id = p_monthly_closing_id and item_key = p_item_key;
  if not found then
    raise exception using errcode = 'P0002', message = 'CLOSE_CHECKLIST_ITEM_NOT_FOUND';
  end if;

  v_result := private.command_success_response(
    v_claim.command_execution_id, p_monthly_closing_id, p_status,
    'accounting.close_item_attested', '[]'::jsonb,
    jsonb_build_object('item_key', p_item_key)
  );
  perform private.complete_command_success(v_claim.command_execution_id, v_result);
  return v_result;
exception when others then
  if v_claim.command_execution_id is not null then
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'CLOSE_ITEM_ATTESTATION_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'CLOSE_ITEM_ATTESTATION_REJECTED',
      v_claim.command_execution_id
    );
  end if;
  raise;
end;
end;
$$;

revoke all on function private.command_attest_monthly_close_item(
  uuid, uuid, text, text, bigint, bigint, jsonb, text, uuid, text, text, uuid
) from public, anon, authenticated;

create or replace function private.command_change_monthly_close_state(
  p_organization_id uuid,
  p_monthly_closing_id uuid,
  p_action text,
  p_reason text,
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
  v_close accounting.monthly_closings;
  v_period accounting.accounting_periods;
  v_result jsonb;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'monthly_closing_id', p_monthly_closing_id,
    'action', p_action,
    'reason', p_reason,
    'approval_request_id', p_approval_request_id
  );
begin
  if p_action in ('cancel', 'recover') then
    perform private.require_permission(p_organization_id, 'accounting.close_period');
  elsif p_action = 'reopen' then
    perform private.require_permission(p_organization_id, 'accounting.reopen_period');
  else
    raise exception using errcode = '22023', message = 'INVALID_CLOSE_ACTION';
  end if;
  perform private.assert_request_fingerprint(
    'accounting.' || p_action || '_close', v_payload, p_request_fingerprint, 1::smallint
  );
  if nullif(btrim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'CLOSE_ACTION_REASON_REQUIRED';
  end if;

  select * into v_claim from private.claim_command(
    p_organization_id, 'accounting.' || p_action || '_close', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
  select mc.* into strict v_close
  from accounting.monthly_closings as mc
  where mc.id = p_monthly_closing_id and mc.organization_id = p_organization_id
  for update;
  select ap.* into strict v_period
  from accounting.accounting_periods as ap
  where ap.id = v_close.accounting_period_id and ap.organization_id = p_organization_id
  for update;

  if p_action = 'cancel' then
    if v_close.status not in ('draft', 'validating', 'ready') or v_period.status <> 'closing' then
      raise exception using errcode = '55000', message = 'CLOSE_NOT_CANCELLABLE';
    end if;
    update accounting.monthly_closings set status = 'cancelled' where id = v_close.id;
    update accounting.accounting_periods
    set status = 'open', close_requested_by = null, close_requested_at = null,
        version = version + 1
    where id = v_period.id;
  elsif p_action = 'recover' then
    if v_close.status <> 'cancelled' or v_period.status <> 'open' then
      raise exception using errcode = '55000', message = 'CLOSE_NOT_RECOVERABLE';
    end if;
    update accounting.monthly_closings
    set status = 'draft', requested_by = auth.uid(), requested_at = statement_timestamp(),
        correlation_id = p_correlation_id
    where id = v_close.id;
    update accounting.accounting_periods
    set status = 'closing', close_requested_by = auth.uid(),
        close_requested_at = statement_timestamp(), version = version + 1
    where id = v_period.id;
  else
    if v_close.status <> 'closed' or v_period.status <> 'closed' then
      raise exception using errcode = '55000', message = 'PERIOD_NOT_REOPENABLE';
    end if;
    if p_approval_request_id is null then
      raise exception using errcode = '55000', message = 'PERIOD_REOPEN_APPROVAL_REQUIRED';
    end if;
    perform private.consume_approval(
      p_organization_id, p_approval_request_id, 'period.reopen',
      'accounting_period', v_period.id, p_request_fingerprint,
      v_claim.command_execution_id, null
    );
    update accounting.accounting_periods
    set status = 'reopened_exceptionally', closed_by = null, closed_at = null,
        reopen_reason = p_reason, reopened_by = auth.uid(),
        reopened_at = statement_timestamp(), version = version + 1
    where id = v_period.id;
  end if;

  v_result := private.command_success_response(
    v_claim.command_execution_id,
    case when p_action = 'reopen' then v_period.id else v_close.id end,
    case p_action when 'cancel' then 'cancelled'
      when 'recover' then 'closing' else 'reopened_exceptionally' end,
    'accounting.' || p_action || '_succeeded'
  );
  perform private.complete_command_success(v_claim.command_execution_id, v_result);
  perform private.record_financial_command_audit(
    p_organization_id, 'accounting.' || p_action || '_close',
    case when p_action = 'reopen' then 'accounting_period' else 'monthly_closing' end,
    case when p_action = 'reopen' then v_period.id else v_close.id end,
    'succeeded', p_reason, p_correlation_id, v_claim.command_execution_id,
    p_idempotency_key
  );
  return v_result;
exception when others then
  if v_claim.command_execution_id is not null then
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'CLOSE_STATE_CHANGE_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'CLOSE_STATE_CHANGE_REJECTED',
      v_claim.command_execution_id
    );
  end if;
  raise;
end;
end;
$$;

revoke all on function private.command_change_monthly_close_state(
  uuid, uuid, text, text, uuid, text, text, uuid
) from public, anon, authenticated;

create or replace function api.attest_monthly_close_item(
  p_organization_id uuid, p_monthly_closing_id uuid, p_item_key text,
  p_status text, p_expected_minor bigint, p_actual_minor bigint,
  p_evidence jsonb, p_notes text, p_approval_request_id uuid,
  p_idempotency_key text, p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_attest_monthly_close_item(
  p_organization_id, p_monthly_closing_id, p_item_key, p_status,
  p_expected_minor, p_actual_minor, p_evidence, p_notes,
  p_approval_request_id, p_idempotency_key, p_request_fingerprint,
  p_correlation_id
) $$;

create or replace function api.cancel_monthly_close(
  p_organization_id uuid, p_monthly_closing_id uuid, p_reason text,
  p_idempotency_key text, p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_change_monthly_close_state(
  p_organization_id, p_monthly_closing_id, 'cancel', p_reason, null,
  p_idempotency_key, p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.recover_monthly_close(
  p_organization_id uuid, p_monthly_closing_id uuid, p_reason text,
  p_idempotency_key text, p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_change_monthly_close_state(
  p_organization_id, p_monthly_closing_id, 'recover', p_reason, null,
  p_idempotency_key, p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.reopen_accounting_period(
  p_organization_id uuid, p_monthly_closing_id uuid, p_reason text,
  p_approval_request_id uuid, p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_change_monthly_close_state(
  p_organization_id, p_monthly_closing_id, 'reopen', p_reason,
  p_approval_request_id, p_idempotency_key, p_request_fingerprint,
  p_correlation_id
) $$;

revoke all on function api.attest_monthly_close_item(
  uuid, uuid, text, text, bigint, bigint, jsonb, text, uuid, text, text, uuid
) from public, anon, authenticated;
revoke all on function api.cancel_monthly_close(uuid, uuid, text, text, text, uuid)
  from public, anon, authenticated;
revoke all on function api.recover_monthly_close(uuid, uuid, text, text, text, uuid)
  from public, anon, authenticated;
revoke all on function api.reopen_accounting_period(uuid, uuid, text, uuid, text, text, uuid)
  from public, anon, authenticated;

grant execute on function api.attest_monthly_close_item(
  uuid, uuid, text, text, bigint, bigint, jsonb, text, uuid, text, text, uuid
) to authenticated;
grant execute on function api.cancel_monthly_close(uuid, uuid, text, text, text, uuid)
  to authenticated;
grant execute on function api.recover_monthly_close(uuid, uuid, text, text, text, uuid)
  to authenticated;
grant execute on function api.reopen_accounting_period(uuid, uuid, text, uuid, text, text, uuid)
  to authenticated;
