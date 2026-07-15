-- Shared command safety primitives for all additive Phase-2 transactional RPCs.

create or replace function private.canonical_request_fingerprint(
  p_command_type text,
  p_payload jsonb,
  p_fingerprint_version smallint default 1
)
returns text
language sql
immutable
strict
security invoker
set search_path = ''
as $$
  select encode(
    extensions.digest(
      convert_to(
        p_fingerprint_version::text || ':' || p_command_type || ':' || p_payload::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  )
$$;

comment on function private.canonical_request_fingerprint(text, jsonb, smallint) is
  'Versioned SHA-256 over PostgreSQL canonical jsonb text and a fixed command type.';
revoke all on function private.canonical_request_fingerprint(text, jsonb, smallint)
  from public, anon, authenticated;

create or replace function private.assert_request_fingerprint(
  p_command_type text,
  p_payload jsonb,
  p_supplied_fingerprint text,
  p_fingerprint_version smallint default 1
)
returns void
language plpgsql
immutable
strict
security invoker
set search_path = ''
as $$
declare
  v_expected text;
begin
  if p_fingerprint_version <> 1 then
    raise exception using errcode = '22023', message = 'UNSUPPORTED_FINGERPRINT_VERSION';
  end if;
  v_expected := private.canonical_request_fingerprint(
    p_command_type, p_payload, p_fingerprint_version
  );
  if p_supplied_fingerprint !~ '^[0-9a-f]{64}$'
     or p_supplied_fingerprint <> v_expected then
    raise exception using errcode = '22023', message = 'REQUEST_FINGERPRINT_MISMATCH';
  end if;
end;
$$;

revoke all on function private.assert_request_fingerprint(text, jsonb, text, smallint)
  from public, anon, authenticated;

create or replace function private.is_retryable_sqlstate(p_sqlstate text)
returns boolean
language sql
immutable
strict
security invoker
set search_path = ''
as $$
  select p_sqlstate in ('40001', '40P01', '55P03', '57014', '57P01', '08000', '08003', '08006')
$$;

revoke all on function private.is_retryable_sqlstate(text) from public, anon, authenticated;

create or replace function private.release_retryable_command(
  p_command_execution_id uuid,
  p_sqlstate text,
  p_command_type text,
  p_subject_type text,
  p_subject_id uuid,
  p_idempotency_key text,
  p_correlation_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_organization_id uuid;
begin
  if not private.is_retryable_sqlstate(p_sqlstate) then
    raise exception using errcode = '22023', message = 'SQLSTATE_IS_NOT_RETRYABLE';
  end if;

  delete from private.command_executions as ce
  where ce.id = p_command_execution_id
    and ce.actor_user_id = auth.uid()
    and ce.status = 'in_progress'
  returning ce.organization_id into v_organization_id;

  if v_organization_id is null then
    raise exception using errcode = '55000', message = 'COMMAND_CLAIM_NOT_RELEASABLE';
  end if;

  insert into audit.events (
    organization_id, event_category, action, subject_type, subject_id,
    actor_user_id, result, reason, correlation_id, idempotency_reference,
    event_metadata
  ) values (
    v_organization_id, 'financial_command', p_command_type, p_subject_type,
    p_subject_id, auth.uid(), 'failed', 'RETRYABLE_COMMAND_FAILURE',
    p_correlation_id, p_idempotency_key,
    jsonb_build_object('sqlstate', p_sqlstate, 'retryable', true)
  );

  return jsonb_build_object(
    'success', false,
    'command_id', p_command_execution_id,
    'entity_id', p_subject_id,
    'journal_entry_ids', '[]'::jsonb,
    'warnings', jsonb_build_array('RETRY_COMMAND'),
    'error_code', 'RETRYABLE_COMMAND_FAILURE',
    'message_key', 'command.retryable_failure',
    'current_state', 'retryable'
  );
end;
$$;

revoke all on function private.release_retryable_command(uuid, text, text, text, uuid, text, uuid)
  from public, anon, authenticated;

create or replace function private.command_success_response(
  p_command_execution_id uuid,
  p_entity_id uuid,
  p_current_state text,
  p_message_key text,
  p_journal_entry_ids jsonb default '[]'::jsonb,
  p_extra jsonb default '{}'::jsonb
)
returns jsonb
language sql
immutable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'success', true,
    'command_id', p_command_execution_id,
    'entity_id', p_entity_id,
    'journal_entry_ids', coalesce(p_journal_entry_ids, '[]'::jsonb),
    'warnings', '[]'::jsonb,
    'error_code', null,
    'message_key', p_message_key,
    'current_state', p_current_state
  ) || coalesce(p_extra, '{}'::jsonb)
$$;

revoke all on function private.command_success_response(uuid, uuid, text, text, jsonb, jsonb)
  from public, anon, authenticated;

create or replace function api.compute_request_fingerprint(
  p_command_type text,
  p_payload jsonb,
  p_fingerprint_version smallint default 1
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select private.canonical_request_fingerprint(
    p_command_type, p_payload, p_fingerprint_version
  )
$$;

revoke all on function api.compute_request_fingerprint(text, jsonb, smallint)
  from public, anon, authenticated;
grant execute on function api.compute_request_fingerprint(text, jsonb, smallint)
  to authenticated;

