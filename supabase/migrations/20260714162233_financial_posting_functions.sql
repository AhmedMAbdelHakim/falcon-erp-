create or replace function private.cairo_accounting_date()
returns date
language sql
stable
security invoker
set search_path = ''
as $$
  select (statement_timestamp() at time zone 'Africa/Cairo')::date
$$;

comment on function private.cairo_accounting_date() is 'Returns the transaction business date in Africa/Cairo.';
revoke all on function private.cairo_accounting_date() from public, anon, authenticated;

create or replace function private.lock_accounting_period(
  p_organization_id uuid,
  p_accounting_date date default null,
  p_allow_closing boolean default false
)
returns accounting.accounting_periods
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_date date := coalesce(p_accounting_date, private.cairo_accounting_date());
  v_period accounting.accounting_periods;
begin
  select ap.*
    into v_period
  from accounting.accounting_periods as ap
  where ap.organization_id = p_organization_id
    and v_date between ap.period_start and ap.period_end
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'ACCOUNTING_PERIOD_NOT_FOUND';
  end if;

  if v_period.status not in ('open', 'reopened_exceptionally')
     and not (p_allow_closing and v_period.status = 'closing') then
    raise exception using errcode = 'P0001', message = 'ACCOUNTING_PERIOD_NOT_OPEN';
  end if;

  return v_period;
end;
$$;

comment on function private.lock_accounting_period(uuid, date, boolean) is
  'Locks the single organization period row used to serialize posting, reversal, and close, then verifies its state.';
revoke all on function private.lock_accounting_period(uuid, date, boolean) from public, anon, authenticated;

create or replace function private.resolve_account_id(
  p_organization_id uuid,
  p_role_key text,
  p_accounting_date date
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_account_id uuid;
begin
  select a.id
    into strict v_account_id
  from accounting.account_roles as ar
  join accounting.account_role_mappings as arm
    on arm.organization_id = ar.organization_id
   and arm.account_role_id = ar.id
  join accounting.accounts as a
    on a.organization_id = arm.organization_id
   and a.id = arm.account_id
  where ar.organization_id = p_organization_id
    and ar.role_key = p_role_key
    and arm.effective_range @> p_accounting_date
    and a.is_active
    and (ar.expected_account_type is null or ar.expected_account_type = a.account_type);

  return v_account_id;
exception
  when no_data_found then
    raise exception using errcode = 'P0001', message = 'ACCOUNT_ROLE_NOT_MAPPED';
  when too_many_rows then
    raise exception using errcode = 'P0001', message = 'ACCOUNT_ROLE_MAPPING_AMBIGUOUS';
end;
$$;

comment on function private.resolve_account_id(uuid, text, date) is
  'Resolves one active effective-dated semantic account role. Business commands never trust client-selected account IDs.';
revoke all on function private.resolve_account_id(uuid, text, date) from public, anon, authenticated;

create or replace function private.assert_journal_balanced(p_journal_entry_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_entry accounting.journal_entries;
  v_line_count bigint;
  v_debit numeric;
  v_credit numeric;
  v_wrong_org_count bigint;
begin
  select je.*
    into strict v_entry
  from accounting.journal_entries as je
  where je.id = p_journal_entry_id;

  select count(*), coalesce(sum(jl.debit_minor::numeric), 0), coalesce(sum(jl.credit_minor::numeric), 0),
         count(*) filter (where a.organization_id <> v_entry.organization_id or not a.is_active)
    into v_line_count, v_debit, v_credit, v_wrong_org_count
  from accounting.journal_lines as jl
  join accounting.accounts as a on a.id = jl.account_id
  where jl.journal_entry_id = p_journal_entry_id;

  if v_line_count < 2 then
    raise exception using errcode = '23514', message = 'JOURNAL_REQUIRES_AT_LEAST_TWO_LINES';
  end if;

  if v_wrong_org_count <> 0 then
    raise exception using errcode = '23514', message = 'JOURNAL_ACCOUNT_ORGANIZATION_MISMATCH';
  end if;

  if v_debit <= 0 or v_debit <> v_credit then
    raise exception using errcode = '23514', message = 'JOURNAL_NOT_BALANCED';
  end if;

  if v_debit > 9223372036854775807::numeric then
    raise exception using errcode = '22003', message = 'JOURNAL_TOTAL_OUT_OF_RANGE';
  end if;

  if not exists (
    select 1
    from accounting.accounting_periods as ap
    where ap.id = v_entry.accounting_period_id
      and ap.organization_id = v_entry.organization_id
      and v_entry.accounting_date between ap.period_start and ap.period_end
  ) then
    raise exception using errcode = '23514', message = 'JOURNAL_DATE_OUTSIDE_PERIOD';
  end if;
end;
$$;

comment on function private.assert_journal_balanced(uuid) is 'Validates line count, organization, active accounts, period date, range, and exact aggregate debit/credit equality.';
revoke all on function private.assert_journal_balanced(uuid) from public, anon, authenticated;

create or replace function private.guard_journal_entry_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_allowed_reversal text;
begin
  if tg_op = 'DELETE' then
    if old.status in ('posted', 'reversed') then
      raise exception using errcode = '55000', message = 'POSTED_JOURNAL_IMMUTABLE';
    end if;
    return old;
  end if;

  if old.status in ('posted', 'reversed') then
    v_allowed_reversal := current_setting('falcon.allowed_reversal_entry', true);

    if old.status = 'posted'
       and new.status = 'reversed'
       and new.reversed_by_entry_id is not null
       and v_allowed_reversal = old.id::text
       and (to_jsonb(new) - array['status', 'reversed_by_entry_id', 'updated_at'])
           = (to_jsonb(old) - array['status', 'reversed_by_entry_id', 'updated_at']) then
      return new;
    end if;

    raise exception using errcode = '55000', message = 'POSTED_JOURNAL_IMMUTABLE';
  end if;

  if old.status = 'draft' and new.status = 'reversed' then
    raise exception using errcode = '55000', message = 'DRAFT_JOURNAL_CANNOT_BE_REVERSED';
  end if;

  return new;
end;
$$;

revoke all on function private.guard_journal_entry_mutation() from public, anon, authenticated;

create trigger journal_entries_immutable_guard
before update or delete on accounting.journal_entries
for each row execute function private.guard_journal_entry_mutation();

create or replace function private.guard_journal_line_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry_id uuid := case when tg_op = 'DELETE' then old.journal_entry_id else new.journal_entry_id end;
  v_status public.journal_status;
begin
  select je.status into strict v_status
  from accounting.journal_entries as je
  where je.id = v_entry_id;

  if v_status <> 'draft' then
    raise exception using errcode = '55000', message = 'POSTED_JOURNAL_LINES_IMMUTABLE';
  end if;

  if tg_op = 'UPDATE' and new.journal_entry_id <> old.journal_entry_id then
    raise exception using errcode = '55000', message = 'JOURNAL_LINE_ENTRY_IMMUTABLE';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.guard_journal_line_mutation() from public, anon, authenticated;

create trigger journal_lines_immutable_guard
before insert or update or delete on accounting.journal_lines
for each row execute function private.guard_journal_line_mutation();

create or replace function private.enforce_deferred_journal_balance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry_id uuid;
  v_status public.journal_status;
begin
  if tg_table_name = 'journal_entries' then
    v_entry_id := case when tg_op = 'DELETE' then old.id else new.id end;
  else
    v_entry_id := case when tg_op = 'DELETE' then old.journal_entry_id else new.journal_entry_id end;
  end if;

  select je.status into v_status
  from accounting.journal_entries as je
  where je.id = v_entry_id;

  if v_status in ('posted', 'reversed') then
    perform private.assert_journal_balanced(v_entry_id);
  end if;

  return null;
end;
$$;

revoke all on function private.enforce_deferred_journal_balance() from public, anon, authenticated;

create constraint trigger journal_entries_deferred_balance
after insert or update on accounting.journal_entries
deferrable initially deferred
for each row execute function private.enforce_deferred_journal_balance();

create constraint trigger journal_lines_deferred_balance
after insert or update or delete on accounting.journal_lines
deferrable initially deferred
for each row execute function private.enforce_deferred_journal_balance();

create or replace function private.guard_append_only_financial_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using errcode = '55000', message = 'FINANCIAL_HISTORY_IMMUTABLE';
end;
$$;

revoke all on function private.guard_append_only_financial_row() from public, anon, authenticated;

create trigger posting_events_append_only
before update or delete on accounting.posting_events
for each row execute function private.guard_append_only_financial_row();

create or replace function private.guard_closed_close_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if tg_table_name = 'monthly_closings' then
    if old.status = 'closed' then
      raise exception using errcode = '55000', message = 'MONTHLY_CLOSE_IMMUTABLE';
    end if;
  else
    select mc.status into strict v_status
    from accounting.monthly_closings as mc
    where mc.id = case when tg_op = 'DELETE' then old.monthly_closing_id else new.monthly_closing_id end;

    if v_status = 'closed' then
      raise exception using errcode = '55000', message = 'MONTHLY_CLOSE_IMMUTABLE';
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.guard_closed_close_mutation() from public, anon, authenticated;

create trigger monthly_closings_immutable_guard
before update or delete on accounting.monthly_closings
for each row execute function private.guard_closed_close_mutation();

create trigger closing_checklist_items_immutable_guard
before update or delete on accounting.closing_checklist_items
for each row execute function private.guard_closed_close_mutation();

create or replace function private.post_journal_entry(
  p_organization_id uuid,
  p_source_type text,
  p_source_id uuid,
  p_posting_purpose text,
  p_description text,
  p_lines jsonb,
  p_idempotency_key text,
  p_request_hash text,
  p_request_hash_version smallint default 1,
  p_correlation_id uuid default extensions.gen_random_uuid(),
  p_accounting_date date default null,
  p_approval_request_id uuid default null,
  p_corrects_entry_id uuid default null,
  p_affected_closed_period_id uuid default null,
  p_reversal_of uuid default null,
  p_reversal_reason text default null,
  p_command_type text default 'ledger.post',
  p_command_execution_id uuid default null,
  p_require_manual_permission boolean default true
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_date date := coalesce(p_accounting_date, private.cairo_accounting_date());
  v_period accounting.accounting_periods;
  v_existing accounting.journal_entries;
  v_entry_id uuid;
  v_line jsonb;
  v_account_id uuid;
  v_role_key text;
  v_line_number smallint := 0;
  v_debit bigint;
  v_credit bigint;
  v_debit_total numeric := 0;
  v_credit_total numeric := 0;
  v_dimensions jsonb;
begin
  if v_actor is null then
    raise exception using errcode = '28000', message = 'AUTHENTICATION_REQUIRED';
  end if;

  if p_require_manual_permission then
    perform private.require_permission(p_organization_id, 'ledger.post');
  end if;

  if p_source_type !~ '^[a-z][a-z0-9_]*$'
     or p_posting_purpose !~ '^[a-z][a-z0-9_]*$'
     or p_command_type !~ '^[a-z][a-z0-9_.]*$'
     or btrim(coalesce(p_description, '')) = ''
     or btrim(coalesce(p_idempotency_key, '')) = ''
     or btrim(coalesce(p_request_hash, '')) = '' then
    raise exception using errcode = '22023', message = 'INVALID_POSTING_REQUEST';
  end if;

  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) < 2 then
    raise exception using errcode = '22023', message = 'JOURNAL_REQUIRES_AT_LEAST_TWO_LINES';
  end if;

  if p_command_type = 'ledger.post'
     and (p_source_type <> 'manual_journal' or p_posting_purpose <> 'manual_adjustment') then
    raise exception using errcode = '22023', message = 'MANUAL_JOURNAL_SOURCE_SCOPE_INVALID';
  end if;

  v_period := private.lock_accounting_period(p_organization_id, v_date, false);

  select je.* into v_existing
  from accounting.journal_entries as je
  where je.organization_id = p_organization_id
    and je.idempotency_key = p_idempotency_key
    and je.posting_purpose = p_posting_purpose
  for update;

  if found then
    if v_existing.request_hash <> p_request_hash
       or v_existing.request_hash_version <> p_request_hash_version
       or v_existing.source_type <> p_source_type
       or v_existing.source_id <> p_source_id then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_CONFLICT';
    end if;
    return v_existing.id;
  end if;

  insert into accounting.journal_entries (
    organization_id, accounting_period_id, accounting_date, description,
    source_type, source_id, posting_purpose, idempotency_key, request_hash,
    request_hash_version, correlation_id, command_execution_id, approval_request_id,
    created_by, reversal_of, reversal_reason, corrects_entry_id, affected_closed_period_id
  ) values (
    p_organization_id, v_period.id, v_date, p_description,
    p_source_type, p_source_id, p_posting_purpose, p_idempotency_key, p_request_hash,
    p_request_hash_version, p_correlation_id, p_command_execution_id, p_approval_request_id,
    v_actor, p_reversal_of, p_reversal_reason, p_corrects_entry_id, p_affected_closed_period_id
  ) returning id into v_entry_id;

  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    if jsonb_typeof(v_line) <> 'object' then
      raise exception using errcode = '22023', message = 'INVALID_JOURNAL_LINE';
    end if;

    v_line_number := v_line_number + 1;
    v_role_key := nullif(v_line ->> 'account_role', '');

    if v_role_key is not null and nullif(v_line ->> 'account_id', '') is not null then
      raise exception using errcode = '22023', message = 'JOURNAL_LINE_ACCOUNT_AMBIGUOUS';
    elsif v_role_key is not null then
      v_account_id := private.resolve_account_id(p_organization_id, v_role_key, v_date);
      if p_command_type = 'ledger.post' and not exists (
        select 1 from accounting.accounts as a
        where a.id = v_account_id
          and a.organization_id = p_organization_id
          and a.is_active
          and a.allows_manual_posting
      ) then
        raise exception using errcode = '22023', message = 'MANUAL_POSTING_TO_CONTROL_ACCOUNT_DENIED';
      end if;
    elsif nullif(v_line ->> 'account_id', '') is not null
          and p_command_type in ('ledger.post', 'ledger.reverse') then
      begin
        v_account_id := (v_line ->> 'account_id')::uuid;
      exception when invalid_text_representation then
        raise exception using errcode = '22023', message = 'INVALID_JOURNAL_ACCOUNT';
      end;

      if not exists (
        select 1 from accounting.accounts as a
        where a.id = v_account_id
          and a.organization_id = p_organization_id
          and a.is_active
          and (p_command_type = 'ledger.reverse' or a.allows_manual_posting)
      ) then
        raise exception using errcode = '22023', message = 'INVALID_JOURNAL_ACCOUNT';
      end if;
    else
      raise exception using errcode = '22023', message = 'JOURNAL_LINE_ACCOUNT_REQUIRED';
    end if;

    begin
      v_debit := coalesce((v_line ->> 'debit_minor')::bigint, 0);
      v_credit := coalesce((v_line ->> 'credit_minor')::bigint, 0);
    exception when invalid_text_representation or numeric_value_out_of_range then
      raise exception using errcode = '22023', message = 'INVALID_MINOR_UNIT_AMOUNT';
    end;

    if not ((v_debit > 0 and v_credit = 0) or (v_credit > 0 and v_debit = 0)) then
      raise exception using errcode = '22023', message = 'JOURNAL_LINE_MUST_BE_ONE_SIDED';
    end if;

    v_dimensions := coalesce(v_line -> 'dimensions', '{}'::jsonb);
    if jsonb_typeof(v_dimensions) <> 'object' then
      raise exception using errcode = '22023', message = 'INVALID_JOURNAL_DIMENSIONS';
    end if;

    insert into accounting.journal_lines (
      journal_entry_id, line_number, account_id, debit_minor, credit_minor, description,
      subledger_type, subledger_id, order_id, customer_id, supplier_id, employee_id,
      partner_id, wallet_id, shipment_id, print_batch_id, dimensions
    ) values (
      v_entry_id, v_line_number, v_account_id, v_debit, v_credit, nullif(v_line ->> 'description', ''),
      nullif(v_line ->> 'subledger_type', ''), nullif(v_line ->> 'subledger_id', '')::uuid,
      nullif(v_line ->> 'order_id', '')::uuid, nullif(v_line ->> 'customer_id', '')::uuid,
      nullif(v_line ->> 'supplier_id', '')::uuid, nullif(v_line ->> 'employee_id', '')::uuid,
      nullif(v_line ->> 'partner_id', '')::uuid, nullif(v_line ->> 'wallet_id', '')::uuid,
      nullif(v_line ->> 'shipment_id', '')::uuid, nullif(v_line ->> 'print_batch_id', '')::uuid,
      v_dimensions
    );

    v_debit_total := v_debit_total + v_debit;
    v_credit_total := v_credit_total + v_credit;
  end loop;

  if v_debit_total <= 0 or v_debit_total <> v_credit_total then
    raise exception using errcode = '23514', message = 'JOURNAL_NOT_BALANCED';
  end if;

  if v_debit_total > 9223372036854775807::numeric then
    raise exception using errcode = '22003', message = 'JOURNAL_TOTAL_OUT_OF_RANGE';
  end if;

  perform private.assert_journal_balanced(v_entry_id);

  update accounting.journal_entries
  set status = 'posted',
      total_debit_minor = v_debit_total::bigint,
      total_credit_minor = v_credit_total::bigint,
      posted_by = v_actor,
      posted_at = statement_timestamp()
  where id = v_entry_id;

  insert into accounting.posting_events (
    organization_id, source_type, source_id, posting_purpose, journal_entry_id,
    command_type, command_execution_id, idempotency_key, request_hash,
    correlation_id, posted_by
  ) values (
    p_organization_id, p_source_type, p_source_id, p_posting_purpose, v_entry_id,
    p_command_type, p_command_execution_id, p_idempotency_key, p_request_hash,
    p_correlation_id, v_actor
  );

  return v_entry_id;
end;
$$;

comment on function private.post_journal_entry(
  uuid, text, uuid, text, text, jsonb, text, text, smallint, uuid, date, uuid,
  uuid, uuid, uuid, text, text, uuid, boolean
) is 'Atomic posting primitive: authorizes, locks the Cairo period, claims idempotency/source-purpose, resolves account roles, balances, posts, and records the posting event.';
revoke all on function private.post_journal_entry(
  uuid, text, uuid, text, text, jsonb, text, text, smallint, uuid, date, uuid,
  uuid, uuid, uuid, text, text, uuid, boolean
) from public, anon, authenticated;

create or replace function private.reverse_journal_entry(
  p_organization_id uuid,
  p_original_entry_id uuid,
  p_reason text,
  p_idempotency_key text,
  p_request_hash text,
  p_correlation_id uuid default extensions.gen_random_uuid(),
  p_approval_request_id uuid default null,
  p_command_execution_id uuid default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_date date := private.cairo_accounting_date();
  v_period accounting.accounting_periods;
  v_original accounting.journal_entries;
  v_existing accounting.journal_entries;
  v_lines jsonb;
  v_reversal_id uuid;
begin
  perform private.require_permission(p_organization_id, 'ledger.reverse');

  if btrim(coalesce(p_reason, '')) = '' then
    raise exception using errcode = '22023', message = 'REVERSAL_REASON_REQUIRED';
  end if;

  v_period := private.lock_accounting_period(p_organization_id, v_date, false);

  select je.* into v_existing
  from accounting.journal_entries as je
  where je.organization_id = p_organization_id
    and je.idempotency_key = p_idempotency_key
    and je.posting_purpose = 'reversal'
  for update;

  if found then
    if v_existing.request_hash <> p_request_hash or v_existing.reversal_of <> p_original_entry_id then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_CONFLICT';
    end if;
    return v_existing.id;
  end if;

  select je.* into strict v_original
  from accounting.journal_entries as je
  where je.id = p_original_entry_id
    and je.organization_id = p_organization_id
  for update;

  if v_original.status <> 'posted' or v_original.reversed_by_entry_id is not null then
    raise exception using errcode = '55000', message = 'JOURNAL_NOT_REVERSIBLE';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'account_id', jl.account_id,
      'debit_minor', jl.credit_minor::text,
      'credit_minor', jl.debit_minor::text,
      'description', coalesce(jl.description, 'Reversal'),
      'subledger_type', jl.subledger_type,
      'subledger_id', jl.subledger_id,
      'order_id', jl.order_id,
      'customer_id', jl.customer_id,
      'supplier_id', jl.supplier_id,
      'employee_id', jl.employee_id,
      'partner_id', jl.partner_id,
      'wallet_id', jl.wallet_id,
      'shipment_id', jl.shipment_id,
      'print_batch_id', jl.print_batch_id,
      'dimensions', jl.dimensions
    ) order by jl.line_number
  ) into v_lines
  from accounting.journal_lines as jl
  where jl.journal_entry_id = v_original.id;

  v_reversal_id := private.post_journal_entry(
    p_organization_id => p_organization_id,
    p_source_type => 'journal_entry',
    p_source_id => p_original_entry_id,
    p_posting_purpose => 'reversal',
    p_description => 'Reversal: ' || v_original.description,
    p_lines => v_lines,
    p_idempotency_key => p_idempotency_key,
    p_request_hash => p_request_hash,
    p_correlation_id => p_correlation_id,
    p_accounting_date => v_date,
    p_approval_request_id => p_approval_request_id,
    p_affected_closed_period_id => case
      when v_original.accounting_period_id <> v_period.id then v_original.accounting_period_id
      else null
    end,
    p_reversal_of => p_original_entry_id,
    p_reversal_reason => p_reason,
    p_command_type => 'ledger.reverse',
    p_command_execution_id => p_command_execution_id,
    p_require_manual_permission => false
  );

  perform set_config('falcon.allowed_reversal_entry', p_original_entry_id::text, true);
  update accounting.journal_entries
  set status = 'reversed', reversed_by_entry_id = v_reversal_id
  where id = p_original_entry_id;
  perform set_config('falcon.allowed_reversal_entry', '', true);

  return v_reversal_id;
end;
$$;

comment on function private.reverse_journal_entry(uuid, uuid, text, text, text, uuid, uuid, uuid) is
  'Posts one current-open-period mirror of a posted entry and atomically links the immutable original. Stored line amounts are negated without recomputation.';
revoke all on function private.reverse_journal_entry(uuid, uuid, text, text, text, uuid, uuid, uuid)
  from public, anon, authenticated;

create or replace function private.calculate_period_close_totals(
  p_organization_id uuid,
  p_accounting_period_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with totals as (
    select
      coalesce(sum(jl.debit_minor::numeric), 0) as trial_debit,
      coalesce(sum(jl.credit_minor::numeric), 0) as trial_credit,
      coalesce(sum(case when a.account_type = 'revenue' then jl.credit_minor - jl.debit_minor else 0 end)::numeric, 0) as revenue,
      coalesce(sum(case when a.account_type = 'contra_revenue' then jl.debit_minor - jl.credit_minor else 0 end)::numeric, 0) as contra_revenue,
      coalesce(sum(case when a.account_type = 'expense' then jl.debit_minor - jl.credit_minor else 0 end)::numeric, 0) as expense
    from accounting.journal_entries as je
    join accounting.journal_lines as jl on jl.journal_entry_id = je.id
    join accounting.accounts as a on a.id = jl.account_id
    where je.organization_id = p_organization_id
      and je.accounting_period_id = p_accounting_period_id
      and je.status in ('posted', 'reversed')
  )
  select jsonb_build_object(
    'trial_debit_minor', trial_debit::text,
    'trial_credit_minor', trial_credit::text,
    'revenue_minor', revenue::text,
    'contra_revenue_minor', contra_revenue::text,
    'expense_minor', expense::text,
    'profit_loss_minor', (revenue - contra_revenue - expense)::text
  )
  from totals
$$;

revoke all on function private.calculate_period_close_totals(uuid, uuid) from public, anon, authenticated;

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

  select count(*) into v_unbalanced_count
  from accounting.journal_entries as je
  where je.accounting_period_id = v_period.id
    and je.status in ('posted', 'reversed')
    and (je.total_debit_minor <= 0 or je.total_debit_minor <> je.total_credit_minor);

  select count(*) into v_blocking_count
  from accounting.closing_checklist_items as cci
  where cci.monthly_closing_id = v_closing.id
    and cci.is_blocking
    and cci.status <> 'passed';

  v_totals := private.calculate_period_close_totals(v_closing.organization_id, v_period.id);
  v_ready := v_unbalanced_count = 0
             and v_blocking_count = 0
             and (v_totals ->> 'trial_debit_minor') = (v_totals ->> 'trial_credit_minor');

  update accounting.monthly_closings
  set status = case when v_ready then 'ready' else 'draft' end,
      trial_balance_debit_minor = (v_totals ->> 'trial_debit_minor')::bigint,
      trial_balance_credit_minor = (v_totals ->> 'trial_credit_minor')::bigint,
      period_revenue_minor = ((v_totals ->> 'revenue_minor')::bigint - (v_totals ->> 'contra_revenue_minor')::bigint),
      period_expense_minor = (v_totals ->> 'expense_minor')::bigint,
      period_profit_loss_minor = (v_totals ->> 'profit_loss_minor')::bigint,
      validation_result = jsonb_build_object(
        'ready', v_ready,
        'blocking_checklist_count', v_blocking_count,
        'unbalanced_entry_count', v_unbalanced_count,
        'validated_at', statement_timestamp()
      ),
      validated_by = auth.uid(),
      validated_at = statement_timestamp()
  where id = v_closing.id;

  return jsonb_build_object(
    'ready', v_ready,
    'monthly_closing_id', v_closing.id,
    'accounting_period_id', v_period.id,
    'blocking_checklist_count', v_blocking_count,
    'unbalanced_entry_count', v_unbalanced_count,
    'totals', v_totals
  );
end;
$$;

comment on function private.validate_monthly_close(uuid) is 'Revalidates a current Cairo period under the shared period lock and snapshots trial balance and P&L totals.';
revoke all on function private.validate_monthly_close(uuid) from public, anon, authenticated;

create or replace function private.close_accounting_period(
  p_monthly_closing_id uuid,
  p_settings_snapshot jsonb,
  p_reconciliation_snapshot jsonb
)
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
  v_validation jsonb;
  v_now timestamptz := statement_timestamp();
begin
  select mc.* into strict v_closing
  from accounting.monthly_closings as mc
  where mc.id = p_monthly_closing_id;

  perform private.require_permission(v_closing.organization_id, 'accounting.close_period');

  if jsonb_typeof(p_settings_snapshot) <> 'object'
     or jsonb_typeof(p_reconciliation_snapshot) <> 'object' then
    raise exception using errcode = '22023', message = 'CLOSE_SNAPSHOTS_MUST_BE_OBJECTS';
  end if;

  select ap.period_start into strict v_target_date
  from accounting.accounting_periods as ap
  where ap.id = v_closing.accounting_period_id
    and ap.organization_id = v_closing.organization_id;
  v_period := private.lock_accounting_period(v_closing.organization_id, v_target_date, true);

  v_validation := private.validate_monthly_close(v_closing.id);
  if not coalesce((v_validation ->> 'ready')::boolean, false) then
    raise exception using errcode = '55000', message = 'MONTHLY_CLOSE_VALIDATION_FAILED';
  end if;

  update accounting.monthly_closings
  set status = 'closed',
      settings_snapshot = p_settings_snapshot,
      reconciliation_snapshot = p_reconciliation_snapshot,
      closed_by = auth.uid(),
      closed_at = v_now
  where id = v_closing.id;

  update accounting.accounting_periods
  set status = 'closed',
      closed_by = auth.uid(),
      closed_at = v_now,
      version = version + 1
  where id = v_period.id;

  return jsonb_build_object(
    'success', true,
    'monthly_closing_id', v_closing.id,
    'accounting_period_id', v_period.id,
    'closed_at', v_now,
    'validation', v_validation
  );
end;
$$;

comment on function private.close_accounting_period(uuid, jsonb, jsonb) is
  'Final close transition. It holds the shared current-period lock through validation and immutable snapshot/status updates.';
revoke all on function private.close_accounting_period(uuid, jsonb, jsonb) from public, anon, authenticated;
