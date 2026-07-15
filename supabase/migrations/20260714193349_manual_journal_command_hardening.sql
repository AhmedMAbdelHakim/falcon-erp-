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
  v_error_message text;
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

    v_result := private.command_success_response(
      v_claim.command_execution_id,
      p_source_id,
      'posted',
      'command.succeeded',
      jsonb_build_array(v_journal_entry_id)
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
    get stacked diagnostics v_error_message = message_text;

    if private.is_retryable_sqlstate(sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, sqlstate, p_command_type, p_source_type,
        p_source_id, p_idempotency_key, p_correlation_id
      );
    end if;

    v_error_code := case
      when sqlstate = '23505' then 'DUPLICATE_POSTING'
      when sqlstate = '23514' then 'ACCOUNTING_INVARIANT_FAILED'
      when sqlstate = '42501' then 'PERMISSION_DENIED'
      when sqlstate = 'P0001' and v_error_message = 'ACCOUNTING_PERIOD_NOT_OPEN'
        then 'POSTING_PERIOD_CLOSED'
      when sqlstate = 'P0001' and v_error_message = 'ACCOUNTING_PERIOD_NOT_FOUND'
        then 'POSTING_PERIOD_NOT_FOUND'
      when sqlstate = '22023' and v_error_message = 'MANUAL_JOURNAL_SOURCE_SCOPE_INVALID'
        then 'MANUAL_JOURNAL_SOURCE_SCOPE_INVALID'
      when sqlstate = '22023' and v_error_message in (
        'MANUAL_POSTING_TO_CONTROL_ACCOUNT_DENIED', 'INVALID_JOURNAL_ACCOUNT'
      ) then 'MANUAL_POSTING_ACCOUNT_DENIED'
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
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform private.assert_request_fingerprint(
    'ledger.post',
    jsonb_build_object(
      'organization_id', p_organization_id,
      'source_type', p_source_type,
      'source_id', p_source_id,
      'posting_purpose', p_posting_purpose,
      'description', p_description,
      'lines', p_lines,
      'accounting_date', p_accounting_date,
      'approval_request_id', p_approval_request_id,
      'corrects_entry_id', p_corrects_entry_id,
      'affected_closed_period_id', p_affected_closed_period_id
    ),
    p_request_fingerprint,
    1::smallint
  );

  return private.execute_mapped_financial_command(
    p_organization_id, 'ledger.post', 'ledger.post', p_source_type, p_source_id,
    p_posting_purpose, p_description, p_lines, p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id, p_accounting_date,
    p_approval_request_id, p_corrects_entry_id, p_affected_closed_period_id
  );
end;
$$;

revoke all on function private.command_post_journal_entry(
  uuid, text, uuid, text, text, jsonb, text, text, uuid, date, uuid, uuid, uuid
) from public, anon;
grant execute on function private.command_post_journal_entry(
  uuid, text, uuid, text, text, jsonb, text, text, uuid, date, uuid, uuid, uuid
) to authenticated;

comment on function private.command_post_journal_entry(
  uuid, text, uuid, text, text, jsonb, text, text, uuid, date, uuid, uuid, uuid
) is 'Canonical-fingerprint guarded manual journal command. Only manual_journal/manual_adjustment postings are accepted by the posting primitive.';
