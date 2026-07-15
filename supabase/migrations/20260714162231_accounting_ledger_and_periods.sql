create table accounting.accounts (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null,
  name text not null,
  account_type text not null,
  normal_balance text not null,
  parent_account_id uuid references accounting.accounts(id) on delete restrict,
  is_control_account boolean not null default false,
  allows_manual_posting boolean not null default true,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint accounts_code_not_blank check (btrim(code) <> ''),
  constraint accounts_name_not_blank check (btrim(name) <> ''),
  constraint accounts_type_valid check (
    account_type in ('asset', 'liability', 'equity', 'revenue', 'contra_revenue', 'expense')
  ),
  constraint accounts_normal_balance_valid check (normal_balance in ('debit', 'credit')),
  constraint accounts_type_normal_balance_consistent check (
    (account_type in ('asset', 'expense', 'contra_revenue') and normal_balance = 'debit')
    or (account_type in ('liability', 'equity', 'revenue') and normal_balance = 'credit')
  ),
  constraint accounts_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint accounts_parent_same_org_fk foreign key (organization_id, parent_account_id)
    references accounting.accounts(organization_id, id) on delete restrict,
  unique (organization_id, code),
  unique (organization_id, id)
);

comment on table accounting.accounts is 'Organization chart of accounts. Posted journal lines are the authoritative balance source.';
comment on column accounting.accounts.code is 'Stable organization-local account code.';
comment on column accounting.accounts.allows_manual_posting is 'False for headers and control accounts that may only be used by mapped business commands.';

create index accounts_parent_account_id_idx
  on accounting.accounts (parent_account_id)
  where parent_account_id is not null;
create index accounts_org_active_type_idx
  on accounting.accounts (organization_id, account_type, code)
  where is_active;

create trigger accounts_set_updated_at
before update on accounting.accounts
for each row execute function private.set_updated_at();

create table accounting.account_roles (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  role_key text not null,
  description text not null,
  expected_account_type text,
  is_required_for_close boolean not null default false,
  created_at timestamptz not null default statement_timestamp(),
  constraint account_roles_key_valid check (role_key ~ '^[a-z][a-z0-9_]*$'),
  constraint account_roles_description_not_blank check (btrim(description) <> ''),
  constraint account_roles_expected_type_valid check (
    expected_account_type is null
    or expected_account_type in ('asset', 'liability', 'equity', 'revenue', 'contra_revenue', 'expense')
  ),
  unique (organization_id, role_key),
  unique (organization_id, id)
);

comment on table accounting.account_roles is 'Semantic posting roles used by business commands instead of hard-coded account IDs.';

create table accounting.account_role_mappings (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  account_role_id uuid not null,
  account_id uuid not null,
  valid_from date not null,
  valid_to date,
  created_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  metadata jsonb not null default '{}'::jsonb,
  effective_range daterange generated always as (
    daterange(valid_from, coalesce(valid_to, 'infinity'::date), '[)')
  ) stored,
  constraint account_role_mappings_dates_valid check (valid_to is null or valid_to > valid_from),
  constraint account_role_mappings_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint account_role_mappings_role_fk foreign key (organization_id, account_role_id)
    references accounting.account_roles(organization_id, id) on delete restrict,
  constraint account_role_mappings_account_fk foreign key (organization_id, account_id)
    references accounting.accounts(organization_id, id) on delete restrict,
  constraint account_role_mappings_no_overlap exclude using gist (
    organization_id with =,
    account_role_id with =,
    effective_range with &&
  )
);

comment on table accounting.account_role_mappings is 'Effective-dated mapping from semantic account role to one ledger account.';

create index account_role_mappings_account_id_idx
  on accounting.account_role_mappings (account_id);
create index account_role_mappings_current_idx
  on accounting.account_role_mappings (organization_id, account_role_id, valid_from, valid_to);

create table accounting.accounting_periods (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  status public.accounting_period_status not null default 'open',
  close_requested_by uuid references auth.users(id) on delete restrict,
  close_requested_at timestamptz,
  closed_by uuid references auth.users(id) on delete restrict,
  closed_at timestamptz,
  reopen_reason text,
  reopened_by uuid references auth.users(id) on delete restrict,
  reopened_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  period_range daterange generated always as (daterange(period_start, period_end, '[]')) stored,
  constraint accounting_periods_dates_valid check (period_end >= period_start),
  constraint accounting_periods_month_bounds check (
    period_start = date_trunc('month', period_start)::date
    and period_end = (date_trunc('month', period_start) + interval '1 month - 1 day')::date
  ),
  constraint accounting_periods_close_metadata_consistent check (
    (status <> 'closed' and closed_at is null and closed_by is null)
    or (status = 'closed' and closed_at is not null and closed_by is not null)
  ),
  constraint accounting_periods_reopen_metadata_consistent check (
    status <> 'reopened_exceptionally'
    or (reopened_at is not null and reopened_by is not null and btrim(coalesce(reopen_reason, '')) <> '')
  ),
  constraint accounting_periods_no_overlap exclude using gist (
    organization_id with =,
    period_range with &&
  ),
  unique (organization_id, period_start),
  unique (organization_id, id)
);

comment on table accounting.accounting_periods is 'Cairo accounting months. All posting and close commands lock this same row before checking status.';

create index accounting_periods_org_status_idx
  on accounting.accounting_periods (organization_id, status, period_start);

create trigger accounting_periods_set_updated_at
before update on accounting.accounting_periods
for each row execute function private.set_updated_at();

create table accounting.journal_entries (
  id uuid primary key default extensions.gen_random_uuid(),
  entry_number bigint generated always as identity,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  accounting_period_id uuid not null,
  status public.journal_status not null default 'draft',
  posting_date timestamptz not null default statement_timestamp(),
  accounting_date date not null,
  description text not null,
  source_type text not null,
  source_id uuid not null,
  posting_purpose text not null,
  currency_code text not null default 'EGP',
  total_debit_minor bigint not null default 0,
  total_credit_minor bigint not null default 0,
  idempotency_key text not null,
  request_hash text not null,
  request_hash_version smallint not null default 1,
  correlation_id uuid not null,
  command_execution_id uuid,
  approval_request_id uuid,
  created_by uuid not null references auth.users(id) on delete restrict,
  approved_by uuid references auth.users(id) on delete restrict,
  posted_by uuid references auth.users(id) on delete restrict,
  posted_at timestamptz,
  reversal_of uuid references accounting.journal_entries(id) on delete restrict,
  reversed_by_entry_id uuid references accounting.journal_entries(id) on delete restrict,
  reversal_reason text,
  corrects_entry_id uuid references accounting.journal_entries(id) on delete restrict,
  affected_closed_period_id uuid references accounting.accounting_periods(id) on delete restrict,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint journal_entries_period_fk foreign key (organization_id, accounting_period_id)
    references accounting.accounting_periods(organization_id, id) on delete restrict,
  constraint journal_entries_command_execution_fk foreign key (organization_id, command_execution_id)
    references private.command_executions(organization_id, id) on delete restrict,
  constraint journal_entries_approval_request_fk foreign key (organization_id, approval_request_id)
    references public.approval_requests(organization_id, id) on delete restrict,
  constraint journal_entries_reversal_same_org_fk foreign key (organization_id, reversal_of)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  constraint journal_entries_reversed_by_same_org_fk foreign key (organization_id, reversed_by_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  constraint journal_entries_corrects_same_org_fk foreign key (organization_id, corrects_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  constraint journal_entries_affected_period_same_org_fk foreign key (organization_id, affected_closed_period_id)
    references accounting.accounting_periods(organization_id, id) on delete restrict,
  constraint journal_entries_description_not_blank check (btrim(description) <> ''),
  constraint journal_entries_source_type_valid check (source_type ~ '^[a-z][a-z0-9_]*$'),
  constraint journal_entries_posting_purpose_valid check (posting_purpose ~ '^[a-z][a-z0-9_]*$'),
  constraint journal_entries_currency_egp check (currency_code = 'EGP'),
  constraint journal_entries_totals_nonnegative check (total_debit_minor >= 0 and total_credit_minor >= 0),
  constraint journal_entries_request_hash_not_blank check (btrim(request_hash) <> ''),
  constraint journal_entries_idempotency_key_not_blank check (btrim(idempotency_key) <> ''),
  constraint journal_entries_hash_version_positive check (request_hash_version > 0),
  constraint journal_entries_posted_metadata_consistent check (
    (status = 'draft' and posted_at is null and posted_by is null)
    or (status in ('posted', 'reversed') and posted_at is not null and posted_by is not null
        and total_debit_minor > 0 and total_debit_minor = total_credit_minor)
  ),
  constraint journal_entries_reversal_consistent check (
    (reversal_of is null and reversal_reason is null)
    or (reversal_of is not null and btrim(coalesce(reversal_reason, '')) <> '')
  ),
  constraint journal_entries_not_self_referential check (
    reversal_of is distinct from id
    and reversed_by_entry_id is distinct from id
    and corrects_entry_id is distinct from id
  ),
  constraint journal_entries_metadata_object check (jsonb_typeof(metadata) = 'object'),
  unique (organization_id, entry_number),
  unique (organization_id, idempotency_key, posting_purpose),
  unique (organization_id, source_type, source_id, posting_purpose),
  unique (organization_id, id)
);

comment on table accounting.journal_entries is 'Double-entry journal headers. Posted and reversed rows are immutable except for the guarded original-to-reversal link.';
comment on column accounting.journal_entries.accounting_date is 'Business accounting date; posting commands validate it against the locked Cairo period.';
comment on column accounting.journal_entries.affected_closed_period_id is 'Optional historical period referenced by a current-period adjusting entry; that period is never mutated.';

create unique index journal_entries_one_reversal_per_original_idx
  on accounting.journal_entries (reversal_of)
  where reversal_of is not null;
create index journal_entries_period_status_idx
  on accounting.journal_entries (accounting_period_id, status, accounting_date);
create index journal_entries_source_idx
  on accounting.journal_entries (organization_id, source_type, source_id);
create index journal_entries_correlation_idx
  on accounting.journal_entries (correlation_id);
create index journal_entries_command_execution_idx
  on accounting.journal_entries (command_execution_id)
  where command_execution_id is not null;
create index journal_entries_approval_request_idx
  on accounting.journal_entries (approval_request_id)
  where approval_request_id is not null;
create index journal_entries_reversed_by_idx
  on accounting.journal_entries (reversed_by_entry_id)
  where reversed_by_entry_id is not null;
create index journal_entries_corrects_idx
  on accounting.journal_entries (corrects_entry_id)
  where corrects_entry_id is not null;

create trigger journal_entries_set_updated_at
before update on accounting.journal_entries
for each row execute function private.set_updated_at();

create table accounting.journal_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  journal_entry_id uuid not null references accounting.journal_entries(id) on delete restrict,
  line_number smallint not null,
  account_id uuid not null references accounting.accounts(id) on delete restrict,
  debit_minor bigint not null default 0,
  credit_minor bigint not null default 0,
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
  print_batch_id uuid,
  dimensions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default statement_timestamp(),
  constraint journal_lines_line_number_positive check (line_number > 0),
  constraint journal_lines_one_sided_positive check (
    (debit_minor > 0 and credit_minor = 0)
    or (credit_minor > 0 and debit_minor = 0)
  ),
  constraint journal_lines_subledger_pair check (
    (subledger_type is null) = (subledger_id is null)
  ),
  constraint journal_lines_dimensions_object check (jsonb_typeof(dimensions) = 'object'),
  unique (journal_entry_id, line_number)
);

comment on table accounting.journal_lines is 'One-sided positive debit/credit lines in EGP minor units. Aggregate balance is enforced at deferred constraint time and posting.';

create index journal_lines_account_entry_idx
  on accounting.journal_lines (account_id, journal_entry_id);
create index journal_lines_subledger_idx
  on accounting.journal_lines (subledger_type, subledger_id)
  where subledger_id is not null;
create index journal_lines_order_idx on accounting.journal_lines (order_id) where order_id is not null;
create index journal_lines_customer_idx on accounting.journal_lines (customer_id) where customer_id is not null;
create index journal_lines_supplier_idx on accounting.journal_lines (supplier_id) where supplier_id is not null;
create index journal_lines_employee_idx on accounting.journal_lines (employee_id) where employee_id is not null;
create index journal_lines_partner_idx on accounting.journal_lines (partner_id) where partner_id is not null;
create index journal_lines_wallet_idx on accounting.journal_lines (wallet_id) where wallet_id is not null;
create index journal_lines_shipment_idx on accounting.journal_lines (shipment_id) where shipment_id is not null;
create index journal_lines_print_batch_idx on accounting.journal_lines (print_batch_id) where print_batch_id is not null;

create table accounting.posting_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  source_type text not null,
  source_id uuid not null,
  posting_purpose text not null,
  journal_entry_id uuid not null,
  command_type text not null,
  command_execution_id uuid,
  idempotency_key text not null,
  request_hash text not null,
  correlation_id uuid not null,
  posted_by uuid not null references auth.users(id) on delete restrict,
  posted_at timestamptz not null default statement_timestamp(),
  metadata jsonb not null default '{}'::jsonb,
  constraint posting_events_entry_fk foreign key (organization_id, journal_entry_id)
    references accounting.journal_entries(organization_id, id) on delete restrict,
  constraint posting_events_command_execution_fk foreign key (organization_id, command_execution_id)
    references private.command_executions(organization_id, id) on delete restrict,
  constraint posting_events_source_type_valid check (source_type ~ '^[a-z][a-z0-9_]*$'),
  constraint posting_events_purpose_valid check (posting_purpose ~ '^[a-z][a-z0-9_]*$'),
  constraint posting_events_command_type_valid check (command_type ~ '^[a-z][a-z0-9_.]*$'),
  constraint posting_events_idempotency_not_blank check (btrim(idempotency_key) <> ''),
  constraint posting_events_request_hash_not_blank check (btrim(request_hash) <> ''),
  constraint posting_events_metadata_object check (jsonb_typeof(metadata) = 'object'),
  unique (organization_id, source_type, source_id, posting_purpose),
  unique (journal_entry_id)
);

comment on table accounting.posting_events is 'Immutable source-purpose claim providing a second duplicate-posting guard beyond command idempotency.';

create index posting_events_command_execution_idx
  on accounting.posting_events (command_execution_id)
  where command_execution_id is not null;
create index posting_events_correlation_idx
  on accounting.posting_events (correlation_id);

create table accounting.monthly_closings (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  accounting_period_id uuid not null,
  status text not null default 'draft',
  checklist_version smallint not null default 1,
  trial_balance_debit_minor bigint,
  trial_balance_credit_minor bigint,
  period_revenue_minor bigint,
  period_expense_minor bigint,
  period_profit_loss_minor bigint,
  cumulative_profit_loss_minor bigint,
  prior_distributions_minor bigint,
  protected_reserve_minor bigint,
  distributable_profit_minor bigint,
  settings_snapshot jsonb not null default '{}'::jsonb,
  reconciliation_snapshot jsonb not null default '{}'::jsonb,
  validation_result jsonb not null default '{}'::jsonb,
  requested_by uuid not null references auth.users(id) on delete restrict,
  requested_at timestamptz not null default statement_timestamp(),
  validated_by uuid references auth.users(id) on delete restrict,
  validated_at timestamptz,
  closed_by uuid references auth.users(id) on delete restrict,
  closed_at timestamptz,
  approval_request_id uuid,
  correlation_id uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint monthly_closings_period_fk foreign key (organization_id, accounting_period_id)
    references accounting.accounting_periods(organization_id, id) on delete restrict,
  constraint monthly_closings_approval_request_fk foreign key (organization_id, approval_request_id)
    references public.approval_requests(organization_id, id) on delete restrict,
  constraint monthly_closings_status_valid check (status in ('draft', 'validating', 'ready', 'closed', 'cancelled')),
  constraint monthly_closings_checklist_version_positive check (checklist_version > 0),
  constraint monthly_closings_trial_balance_nonnegative check (
    (trial_balance_debit_minor is null or trial_balance_debit_minor >= 0)
    and (trial_balance_credit_minor is null or trial_balance_credit_minor >= 0)
  ),
  constraint monthly_closings_snapshot_objects check (
    jsonb_typeof(settings_snapshot) = 'object'
    and jsonb_typeof(reconciliation_snapshot) = 'object'
    and jsonb_typeof(validation_result) = 'object'
  ),
  constraint monthly_closings_closed_metadata check (
    status <> 'closed' or (closed_at is not null and closed_by is not null)
  ),
  unique (organization_id, accounting_period_id),
  unique (organization_id, id)
);

comment on table accounting.monthly_closings is 'Immutable-at-close snapshot of reconciliations, policy inputs, period result, cumulative losses, prior distributions, reserves, and approvals.';

create index monthly_closings_status_idx
  on accounting.monthly_closings (organization_id, status, requested_at);
create index monthly_closings_approval_idx
  on accounting.monthly_closings (approval_request_id)
  where approval_request_id is not null;

create trigger monthly_closings_set_updated_at
before update on accounting.monthly_closings
for each row execute function private.set_updated_at();

create table accounting.closing_checklist_items (
  id uuid primary key default extensions.gen_random_uuid(),
  monthly_closing_id uuid not null references accounting.monthly_closings(id) on delete restrict,
  item_key text not null,
  status text not null default 'pending',
  is_blocking boolean not null default true,
  expected_minor bigint,
  actual_minor bigint,
  difference_minor bigint generated always as (
    case when expected_minor is null or actual_minor is null then null else actual_minor - expected_minor end
  ) stored,
  evidence jsonb not null default '{}'::jsonb,
  notes text,
  checked_by uuid references auth.users(id) on delete restrict,
  checked_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint closing_checklist_items_key_valid check (item_key ~ '^[a-z][a-z0-9_]*$'),
  constraint closing_checklist_items_status_valid check (status in ('pending', 'passed', 'failed', 'waived')),
  constraint closing_checklist_items_evidence_object check (jsonb_typeof(evidence) = 'object'),
  constraint closing_checklist_items_checked_metadata check (
    status = 'pending' or (checked_at is not null and checked_by is not null)
  ),
  unique (monthly_closing_id, item_key)
);

comment on table accounting.closing_checklist_items is 'Close controls. A blocking item must pass; waivers remain visible and require the surrounding approved close workflow.';

create index closing_checklist_items_open_idx
  on accounting.closing_checklist_items (monthly_closing_id, status, is_blocking)
  where status <> 'passed';

create trigger closing_checklist_items_set_updated_at
before update on accounting.closing_checklist_items
for each row execute function private.set_updated_at();

alter table public.profit_distributions
  add constraint profit_distributions_monthly_closing_fk
  foreign key (organization_id, monthly_closing_id)
  references accounting.monthly_closings(organization_id, id) on delete restrict;

create index profit_distributions_monthly_closing_idx
  on public.profit_distributions (monthly_closing_id);

alter table accounting.accounts enable row level security;
alter table accounting.account_roles enable row level security;
alter table accounting.account_role_mappings enable row level security;
alter table accounting.accounting_periods enable row level security;
alter table accounting.journal_entries enable row level security;
alter table accounting.journal_lines enable row level security;
alter table accounting.posting_events enable row level security;
alter table accounting.monthly_closings enable row level security;
alter table accounting.closing_checklist_items enable row level security;

revoke all on all tables in schema accounting from public, anon, authenticated;
