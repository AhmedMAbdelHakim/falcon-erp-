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
  )
  select
    p_organization_id,
    case
      when mapped.role_key like 'wallet_%' then 'wallets'
      when mapped.role_key in ('customer_deposits', 'customer_credits', 'refund_payable') then 'customer_money'
      when mapped.role_key in ('courier_receivables', 'courier_payables') then 'courier'
      when mapped.role_key in ('goods_received_not_invoiced', 'supplier_payables') then 'suppliers'
      when mapped.role_key = 'payroll_payable' then 'payroll'
      when mapped.role_key in ('partner_capital', 'partner_current_accounts', 'partner_loans_payable') then 'partners'
      else 'other'
    end,
    mapped.role_key,
    mapped.id,
    mapped.code,
    mapped.name,
    balance.ledger_balance,
    balance.dimensioned_balance,
    balance.ledger_balance - balance.dimensioned_balance,
    case when balance.ledger_balance = balance.dimensioned_balance then 'reconciled' else 'difference' end,
    'EGP'::text,
    p_as_of_date,
    balance.latest_posted_at,
    statement_timestamp()
  from mapped_accounts as mapped
  cross join lateral (
    select
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
    from accounting.journal_entries as entry
    join accounting.journal_lines as line
      on line.journal_entry_id = entry.id
     and line.account_id = mapped.id
    where entry.organization_id = p_organization_id
      and entry.status in ('posted', 'reversed')
      and entry.accounting_date <= p_as_of_date
  ) as balance
  order by 2, 3;
end;
$$;
