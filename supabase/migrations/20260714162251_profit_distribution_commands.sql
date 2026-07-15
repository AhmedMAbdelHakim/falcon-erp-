-- Calculated, separately approved, and separately posted profit distributions.

insert into private.permissions (id, permission_key, description, is_sensitive)
select md5('falcon-permission:' || permission_key)::uuid, permission_key, description, true
from (values
  ('profit_distributions.calculate', 'Calculate a distribution from a closed period'),
  ('profit_distributions.approve', 'Approve a calculated profit distribution'),
  ('profit_distributions.post', 'Post an approved profit distribution')
) as permission_seed(permission_key, description)
on conflict (permission_key) do nothing;

create or replace function private.command_profit_distribution(
  p_organization_id uuid,
  p_action text,
  p_monthly_closing_id uuid,
  p_profit_distribution_id uuid,
  p_distribution_no text,
  p_distribution_amount_minor bigint,
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
  v_command_type text := 'partners.profit_distribution.' || p_action;
  v_claim record;
  v_close accounting.monthly_closings;
  v_period accounting.accounting_periods;
  v_distribution public.profit_distributions;
  v_distribution_id uuid;
  v_share_total bigint;
  v_allocated bigint;
  v_journal_entry_id uuid;
  v_lines jsonb;
  v_result jsonb;
  v_sqlstate text;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'action', p_action,
    'monthly_closing_id', p_monthly_closing_id,
    'profit_distribution_id', p_profit_distribution_id,
    'distribution_no', p_distribution_no,
    'distribution_amount_minor', p_distribution_amount_minor,
    'approval_request_id', p_approval_request_id
  );
begin
  if p_action not in ('calculate', 'approve', 'post') then
    raise exception using errcode = '22023', message = 'INVALID_DISTRIBUTION_ACTION';
  end if;
  perform private.require_permission(
    p_organization_id, 'profit_distributions.' || p_action
  );
  perform private.assert_request_fingerprint(
    v_command_type, v_payload, p_request_fingerprint, 1::smallint
  );
  select * into v_claim from private.claim_command(
    p_organization_id, v_command_type, p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;

  begin
    if p_action = 'calculate' then
      if p_profit_distribution_id is not null
         or nullif(btrim(p_distribution_no), '') is null
         or p_distribution_amount_minor is null
         or p_distribution_amount_minor <= 0 then
        raise exception using errcode = '22023', message = 'INVALID_DISTRIBUTION_CALCULATION';
      end if;
      select mc.* into strict v_close
      from accounting.monthly_closings as mc
      where mc.id = p_monthly_closing_id
        and mc.organization_id = p_organization_id
      for update;
      select ap.* into strict v_period
      from accounting.accounting_periods as ap
      where ap.id = v_close.accounting_period_id
        and ap.organization_id = p_organization_id
      for update;
      if v_close.status <> 'closed' or v_period.status <> 'closed'
         or v_close.distributable_profit_minor is null
         or p_distribution_amount_minor > v_close.distributable_profit_minor then
        raise exception using errcode = '23514', message = 'DISTRIBUTION_EXCEEDS_CLOSED_BASIS';
      end if;

      perform 1 from public.partners as p
      where p.organization_id = p_organization_id and p.is_active
      order by p.id for update;
      select coalesce(sum(pop.profit_share_bps), 0),
             coalesce(sum((p_distribution_amount_minor * pop.profit_share_bps::bigint) / 10000), 0)
      into v_share_total, v_allocated
      from public.partner_ownership_periods as pop
      join public.partners as p
        on p.organization_id = pop.organization_id and p.id = pop.partner_id
      where pop.organization_id = p_organization_id
        and p.is_active
        and pop.effective_from <= v_period.period_end
        and (pop.effective_to is null or pop.effective_to > v_period.period_end);
      if v_share_total <> 10000 or v_allocated <= 0 then
        raise exception using errcode = '23514', message = 'PARTNER_PROFIT_SHARES_INVALID';
      end if;

      insert into public.profit_distributions (
        organization_id, monthly_closing_id, distribution_no, status,
        distributable_profit_minor, approved_distribution_minor,
        allocated_minor, retained_remainder_minor, ownership_snapshot_at,
        created_by, updated_by
      ) values (
        p_organization_id, p_monthly_closing_id, p_distribution_no, 'submitted',
        v_close.distributable_profit_minor, p_distribution_amount_minor,
        v_allocated, p_distribution_amount_minor - v_allocated,
        v_close.closed_at, auth.uid(), auth.uid()
      ) returning id into v_distribution_id;

      insert into public.profit_distribution_lines (
        organization_id, profit_distribution_id, partner_id,
        ownership_bps_snapshot, allocation_numerator, allocated_amount_minor,
        created_by, updated_by
      )
      select p_organization_id, v_distribution_id, pop.partner_id,
             pop.profit_share_bps,
             p_distribution_amount_minor::numeric * pop.profit_share_bps::numeric,
             (p_distribution_amount_minor * pop.profit_share_bps::bigint) / 10000,
             auth.uid(), auth.uid()
      from public.partner_ownership_periods as pop
      join public.partners as p
        on p.organization_id = pop.organization_id and p.id = pop.partner_id
      where pop.organization_id = p_organization_id
        and p.is_active
        and pop.effective_from <= v_period.period_end
        and (pop.effective_to is null or pop.effective_to > v_period.period_end);
    else
      select pd.* into strict v_distribution
      from public.profit_distributions as pd
      where pd.id = p_profit_distribution_id
        and pd.organization_id = p_organization_id
      for update;
      v_distribution_id := v_distribution.id;

      if p_action = 'approve' then
        if v_distribution.status <> 'submitted'
           or v_distribution.created_by = auth.uid()
           or p_approval_request_id is null then
          raise exception using errcode = '42501', message = 'DISTRIBUTION_APPROVAL_SOD_FAILED';
        end if;
        perform private.consume_approval(
          p_organization_id, p_approval_request_id,
          'profit_distribution.approve', 'profit_distribution',
          v_distribution.id, p_request_fingerprint,
          v_claim.command_execution_id, v_distribution.allocated_minor
        );
        update public.profit_distributions
        set status = 'approved', approval_request_id = p_approval_request_id,
            approved_at = statement_timestamp(), approved_by = auth.uid(),
            version = version + 1, updated_by = auth.uid()
        where id = v_distribution.id;
      else
        if v_distribution.status <> 'approved'
           or v_distribution.approved_by = auth.uid() then
          raise exception using errcode = '42501', message = 'DISTRIBUTION_POSTING_SOD_FAILED';
        end if;
        select jsonb_build_array(jsonb_build_object(
          'account_role', 'retained_earnings',
          'debit_minor', v_distribution.allocated_minor::text,
          'credit_minor', '0',
          'subledger_type', 'profit_distribution',
          'subledger_id', v_distribution.id
        )) || coalesce(jsonb_agg(jsonb_build_object(
          'account_role', 'partner_current_accounts',
          'debit_minor', '0',
          'credit_minor', pdl.allocated_amount_minor::text,
          'partner_id', pdl.partner_id,
          'subledger_type', 'partner_distribution',
          'subledger_id', pdl.id
        ) order by pdl.partner_id) filter (where pdl.allocated_amount_minor > 0), '[]'::jsonb)
        into v_lines
        from public.profit_distribution_lines as pdl
        where pdl.organization_id = p_organization_id
          and pdl.profit_distribution_id = v_distribution.id;

        v_journal_entry_id := private.post_journal_entry(
          p_organization_id => p_organization_id,
          p_source_type => 'profit_distribution',
          p_source_id => v_distribution.id,
          p_posting_purpose => 'distribution',
          p_description => 'Approved partner profit distribution',
          p_lines => v_lines,
          p_idempotency_key => p_idempotency_key,
          p_request_hash => p_request_fingerprint,
          p_correlation_id => p_correlation_id,
          p_approval_request_id => v_distribution.approval_request_id,
          p_command_type => v_command_type,
          p_command_execution_id => v_claim.command_execution_id,
          p_require_manual_permission => false
        );
        update public.profit_distributions
        set status = 'posted', journal_entry_id = v_journal_entry_id,
            posted_at = statement_timestamp(), version = version + 1,
            updated_by = auth.uid()
        where id = v_distribution.id;
      end if;
    end if;

    v_result := private.command_success_response(
      v_claim.command_execution_id, v_distribution_id,
      case p_action when 'calculate' then 'submitted'
        when 'approve' then 'approved' else 'posted' end,
      'profit_distribution.' || p_action || '_succeeded',
      case when v_journal_entry_id is null then '[]'::jsonb
        else jsonb_build_array(v_journal_entry_id) end
    );
    perform private.complete_command_success(v_claim.command_execution_id, v_result);
    perform private.record_financial_command_audit(
      p_organization_id, v_command_type, 'profit_distribution',
      v_distribution_id, 'succeeded', null, p_correlation_id,
      v_claim.command_execution_id, p_idempotency_key
    );
    return v_result;
  exception when others then
    v_sqlstate := sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id, v_sqlstate, v_command_type,
        'profit_distribution', coalesce(p_profit_distribution_id, p_monthly_closing_id),
        p_idempotency_key, p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id, 'PROFIT_DISTRIBUTION_REJECTED', null
    );
    return private.command_replay_response(
      'failed_terminal', null, 'PROFIT_DISTRIBUTION_REJECTED',
      v_claim.command_execution_id
    );
  end;
end;
$$;

revoke all on function private.command_profit_distribution(
  uuid, text, uuid, uuid, text, bigint, uuid, text, text, uuid
) from public, anon, authenticated;

create or replace function api.calculate_profit_distribution(
  p_organization_id uuid, p_monthly_closing_id uuid, p_distribution_no text,
  p_distribution_amount_minor bigint, p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_profit_distribution(
  p_organization_id, 'calculate', p_monthly_closing_id, null,
  p_distribution_no, p_distribution_amount_minor, null,
  p_idempotency_key, p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.approve_profit_distribution(
  p_organization_id uuid, p_profit_distribution_id uuid,
  p_approval_request_id uuid, p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_profit_distribution(
  p_organization_id, 'approve', null, p_profit_distribution_id,
  null, null, p_approval_request_id,
  p_idempotency_key, p_request_fingerprint, p_correlation_id
) $$;

create or replace function api.post_profit_distribution(
  p_organization_id uuid, p_profit_distribution_id uuid,
  p_idempotency_key text, p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path = ''
as $$ select private.command_profit_distribution(
  p_organization_id, 'post', null, p_profit_distribution_id,
  null, null, null, p_idempotency_key, p_request_fingerprint, p_correlation_id
) $$;

revoke all on function api.calculate_profit_distribution(uuid, uuid, text, bigint, text, text, uuid)
  from public, anon, authenticated;
revoke all on function api.approve_profit_distribution(uuid, uuid, uuid, text, text, uuid)
  from public, anon, authenticated;
revoke all on function api.post_profit_distribution(uuid, uuid, text, text, uuid)
  from public, anon, authenticated;
grant execute on function api.calculate_profit_distribution(uuid, uuid, text, bigint, text, text, uuid)
  to authenticated;
grant execute on function api.approve_profit_distribution(uuid, uuid, uuid, text, text, uuid)
  to authenticated;
grant execute on function api.post_profit_distribution(uuid, uuid, text, text, uuid)
  to authenticated;
