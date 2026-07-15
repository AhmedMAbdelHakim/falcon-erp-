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
    wallet.currency::text,
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
