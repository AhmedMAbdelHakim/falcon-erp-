-- Server-derived cumulative retained-profit, reserve, and distribution basis.

create or replace function private.refresh_monthly_close_distribution_basis(
  p_monthly_closing_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_close accounting.monthly_closings;
  v_period accounting.accounting_periods;
  v_settings private.organization_finance_settings;
  v_cumulative_profit_loss bigint;
  v_prior_distributions bigint;
  v_positive_retained bigint;
  v_policy_reserve bigint;
  v_protected_reserve bigint;
  v_distributable bigint;
  v_settings_complete boolean;
  v_snapshot jsonb;
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
  if v_period.status <> 'closing' or v_close.status = 'closed' then
    raise exception using errcode = '55000', message = 'CLOSE_BASIS_NOT_EDITABLE';
  end if;

  select s.* into strict v_settings
  from private.organization_finance_settings as s
  where s.organization_id = v_close.organization_id
    and s.effective_from <= statement_timestamp()
    and (s.effective_to is null or s.effective_to > statement_timestamp())
  order by s.version_no desc
  limit 1;

  v_settings_complete := v_settings.minimum_operating_capital_minor is not null
    and v_settings.reserve_requirement_bps is not null;

  select coalesce(sum(case
    when a.account_type = 'revenue' then jl.credit_minor - jl.debit_minor
    when a.account_type in ('contra_revenue', 'expense') then jl.credit_minor - jl.debit_minor
    else 0
  end), 0)::bigint
  into v_cumulative_profit_loss
  from accounting.journal_entries as je
  join accounting.journal_lines as jl on jl.journal_entry_id = je.id
  join accounting.accounts as a
    on a.organization_id = je.organization_id and a.id = jl.account_id
  where je.organization_id = v_close.organization_id
    and je.accounting_date <= v_period.period_end
    and je.status in ('posted', 'reversed');

  select coalesce(sum(pd.allocated_minor), 0)::bigint
  into v_prior_distributions
  from public.profit_distributions as pd
  where pd.organization_id = v_close.organization_id
    and pd.status = 'posted'
    and pd.monthly_closing_id <> p_monthly_closing_id;

  v_positive_retained := greatest(v_cumulative_profit_loss - v_prior_distributions, 0);
  v_policy_reserve := case when v_settings_complete then
    (v_positive_retained * v_settings.reserve_requirement_bps::bigint) / 10000
    else 0 end;
  v_protected_reserve := case when v_settings_complete then
    greatest(v_settings.minimum_operating_capital_minor, v_policy_reserve)
    else 0 end;
  v_distributable := case when v_settings_complete then
    greatest(v_positive_retained - v_protected_reserve, 0)
    else 0 end;

  v_snapshot := jsonb_build_object(
    'settings_version_no', v_settings.version_no,
    'settings_id', v_settings.id,
    'minimum_operating_capital_minor', v_settings.minimum_operating_capital_minor,
    'reserve_requirement_bps', v_settings.reserve_requirement_bps,
    'reserve_formula_version', 1,
    'reserve_formula', 'max(minimum_operating_capital, floor(positive_retained_after_prior_distributions * reserve_bps / 10000))',
    'settings_complete', v_settings_complete
  );

  update accounting.monthly_closings
  set cumulative_profit_loss_minor = v_cumulative_profit_loss,
      prior_distributions_minor = v_prior_distributions,
      protected_reserve_minor = v_protected_reserve,
      distributable_profit_minor = v_distributable,
      settings_snapshot = v_snapshot
  where id = p_monthly_closing_id;

  update accounting.closing_checklist_items
  set status = case when v_settings_complete then 'passed' else 'failed' end,
      expected_minor = case when v_settings_complete then v_protected_reserve end,
      actual_minor = case when v_settings_complete then v_protected_reserve end,
      evidence = jsonb_build_object(
        'settings', v_snapshot,
        'cumulative_profit_loss_minor', v_cumulative_profit_loss,
        'prior_distributions_minor', v_prior_distributions,
        'positive_retained_minor', v_positive_retained,
        'policy_reserve_minor', v_policy_reserve,
        'protected_reserve_minor', v_protected_reserve,
        'distributable_profit_minor', v_distributable
      ),
      notes = case when v_settings_complete then null
        else 'Approved minimum operating capital and reserve basis points are required' end,
      checked_by = auth.uid(), checked_at = statement_timestamp()
  where monthly_closing_id = p_monthly_closing_id
    and item_key = 'protected_reserve';

  return jsonb_build_object(
    'cumulative_profit_loss_minor', v_cumulative_profit_loss,
    'prior_distributions_minor', v_prior_distributions,
    'positive_retained_minor', v_positive_retained,
    'protected_reserve_minor', v_protected_reserve,
    'distributable_profit_minor', v_distributable,
    'settings', v_snapshot
  );
end;
$$;

comment on function private.refresh_monthly_close_distribution_basis(uuid) is
  'Computes cumulative P&L less posted distributions and the approved v1 reserve formula; missing policy inputs fail the close checklist.';
revoke all on function private.refresh_monthly_close_distribution_basis(uuid)
  from public, anon, authenticated;

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
  v_server_basis jsonb;
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
  v_period := private.lock_accounting_period(
    v_closing.organization_id, v_target_date, true
  );

  v_validation := private.validate_monthly_close(v_closing.id);
  if not coalesce((v_validation ->> 'ready')::boolean, false) then
    raise exception using errcode = '55000', message = 'MONTHLY_CLOSE_VALIDATION_FAILED';
  end if;
  v_server_basis := v_validation -> 'distribution_basis';

  update accounting.monthly_closings
  set status = 'closed',
      settings_snapshot = (v_server_basis -> 'settings')
        || jsonb_build_object('caller_context', p_settings_snapshot),
      reconciliation_snapshot = jsonb_build_object(
        'server_validation', v_validation,
        'external_evidence', p_reconciliation_snapshot
      ),
      closed_by = auth.uid(), closed_at = v_now
  where id = v_closing.id;

  update accounting.accounting_periods
  set status = 'closed', closed_by = auth.uid(), closed_at = v_now,
      version = version + 1
  where id = v_period.id;

  return jsonb_build_object(
    'success', true,
    'monthly_closing_id', v_closing.id,
    'accounting_period_id', v_period.id,
    'closed_at', v_now,
    'validation', v_validation,
    'distribution_basis', v_server_basis
  );
end;
$$;

revoke all on function private.close_accounting_period(uuid, jsonb, jsonb)
  from public, anon, authenticated;
