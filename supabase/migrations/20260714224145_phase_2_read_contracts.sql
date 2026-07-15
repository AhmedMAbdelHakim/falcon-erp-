create index journal_entries_read_cursor_idx
  on accounting.journal_entries (organization_id, accounting_date desc, entry_number desc);

create index audit_events_read_cursor_idx
  on audit.events (organization_id, occurred_at desc, id desc);

create index wallet_reconciliations_latest_read_idx
  on public.wallet_reconciliations (organization_id, wallet_id, period_ended_at desc, created_at desc);

create or replace function private.require_any_permission(
  p_organization_id uuid,
  p_permission_keys text[]
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception using errcode = '28000', message = 'Authentication required';
  end if;

  if p_organization_id is null or coalesce(array_length(p_permission_keys, 1), 0) = 0 then
    raise exception using errcode = '22023', message = 'Organization and permissions are required';
  end if;

  if not exists (
    select 1
    from unnest(p_permission_keys) as requested(permission_key)
    where private.has_permission(p_organization_id, requested.permission_key)
  ) then
    raise exception using errcode = '42501', message = 'Permission denied';
  end if;
end;
$$;

revoke all on function private.require_any_permission(uuid, text[])
  from public, anon, authenticated;

create or replace function private.read_dashboard_summary(
  p_organization_id uuid,
  p_period_start date,
  p_period_end date
)
returns table (
  organization_id uuid,
  period_start date,
  period_end date,
  currency_code text,
  gross_revenue_minor bigint,
  contra_revenue_minor bigint,
  net_revenue_minor bigint,
  expense_minor bigint,
  profit_loss_minor bigint,
  wallet_book_balance_minor bigint,
  protected_liabilities_minor bigint,
  pending_withdrawals_minor bigint,
  protected_reserve_minor bigint,
  safe_cash_minor bigint,
  unreconciled_wallet_count bigint,
  open_approval_count bigint,
  unposted_event_count bigint,
  negative_inventory_count bigint,
  last_posted_at timestamptz,
  last_reconciled_at timestamptz,
  generated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_minimum_operating_capital bigint := 0;
  v_protected_reserve bigint := 0;
begin
  perform private.require_permission(p_organization_id, 'ledger.read');
  if p_period_start is null or p_period_end is null or p_period_start > p_period_end then
    raise exception using errcode = '22023', message = 'Invalid dashboard date range';
  end if;

  select coalesce(settings.minimum_operating_capital_minor, 0)
  into v_minimum_operating_capital
  from private.organization_finance_settings as settings
  where settings.organization_id = p_organization_id
    and settings.effective_from <= statement_timestamp()
    and (settings.effective_to is null or settings.effective_to > statement_timestamp())
  order by settings.version_no desc
  limit 1;

  select coalesce(closing.protected_reserve_minor, 0)
  into v_protected_reserve
  from accounting.monthly_closings as closing
  join accounting.accounting_periods as period
    on period.organization_id = closing.organization_id
   and period.id = closing.accounting_period_id
  where closing.organization_id = p_organization_id
    and closing.status = 'closed'
    and period.period_end <= p_period_end
  order by closing.closed_at desc
  limit 1;

  return query
  with period_ledger as (
    select
      coalesce(sum(case when account.account_type = 'revenue'
        then line.credit_minor - line.debit_minor else 0 end), 0)::bigint as gross_revenue,
      coalesce(sum(case when account.account_type = 'contra_revenue'
        then line.debit_minor - line.credit_minor else 0 end), 0)::bigint as contra_revenue,
      coalesce(sum(case when account.account_type = 'expense'
        then line.debit_minor - line.credit_minor else 0 end), 0)::bigint as expenses,
      max(entry.posted_at) as latest_posted_at
    from accounting.journal_entries as entry
    join accounting.journal_lines as line on line.journal_entry_id = entry.id
    join accounting.accounts as account on account.id = line.account_id
    where entry.organization_id = p_organization_id
      and entry.status in ('posted', 'reversed')
      and entry.accounting_date between p_period_start and p_period_end
  ),
  wallet_ledger as (
    select coalesce(sum(line.debit_minor - line.credit_minor), 0)::bigint as book_balance
    from accounting.journal_entries as entry
    join accounting.journal_lines as line on line.journal_entry_id = entry.id
    where entry.organization_id = p_organization_id
      and entry.status in ('posted', 'reversed')
      and entry.accounting_date <= p_period_end
      and line.wallet_id is not null
  ),
  protected_liabilities as (
    select greatest(coalesce(sum(line.credit_minor - line.debit_minor), 0), 0)::bigint as balance
    from accounting.journal_entries as entry
    join accounting.journal_lines as line on line.journal_entry_id = entry.id
    join accounting.accounts as account on account.id = line.account_id
    where entry.organization_id = p_organization_id
      and entry.status in ('posted', 'reversed')
      and entry.accounting_date <= p_period_end
      and account.account_type = 'liability'
      and account.is_control_account
  ),
  pending_withdrawals as (
    select coalesce(sum(withdrawal.requested_amount_minor), 0)::bigint as balance
    from public.partner_withdrawals as withdrawal
    where withdrawal.organization_id = p_organization_id
      and withdrawal.status in ('submitted', 'approved')
  ),
  latest_wallet_reconciliations as (
    select wallet.id as wallet_id, reconciliation.status, reconciliation.difference_minor,
      reconciliation.finalized_at
    from public.wallets as wallet
    left join lateral (
      select candidate.status, candidate.difference_minor, candidate.finalized_at
      from public.wallet_reconciliations as candidate
      where candidate.organization_id = wallet.organization_id
        and candidate.wallet_id = wallet.id
        and candidate.period_ended_at::date <= p_period_end
      order by candidate.period_ended_at desc, candidate.created_at desc
      limit 1
    ) as reconciliation on true
    where wallet.organization_id = p_organization_id and wallet.is_active
  ),
  wallet_reconciliation_state as (
    select
      count(*) filter (where state.status is distinct from 'finalized'
        or coalesce(state.difference_minor, 0) <> 0)::bigint as unreconciled_count,
      max(state.finalized_at) as latest_finalized_at
    from latest_wallet_reconciliations as state
  ),
  alert_counts as (
    select
      (select count(*)::bigint from public.approval_requests as request
        where request.organization_id = p_organization_id
          and request.status in ('draft', 'submitted', 'approved')) as approvals,
      (select count(*)::bigint from public.unposted_financial_events as event
        where event.organization_id = p_organization_id) as unposted,
      (select count(*)::bigint from public.inventory_negative_balance_alerts as alert
        where alert.organization_id = p_organization_id) as negative_inventory
  )
  select
    p_organization_id,
    p_period_start,
    p_period_end,
    'EGP'::text,
    ledger.gross_revenue,
    ledger.contra_revenue,
    ledger.gross_revenue - ledger.contra_revenue,
    ledger.expenses,
    ledger.gross_revenue - ledger.contra_revenue - ledger.expenses,
    wallet.book_balance,
    liabilities.balance,
    withdrawals.balance,
    greatest(v_minimum_operating_capital, v_protected_reserve),
    greatest(wallet.book_balance - liabilities.balance - withdrawals.balance
      - greatest(v_minimum_operating_capital, v_protected_reserve), 0)::bigint,
    reconciliation.unreconciled_count,
    alerts.approvals,
    alerts.unposted,
    alerts.negative_inventory,
    ledger.latest_posted_at,
    reconciliation.latest_finalized_at,
    statement_timestamp()
  from period_ledger as ledger
  cross join wallet_ledger as wallet
  cross join protected_liabilities as liabilities
  cross join pending_withdrawals as withdrawals
  cross join wallet_reconciliation_state as reconciliation
  cross join alert_counts as alerts;
end;
$$;

create or replace function api.read_dashboard_summary(
  p_organization_id uuid,
  p_period_start date,
  p_period_end date
)
returns table (
  organization_id uuid, period_start date, period_end date, currency_code text,
  gross_revenue_minor bigint, contra_revenue_minor bigint, net_revenue_minor bigint,
  expense_minor bigint, profit_loss_minor bigint, wallet_book_balance_minor bigint,
  protected_liabilities_minor bigint, pending_withdrawals_minor bigint,
  protected_reserve_minor bigint, safe_cash_minor bigint, unreconciled_wallet_count bigint,
  open_approval_count bigint, unposted_event_count bigint, negative_inventory_count bigint,
  last_posted_at timestamptz, last_reconciled_at timestamptz, generated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.read_dashboard_summary(p_organization_id, p_period_start, p_period_end)
$$;

create or replace function private.read_profit_and_loss(
  p_organization_id uuid,
  p_period_start date,
  p_period_end date
)
returns table (
  organization_id uuid,
  month_start date,
  month_end date,
  period_status text,
  currency_code text,
  gross_revenue_minor bigint,
  contra_revenue_minor bigint,
  net_revenue_minor bigint,
  expense_minor bigint,
  profit_loss_minor bigint,
  last_posted_at timestamptz,
  generated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_permission(p_organization_id, 'ledger.read');
  if p_period_start is null or p_period_end is null or p_period_start > p_period_end then
    raise exception using errcode = '22023', message = 'Invalid profit and loss date range';
  end if;

  return query
  select
    entry.organization_id,
    date_trunc('month', entry.accounting_date)::date,
    (date_trunc('month', entry.accounting_date) + interval '1 month - 1 day')::date,
    coalesce(period.status::text, 'unconfigured'),
    'EGP'::text,
    sum(case when account.account_type = 'revenue'
      then line.credit_minor - line.debit_minor else 0 end)::bigint,
    sum(case when account.account_type = 'contra_revenue'
      then line.debit_minor - line.credit_minor else 0 end)::bigint,
    sum(case
      when account.account_type = 'revenue' then line.credit_minor - line.debit_minor
      when account.account_type = 'contra_revenue' then line.credit_minor - line.debit_minor
      else 0 end)::bigint,
    sum(case when account.account_type = 'expense'
      then line.debit_minor - line.credit_minor else 0 end)::bigint,
    sum(case
      when account.account_type = 'revenue' then line.credit_minor - line.debit_minor
      when account.account_type in ('contra_revenue', 'expense') then line.credit_minor - line.debit_minor
      else 0 end)::bigint,
    max(entry.posted_at),
    statement_timestamp()
  from accounting.journal_entries as entry
  join accounting.journal_lines as line on line.journal_entry_id = entry.id
  join accounting.accounts as account on account.id = line.account_id
  left join accounting.accounting_periods as period
    on period.organization_id = entry.organization_id
   and entry.accounting_date between period.period_start and period.period_end
  where entry.organization_id = p_organization_id
    and entry.status in ('posted', 'reversed')
    and entry.accounting_date between p_period_start and p_period_end
  group by entry.organization_id, date_trunc('month', entry.accounting_date), period.status
  order by date_trunc('month', entry.accounting_date);
end;
$$;

create or replace function api.read_profit_and_loss(
  p_organization_id uuid,
  p_period_start date,
  p_period_end date
)
returns table (
  organization_id uuid, month_start date, month_end date, period_status text,
  currency_code text, gross_revenue_minor bigint, contra_revenue_minor bigint,
  net_revenue_minor bigint, expense_minor bigint, profit_loss_minor bigint,
  last_posted_at timestamptz, generated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.read_profit_and_loss(p_organization_id, p_period_start, p_period_end)
$$;

create or replace function private.read_trial_balance(
  p_organization_id uuid,
  p_period_start date,
  p_period_end date
)
returns table (
  organization_id uuid,
  account_id uuid,
  account_code text,
  account_name text,
  account_type text,
  normal_balance text,
  opening_debit_minor bigint,
  opening_credit_minor bigint,
  period_debit_minor bigint,
  period_credit_minor bigint,
  closing_debit_minor bigint,
  closing_credit_minor bigint,
  currency_code text,
  generated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_permission(p_organization_id, 'ledger.read');
  if p_period_start is null or p_period_end is null or p_period_start > p_period_end then
    raise exception using errcode = '22023', message = 'Invalid trial balance date range';
  end if;

  return query
  with account_totals as (
    select
      account.id,
      account.code,
      account.name,
      account.account_type,
      account.normal_balance,
      coalesce(sum(line.debit_minor - line.credit_minor)
        filter (where entry.accounting_date < p_period_start), 0)::bigint as opening_net,
      coalesce(sum(line.debit_minor)
        filter (where entry.accounting_date between p_period_start and p_period_end), 0)::bigint as period_debit,
      coalesce(sum(line.credit_minor)
        filter (where entry.accounting_date between p_period_start and p_period_end), 0)::bigint as period_credit,
      coalesce(sum(line.debit_minor - line.credit_minor)
        filter (where entry.accounting_date <= p_period_end), 0)::bigint as closing_net
    from accounting.accounts as account
    left join accounting.journal_lines as line on line.account_id = account.id
    left join accounting.journal_entries as entry
      on entry.id = line.journal_entry_id
     and entry.organization_id = p_organization_id
     and entry.status in ('posted', 'reversed')
    where account.organization_id = p_organization_id
    group by account.id, account.code, account.name, account.account_type, account.normal_balance
  )
  select
    p_organization_id,
    totals.id,
    totals.code,
    totals.name,
    totals.account_type,
    totals.normal_balance,
    greatest(totals.opening_net, 0)::bigint,
    greatest(-totals.opening_net, 0)::bigint,
    totals.period_debit,
    totals.period_credit,
    greatest(totals.closing_net, 0)::bigint,
    greatest(-totals.closing_net, 0)::bigint,
    'EGP'::text,
    statement_timestamp()
  from account_totals as totals
  where totals.opening_net <> 0 or totals.period_debit <> 0 or totals.period_credit <> 0
  order by totals.code;
end;
$$;

create or replace function api.read_trial_balance(
  p_organization_id uuid,
  p_period_start date,
  p_period_end date
)
returns table (
  organization_id uuid, account_id uuid, account_code text, account_name text,
  account_type text, normal_balance text, opening_debit_minor bigint,
  opening_credit_minor bigint, period_debit_minor bigint, period_credit_minor bigint,
  closing_debit_minor bigint, closing_credit_minor bigint, currency_code text,
  generated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.read_trial_balance(p_organization_id, p_period_start, p_period_end)
$$;

create or replace function private.read_control_account_reconciliation(
  p_organization_id uuid,
  p_as_of_date date
)
returns table (
  organization_id uuid,
  reconciliation_domain text,
  account_role text,
  account_id uuid,
  account_code text,
  account_name text,
  ledger_balance_minor bigint,
  dimensioned_balance_minor bigint,
  difference_minor bigint,
  reconciliation_status text,
  currency_code text,
  as_of_date date,
  last_posted_at timestamptz,
  generated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_permission(p_organization_id, 'ledger.read');
  if p_as_of_date is null then
    raise exception using errcode = '22023', message = 'As-of date is required';
  end if;

  return query
  with mapped_accounts as (
    select role.role_key, account.id, account.code, account.name, account.account_type
    from accounting.account_roles as role
    join accounting.account_role_mappings as mapping
      on mapping.organization_id = role.organization_id
     and mapping.account_role_id = role.id
     and mapping.valid_from <= p_as_of_date
     and (mapping.valid_to is null or mapping.valid_to > p_as_of_date)
    join accounting.accounts as account
      on account.organization_id = mapping.organization_id
     and account.id = mapping.account_id
    where role.organization_id = p_organization_id
      and role.role_key in (
        'wallet_vodafone_maaz', 'wallet_cash_clearing',
        'customer_deposits', 'customer_credits', 'refund_payable',
        'courier_receivables', 'courier_payables',
        'goods_received_not_invoiced', 'supplier_payables',
        'payroll_payable', 'partner_capital', 'partner_current_accounts',
        'partner_loans_payable'
      )
  ),
  balances as (
    select
      mapped.role_key,
      mapped.id,
      mapped.code,
      mapped.name,
      mapped.account_type,
      coalesce(sum(case when mapped.account_type in ('asset', 'expense', 'contra_revenue')
        then line.debit_minor - line.credit_minor
        else line.credit_minor - line.debit_minor end), 0)::bigint as ledger_balance,
      coalesce(sum(case when
        case
          when mapped.role_key like 'wallet_%' then line.wallet_id is not null
          when mapped.role_key in ('customer_deposits', 'customer_credits', 'refund_payable')
            then line.customer_id is not null
          when mapped.role_key in ('courier_receivables', 'courier_payables')
            then line.shipment_id is not null or line.subledger_id is not null
          when mapped.role_key in ('goods_received_not_invoiced', 'supplier_payables')
            then line.supplier_id is not null or line.print_batch_id is not null
          when mapped.role_key = 'payroll_payable' then line.employee_id is not null
          when mapped.role_key in ('partner_capital', 'partner_current_accounts', 'partner_loans_payable')
            then line.partner_id is not null
          else line.subledger_id is not null
        end
        then case when mapped.account_type in ('asset', 'expense', 'contra_revenue')
          then line.debit_minor - line.credit_minor
          else line.credit_minor - line.debit_minor end
        else 0 end), 0)::bigint as dimensioned_balance,
      max(entry.posted_at) as latest_posted_at
    from mapped_accounts as mapped
    left join accounting.journal_lines as line on line.account_id = mapped.id
    left join accounting.journal_entries as entry
      on entry.id = line.journal_entry_id
     and entry.organization_id = p_organization_id
     and entry.status in ('posted', 'reversed')
     and entry.accounting_date <= p_as_of_date
    group by mapped.role_key, mapped.id, mapped.code, mapped.name, mapped.account_type
  )
  select
    p_organization_id,
    case
      when balance.role_key like 'wallet_%' then 'wallets'
      when balance.role_key in ('customer_deposits', 'customer_credits', 'refund_payable') then 'customer_money'
      when balance.role_key in ('courier_receivables', 'courier_payables') then 'courier'
      when balance.role_key in ('goods_received_not_invoiced', 'supplier_payables') then 'suppliers'
      when balance.role_key = 'payroll_payable' then 'payroll'
      when balance.role_key in ('partner_capital', 'partner_current_accounts', 'partner_loans_payable') then 'partners'
      else 'other'
    end,
    balance.role_key,
    balance.id,
    balance.code,
    balance.name,
    balance.ledger_balance,
    balance.dimensioned_balance,
    balance.ledger_balance - balance.dimensioned_balance,
    case when balance.ledger_balance = balance.dimensioned_balance then 'reconciled' else 'difference' end,
    'EGP'::text,
    p_as_of_date,
    balance.latest_posted_at,
    statement_timestamp()
  from balances as balance
  order by 2, 3;
end;
$$;

create or replace function api.read_control_account_reconciliation(
  p_organization_id uuid,
  p_as_of_date date
)
returns table (
  organization_id uuid, reconciliation_domain text, account_role text,
  account_id uuid, account_code text, account_name text, ledger_balance_minor bigint,
  dimensioned_balance_minor bigint, difference_minor bigint, reconciliation_status text,
  currency_code text, as_of_date date, last_posted_at timestamptz, generated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.read_control_account_reconciliation(p_organization_id, p_as_of_date)
$$;

create or replace function private.read_liquidity_summary(
  p_organization_id uuid,
  p_as_of_date date
)
returns table (
  organization_id uuid,
  wallet_id uuid,
  wallet_code text,
  wallet_name text,
  provider text,
  currency_code text,
  book_balance_minor bigint,
  reconciliation_id uuid,
  reconciliation_status text,
  physical_balance_minor bigint,
  difference_minor bigint,
  is_reconciled boolean,
  reconciled_through_at timestamptz,
  finalized_at timestamptz,
  last_posted_at timestamptz,
  as_of_date date,
  generated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_any_permission(
    p_organization_id,
    array['wallets.read_summary', 'ledger.read']::text[]
  );
  if p_as_of_date is null then
    raise exception using errcode = '22023', message = 'As-of date is required';
  end if;

  return query
  select
    wallet.organization_id,
    wallet.id,
    wallet.code,
    wallet.name,
    wallet.provider,
    wallet.currency,
    coalesce(book.balance, 0)::bigint,
    reconciliation.id,
    reconciliation.status,
    reconciliation.actual_closing_balance_minor,
    reconciliation.difference_minor,
    coalesce(reconciliation.status = 'finalized' and reconciliation.difference_minor = 0, false),
    reconciliation.period_ended_at,
    reconciliation.finalized_at,
    book.latest_posted_at,
    p_as_of_date,
    statement_timestamp()
  from public.wallets as wallet
  left join lateral (
    select
      coalesce(sum(line.debit_minor - line.credit_minor), 0)::bigint as balance,
      max(entry.posted_at) as latest_posted_at
    from accounting.journal_entries as entry
    join accounting.journal_lines as line on line.journal_entry_id = entry.id
    where entry.organization_id = wallet.organization_id
      and entry.status in ('posted', 'reversed')
      and entry.accounting_date <= p_as_of_date
      and line.wallet_id = wallet.id
  ) as book on true
  left join lateral (
    select candidate.id, candidate.status, candidate.actual_closing_balance_minor,
      candidate.difference_minor, candidate.period_ended_at, candidate.finalized_at
    from public.wallet_reconciliations as candidate
    where candidate.organization_id = wallet.organization_id
      and candidate.wallet_id = wallet.id
      and candidate.period_ended_at::date <= p_as_of_date
    order by candidate.period_ended_at desc, candidate.created_at desc
    limit 1
  ) as reconciliation on true
  where wallet.organization_id = p_organization_id
  order by wallet.code;
end;
$$;

create or replace function api.read_liquidity_summary(
  p_organization_id uuid,
  p_as_of_date date
)
returns table (
  organization_id uuid, wallet_id uuid, wallet_code text, wallet_name text,
  provider text, currency_code text, book_balance_minor bigint, reconciliation_id uuid,
  reconciliation_status text, physical_balance_minor bigint, difference_minor bigint,
  is_reconciled boolean, reconciled_through_at timestamptz, finalized_at timestamptz,
  last_posted_at timestamptz, as_of_date date, generated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.read_liquidity_summary(p_organization_id, p_as_of_date)
$$;

create or replace function private.list_journal_entries(
  p_organization_id uuid,
  p_period_start date default null,
  p_period_end date default null,
  p_status public.journal_status default null,
  p_source_type text default null,
  p_cursor_accounting_date date default null,
  p_cursor_entry_number bigint default null,
  p_page_size integer default 50
)
returns table (
  organization_id uuid,
  journal_entry_id uuid,
  entry_number bigint,
  accounting_period_id uuid,
  period_status public.accounting_period_status,
  status public.journal_status,
  posting_date timestamptz,
  accounting_date date,
  description text,
  source_type text,
  source_id uuid,
  posting_purpose text,
  currency_code text,
  total_debit_minor bigint,
  total_credit_minor bigint,
  correlation_id uuid,
  approval_request_id uuid,
  posted_by uuid,
  posted_at timestamptz,
  reversal_of uuid,
  reversed_by_entry_id uuid,
  reversal_reason text,
  corrects_entry_id uuid,
  affected_closed_period_id uuid,
  is_adjustment boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_permission(p_organization_id, 'ledger.read');
  if p_page_size not between 1 and 100 then
    raise exception using errcode = '22023', message = 'Page size must be between 1 and 100';
  end if;
  if p_period_start is not null and p_period_end is not null and p_period_start > p_period_end then
    raise exception using errcode = '22023', message = 'Invalid journal date range';
  end if;
  if (p_cursor_accounting_date is null) <> (p_cursor_entry_number is null) then
    raise exception using errcode = '22023', message = 'Journal cursor fields must be provided together';
  end if;
  if p_source_type is not null and (length(p_source_type) > 80 or p_source_type !~ '^[a-z][a-z0-9_]*$') then
    raise exception using errcode = '22023', message = 'Invalid source type filter';
  end if;

  return query
  select
    entry.organization_id,
    entry.id,
    entry.entry_number,
    entry.accounting_period_id,
    period.status,
    entry.status,
    entry.posting_date,
    entry.accounting_date,
    entry.description,
    entry.source_type,
    entry.source_id,
    entry.posting_purpose,
    entry.currency_code,
    entry.total_debit_minor,
    entry.total_credit_minor,
    entry.correlation_id,
    entry.approval_request_id,
    entry.posted_by,
    entry.posted_at,
    entry.reversal_of,
    entry.reversed_by_entry_id,
    entry.reversal_reason,
    entry.corrects_entry_id,
    entry.affected_closed_period_id,
    entry.affected_closed_period_id is not null
  from accounting.journal_entries as entry
  join accounting.accounting_periods as period
    on period.organization_id = entry.organization_id
   and period.id = entry.accounting_period_id
  where entry.organization_id = p_organization_id
    and (p_period_start is null or entry.accounting_date >= p_period_start)
    and (p_period_end is null or entry.accounting_date <= p_period_end)
    and (p_status is null or entry.status = p_status)
    and (p_source_type is null or entry.source_type = p_source_type)
    and (p_cursor_accounting_date is null
      or (entry.accounting_date, entry.entry_number) < (p_cursor_accounting_date, p_cursor_entry_number))
  order by entry.accounting_date desc, entry.entry_number desc
  limit p_page_size;
end;
$$;

create or replace function api.list_journal_entries(
  p_organization_id uuid,
  p_period_start date default null,
  p_period_end date default null,
  p_status public.journal_status default null,
  p_source_type text default null,
  p_cursor_accounting_date date default null,
  p_cursor_entry_number bigint default null,
  p_page_size integer default 50
)
returns table (
  organization_id uuid, journal_entry_id uuid, entry_number bigint,
  accounting_period_id uuid, period_status public.accounting_period_status,
  status public.journal_status, posting_date timestamptz, accounting_date date,
  description text, source_type text, source_id uuid, posting_purpose text,
  currency_code text, total_debit_minor bigint, total_credit_minor bigint,
  correlation_id uuid, approval_request_id uuid, posted_by uuid, posted_at timestamptz,
  reversal_of uuid, reversed_by_entry_id uuid, reversal_reason text,
  corrects_entry_id uuid, affected_closed_period_id uuid, is_adjustment boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.list_journal_entries(
    p_organization_id, p_period_start, p_period_end, p_status, p_source_type,
    p_cursor_accounting_date, p_cursor_entry_number, p_page_size
  )
$$;

create or replace function private.list_journal_lines(
  p_organization_id uuid,
  p_journal_entry_id uuid,
  p_after_line_number smallint default null,
  p_page_size integer default 100
)
returns table (
  organization_id uuid,
  journal_entry_id uuid,
  journal_line_id uuid,
  line_number smallint,
  account_id uuid,
  account_code text,
  account_name text,
  account_type text,
  debit_minor bigint,
  credit_minor bigint,
  description text,
  subledger_type text,
  subledger_id uuid,
  order_id uuid,
  customer_id uuid,
  supplier_id uuid,
  employee_id uuid,
  partner_id uuid,
  wallet_id uuid,
  shipment_id uuid,
  print_batch_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_permission(p_organization_id, 'ledger.read');
  if p_journal_entry_id is null then
    raise exception using errcode = '22023', message = 'Journal entry is required';
  end if;
  if p_page_size not between 1 and 100 then
    raise exception using errcode = '22023', message = 'Page size must be between 1 and 100';
  end if;

  return query
  select
    entry.organization_id,
    entry.id,
    line.id,
    line.line_number,
    account.id,
    account.code,
    account.name,
    account.account_type,
    line.debit_minor,
    line.credit_minor,
    line.description,
    line.subledger_type,
    line.subledger_id,
    line.order_id,
    line.customer_id,
    line.supplier_id,
    line.employee_id,
    line.partner_id,
    line.wallet_id,
    line.shipment_id,
    line.print_batch_id
  from accounting.journal_entries as entry
  join accounting.journal_lines as line on line.journal_entry_id = entry.id
  join accounting.accounts as account on account.id = line.account_id
  where entry.organization_id = p_organization_id
    and entry.id = p_journal_entry_id
    and (p_after_line_number is null or line.line_number > p_after_line_number)
  order by line.line_number
  limit p_page_size;
end;
$$;

create or replace function api.list_journal_lines(
  p_organization_id uuid,
  p_journal_entry_id uuid,
  p_after_line_number smallint default null,
  p_page_size integer default 100
)
returns table (
  organization_id uuid, journal_entry_id uuid, journal_line_id uuid,
  line_number smallint, account_id uuid, account_code text, account_name text,
  account_type text, debit_minor bigint, credit_minor bigint, description text,
  subledger_type text, subledger_id uuid, order_id uuid, customer_id uuid,
  supplier_id uuid, employee_id uuid, partner_id uuid, wallet_id uuid,
  shipment_id uuid, print_batch_id uuid
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.list_journal_lines(
    p_organization_id, p_journal_entry_id, p_after_line_number, p_page_size
  )
$$;

create or replace function private.list_monthly_closes(
  p_organization_id uuid,
  p_status text default null,
  p_cursor_period_start date default null,
  p_cursor_period_id uuid default null,
  p_page_size integer default 24
)
returns table (
  organization_id uuid,
  accounting_period_id uuid,
  period_start date,
  period_end date,
  period_status public.accounting_period_status,
  period_version bigint,
  monthly_closing_id uuid,
  closing_status text,
  checklist_version smallint,
  trial_balance_debit_minor bigint,
  trial_balance_credit_minor bigint,
  period_revenue_minor bigint,
  period_expense_minor bigint,
  period_profit_loss_minor bigint,
  cumulative_profit_loss_minor bigint,
  prior_distributions_minor bigint,
  protected_reserve_minor bigint,
  distributable_profit_minor bigint,
  approval_request_id uuid,
  approval_status public.approval_status,
  requested_by uuid,
  requested_at timestamptz,
  validated_by uuid,
  validated_at timestamptz,
  closed_by uuid,
  closed_at timestamptz,
  reopen_reason text,
  reopened_by uuid,
  reopened_at timestamptz,
  correlation_id uuid,
  validation_summary jsonb,
  generated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_permission(p_organization_id, 'ledger.read');
  if p_page_size not between 1 and 100 then
    raise exception using errcode = '22023', message = 'Page size must be between 1 and 100';
  end if;
  if (p_cursor_period_start is null) <> (p_cursor_period_id is null) then
    raise exception using errcode = '22023', message = 'Close cursor fields must be provided together';
  end if;
  if p_status is not null and length(p_status) > 40 then
    raise exception using errcode = '22023', message = 'Invalid close status filter';
  end if;

  return query
  select
    period.organization_id,
    period.id,
    period.period_start,
    period.period_end,
    period.status,
    period.version,
    closing.id,
    closing.status,
    closing.checklist_version,
    closing.trial_balance_debit_minor,
    closing.trial_balance_credit_minor,
    closing.period_revenue_minor,
    closing.period_expense_minor,
    closing.period_profit_loss_minor,
    closing.cumulative_profit_loss_minor,
    closing.prior_distributions_minor,
    closing.protected_reserve_minor,
    closing.distributable_profit_minor,
    closing.approval_request_id,
    approval.status,
    closing.requested_by,
    closing.requested_at,
    closing.validated_by,
    closing.validated_at,
    closing.closed_by,
    closing.closed_at,
    period.reopen_reason,
    period.reopened_by,
    period.reopened_at,
    closing.correlation_id,
    case when closing.validation_result is null then null
      else closing.validation_result - array['object_name', 'bucket_id', 'path', 'url',
        'signed_url', 'token', 'secret', 'checksum_sha256']::text[] end,
    statement_timestamp()
  from accounting.accounting_periods as period
  left join accounting.monthly_closings as closing
    on closing.organization_id = period.organization_id
   and closing.accounting_period_id = period.id
  left join public.approval_requests as approval
    on approval.organization_id = closing.organization_id
   and approval.id = closing.approval_request_id
  where period.organization_id = p_organization_id
    and (p_status is null or period.status::text = p_status or closing.status = p_status)
    and (p_cursor_period_start is null
      or (period.period_start, period.id) < (p_cursor_period_start, p_cursor_period_id))
  order by period.period_start desc, period.id desc
  limit p_page_size;
end;
$$;

create or replace function api.list_monthly_closes(
  p_organization_id uuid,
  p_status text default null,
  p_cursor_period_start date default null,
  p_cursor_period_id uuid default null,
  p_page_size integer default 24
)
returns table (
  organization_id uuid, accounting_period_id uuid, period_start date, period_end date,
  period_status public.accounting_period_status, period_version bigint,
  monthly_closing_id uuid, closing_status text, checklist_version smallint,
  trial_balance_debit_minor bigint, trial_balance_credit_minor bigint,
  period_revenue_minor bigint, period_expense_minor bigint, period_profit_loss_minor bigint,
  cumulative_profit_loss_minor bigint, prior_distributions_minor bigint,
  protected_reserve_minor bigint, distributable_profit_minor bigint,
  approval_request_id uuid, approval_status public.approval_status, requested_by uuid,
  requested_at timestamptz, validated_by uuid, validated_at timestamptz,
  closed_by uuid, closed_at timestamptz, reopen_reason text, reopened_by uuid,
  reopened_at timestamptz, correlation_id uuid, validation_summary jsonb,
  generated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.list_monthly_closes(
    p_organization_id, p_status, p_cursor_period_start, p_cursor_period_id, p_page_size
  )
$$;

create or replace function private.list_monthly_close_checklist(
  p_organization_id uuid,
  p_monthly_closing_id uuid,
  p_status text default null
)
returns table (
  organization_id uuid,
  monthly_closing_id uuid,
  checklist_item_id uuid,
  item_key text,
  status text,
  is_blocking boolean,
  expected_minor bigint,
  actual_minor bigint,
  difference_minor bigint,
  evidence_metadata jsonb,
  notes text,
  checked_by uuid,
  checked_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_permission(p_organization_id, 'ledger.read');
  if p_monthly_closing_id is null then
    raise exception using errcode = '22023', message = 'Monthly closing is required';
  end if;
  if p_status is not null and length(p_status) > 40 then
    raise exception using errcode = '22023', message = 'Invalid checklist status filter';
  end if;

  return query
  select
    closing.organization_id,
    closing.id,
    item.id,
    item.item_key,
    item.status,
    item.is_blocking,
    item.expected_minor,
    item.actual_minor,
    item.difference_minor,
    item.evidence - array['object_name', 'bucket_id', 'path', 'url', 'signed_url',
      'token', 'secret', 'checksum_sha256']::text[],
    item.notes,
    item.checked_by,
    item.checked_at,
    item.updated_at
  from accounting.monthly_closings as closing
  join accounting.closing_checklist_items as item on item.monthly_closing_id = closing.id
  where closing.organization_id = p_organization_id
    and closing.id = p_monthly_closing_id
    and (p_status is null or item.status = p_status)
  order by item.item_key;
end;
$$;

create or replace function api.list_monthly_close_checklist(
  p_organization_id uuid,
  p_monthly_closing_id uuid,
  p_status text default null
)
returns table (
  organization_id uuid, monthly_closing_id uuid, checklist_item_id uuid,
  item_key text, status text, is_blocking boolean, expected_minor bigint,
  actual_minor bigint, difference_minor bigint, evidence_metadata jsonb,
  notes text, checked_by uuid, checked_at timestamptz, updated_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.list_monthly_close_checklist(
    p_organization_id, p_monthly_closing_id, p_status
  )
$$;

create or replace function private.search_audit_events(
  p_organization_id uuid,
  p_occurred_from timestamptz default null,
  p_occurred_to timestamptz default null,
  p_event_category text default null,
  p_action text default null,
  p_result text default null,
  p_subject_type text default null,
  p_subject_id uuid default null,
  p_correlation_id uuid default null,
  p_cursor_occurred_at timestamptz default null,
  p_cursor_event_id uuid default null,
  p_page_size integer default 50
)
returns table (
  organization_id uuid,
  audit_event_id uuid,
  event_category text,
  action text,
  subject_type text,
  subject_id uuid,
  actor_type text,
  actor_user_id uuid,
  result text,
  reason text,
  correlation_id uuid,
  command_execution_id uuid,
  has_state_change boolean,
  has_metadata boolean,
  occurred_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_permission(p_organization_id, 'audit.read');
  if p_page_size not between 1 and 100 then
    raise exception using errcode = '22023', message = 'Page size must be between 1 and 100';
  end if;
  if p_occurred_from is not null and p_occurred_to is not null and p_occurred_from > p_occurred_to then
    raise exception using errcode = '22023', message = 'Invalid audit date range';
  end if;
  if (p_cursor_occurred_at is null) <> (p_cursor_event_id is null) then
    raise exception using errcode = '22023', message = 'Audit cursor fields must be provided together';
  end if;
  if greatest(
    coalesce(length(p_event_category), 0), coalesce(length(p_action), 0),
    coalesce(length(p_result), 0), coalesce(length(p_subject_type), 0)
  ) > 120 then
    raise exception using errcode = '22023', message = 'Audit filter is too long';
  end if;

  return query
  select
    event.organization_id,
    event.id,
    event.event_category,
    event.action,
    event.subject_type,
    event.subject_id,
    event.actor_type,
    event.actor_user_id,
    event.result,
    event.reason,
    event.correlation_id,
    event.command_execution_id,
    event.before_state <> '{}'::jsonb or event.after_state <> '{}'::jsonb,
    event.event_metadata <> '{}'::jsonb,
    event.occurred_at
  from audit.events as event
  where event.organization_id = p_organization_id
    and (p_occurred_from is null or event.occurred_at >= p_occurred_from)
    and (p_occurred_to is null or event.occurred_at <= p_occurred_to)
    and (p_event_category is null or event.event_category = p_event_category)
    and (p_action is null or event.action = p_action)
    and (p_result is null or event.result = p_result)
    and (p_subject_type is null or event.subject_type = p_subject_type)
    and (p_subject_id is null or event.subject_id = p_subject_id)
    and (p_correlation_id is null or event.correlation_id = p_correlation_id)
    and (p_cursor_occurred_at is null
      or (event.occurred_at, event.id) < (p_cursor_occurred_at, p_cursor_event_id))
  order by event.occurred_at desc, event.id desc
  limit p_page_size;
end;
$$;

create or replace function api.search_audit_events(
  p_organization_id uuid,
  p_occurred_from timestamptz default null,
  p_occurred_to timestamptz default null,
  p_event_category text default null,
  p_action text default null,
  p_result text default null,
  p_subject_type text default null,
  p_subject_id uuid default null,
  p_correlation_id uuid default null,
  p_cursor_occurred_at timestamptz default null,
  p_cursor_event_id uuid default null,
  p_page_size integer default 50
)
returns table (
  organization_id uuid, audit_event_id uuid, event_category text, action text,
  subject_type text, subject_id uuid, actor_type text, actor_user_id uuid,
  result text, reason text, correlation_id uuid, command_execution_id uuid,
  has_state_change boolean, has_metadata boolean, occurred_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select * from private.search_audit_events(
    p_organization_id, p_occurred_from, p_occurred_to, p_event_category,
    p_action, p_result, p_subject_type, p_subject_id, p_correlation_id,
    p_cursor_occurred_at, p_cursor_event_id, p_page_size
  )
$$;

revoke all on function private.read_dashboard_summary(uuid, date, date),
  private.read_profit_and_loss(uuid, date, date),
  private.read_trial_balance(uuid, date, date),
  private.read_control_account_reconciliation(uuid, date),
  private.read_liquidity_summary(uuid, date),
  private.list_journal_entries(uuid, date, date, public.journal_status, text, date, bigint, integer),
  private.list_journal_lines(uuid, uuid, smallint, integer),
  private.list_monthly_closes(uuid, text, date, uuid, integer),
  private.list_monthly_close_checklist(uuid, uuid, text),
  private.search_audit_events(uuid, timestamptz, timestamptz, text, text, text, text, uuid, uuid, timestamptz, uuid, integer)
  from public, anon, authenticated;

grant execute on function private.read_dashboard_summary(uuid, date, date),
  private.read_profit_and_loss(uuid, date, date),
  private.read_trial_balance(uuid, date, date),
  private.read_control_account_reconciliation(uuid, date),
  private.read_liquidity_summary(uuid, date),
  private.list_journal_entries(uuid, date, date, public.journal_status, text, date, bigint, integer),
  private.list_journal_lines(uuid, uuid, smallint, integer),
  private.list_monthly_closes(uuid, text, date, uuid, integer),
  private.list_monthly_close_checklist(uuid, uuid, text),
  private.search_audit_events(uuid, timestamptz, timestamptz, text, text, text, text, uuid, uuid, timestamptz, uuid, integer)
  to authenticated;

revoke all on function api.read_dashboard_summary(uuid, date, date),
  api.read_profit_and_loss(uuid, date, date),
  api.read_trial_balance(uuid, date, date),
  api.read_control_account_reconciliation(uuid, date),
  api.read_liquidity_summary(uuid, date),
  api.list_journal_entries(uuid, date, date, public.journal_status, text, date, bigint, integer),
  api.list_journal_lines(uuid, uuid, smallint, integer),
  api.list_monthly_closes(uuid, text, date, uuid, integer),
  api.list_monthly_close_checklist(uuid, uuid, text),
  api.search_audit_events(uuid, timestamptz, timestamptz, text, text, text, text, uuid, uuid, timestamptz, uuid, integer)
  from public, anon, authenticated;

grant execute on function api.read_dashboard_summary(uuid, date, date),
  api.read_profit_and_loss(uuid, date, date),
  api.read_trial_balance(uuid, date, date),
  api.read_control_account_reconciliation(uuid, date),
  api.read_liquidity_summary(uuid, date),
  api.list_journal_entries(uuid, date, date, public.journal_status, text, date, bigint, integer),
  api.list_journal_lines(uuid, uuid, smallint, integer),
  api.list_monthly_closes(uuid, text, date, uuid, integer),
  api.list_monthly_close_checklist(uuid, uuid, text),
  api.search_audit_events(uuid, timestamptz, timestamptz, text, text, text, text, uuid, uuid, timestamptz, uuid, integer)
  to authenticated;

comment on function api.read_dashboard_summary(uuid, date, date) is
  'Permission-scoped dashboard totals from posted EGP ledger lines, current liquidity controls, reconciliations, and operational alert counts.';
comment on function api.read_profit_and_loss(uuid, date, date) is
  'Monthly P&L from posted and reversed journal lines. Customer deposits, wallet transfers, partner funding, withdrawals, and distributions affect P&L only through explicitly mapped revenue/contra-revenue/expense accounts.';
comment on function api.read_trial_balance(uuid, date, date) is
  'Permission-scoped trial balance with explicit opening, activity, and closing debit/credit amounts.';
comment on function api.read_control_account_reconciliation(uuid, date) is
  'Compares effective control-account ledger balances with approved journal-line dimensions; payroll and partner results are aggregate only.';
comment on function api.read_liquidity_summary(uuid, date) is
  'Wallet book balances from posted ledger lines with latest provider reconciliation state; legal-holder and provider reference metadata are omitted.';
comment on function api.list_journal_entries(uuid, date, date, public.journal_status, text, date, bigint, integer) is
  'Keyset-paginated journal headers for ledger readers; request hashes, idempotency keys, command internals, and metadata are omitted.';
comment on function api.list_journal_lines(uuid, uuid, smallint, integer) is
  'Paginated journal lines with approved account and subledger dimensions; unrestricted dimensions JSON is omitted.';
comment on function api.list_monthly_closes(uuid, text, date, uuid, integer) is
  'Keyset-paginated accounting periods and monthly-close computed results, approval state, and reopen metadata.';
comment on function api.list_monthly_close_checklist(uuid, uuid, text) is
  'Monthly-close checklist with top-level attachment paths, URLs, tokens, secrets, and checksums removed from evidence metadata.';
comment on function api.search_audit_events(uuid, timestamptz, timestamptz, text, text, text, text, uuid, uuid, timestamptz, uuid, integer) is
  'Audit-reader-only keyset search. Raw before/after state, event metadata, role payload, IP, user agent, and idempotency references are omitted.';
