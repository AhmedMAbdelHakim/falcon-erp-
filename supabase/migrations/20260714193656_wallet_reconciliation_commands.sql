alter table public.wallet_reconciliation_items
  drop constraint wallet_reconciliation_items_source_type_check;
alter table public.wallet_reconciliation_items
  add constraint wallet_reconciliation_items_source_type_check check (
    source_type in (
      'customer_payment', 'customer_refund', 'wallet_transfer',
      'courier_settlement', 'supplier_payment', 'expense_payment',
      'payroll_payment', 'partner_withdrawal', 'partner_capital',
      'partner_loan', 'manual_journal', 'journal_reversal',
      'wallet_reconciliation', 'journal_adjustment'
    )
  );

create or replace function private.command_prepare_wallet_reconciliation(
  p_organization_id uuid,
  p_wallet_id uuid,
  p_period_started_at timestamptz,
  p_period_ended_at timestamptz,
  p_actual_closing_balance_minor bigint,
  p_evidence_attachment_id uuid,
  p_difference_explanation text,
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
  v_wallet public.wallets;
  v_reconciliation_id uuid := extensions.gen_random_uuid();
  v_approval_id uuid;
  v_opening bigint;
  v_movements bigint;
  v_expected bigint;
  v_difference bigint;
  v_reconciliation_date date;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'wallet_id', p_wallet_id,
    'period_started_at', p_period_started_at,
    'period_ended_at', p_period_ended_at,
    'actual_closing_balance_minor', p_actual_closing_balance_minor,
    'evidence_attachment_id', p_evidence_attachment_id,
    'difference_explanation', p_difference_explanation
  );
  v_approval_payload jsonb;
  v_approval_fingerprint text;
  v_result jsonb;
  v_sqlstate text;
begin
  perform private.require_permission(p_organization_id, 'wallets.reconcile');
  perform private.assert_request_fingerprint(
    'wallets.reconcile.prepare', v_payload, p_request_fingerprint, 1::smallint
  );
  if p_period_ended_at <= p_period_started_at then
    raise exception using errcode = '22023', message = 'RECONCILIATION_PERIOD_INVALID';
  end if;

  select * into v_claim from private.claim_command(
    p_organization_id, 'wallets.reconcile.prepare', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    select w.* into strict v_wallet
    from public.wallets as w
    where w.organization_id = p_organization_id
      and w.id = p_wallet_id
      and w.is_active
    for update;

    if exists (
      select 1 from public.wallet_reconciliations as wr
      where wr.organization_id = p_organization_id
        and wr.wallet_id = p_wallet_id
        and wr.status <> 'cancelled'
        and tstzrange(wr.period_started_at, wr.period_ended_at, '[)')
          && tstzrange(p_period_started_at, p_period_ended_at, '[)')
    ) then
      raise exception using errcode = '23505', message = 'WALLET_RECONCILIATION_PERIOD_OVERLAP';
    end if;

    select coalesce(sum(jl.debit_minor - jl.credit_minor), 0)::bigint
    into v_opening
    from accounting.journal_lines as jl
    join accounting.journal_entries as je on je.id = jl.journal_entry_id
    where je.organization_id = p_organization_id
      and je.status = 'posted'
      and jl.wallet_id = p_wallet_id
      and je.posted_at < p_period_started_at;

    select coalesce(sum(jl.debit_minor - jl.credit_minor), 0)::bigint
    into v_movements
    from accounting.journal_lines as jl
    join accounting.journal_entries as je on je.id = jl.journal_entry_id
    where je.organization_id = p_organization_id
      and je.status = 'posted'
      and jl.wallet_id = p_wallet_id
      and je.posted_at >= p_period_started_at
      and je.posted_at < p_period_ended_at;

    v_expected := v_opening + v_movements;
    v_difference := p_actual_closing_balance_minor - v_expected;
    v_reconciliation_date :=
      ((p_period_ended_at - interval '1 microsecond') at time zone 'Africa/Cairo')::date;

    if v_difference <> 0 and nullif(btrim(p_difference_explanation), '') is null then
      raise exception using errcode = '22023', message = 'RECONCILIATION_DIFFERENCE_EXPLANATION_REQUIRED';
    end if;

    insert into public.wallet_reconciliations (
      id, organization_id, wallet_id, period_started_at, period_ended_at,
      reconciliation_date, opening_book_balance_minor, system_movements_minor,
      expected_closing_balance_minor, actual_closing_balance_minor,
      difference_minor, status, difference_explanation, prepared_by,
      evidence_attachment_id, correlation_id
    ) values (
      v_reconciliation_id, p_organization_id, p_wallet_id,
      p_period_started_at, p_period_ended_at, v_reconciliation_date,
      v_opening, v_movements, v_expected, p_actual_closing_balance_minor,
      v_difference, 'prepared', nullif(btrim(p_difference_explanation), ''),
      auth.uid(), p_evidence_attachment_id, p_correlation_id
    );

    insert into public.wallet_reconciliation_items (
      organization_id, wallet_reconciliation_id, wallet_id, sequence_number,
      movement_type, source_type, source_id, movement_amount_minor,
      book_balance_after_minor, occurred_at, description
    )
    select
      p_organization_id, v_reconciliation_id, p_wallet_id,
      row_number() over (order by q.posted_at, q.journal_entry_id)::integer,
      case
        when q.source_type = 'customer_payment' then 'receipt'
        when q.source_type in ('customer_refund', 'supplier_payment', 'expense_payment',
          'payroll_payment', 'partner_withdrawal') then 'payment'
        when q.source_type = 'wallet_transfer' and q.movement_minor > 0 then 'transfer_in'
        when q.source_type = 'wallet_transfer' then 'transfer_out'
        when q.source_type in ('manual_journal', 'journal_reversal', 'wallet_reconciliation') then 'adjustment'
        when q.movement_minor > 0 then 'receipt'
        else 'payment'
      end,
      q.source_type, q.source_id, q.movement_minor,
      v_opening + sum(q.movement_minor) over (order by q.posted_at, q.journal_entry_id),
      q.posted_at, q.description
    from (
      select je.id as journal_entry_id, je.source_type, je.source_id,
        je.posted_at, je.description,
        sum(jl.debit_minor - jl.credit_minor)::bigint as movement_minor
      from accounting.journal_entries as je
      join accounting.journal_lines as jl on jl.journal_entry_id = je.id
      where je.organization_id = p_organization_id
        and je.status = 'posted'
        and jl.wallet_id = p_wallet_id
        and je.posted_at >= p_period_started_at
        and je.posted_at < p_period_ended_at
      group by je.id, je.source_type, je.source_id, je.posted_at, je.description
      having sum(jl.debit_minor - jl.credit_minor) <> 0
    ) as q;

    v_approval_payload := jsonb_build_object(
      'organization_id', p_organization_id,
      'wallet_reconciliation_id', v_reconciliation_id,
      'wallet_id', p_wallet_id,
      'period_started_at', p_period_started_at,
      'period_ended_at', p_period_ended_at,
      'opening_book_balance_minor', v_opening,
      'system_movements_minor', v_movements,
      'expected_closing_balance_minor', v_expected,
      'actual_closing_balance_minor', p_actual_closing_balance_minor,
      'difference_minor', v_difference,
      'evidence_attachment_id', p_evidence_attachment_id,
      'difference_explanation', nullif(btrim(p_difference_explanation), '')
    );
    v_approval_fingerprint := encode(
      extensions.digest(convert_to(v_approval_payload::text, 'UTF8'), 'sha256'), 'hex'
    );
    v_approval_id := private.command_submit_approval_request(
      p_organization_id, 'wallet.reconciliation.finalize', 'wallet_reconciliation',
      v_reconciliation_id, 'wallets.reconcile',
      'Review frozen wallet reconciliation and difference',
      v_approval_payload, v_approval_fingerprint, abs(v_difference), null,
      statement_timestamp() + interval '14 days'
    );
    update public.wallet_reconciliations
    set approval_request_id = v_approval_id
    where id = v_reconciliation_id;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_reconciliation_id, 'prepared',
      'wallet.reconciliation_prepared', '[]'::jsonb,
      jsonb_build_object(
        'approval_request_id', v_approval_id,
        'opening_book_balance_minor', v_opening,
        'system_movements_minor', v_movements,
        'expected_closing_balance_minor', v_expected,
        'actual_closing_balance_minor', p_actual_closing_balance_minor,
        'difference_minor', v_difference
      )
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'wallets.reconcile.prepare', 'wallet_reconciliation',
      v_reconciliation_id, 'succeeded', null, p_correlation_id,
      v_claim.command_execution_id, p_idempotency_key, v_approval_payload
    );
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'wallets.reconcile.prepare',
        'wallet', p_wallet_id, p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'WALLET_RECONCILIATION_PREPARE_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'WALLET_RECONCILIATION_PREPARE_REJECTED',
      v_claim.command_execution_id
    );
  end;
end;
$$;

create or replace function private.command_finalize_wallet_reconciliation(
  p_organization_id uuid,
  p_wallet_reconciliation_id uuid,
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
  v_reconciliation public.wallet_reconciliations;
  v_wallet public.wallets;
  v_approval public.approval_requests;
  v_approval_payload jsonb;
  v_approval_fingerprint text;
  v_lines jsonb;
  v_journal_id uuid;
  v_result jsonb;
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'wallet_reconciliation_id', p_wallet_reconciliation_id
  );
begin
  perform private.require_permission(p_organization_id, 'wallets.reconcile');
  perform private.assert_request_fingerprint(
    'wallets.reconcile.finalize', v_payload, p_request_fingerprint, 1::smallint
  );
  select * into v_claim from private.claim_command(
    p_organization_id, 'wallets.reconcile.finalize', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    select wr.* into strict v_reconciliation
    from public.wallet_reconciliations as wr
    where wr.organization_id = p_organization_id
      and wr.id = p_wallet_reconciliation_id
    for update;
    select w.* into strict v_wallet
    from public.wallets as w
    where w.organization_id = p_organization_id
      and w.id = v_reconciliation.wallet_id
      and w.is_active
    for update;

    if v_reconciliation.status <> 'prepared'
       or v_reconciliation.prepared_by = auth.uid() then
      raise exception using errcode = '42501', message = 'WALLET_RECONCILIATION_FINALIZE_SOD_OR_STATE_INVALID';
    end if;

    v_approval_payload := jsonb_build_object(
      'organization_id', v_reconciliation.organization_id,
      'wallet_reconciliation_id', v_reconciliation.id,
      'wallet_id', v_reconciliation.wallet_id,
      'period_started_at', v_reconciliation.period_started_at,
      'period_ended_at', v_reconciliation.period_ended_at,
      'opening_book_balance_minor', v_reconciliation.opening_book_balance_minor,
      'system_movements_minor', v_reconciliation.system_movements_minor,
      'expected_closing_balance_minor', v_reconciliation.expected_closing_balance_minor,
      'actual_closing_balance_minor', v_reconciliation.actual_closing_balance_minor,
      'difference_minor', v_reconciliation.difference_minor,
      'evidence_attachment_id', v_reconciliation.evidence_attachment_id,
      'difference_explanation', v_reconciliation.difference_explanation
    );
    v_approval_fingerprint := encode(
      extensions.digest(convert_to(v_approval_payload::text, 'UTF8'), 'sha256'), 'hex'
    );
    select ar.* into strict v_approval
    from public.approval_requests as ar
    where ar.organization_id = p_organization_id
      and ar.id = v_reconciliation.approval_request_id
    for update;
    if v_approval.payload_snapshot <> v_approval_payload
       or v_approval.subject_fingerprint <> v_approval_fingerprint then
      raise exception using errcode = '55000', message = 'WALLET_RECONCILIATION_APPROVAL_SCOPE_CHANGED';
    end if;

    perform private.consume_approval(
      p_organization_id, v_approval.id, 'wallet.reconciliation.finalize',
      'wallet_reconciliation', v_reconciliation.id, v_approval_fingerprint,
      v_claim.command_execution_id, abs(v_reconciliation.difference_minor)
    );

    if v_reconciliation.difference_minor <> 0 then
      if v_reconciliation.difference_minor > 0 then
        v_lines := jsonb_build_array(
          jsonb_build_object(
            'account_role', 'wallet_' || lower(regexp_replace(v_wallet.code, '[^a-zA-Z0-9]+', '_', 'g')),
            'debit_minor', v_reconciliation.difference_minor::text, 'credit_minor', '0',
            'wallet_id', v_wallet.id, 'subledger_type', 'wallet_reconciliation',
            'subledger_id', v_reconciliation.id
          ),
          jsonb_build_object(
            'account_role', 'wallet_reconciliation_variance',
            'debit_minor', '0', 'credit_minor', v_reconciliation.difference_minor::text,
            'subledger_type', 'wallet_reconciliation', 'subledger_id', v_reconciliation.id
          )
        );
      else
        v_lines := jsonb_build_array(
          jsonb_build_object(
            'account_role', 'wallet_reconciliation_variance',
            'debit_minor', (-v_reconciliation.difference_minor)::text, 'credit_minor', '0',
            'subledger_type', 'wallet_reconciliation', 'subledger_id', v_reconciliation.id
          ),
          jsonb_build_object(
            'account_role', 'wallet_' || lower(regexp_replace(v_wallet.code, '[^a-zA-Z0-9]+', '_', 'g')),
            'debit_minor', '0', 'credit_minor', (-v_reconciliation.difference_minor)::text,
            'wallet_id', v_wallet.id, 'subledger_type', 'wallet_reconciliation',
            'subledger_id', v_reconciliation.id
          )
        );
      end if;
      v_journal_id := private.post_journal_entry(
        p_organization_id => p_organization_id,
        p_source_type => 'wallet_reconciliation',
        p_source_id => v_reconciliation.id,
        p_posting_purpose => 'adjustment',
        p_description => 'Approved wallet reconciliation difference',
        p_lines => v_lines,
        p_idempotency_key => p_idempotency_key,
        p_request_hash => p_request_fingerprint,
        p_correlation_id => p_correlation_id,
        p_accounting_date => v_reconciliation.reconciliation_date,
        p_approval_request_id => v_approval.id,
        p_command_type => 'wallets.reconcile.finalize',
        p_command_execution_id => v_claim.command_execution_id,
        p_require_manual_permission => false
      );
    end if;

    update public.wallet_reconciliations
    set status = 'finalized', reviewed_by = auth.uid(),
      reviewed_at = statement_timestamp(), finalized_at = statement_timestamp(),
      adjustment_reference_type = case when v_journal_id is null then null else 'journal_entry' end,
      adjustment_reference_id = v_journal_id, correlation_id = p_correlation_id
    where id = v_reconciliation.id;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_reconciliation.id, 'finalized',
      'wallet.reconciliation_finalized',
      case when v_journal_id is null then '[]'::jsonb else jsonb_build_array(v_journal_id) end,
      jsonb_build_object('difference_minor', v_reconciliation.difference_minor)
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'wallets.reconcile.finalize', 'wallet_reconciliation',
      v_reconciliation.id, 'succeeded', null, p_correlation_id,
      v_claim.command_execution_id, p_idempotency_key,
      jsonb_build_object('difference_minor', v_reconciliation.difference_minor,
        'journal_entry_id', v_journal_id)
    );
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'wallets.reconcile.finalize',
        'wallet_reconciliation', p_wallet_reconciliation_id,
        p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'WALLET_RECONCILIATION_FINALIZE_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'WALLET_RECONCILIATION_FINALIZE_REJECTED',
      v_claim.command_execution_id
    );
  end;
end;
$$;

create or replace function api.prepare_wallet_reconciliation(
  p_organization_id uuid, p_wallet_id uuid,
  p_period_started_at timestamptz, p_period_ended_at timestamptz,
  p_actual_closing_balance_minor bigint, p_evidence_attachment_id uuid,
  p_difference_explanation text, p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$
  select private.command_prepare_wallet_reconciliation(
    p_organization_id, p_wallet_id, p_period_started_at, p_period_ended_at,
    p_actual_closing_balance_minor, p_evidence_attachment_id,
    p_difference_explanation, p_idempotency_key, p_request_fingerprint,
    p_correlation_id
  )
$$;

create or replace function api.finalize_wallet_reconciliation(
  p_organization_id uuid, p_wallet_reconciliation_id uuid,
  p_idempotency_key text, p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$
  select private.command_finalize_wallet_reconciliation(
    p_organization_id, p_wallet_reconciliation_id, p_idempotency_key,
    p_request_fingerprint, p_correlation_id
  )
$$;

revoke all on function private.command_prepare_wallet_reconciliation(
  uuid, uuid, timestamptz, timestamptz, bigint, uuid, text, text, text, uuid
) from public, anon;
grant execute on function private.command_prepare_wallet_reconciliation(
  uuid, uuid, timestamptz, timestamptz, bigint, uuid, text, text, text, uuid
) to authenticated;
revoke all on function private.command_finalize_wallet_reconciliation(
  uuid, uuid, text, text, uuid
) from public, anon;
grant execute on function private.command_finalize_wallet_reconciliation(
  uuid, uuid, text, text, uuid
) to authenticated;
revoke all on function api.prepare_wallet_reconciliation(
  uuid, uuid, timestamptz, timestamptz, bigint, uuid, text, text, text, uuid
) from public, anon;
grant execute on function api.prepare_wallet_reconciliation(
  uuid, uuid, timestamptz, timestamptz, bigint, uuid, text, text, text, uuid
) to authenticated;
revoke all on function api.finalize_wallet_reconciliation(uuid, uuid, text, text, uuid)
  from public, anon;
grant execute on function api.finalize_wallet_reconciliation(uuid, uuid, text, text, uuid)
  to authenticated;
