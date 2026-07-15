create table private.command_executions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  command_type text not null,
  idempotency_key text not null,
  request_fingerprint text not null,
  fingerprint_version smallint not null default 1,
  actor_user_id uuid not null,
  status public.command_status not null default 'in_progress',
  correlation_id uuid not null,
  result_reference jsonb,
  error_code text,
  error_message text,
  started_at timestamptz not null default statement_timestamp(),
  completed_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint command_executions_actor_org_fk
    foreign key (organization_id, actor_user_id)
    references public.profiles (organization_id, id) on delete restrict,
  constraint command_executions_command_type_format_chk
    check (command_type ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  constraint command_executions_idempotency_key_chk
    check (char_length(idempotency_key) between 8 and 200 and btrim(idempotency_key) = idempotency_key),
  constraint command_executions_fingerprint_chk
    check (request_fingerprint ~ '^[0-9a-f]{64}$'),
  constraint command_executions_fingerprint_version_chk check (fingerprint_version > 0),
  constraint command_executions_result_reference_chk
    check (result_reference is null or jsonb_typeof(result_reference) = 'object'),
  constraint command_executions_error_code_chk
    check (error_code is null or error_code ~ '^[A-Z][A-Z0-9_]{1,63}$'),
  constraint command_executions_error_message_chk
    check (error_message is null or (btrim(error_message) <> '' and char_length(error_message) <= 500)),
  constraint command_executions_terminal_state_chk check (
    (status = 'in_progress' and completed_at is null and result_reference is null and error_code is null and error_message is null)
    or (status = 'succeeded' and completed_at is not null and error_code is null and error_message is null)
    or (status = 'failed_terminal' and completed_at is not null and error_code is not null and result_reference is null)
  ),
  constraint command_executions_org_id_id_uk unique (organization_id, id),
  constraint command_executions_idempotency_scope_uk
    unique (organization_id, command_type, idempotency_key)
);

comment on table private.command_executions is
  'Transactional idempotency claims. The unique scope serializes concurrent claimants; only canonical SHA-256 fingerprints and sanitized outcomes are stored.';
comment on column private.command_executions.result_reference is
  'Small non-sensitive object containing stable identifiers needed to replay a successful result; never a copy of the request payload.';

create index command_executions_actor_idx
  on private.command_executions (organization_id, actor_user_id, created_at desc);
create index command_executions_correlation_idx
  on private.command_executions (correlation_id);
create index command_executions_in_progress_idx
  on private.command_executions (organization_id, started_at)
  where status = 'in_progress';

create trigger command_executions_set_updated_at
before update on private.command_executions
for each row execute function private.set_updated_at();

create or replace function private.protect_command_execution()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.organization_id <> new.organization_id
    or old.command_type <> new.command_type
    or old.idempotency_key <> new.idempotency_key
    or old.request_fingerprint <> new.request_fingerprint
    or old.fingerprint_version <> new.fingerprint_version
    or old.actor_user_id <> new.actor_user_id
    or old.correlation_id <> new.correlation_id
    or old.started_at <> new.started_at
    or old.created_at <> new.created_at then
    raise exception using errcode = '55000', message = 'Command claim identity is immutable';
  end if;

  if old.status <> 'in_progress' then
    raise exception using errcode = '55000', message = 'Terminal command outcome is immutable';
  end if;

  if new.status not in ('succeeded', 'failed_terminal') then
    raise exception using errcode = '55000', message = 'Invalid command outcome transition';
  end if;

  return new;
end;
$$;

revoke all on function private.protect_command_execution() from public, anon, authenticated;

create trigger command_executions_protect_transition
before update on private.command_executions
for each row execute function private.protect_command_execution();

create or replace function private.claim_command(
  p_organization_id uuid,
  p_command_type text,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_fingerprint_version smallint,
  p_correlation_id uuid
)
returns table (
  command_execution_id uuid,
  command_status public.command_status,
  is_replay boolean,
  result_reference jsonb,
  error_code text,
  execution_correlation_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_user_id uuid := (select auth.uid());
  v_execution private.command_executions%rowtype;
  v_inserted boolean := false;
begin
  if v_actor_user_id is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if private.current_organization_id() is distinct from p_organization_id then
    raise exception using errcode = '42501', message = 'Organization access denied';
  end if;

  insert into private.command_executions (
    organization_id,
    command_type,
    idempotency_key,
    request_fingerprint,
    fingerprint_version,
    actor_user_id,
    correlation_id
  ) values (
    p_organization_id,
    p_command_type,
    p_idempotency_key,
    p_request_fingerprint,
    p_fingerprint_version,
    v_actor_user_id,
    p_correlation_id
  )
  on conflict (organization_id, command_type, idempotency_key) do nothing
  returning * into v_execution;

  v_inserted := found;

  if not v_inserted then
    select ce.*
      into strict v_execution
    from private.command_executions as ce
    where ce.organization_id = p_organization_id
      and ce.command_type = p_command_type
      and ce.idempotency_key = p_idempotency_key
    for update;

    if v_execution.request_fingerprint <> p_request_fingerprint
      or v_execution.fingerprint_version <> p_fingerprint_version then
      raise exception using
        errcode = '22023',
        message = 'Idempotency key was already used with a different request';
    end if;

    if v_execution.actor_user_id <> v_actor_user_id then
      raise exception using
        errcode = '42501',
        message = 'Idempotency key belongs to a different actor';
    end if;
  end if;

  return query
  select
    v_execution.id,
    v_execution.status,
    not v_inserted,
    v_execution.result_reference,
    v_execution.error_code,
    v_execution.correlation_id;
end;
$$;

comment on function private.claim_command(uuid, text, text, text, smallint, uuid) is
  'Claims a scoped idempotency key. A conflicting insert waits for the winner, then replays only an identical actor and fingerprint.';
revoke all on function private.claim_command(uuid, text, text, text, smallint, uuid)
  from public, anon, authenticated;

create or replace function private.complete_command_success(
  p_command_execution_id uuid,
  p_result_reference jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_result_reference is not null and jsonb_typeof(p_result_reference) <> 'object' then
    raise exception using errcode = '22023', message = 'Result reference must be a JSON object';
  end if;

  update private.command_executions as ce
  set status = 'succeeded',
      result_reference = p_result_reference,
      completed_at = statement_timestamp()
  where ce.id = p_command_execution_id
    and ce.actor_user_id = (select auth.uid())
    and ce.status = 'in_progress';

  if not found then
    raise exception using errcode = '55000', message = 'Command claim cannot be completed';
  end if;
end;
$$;

revoke all on function private.complete_command_success(uuid, jsonb)
  from public, anon, authenticated;

create or replace function private.complete_command_failure(
  p_command_execution_id uuid,
  p_error_code text,
  p_error_message text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.command_executions as ce
  set status = 'failed_terminal',
      error_code = p_error_code,
      error_message = p_error_message,
      completed_at = statement_timestamp()
  where ce.id = p_command_execution_id
    and ce.actor_user_id = (select auth.uid())
    and ce.status = 'in_progress';

  if not found then
    raise exception using errcode = '55000', message = 'Command claim cannot be completed';
  end if;
end;
$$;

revoke all on function private.complete_command_failure(uuid, text, text)
  from public, anon, authenticated;

create table public.approval_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  request_type text not null,
  entity_type text not null,
  entity_id uuid not null,
  requested_by uuid not null,
  requester_partner_id uuid,
  requested_at timestamptz not null default statement_timestamp(),
  submitted_at timestamptz,
  status public.approval_status not null default 'draft',
  required_permission_id uuid not null references private.permissions(id) on delete restrict,
  requires_separation_of_duties boolean not null default true,
  required_approval_count smallint not null default 1,
  reason text not null,
  subject_fingerprint text not null,
  fingerprint_version smallint not null default 1,
  requested_amount_minor bigint,
  approved_min_amount_minor bigint,
  approved_max_amount_minor bigint,
  payload_snapshot jsonb not null default '{}'::jsonb,
  expires_at timestamptz,
  resolved_at timestamptz,
  resolved_by uuid,
  resolution_reason text,
  consumed_at timestamptz,
  consumed_by_command_execution_id uuid,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint approval_requests_requester_org_fk
    foreign key (organization_id, requested_by)
    references public.profiles (organization_id, id) on delete restrict,
  constraint approval_requests_resolver_org_fk
    foreign key (organization_id, resolved_by)
    references public.profiles (organization_id, id) on delete restrict,
  constraint approval_requests_consumed_command_org_fk
    foreign key (organization_id, consumed_by_command_execution_id)
    references private.command_executions (organization_id, id) on delete restrict,
  constraint approval_requests_request_type_format_chk
    check (request_type ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  constraint approval_requests_entity_type_format_chk
    check (entity_type ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint approval_requests_reason_not_blank_chk check (btrim(reason) <> ''),
  constraint approval_requests_required_approval_count_chk
    check (required_approval_count between 1 and 10),
  constraint approval_requests_resolution_reason_chk
    check (resolution_reason is null or btrim(resolution_reason) <> ''),
  constraint approval_requests_fingerprint_chk
    check (subject_fingerprint ~ '^[0-9a-f]{64}$' and fingerprint_version > 0),
  constraint approval_requests_payload_object_chk check (jsonb_typeof(payload_snapshot) = 'object'),
  constraint approval_requests_amount_range_chk check (
    approved_min_amount_minor is null
    or approved_max_amount_minor is null
    or approved_max_amount_minor >= approved_min_amount_minor
  ),
  constraint approval_requests_requested_amount_range_chk check (
    requested_amount_minor is null
    or (
      (approved_min_amount_minor is null or requested_amount_minor >= approved_min_amount_minor)
      and (approved_max_amount_minor is null or requested_amount_minor <= approved_max_amount_minor)
    )
  ),
  constraint approval_requests_expiry_chk check (expires_at is null or expires_at > requested_at),
  constraint approval_requests_status_timestamps_chk check (
    (status = 'draft' and submitted_at is null and resolved_at is null and resolved_by is null and consumed_at is null and consumed_by_command_execution_id is null)
    or (status = 'submitted' and submitted_at is not null and resolved_at is null and resolved_by is null and consumed_at is null and consumed_by_command_execution_id is null)
    or (status in ('approved', 'rejected') and submitted_at is not null and resolved_at is not null and resolved_by is not null and consumed_at is null and consumed_by_command_execution_id is null)
    or (status = 'cancelled' and resolved_at is not null and resolved_by is not null and consumed_at is null and consumed_by_command_execution_id is null)
    or (status = 'expired' and submitted_at is not null and resolved_at is not null and consumed_at is null and consumed_by_command_execution_id is null)
    or (status = 'consumed' and submitted_at is not null and resolved_at is not null and resolved_by is not null and consumed_at is not null and consumed_by_command_execution_id is not null)
  ),
  constraint approval_requests_resolution_reason_required_chk check (
    status in ('draft', 'submitted', 'approved', 'consumed') or resolution_reason is not null
  ),
  constraint approval_requests_org_id_id_uk unique (organization_id, id)
);

comment on table public.approval_requests is
  'One-time approval envelope bound to organization, subject, canonical fingerprint, requester, capability, amount scope, expiry, and immutable payload snapshot.';
comment on column public.approval_requests.requested_amount_minor is
  'Signed bigint EGP minor units when the approval is amount-bound.';
comment on column public.approval_requests.requester_partner_id is
  'Partner entity identity for separation of duties. A composite FK is added after the partners migration.';

create index approval_requests_requester_idx
  on public.approval_requests (organization_id, requested_by, requested_at desc);
create index approval_requests_required_permission_idx
  on public.approval_requests (required_permission_id);
create index approval_requests_resolved_by_idx
  on public.approval_requests (resolved_by);
create index approval_requests_consumed_command_idx
  on public.approval_requests (consumed_by_command_execution_id);
create index approval_requests_open_queue_idx
  on public.approval_requests (organization_id, request_type, requested_at)
  where status in ('draft', 'submitted', 'approved');
create index approval_requests_entity_idx
  on public.approval_requests (organization_id, entity_type, entity_id, requested_at desc);

create trigger approval_requests_set_updated_at
before update on public.approval_requests
for each row execute function private.set_updated_at();

create or replace function private.protect_approval_request()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.status <> 'draft' and (
    old.organization_id <> new.organization_id
    or old.request_type <> new.request_type
    or old.entity_type <> new.entity_type
    or old.entity_id <> new.entity_id
    or old.requested_by <> new.requested_by
    or old.requester_partner_id is distinct from new.requester_partner_id
    or old.requested_at <> new.requested_at
    or old.submitted_at is distinct from new.submitted_at
    or old.required_permission_id <> new.required_permission_id
    or old.requires_separation_of_duties <> new.requires_separation_of_duties
    or old.required_approval_count <> new.required_approval_count
    or old.reason <> new.reason
    or old.subject_fingerprint <> new.subject_fingerprint
    or old.fingerprint_version <> new.fingerprint_version
    or old.requested_amount_minor is distinct from new.requested_amount_minor
    or old.approved_min_amount_minor is distinct from new.approved_min_amount_minor
    or old.approved_max_amount_minor is distinct from new.approved_max_amount_minor
    or old.payload_snapshot <> new.payload_snapshot
    or old.expires_at is distinct from new.expires_at
    or old.created_at <> new.created_at
  ) then
    raise exception using errcode = '55000', message = 'Submitted approval scope is immutable';
  end if;

  if old.status = 'draft' and new.status not in ('draft', 'submitted', 'cancelled') then
    raise exception using errcode = '55000', message = 'Invalid approval transition';
  elsif old.status = 'submitted' and new.status not in ('submitted', 'approved', 'rejected', 'expired', 'cancelled') then
    raise exception using errcode = '55000', message = 'Invalid approval transition';
  elsif old.status = 'approved' and new.status not in ('approved', 'consumed') then
    raise exception using errcode = '55000', message = 'Invalid approval transition';
  elsif old.status in ('rejected', 'expired', 'cancelled', 'consumed') then
    raise exception using errcode = '55000', message = 'Terminal approval is immutable';
  end if;

  return new;
end;
$$;

revoke all on function private.protect_approval_request() from public, anon, authenticated;

create trigger approval_requests_protect_transition
before update on public.approval_requests
for each row execute function private.protect_approval_request();

create table public.approval_actions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  approval_request_id uuid not null,
  action_type public.approval_action_type not null,
  acted_by uuid not null,
  approver_partner_id uuid,
  comment text,
  previous_status public.approval_status not null,
  resulting_status public.approval_status not null,
  subject_fingerprint text not null,
  acted_at timestamptz not null default statement_timestamp(),
  correlation_id uuid not null,
  constraint approval_actions_request_org_fk
    foreign key (organization_id, approval_request_id)
    references public.approval_requests (organization_id, id) on delete restrict,
  constraint approval_actions_actor_org_fk
    foreign key (organization_id, acted_by)
    references public.profiles (organization_id, id) on delete restrict,
  constraint approval_actions_comment_not_blank_chk check (comment is null or btrim(comment) <> ''),
  constraint approval_actions_fingerprint_chk check (subject_fingerprint ~ '^[0-9a-f]{64}$'),
  constraint approval_actions_transition_chk check (
    (action_type = 'approve' and previous_status = 'submitted' and resulting_status in ('submitted', 'approved'))
    or (action_type = 'reject' and previous_status = 'submitted' and resulting_status = 'rejected')
    or (action_type = 'cancel' and previous_status in ('draft', 'submitted') and resulting_status = 'cancelled')
  ),
  constraint approval_actions_actor_decision_uk unique (approval_request_id, acted_by)
);

comment on table public.approval_actions is
  'Append-only approval decisions. The actor, status transition, subject fingerprint, correlation, and optional partner identity are retained.';
comment on column public.approval_actions.approver_partner_id is
  'Partner entity identity used to prevent a partner from approving their own withdrawal; FK added after partners exist.';

create index approval_actions_request_idx
  on public.approval_actions (organization_id, approval_request_id, acted_at);
create index approval_actions_actor_idx
  on public.approval_actions (organization_id, acted_by, acted_at desc);
create index approval_actions_correlation_idx on public.approval_actions (correlation_id);
create unique index approval_actions_partner_approval_uidx
  on public.approval_actions (approval_request_id, approver_partner_id)
  where action_type in ('approve', 'reject') and approver_partner_id is not null;

create or replace function private.validate_approval_action()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.approval_requests%rowtype;
  v_actor uuid := (select auth.uid());
  v_required_permission text;
  v_prior_approval_count integer;
begin
  if v_actor is null or new.acted_by <> v_actor then
    raise exception using errcode = '42501', message = 'Approval actor mismatch';
  end if;

  select ar.*
    into v_request
  from public.approval_requests as ar
  where ar.organization_id = new.organization_id
    and ar.id = new.approval_request_id
  for update of ar;

  if not found then
    raise exception using errcode = 'P0002', message = 'Approval request not found';
  end if;

  select perm.permission_key
    into strict v_required_permission
  from private.permissions as perm
  where perm.id = v_request.required_permission_id;

  if v_request.status <> new.previous_status
    or v_request.subject_fingerprint <> new.subject_fingerprint then
    raise exception using errcode = '55000', message = 'Approval request changed';
  end if;

  if new.action_type in ('approve', 'reject') then
    if not private.has_permission(new.organization_id, v_required_permission) then
      raise exception using errcode = '42501', message = 'Approval permission denied';
    end if;

    if v_request.requires_separation_of_duties and v_request.requested_by = new.acted_by then
      raise exception using errcode = '42501', message = 'Self-approval is not permitted';
    end if;

    if new.action_type in ('approve', 'reject')
      and v_request.requester_partner_id is not null
      and new.approver_partner_id is null then
      raise exception using errcode = '23514', message = 'Approver partner identity is required';
    end if;

    if new.action_type in ('approve', 'reject')
      and v_request.requester_partner_id is not null
      and v_request.requester_partner_id = new.approver_partner_id then
      raise exception using errcode = '42501', message = 'Partner cannot decide own request';
    end if;

    if new.action_type = 'approve' then
      select count(*)
        into v_prior_approval_count
      from public.approval_actions as aa
      where aa.approval_request_id = new.approval_request_id
        and aa.action_type = 'approve';

      if v_prior_approval_count >= v_request.required_approval_count then
        raise exception using errcode = '55000', message = 'Required approvals are already complete';
      elsif v_prior_approval_count + 1 = v_request.required_approval_count
        and new.resulting_status <> 'approved' then
        raise exception using errcode = '23514', message = 'Final required approval must approve the request';
      elsif v_prior_approval_count + 1 < v_request.required_approval_count
        and new.resulting_status <> 'submitted' then
        raise exception using errcode = '23514', message = 'Additional approvals are still required';
      end if;
    end if;
  elsif new.action_type = 'cancel'
    and v_request.requested_by <> new.acted_by
    and not private.has_permission(new.organization_id, v_required_permission) then
    raise exception using errcode = '42501', message = 'Approval cancellation denied';
  end if;

  return new;
end;
$$;

revoke all on function private.validate_approval_action() from public, anon, authenticated;

create trigger approval_actions_validate
before insert on public.approval_actions
for each row execute function private.validate_approval_action();

create or replace function private.prevent_row_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  raise exception using errcode = '55000', message = 'Append-only record cannot be changed or deleted';
end;
$$;

revoke all on function private.prevent_row_mutation() from public, anon, authenticated;

create trigger approval_actions_append_only
before update or delete on public.approval_actions
for each row execute function private.prevent_row_mutation();

create table private.outbox_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  topic text not null,
  aggregate_type text not null,
  aggregate_id uuid not null,
  event_type text not null,
  payload jsonb not null,
  deduplication_key text,
  correlation_id uuid not null,
  command_execution_id uuid,
  available_at timestamptz not null default statement_timestamp(),
  attempt_count integer not null default 0,
  locked_at timestamptz,
  locked_by text,
  published_at timestamptz,
  last_error text,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint outbox_events_command_org_fk
    foreign key (organization_id, command_execution_id)
    references private.command_executions (organization_id, id) on delete restrict,
  constraint outbox_events_topic_format_chk
    check (topic ~ '^[a-z][a-z0-9_.-]{1,127}$'),
  constraint outbox_events_aggregate_type_format_chk
    check (aggregate_type ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint outbox_events_event_type_format_chk
    check (event_type ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  constraint outbox_events_payload_object_chk check (jsonb_typeof(payload) = 'object'),
  constraint outbox_events_deduplication_key_chk
    check (deduplication_key is null or (btrim(deduplication_key) <> '' and char_length(deduplication_key) <= 200)),
  constraint outbox_events_attempt_count_chk check (attempt_count >= 0),
  constraint outbox_events_lock_pair_chk check (
    (locked_at is null and locked_by is null)
    or (locked_at is not null and locked_by is not null and btrim(locked_by) <> '')
  ),
  constraint outbox_events_last_error_chk
    check (last_error is null or (btrim(last_error) <> '' and char_length(last_error) <= 1000))
);

comment on table private.outbox_events is
  'Transactional outbox. Business transactions enqueue non-secret event payloads; workers update delivery metadata only.';

create unique index outbox_events_deduplication_uidx
  on private.outbox_events (organization_id, topic, deduplication_key)
  where deduplication_key is not null;
create index outbox_events_ready_idx
  on private.outbox_events (available_at, created_at)
  where published_at is null and locked_at is null;
create index outbox_events_aggregate_idx
  on private.outbox_events (organization_id, aggregate_type, aggregate_id, created_at);
create index outbox_events_command_execution_idx
  on private.outbox_events (command_execution_id);
create index outbox_events_correlation_idx on private.outbox_events (correlation_id);

create trigger outbox_events_set_updated_at
before update on private.outbox_events
for each row execute function private.set_updated_at();

create or replace function private.protect_outbox_event()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if old.organization_id <> new.organization_id
    or old.topic <> new.topic
    or old.aggregate_type <> new.aggregate_type
    or old.aggregate_id <> new.aggregate_id
    or old.event_type <> new.event_type
    or old.payload <> new.payload
    or old.deduplication_key is distinct from new.deduplication_key
    or old.correlation_id <> new.correlation_id
    or old.command_execution_id is distinct from new.command_execution_id
    or old.available_at <> new.available_at
    or old.created_at <> new.created_at then
    raise exception using errcode = '55000', message = 'Outbox event identity and payload are immutable';
  end if;

  if old.published_at is not null then
    raise exception using errcode = '55000', message = 'Published outbox event is immutable';
  end if;

  return new;
end;
$$;

revoke all on function private.protect_outbox_event() from public, anon, authenticated;

create trigger outbox_events_protect_payload
before update on private.outbox_events
for each row execute function private.protect_outbox_event();

create table audit.events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  event_category text not null,
  action text not null,
  subject_type text not null,
  subject_id uuid,
  actor_type text not null default 'user',
  actor_user_id uuid,
  actor_role_keys jsonb not null default '[]'::jsonb,
  result text not null,
  reason text,
  correlation_id uuid not null,
  command_execution_id uuid,
  idempotency_reference text,
  before_state jsonb,
  after_state jsonb,
  event_metadata jsonb not null default '{}'::jsonb,
  request_ip inet,
  user_agent text,
  occurred_at timestamptz not null default statement_timestamp(),
  created_at timestamptz not null default statement_timestamp(),
  constraint audit_events_actor_org_fk
    foreign key (organization_id, actor_user_id)
    references public.profiles (organization_id, id) on delete restrict,
  constraint audit_events_command_org_fk
    foreign key (organization_id, command_execution_id)
    references private.command_executions (organization_id, id) on delete restrict,
  constraint audit_events_category_format_chk
    check (event_category ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint audit_events_action_format_chk
    check (action ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  constraint audit_events_subject_type_format_chk
    check (subject_type ~ '^[a-z][a-z0-9_]{1,63}$'),
  constraint audit_events_actor_type_chk check (actor_type in ('user', 'system', 'service')),
  constraint audit_events_actor_identity_chk check (
    (actor_type = 'user' and actor_user_id is not null)
    or (actor_type in ('system', 'service') and actor_user_id is null)
  ),
  constraint audit_events_roles_array_chk check (jsonb_typeof(actor_role_keys) = 'array'),
  constraint audit_events_result_chk check (result in ('succeeded', 'denied', 'failed')),
  constraint audit_events_reason_not_blank_chk check (reason is null or btrim(reason) <> ''),
  constraint audit_events_before_object_chk check (before_state is null or jsonb_typeof(before_state) = 'object'),
  constraint audit_events_after_object_chk check (after_state is null or jsonb_typeof(after_state) = 'object'),
  constraint audit_events_metadata_object_chk check (jsonb_typeof(event_metadata) = 'object'),
  constraint audit_events_user_agent_chk check (user_agent is null or char_length(user_agent) <= 1000)
);

comment on table audit.events is
  'Append-only financial, approval, configuration, command, export, security, and exception audit events.';
comment on column audit.events.event_metadata is
  'Safe structured context only. Secrets, raw evidence contents, and unnecessary personal data are prohibited.';

create index audit_events_org_occurred_idx
  on audit.events (organization_id, occurred_at desc, id);
create index audit_events_subject_idx
  on audit.events (organization_id, subject_type, subject_id, occurred_at desc);
create index audit_events_actor_idx
  on audit.events (organization_id, actor_user_id, occurred_at desc);
create index audit_events_command_execution_idx
  on audit.events (command_execution_id);
create index audit_events_correlation_idx on audit.events (correlation_id);
create index audit_events_denied_failed_idx
  on audit.events (organization_id, event_category, occurred_at desc)
  where result in ('denied', 'failed');

create trigger audit_events_append_only
before update or delete on audit.events
for each row execute function private.prevent_row_mutation();

alter table private.organization_finance_settings
  add constraint organization_finance_settings_approval_org_fk
  foreign key (organization_id, approval_reference_id)
  references public.approval_requests (organization_id, id) on delete restrict;

create index organization_finance_settings_approval_reference_idx
  on private.organization_finance_settings (approval_reference_id);

alter table private.command_executions enable row level security;
alter table public.approval_requests enable row level security;
alter table public.approval_actions enable row level security;
alter table private.outbox_events enable row level security;
alter table audit.events enable row level security;

revoke all on table private.command_executions from public, anon, authenticated;
revoke all on table public.approval_requests from public, anon, authenticated;
revoke all on table public.approval_actions from public, anon, authenticated;
revoke all on table private.outbox_events from public, anon, authenticated;
revoke all on table audit.events from public, anon, authenticated;
