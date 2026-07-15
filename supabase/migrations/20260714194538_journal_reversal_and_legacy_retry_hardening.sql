create or replace function private.command_request_journal_reversal(
  p_organization_id uuid,
  p_original_entry_id uuid,
  p_reason text,
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
  v_entry accounting.journal_entries;
  v_permission_id uuid;
  v_approval_id uuid := extensions.gen_random_uuid();
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'original_entry_id', p_original_entry_id,
    'reason', p_reason
  );
  v_result jsonb;
  v_sqlstate text;
begin
  perform private.require_permission(p_organization_id, 'ledger.reverse');
  perform private.assert_request_fingerprint(
    'ledger.reverse', v_payload, p_request_fingerprint, 1::smallint
  );
  if nullif(btrim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'REVERSAL_REASON_REQUIRED';
  end if;

  select * into v_claim from private.claim_command(
    p_organization_id, 'ledger.reverse.request', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    select je.* into strict v_entry
    from accounting.journal_entries as je
    where je.organization_id = p_organization_id
      and je.id = p_original_entry_id
    for update;
    if v_entry.status <> 'posted' or v_entry.reversal_of is not null then
      raise exception using errcode = '55000', message = 'JOURNAL_NOT_REVERSIBLE';
    end if;
    if exists (
      select 1 from accounting.journal_entries as reversal
      where reversal.organization_id = p_organization_id
        and reversal.reversal_of = v_entry.id
    ) then
      raise exception using errcode = '23505', message = 'JOURNAL_ALREADY_REVERSED';
    end if;
    select id into strict v_permission_id
    from private.permissions
    where permission_key = 'ledger.reverse' and is_active;

    insert into public.approval_requests(
      id, organization_id, request_type, entity_type, entity_id,
      requested_by, submitted_at, status, required_permission_id,
      requires_separation_of_duties, required_approval_count, reason,
      subject_fingerprint, payload_snapshot, expires_at
    ) values (
      v_approval_id, p_organization_id, 'journal.reverse', 'journal_entry',
      v_entry.id, auth.uid(), statement_timestamp(), 'submitted',
      v_permission_id, true, 1, p_reason, p_request_fingerprint,
      v_payload, statement_timestamp() + interval '14 days'
    );

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_entry.id, 'submitted',
      'journal.reversal_requested', '[]'::jsonb,
      jsonb_build_object(
        'approval_request_id', v_approval_id,
        'approval_request_fingerprint', p_request_fingerprint
      )
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'ledger.reverse.request', 'journal_entry', v_entry.id,
      'succeeded', p_reason, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key, jsonb_build_object('approval_request_id', v_approval_id)
    );
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'ledger.reverse.request',
        'journal_entry', p_original_entry_id, p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'REVERSAL_REQUEST_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'REVERSAL_REQUEST_REJECTED',
      v_claim.command_execution_id
    );
  end;
end;
$$;

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
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'original_entry_id', p_original_entry_id,
    'reason', p_reason
  );
begin
  perform private.require_permission(p_organization_id, 'ledger.reverse');
  perform private.assert_request_fingerprint(
    'ledger.reverse', v_payload, p_request_fingerprint, 1::smallint
  );
  if nullif(btrim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'REVERSAL_REASON_REQUIRED';
  end if;
  select * into v_claim from private.claim_command(
    p_organization_id, 'ledger.reverse', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
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
    v_result := private.command_success_response(
      v_claim.command_execution_id, p_original_entry_id, 'reversed',
      'journal.reversed', jsonb_build_array(v_reversal_id)
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, 'ledger.reverse', 'journal_entry', p_original_entry_id,
      'succeeded', p_reason, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key, jsonb_build_object('reversal_entry_id', v_reversal_id)
    );
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, 'ledger.reverse',
        'journal_entry', p_original_entry_id, p_idempotency_key, p_correlation_id
      );
    end if;
    v_error_code := case when v_sqlstate = '42501' then 'PERMISSION_DENIED' else 'REVERSAL_REJECTED' end;
    perform private.complete_command_failure(v_claim.command_execution_id, v_error_code, null);
    perform private.record_financial_command_audit(
      p_organization_id, 'ledger.reverse', 'journal_entry', p_original_entry_id,
      'failed', v_error_code, p_correlation_id, v_claim.command_execution_id,
      p_idempotency_key
    );
    return private.command_replay_response(
      'failed_terminal', null, v_error_code, v_claim.command_execution_id
    );
  end;
end;
$$;

create or replace function api.request_journal_reversal(
  p_organization_id uuid, p_original_entry_id uuid, p_reason text,
  p_idempotency_key text, p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$
  select private.command_request_journal_reversal(
    p_organization_id, p_original_entry_id, p_reason, p_idempotency_key,
    p_request_fingerprint, p_correlation_id
  )
$$;

revoke all on function private.command_request_journal_reversal(
  uuid, uuid, text, text, text, uuid
) from public, anon;
grant execute on function private.command_request_journal_reversal(
  uuid, uuid, text, text, text, uuid
) to authenticated;
revoke all on function private.command_reverse_journal_entry(
  uuid, uuid, text, text, text, uuid, uuid
) from public, anon;
grant execute on function private.command_reverse_journal_entry(
  uuid, uuid, text, text, text, uuid, uuid
) to authenticated;
revoke all on function api.request_journal_reversal(
  uuid, uuid, text, text, text, uuid
) from public, anon;
grant execute on function api.request_journal_reversal(
  uuid, uuid, text, text, text, uuid
) to authenticated;

do $migration$
declare
  v_row record;
  v_definition text;
  v_repaired text;
begin
  for v_row in
    select * from (values
      ('private.command_start_monthly_close(uuid,date,text,text,uuid,uuid)'::regprocedure,
       'accounting.start_close', 'accounting_period', 'null'),
      ('private.command_validate_monthly_close(uuid,uuid,text,text,uuid)'::regprocedure,
       'accounting.validate_close', 'monthly_closing', 'p_monthly_closing_id'),
      ('private.command_close_accounting_period(uuid,uuid,uuid,jsonb,jsonb,text,text,uuid)'::regprocedure,
       'accounting.close_period', 'monthly_closing', 'p_monthly_closing_id'),
      ('private.command_attest_monthly_close_item(uuid,uuid,text,text,bigint,bigint,jsonb,text,uuid,text,text,uuid)'::regprocedure,
       'accounting.attest_close_item', 'monthly_closing', 'p_monthly_closing_id')
    ) as x(signature, command_type, subject_type, subject_expression)
  loop
    v_definition := pg_get_functiondef(v_row.signature);
    v_repaired := replace(v_definition, E'declare\n', E'declare\n  v_retry_sqlstate text;\n');
    v_repaired := replace(
      v_repaired,
      E'exception when others then\n',
      E'exception when others then\n  v_retry_sqlstate := sqlstate;\n  if private.is_retryable_sqlstate(v_retry_sqlstate) then\n    return private.release_retryable_command(\n      v_claim.command_execution_id, v_retry_sqlstate, '
      || quote_literal(v_row.command_type) || E', ' || quote_literal(v_row.subject_type)
      || E', ' || v_row.subject_expression
      || E', p_idempotency_key, p_correlation_id\n    );\n  end if;\n'
    );
    if v_repaired = v_definition
       or position('release_retryable_command' in v_repaired) = 0 then
      raise exception 'RETRY_HARDENING_TARGET_NOT_FOUND: %', v_row.signature;
    end if;
    execute v_repaired;
  end loop;
end;
$migration$;

do $migration$
declare
  v_definition text;
  v_repaired text;
begin
  v_definition := pg_get_functiondef(
    'private.command_change_monthly_close_state(uuid,uuid,text,text,uuid,text,text,uuid)'::regprocedure
  );
  v_repaired := replace(v_definition, E'declare\n', E'declare\n  v_retry_sqlstate text;\n');
  v_repaired := replace(
    v_repaired,
    E'exception when others then\n',
    E'exception when others then\n  v_retry_sqlstate := sqlstate;\n  if private.is_retryable_sqlstate(v_retry_sqlstate) then\n    return private.release_retryable_command(\n      v_claim.command_execution_id, v_retry_sqlstate,\n      ''accounting.'' || p_action || ''_close'', ''monthly_closing'',\n      p_monthly_closing_id, p_idempotency_key, p_correlation_id\n    );\n  end if;\n'
  );
  if v_repaired = v_definition
     or position('release_retryable_command' in v_repaired) = 0 then
    raise exception 'RETRY_HARDENING_TARGET_NOT_FOUND: command_change_monthly_close_state';
  end if;
  execute v_repaired;
end;
$migration$;
