create type public.employee_status as enum ('draft', 'active', 'on_leave', 'terminated', 'inactive');
create type public.employee_kind as enum ('moderator', 'operations', 'finance', 'management', 'other');
create type public.employee_advance_status as enum ('draft', 'approved', 'paid', 'partially_recovered', 'recovered', 'cancelled', 'reversed');
create type public.bonus_review_status as enum ('draft', 'calculated', 'reviewed', 'approved', 'rejected', 'superseded');
create type public.partner_transaction_type as enum ('capital_contribution', 'capital_return', 'current_account_credit', 'current_account_debit');
create type public.partner_loan_status as enum ('draft', 'active', 'partially_repaid', 'repaid', 'cancelled', 'reversed');
create type public.partner_withdrawal_type as enum (
  'available_profit_draw', 'future_profit_advance', 'expense_reimbursement',
  'partner_loan_repayment', 'other_approved'
);
create type public.profit_distribution_status as enum ('draft', 'submitted', 'approved', 'posted', 'cancelled', 'reversed');

create table public.employees (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  profile_id uuid,
  employee_no text not null,
  full_name text not null,
  employee_kind public.employee_kind not null,
  status public.employee_status not null default 'draft',
  hire_date date not null,
  termination_date date,
  payment_recipient_name text,
  payment_recipient_reference text,
  payroll_enabled boolean not null default false,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint employees_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint employees_profile_fk foreign key (profile_id) references public.profiles (id),
  constraint employees_number_not_blank check (btrim(employee_no) <> ''),
  constraint employees_name_not_blank check (btrim(full_name) <> ''),
  constraint employees_termination_date_check check (termination_date is null or termination_date >= hire_date),
  constraint employees_terminated_state_check check (status <> 'terminated' or termination_date is not null),
  constraint employees_version_positive check (version > 0),
  constraint employees_number_unique unique (organization_id, employee_no),
  constraint employees_profile_unique unique (organization_id, profile_id)
);

comment on table public.employees is 'Sensitive employee master data; payroll is disabled until effective compensation policy is approved.';

create table public.employee_compensation_periods (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  employee_id uuid not null,
  effective_from date not null,
  effective_to date,
  base_salary_minor bigint not null,
  currency_code text not null default 'EGP',
  proration_policy_snapshot jsonb not null default '{}'::jsonb,
  final_pay_policy_snapshot jsonb not null default '{}'::jsonb,
  approval_request_id uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint employee_compensation_periods_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint employee_compensation_periods_employee_fk foreign key (employee_id) references public.employees (id),
  constraint employee_compensation_periods_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint employee_compensation_periods_dates_check check (effective_to is null or effective_to > effective_from),
  constraint employee_compensation_periods_salary_nonnegative check (base_salary_minor >= 0),
  constraint employee_compensation_periods_currency_egp check (currency_code = 'EGP'),
  constraint employee_compensation_periods_proration_object check (jsonb_typeof(proration_policy_snapshot) = 'object'),
  constraint employee_compensation_periods_final_pay_object check (jsonb_typeof(final_pay_policy_snapshot) = 'object'),
  constraint employee_compensation_periods_no_overlap exclude using gist (
    employee_id with =,
    daterange(effective_from, coalesce(effective_to, 'infinity'::date), '[)') with &&
  )
);

comment on table public.employee_compensation_periods is 'Approved effective-dated salary and proration policy used to freeze payroll inputs.';

create table public.employee_advances (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  employee_id uuid not null,
  wallet_id uuid,
  request_date date not null,
  paid_date date,
  amount_minor bigint not null,
  recovered_minor bigint not null default 0,
  status public.employee_advance_status not null default 'draft',
  reason text not null,
  approval_request_id uuid,
  journal_entry_id uuid,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint employee_advances_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint employee_advances_employee_fk foreign key (employee_id) references public.employees (id),
  constraint employee_advances_wallet_fk foreign key (wallet_id) references public.wallets (id),
  constraint employee_advances_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint employee_advances_amount_positive check (amount_minor > 0),
  constraint employee_advances_recovery_check check (recovered_minor between 0 and amount_minor),
  constraint employee_advances_reason_not_blank check (btrim(reason) <> ''),
  constraint employee_advances_paid_fields_check check (
    status not in ('paid', 'partially_recovered', 'recovered') or (paid_date is not null and wallet_id is not null and journal_entry_id is not null)
  ),
  constraint employee_advances_version_positive check (version > 0)
);

comment on table public.employee_advances is 'Employee receivables recovered only through approved payroll deductions or explicit repayment.';

create table public.bonus_schemes (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  scheme_code text not null,
  name text not null,
  employee_kind public.employee_kind not null,
  effective_from date not null,
  effective_to date,
  minimum_score_bps integer not null default 6000,
  minimum_bonus_minor bigint not null,
  maximum_bonus_minor bigint not null,
  source_cutoff_policy jsonb not null,
  is_active boolean not null default true,
  approval_request_id uuid,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid,
  constraint bonus_schemes_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint bonus_schemes_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint bonus_schemes_code_not_blank check (btrim(scheme_code) <> ''),
  constraint bonus_schemes_name_not_blank check (btrim(name) <> ''),
  constraint bonus_schemes_dates_check check (effective_to is null or effective_to > effective_from),
  constraint bonus_schemes_score_range check (minimum_score_bps between 0 and 10000),
  constraint bonus_schemes_amount_range check (
    minimum_bonus_minor >= 0 and maximum_bonus_minor >= minimum_bonus_minor
    and (employee_kind <> 'moderator' or (minimum_bonus_minor >= 50000 and maximum_bonus_minor <= 300000))
    and (employee_kind <> 'operations' or (minimum_bonus_minor >= 50000 and maximum_bonus_minor <= 200000))
  ),
  constraint bonus_schemes_cutoff_object check (jsonb_typeof(source_cutoff_policy) = 'object'),
  constraint bonus_schemes_active_requires_approval check (not is_active or approval_request_id is not null),
  constraint bonus_schemes_code_unique unique (organization_id, scheme_code, effective_from),
  constraint bonus_schemes_no_overlap exclude using gist (
    organization_id with =,
    employee_kind with =,
    daterange(effective_from, coalesce(effective_to, 'infinity'::date), '[)') with &&
  ) where (is_active)
);

comment on table public.bonus_schemes is 'Approved effective bonus policy with role-specific Falcon payout caps and cutoff rules.';

create table public.bonus_metrics (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  bonus_scheme_id uuid not null,
  metric_code text not null,
  name text not null,
  weight_bps integer not null,
  source_definition jsonb not null,
  display_order integer not null default 0,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint bonus_metrics_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint bonus_metrics_scheme_fk foreign key (bonus_scheme_id) references public.bonus_schemes (id),
  constraint bonus_metrics_code_not_blank check (btrim(metric_code) <> ''),
  constraint bonus_metrics_name_not_blank check (btrim(name) <> ''),
  constraint bonus_metrics_weight_range check (weight_bps between 0 and 10000),
  constraint bonus_metrics_source_object check (jsonb_typeof(source_definition) = 'object'),
  constraint bonus_metrics_order_nonnegative check (display_order >= 0),
  constraint bonus_metrics_code_unique unique (bonus_scheme_id, metric_code)
);

comment on table public.bonus_metrics is 'Weighted measurable inputs; scheme-level weights are validated by payroll calculation commands.';

create table public.bonus_slabs (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  bonus_scheme_id uuid not null,
  minimum_score_bps integer not null,
  maximum_score_bps integer not null,
  bonus_minor bigint not null,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint bonus_slabs_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint bonus_slabs_scheme_fk foreign key (bonus_scheme_id) references public.bonus_schemes (id),
  constraint bonus_slabs_score_range check (
    minimum_score_bps between 0 and 10000 and maximum_score_bps between minimum_score_bps and 10000
  ),
  constraint bonus_slabs_amount_nonnegative check (bonus_minor >= 0),
  constraint bonus_slabs_no_overlap exclude using gist (
    bonus_scheme_id with =,
    int4range(minimum_score_bps, maximum_score_bps, '[]') with &&
  )
);

comment on table public.bonus_slabs is 'Non-overlapping score bands mapped to fixed minor-unit bonus amounts.';

create table public.employee_performance_reviews (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  employee_id uuid not null,
  bonus_scheme_id uuid not null,
  metric_period_start date not null,
  metric_period_end date not null,
  source_cutoff_at timestamptz not null,
  source_rows_snapshot jsonb not null,
  attribution_snapshot jsonb not null,
  calculated_score_bps integer not null default 0,
  calculated_bonus_minor bigint not null default 0,
  override_bonus_minor bigint,
  final_bonus_minor bigint not null default 0,
  override_reason text,
  override_approved_by uuid,
  override_approved_at timestamptz,
  status public.bonus_review_status not null default 'draft',
  reviewed_by uuid,
  reviewed_at timestamptz,
  approved_by uuid,
  approved_at timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint employee_performance_reviews_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint employee_performance_reviews_employee_fk foreign key (employee_id) references public.employees (id),
  constraint employee_performance_reviews_scheme_fk foreign key (bonus_scheme_id) references public.bonus_schemes (id),
  constraint employee_performance_reviews_period_check check (metric_period_end >= metric_period_start),
  constraint employee_performance_reviews_source_array check (jsonb_typeof(source_rows_snapshot) = 'array'),
  constraint employee_performance_reviews_attribution_object check (jsonb_typeof(attribution_snapshot) = 'object'),
  constraint employee_performance_reviews_score_range check (calculated_score_bps between 0 and 10000),
  constraint employee_performance_reviews_amounts_nonnegative check (
    calculated_bonus_minor >= 0 and final_bonus_minor >= 0
    and (override_bonus_minor is null or override_bonus_minor >= 0)
  ),
  constraint employee_performance_reviews_final_bonus_matches check (
    final_bonus_minor = coalesce(override_bonus_minor, calculated_bonus_minor)
  ),
  constraint employee_performance_reviews_override_controls check (
    override_bonus_minor is null
    or (
      nullif(btrim(override_reason), '') is not null
      and override_approved_by is not null
      and override_approved_at is not null
    )
  ),
  constraint employee_performance_reviews_approval_fields check (
    status <> 'approved' or (approved_by is not null and approved_at is not null)
  ),
  constraint employee_performance_reviews_version_positive check (version > 0),
  constraint employee_performance_reviews_period_unique unique (employee_id, metric_period_start, metric_period_end)
);

comment on table public.employee_performance_reviews is 'Cutoff-stable bonus review snapshot; known returns are excluded before approval.';

create table public.employee_performance_scores (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  employee_performance_review_id uuid not null,
  bonus_metric_id uuid not null,
  raw_value numeric(20, 6),
  score_bps integer not null,
  weight_bps_snapshot integer not null,
  weighted_score_bps integer not null,
  evidence_snapshot jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint employee_performance_scores_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint employee_performance_scores_review_fk foreign key (employee_performance_review_id) references public.employee_performance_reviews (id),
  constraint employee_performance_scores_metric_fk foreign key (bonus_metric_id) references public.bonus_metrics (id),
  constraint employee_performance_scores_score_range check (score_bps between 0 and 10000),
  constraint employee_performance_scores_weight_range check (weight_bps_snapshot between 0 and 10000),
  constraint employee_performance_scores_weighted_matches check (
    weighted_score_bps = ((score_bps::bigint * weight_bps_snapshot::bigint + 5000) / 10000)::integer
  ),
  constraint employee_performance_scores_evidence_array check (jsonb_typeof(evidence_snapshot) = 'array'),
  constraint employee_performance_scores_metric_unique unique (employee_performance_review_id, bonus_metric_id)
);

comment on table public.employee_performance_scores is 'Metric-level bonus evidence with frozen weights and integer half-up contribution.';

create table public.bonus_adjustments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  employee_id uuid not null,
  source_performance_review_id uuid not null,
  source_event_type text not null,
  source_event_id uuid not null,
  amount_minor bigint not null,
  applies_to_period_start date not null,
  reason text not null,
  approval_request_id uuid not null,
  applied_payroll_entry_id uuid,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint bonus_adjustments_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint bonus_adjustments_employee_fk foreign key (employee_id) references public.employees (id),
  constraint bonus_adjustments_review_fk foreign key (source_performance_review_id) references public.employee_performance_reviews (id),
  constraint bonus_adjustments_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint bonus_adjustments_source_type_not_blank check (btrim(source_event_type) <> ''),
  constraint bonus_adjustments_amount_nonzero check (amount_minor <> 0),
  constraint bonus_adjustments_reason_not_blank check (btrim(reason) <> ''),
  constraint bonus_adjustments_source_unique unique (organization_id, source_event_type, source_event_id, employee_id)
);

comment on table public.bonus_adjustments is 'Approved next-period adjustment for facts discovered after a bonus cutoff, including late returns.';

create table public.payroll_periods (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  period_start date not null,
  period_end date not null,
  due_date date not null,
  payment_deadline date not null,
  source_cutoff_at timestamptz not null,
  status public.payroll_status not null default 'draft',
  calculation_policy_snapshot jsonb not null,
  approved_at timestamptz,
  approved_by uuid,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint payroll_periods_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint payroll_periods_start_first_day check (extract(day from period_start) = 1),
  constraint payroll_periods_end_last_day check (period_end = (period_start + interval '1 month' - interval '1 day')::date),
  constraint payroll_periods_due_first_day check (due_date = period_start),
  constraint payroll_periods_deadline_tenth_day check (payment_deadline = period_start + 9),
  constraint payroll_periods_policy_object check (jsonb_typeof(calculation_policy_snapshot) = 'object'),
  constraint payroll_periods_approval_fields check (
    status not in ('approved', 'partially_paid', 'paid', 'overdue') or (approved_at is not null and approved_by is not null)
  ),
  constraint payroll_periods_version_positive check (version > 0),
  constraint payroll_periods_month_unique unique (organization_id, period_start)
);

comment on table public.payroll_periods is 'Cairo payroll month due on day 1, payable through day 10, with frozen calculation policy.';

create table public.payroll_entries (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  payroll_period_id uuid not null,
  employee_id uuid not null,
  employee_performance_review_id uuid,
  status public.payroll_status not null default 'draft',
  base_salary_minor bigint not null,
  bonus_minor bigint not null default 0,
  approved_allowances_minor bigint not null default 0,
  advance_deductions_minor bigint not null default 0,
  approved_deductions_minor bigint not null default 0,
  net_payroll_minor bigint not null,
  paid_minor bigint not null default 0,
  compensation_snapshot jsonb not null,
  bonus_scheme_snapshot jsonb,
  deduction_snapshot jsonb not null default '[]'::jsonb,
  approval_request_id uuid,
  accrual_journal_entry_id uuid,
  approved_at timestamptz,
  approved_by uuid,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint payroll_entries_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint payroll_entries_period_fk foreign key (payroll_period_id) references public.payroll_periods (id),
  constraint payroll_entries_employee_fk foreign key (employee_id) references public.employees (id),
  constraint payroll_entries_review_fk foreign key (employee_performance_review_id) references public.employee_performance_reviews (id),
  constraint payroll_entries_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint payroll_entries_components_nonnegative check (
    base_salary_minor >= 0 and bonus_minor >= 0 and approved_allowances_minor >= 0
    and advance_deductions_minor >= 0 and approved_deductions_minor >= 0
    and net_payroll_minor >= 0 and paid_minor >= 0
  ),
  constraint payroll_entries_formula check (
    net_payroll_minor::numeric = base_salary_minor::numeric + bonus_minor::numeric
      + approved_allowances_minor::numeric - advance_deductions_minor::numeric
      - approved_deductions_minor::numeric
  ),
  constraint payroll_entries_paid_within_net check (paid_minor <= net_payroll_minor),
  constraint payroll_entries_compensation_object check (jsonb_typeof(compensation_snapshot) = 'object'),
  constraint payroll_entries_bonus_object check (bonus_scheme_snapshot is null or jsonb_typeof(bonus_scheme_snapshot) = 'object'),
  constraint payroll_entries_deductions_array check (jsonb_typeof(deduction_snapshot) = 'array'),
  constraint payroll_entries_approval_fields check (
    status not in ('approved', 'partially_paid', 'paid', 'overdue')
    or (approved_at is not null and approved_by is not null and accrual_journal_entry_id is not null)
  ),
  constraint payroll_entries_version_positive check (version > 0),
  constraint payroll_entries_employee_period_unique unique (payroll_period_id, employee_id)
);

comment on table public.payroll_entries is 'Employee payroll accrual snapshot; approval and payment are separate financial events.';

alter table public.bonus_adjustments
  add constraint bonus_adjustments_payroll_entry_fk
  foreign key (applied_payroll_entry_id) references public.payroll_entries (id);

create table public.payroll_payments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  payroll_entry_id uuid not null,
  wallet_id uuid not null,
  amount_minor bigint not null,
  payment_date date not null,
  provider_reference text not null,
  evidence_attachment_id uuid,
  journal_entry_id uuid not null,
  reverses_payroll_payment_id uuid,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint payroll_payments_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint payroll_payments_entry_fk foreign key (payroll_entry_id) references public.payroll_entries (id),
  constraint payroll_payments_wallet_fk foreign key (wallet_id) references public.wallets (id),
  constraint payroll_payments_reversal_fk foreign key (reverses_payroll_payment_id) references public.payroll_payments (id),
  constraint payroll_payments_amount_positive check (amount_minor > 0),
  constraint payroll_payments_reference_not_blank check (btrim(provider_reference) <> ''),
  constraint payroll_payments_not_self_reversal check (reverses_payroll_payment_id is distinct from id)
);

comment on table public.payroll_payments is 'Append-only partial payroll liability payments with required payment reference.';

create table public.partners (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  profile_id uuid,
  partner_code text not null,
  full_name text not null,
  is_active boolean not null default true,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid,
  constraint partners_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint partners_profile_fk foreign key (profile_id) references public.profiles (id),
  constraint partners_code_not_blank check (btrim(partner_code) <> ''),
  constraint partners_name_not_blank check (btrim(full_name) <> ''),
  constraint partners_version_positive check (version > 0),
  constraint partners_code_unique unique (organization_id, partner_code),
  constraint partners_profile_unique unique (organization_id, profile_id)
);

comment on table public.partners is 'Stable partner rows used as the serialization lock for rolling withdrawal evaluation.';

create table public.partner_ownership_periods (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  partner_id uuid not null,
  effective_from date not null,
  effective_to date,
  ownership_bps integer not null,
  profit_share_bps integer not null,
  approval_request_id uuid,
  source_reference text,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid,
  constraint partner_ownership_periods_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint partner_ownership_periods_partner_fk foreign key (partner_id) references public.partners (id),
  constraint partner_ownership_periods_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint partner_ownership_periods_dates_check check (effective_to is null or effective_to > effective_from),
  constraint partner_ownership_periods_ownership_range check (ownership_bps between 0 and 10000),
  constraint partner_ownership_periods_profit_range check (profit_share_bps between 0 and 10000),
  constraint partner_ownership_periods_authority_check check (
    approval_request_id is not null or source_reference = 'phase1_source'
  ),
  constraint partner_ownership_periods_no_overlap exclude using gist (
    partner_id with =,
    daterange(effective_from, coalesce(effective_to, 'infinity'::date), '[)') with &&
  )
);

comment on table public.partner_ownership_periods is 'Approved effective ownership and profit-share percentages; organization totals are command-validated to 10000 bps.';

create table public.partner_capital_transactions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  partner_id uuid not null,
  transaction_type public.partner_transaction_type not null,
  amount_minor bigint not null,
  accounting_date date not null,
  wallet_id uuid,
  reason text not null,
  evidence_attachment_id uuid,
  approval_request_id uuid,
  journal_entry_id uuid not null,
  reverses_capital_transaction_id uuid,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint partner_capital_transactions_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint partner_capital_transactions_partner_fk foreign key (partner_id) references public.partners (id),
  constraint partner_capital_transactions_wallet_fk foreign key (wallet_id) references public.wallets (id),
  constraint partner_capital_transactions_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint partner_capital_transactions_reversal_fk foreign key (reverses_capital_transaction_id) references public.partner_capital_transactions (id),
  constraint partner_capital_transactions_amount_positive check (amount_minor > 0),
  constraint partner_capital_transactions_reason_not_blank check (btrim(reason) <> ''),
  constraint partner_capital_transactions_not_self_reversal check (reverses_capital_transaction_id is distinct from id)
);

comment on table public.partner_capital_transactions is 'Append-only partner capital/current-account movements, kept distinct from operating P&L.';

create table public.partner_loans (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  partner_id uuid not null,
  loan_no text not null,
  direction text not null,
  principal_minor bigint not null,
  repaid_minor bigint not null default 0,
  start_date date not null,
  due_date date,
  status public.partner_loan_status not null default 'draft',
  terms_snapshot jsonb not null,
  approval_request_id uuid,
  journal_entry_id uuid,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint partner_loans_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint partner_loans_partner_fk foreign key (partner_id) references public.partners (id),
  constraint partner_loans_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint partner_loans_number_not_blank check (btrim(loan_no) <> ''),
  constraint partner_loans_direction_check check (direction in ('partner_to_falcon', 'falcon_to_partner')),
  constraint partner_loans_principal_positive check (principal_minor > 0),
  constraint partner_loans_repaid_check check (repaid_minor between 0 and principal_minor),
  constraint partner_loans_due_date_check check (due_date is null or due_date >= start_date),
  constraint partner_loans_terms_object check (jsonb_typeof(terms_snapshot) = 'object'),
  constraint partner_loans_version_positive check (version > 0),
  constraint partner_loans_number_unique unique (organization_id, loan_no)
);

comment on table public.partner_loans is 'Partner loan principal and repayment lifecycle, separate from capital and distributions.';

create table public.partner_withdrawals (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  partner_id uuid not null,
  withdrawal_no text not null,
  withdrawal_type public.partner_withdrawal_type not null,
  status public.withdrawal_status not null default 'draft',
  requested_amount_minor bigint not null,
  rolling_24h_existing_minor bigint not null default 0,
  rolling_24h_total_minor bigint not null,
  approval_threshold_minor bigint not null,
  requires_other_partner_approval boolean not null,
  available_source_balance_minor bigint,
  safe_withdrawal_amount_minor bigint,
  liquidity_snapshot jsonb,
  request_fingerprint text not null,
  requested_at timestamptz not null,
  approval_request_id uuid,
  approved_at timestamptz,
  approved_by_partner_id uuid,
  wallet_id uuid,
  executed_at timestamptz,
  journal_entry_id uuid,
  reason text not null,
  evidence_attachment_id uuid,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint partner_withdrawals_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint partner_withdrawals_partner_fk foreign key (partner_id) references public.partners (id),
  constraint partner_withdrawals_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint partner_withdrawals_approver_partner_fk foreign key (approved_by_partner_id) references public.partners (id),
  constraint partner_withdrawals_wallet_fk foreign key (wallet_id) references public.wallets (id),
  constraint partner_withdrawals_number_not_blank check (btrim(withdrawal_no) <> ''),
  constraint partner_withdrawals_amount_positive check (requested_amount_minor > 0),
  constraint partner_withdrawals_rolling_amounts check (
    rolling_24h_existing_minor >= 0
    and rolling_24h_total_minor = rolling_24h_existing_minor + requested_amount_minor
  ),
  constraint partner_withdrawals_threshold_positive check (approval_threshold_minor > 0),
  constraint partner_withdrawals_approval_requirement_matches check (
    requires_other_partner_approval = (rolling_24h_total_minor > approval_threshold_minor)
  ),
  constraint partner_withdrawals_source_balance_nonnegative check (
    available_source_balance_minor is null or available_source_balance_minor >= 0
  ),
  constraint partner_withdrawals_liquidity_object check (
    liquidity_snapshot is null or jsonb_typeof(liquidity_snapshot) = 'object'
  ),
  constraint partner_withdrawals_fingerprint_not_blank check (btrim(request_fingerprint) <> ''),
  constraint partner_withdrawals_reason_not_blank check (btrim(reason) <> ''),
  constraint partner_withdrawals_other_partner_approval check (
    not requires_other_partner_approval
    or status in ('draft', 'submitted', 'rejected', 'cancelled', 'expired')
    or (
      approval_request_id is not null and approved_by_partner_id is not null
      and approved_by_partner_id <> partner_id and approved_at is not null
    )
  ),
  constraint partner_withdrawals_execution_fields check (
    status not in ('executed', 'reversed')
    or (
      wallet_id is not null and executed_at is not null and journal_entry_id is not null
      and safe_withdrawal_amount_minor is not null
      and safe_withdrawal_amount_minor >= requested_amount_minor
      and liquidity_snapshot is not null
    )
  ),
  constraint partner_withdrawals_version_positive check (version > 0),
  constraint partner_withdrawals_number_unique unique (organization_id, withdrawal_no),
  constraint partner_withdrawals_fingerprint_unique unique (organization_id, partner_id, request_fingerprint)
);

comment on table public.partner_withdrawals is 'Controlled non-P&L withdrawal request with locked rolling-24h and liquidity snapshots.';

create table public.profit_distributions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  monthly_closing_id uuid not null,
  distribution_no text not null,
  purpose text not null default 'monthly_profit_distribution',
  status public.profit_distribution_status not null default 'draft',
  distributable_profit_minor bigint not null,
  approved_distribution_minor bigint not null,
  allocated_minor bigint not null default 0,
  retained_remainder_minor bigint not null default 0,
  ownership_snapshot_at timestamptz not null,
  approval_request_id uuid,
  approved_at timestamptz,
  approved_by uuid,
  journal_entry_id uuid,
  posted_at timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint profit_distributions_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint profit_distributions_approval_fk foreign key (approval_request_id) references public.approval_requests (id),
  constraint profit_distributions_number_not_blank check (btrim(distribution_no) <> ''),
  constraint profit_distributions_purpose_not_blank check (btrim(purpose) <> ''),
  constraint profit_distributions_amounts_nonnegative check (
    distributable_profit_minor >= 0 and approved_distribution_minor > 0
    and allocated_minor >= 0 and retained_remainder_minor >= 0
  ),
  constraint profit_distributions_within_distributable check (
    approved_distribution_minor <= distributable_profit_minor
  ),
  constraint profit_distributions_allocation_balance check (
    allocated_minor + retained_remainder_minor = approved_distribution_minor
  ),
  constraint profit_distributions_approval_fields check (
    status not in ('approved', 'posted') or (approval_request_id is not null and approved_at is not null and approved_by is not null)
  ),
  constraint profit_distributions_posted_fields check (
    status <> 'posted' or (posted_at is not null and journal_entry_id is not null)
  ),
  constraint profit_distributions_version_positive check (version > 0),
  constraint profit_distributions_number_unique unique (organization_id, distribution_no),
  constraint profit_distributions_close_purpose_unique unique (organization_id, monthly_closing_id, purpose)
);

comment on table public.profit_distributions is 'One approved distribution purpose per monthly close; the next accounting migration adds the close FK.';

create table public.profit_distribution_lines (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  profit_distribution_id uuid not null,
  partner_id uuid not null,
  ownership_bps_snapshot integer not null,
  allocation_numerator numeric(30, 0) not null,
  allocated_amount_minor bigint not null,
  created_at timestamptz not null default statement_timestamp(),
  created_by uuid not null,
  updated_at timestamptz not null default statement_timestamp(),
  updated_by uuid not null,
  constraint profit_distribution_lines_organization_fk foreign key (organization_id) references public.organizations (id),
  constraint profit_distribution_lines_distribution_fk foreign key (profit_distribution_id) references public.profit_distributions (id),
  constraint profit_distribution_lines_partner_fk foreign key (partner_id) references public.partners (id),
  constraint profit_distribution_lines_share_range check (ownership_bps_snapshot between 0 and 10000),
  constraint profit_distribution_lines_numerator_nonnegative check (allocation_numerator >= 0),
  constraint profit_distribution_lines_amount_nonnegative check (allocated_amount_minor >= 0),
  constraint profit_distribution_lines_floor_matches check (
    allocated_amount_minor::numeric = trunc(allocation_numerator / 10000)
  ),
  constraint profit_distribution_lines_partner_unique unique (profit_distribution_id, partner_id)
);

comment on table public.profit_distribution_lines is 'Ownership snapshots and floor allocations; indivisible minor-unit remainder stays retained.';

create index employees_profile_idx on public.employees (profile_id) where profile_id is not null;
create index employees_status_kind_idx on public.employees (organization_id, status, employee_kind);
create index employee_compensation_periods_employee_idx on public.employee_compensation_periods (employee_id);
create index employee_compensation_periods_approval_idx on public.employee_compensation_periods (approval_request_id);
create index employee_advances_employee_status_idx on public.employee_advances (employee_id, status);
create index employee_advances_wallet_idx on public.employee_advances (wallet_id) where wallet_id is not null;
create index employee_advances_approval_idx on public.employee_advances (approval_request_id) where approval_request_id is not null;
create index bonus_schemes_approval_idx on public.bonus_schemes (approval_request_id);
create index bonus_schemes_effective_idx on public.bonus_schemes (organization_id, employee_kind, effective_from, effective_to) where is_active;
create index bonus_metrics_scheme_idx on public.bonus_metrics (bonus_scheme_id);
create index bonus_slabs_scheme_idx on public.bonus_slabs (bonus_scheme_id);
create index employee_performance_reviews_employee_idx on public.employee_performance_reviews (employee_id);
create index employee_performance_reviews_scheme_idx on public.employee_performance_reviews (bonus_scheme_id);
create index employee_performance_reviews_status_idx on public.employee_performance_reviews (organization_id, status, metric_period_end);
create index employee_performance_scores_review_idx on public.employee_performance_scores (employee_performance_review_id);
create index employee_performance_scores_metric_idx on public.employee_performance_scores (bonus_metric_id);
create index bonus_adjustments_employee_period_idx on public.bonus_adjustments (employee_id, applies_to_period_start);
create index bonus_adjustments_review_idx on public.bonus_adjustments (source_performance_review_id);
create index bonus_adjustments_approval_idx on public.bonus_adjustments (approval_request_id);
create index bonus_adjustments_payroll_entry_idx on public.bonus_adjustments (applied_payroll_entry_id) where applied_payroll_entry_id is not null;
create index payroll_periods_status_idx on public.payroll_periods (organization_id, status, payment_deadline);
create index payroll_entries_period_idx on public.payroll_entries (payroll_period_id);
create index payroll_entries_employee_idx on public.payroll_entries (employee_id);
create index payroll_entries_review_idx on public.payroll_entries (employee_performance_review_id) where employee_performance_review_id is not null;
create index payroll_entries_approval_idx on public.payroll_entries (approval_request_id) where approval_request_id is not null;
create index payroll_entries_status_idx on public.payroll_entries (organization_id, status);
create index payroll_payments_entry_idx on public.payroll_payments (payroll_entry_id);
create index payroll_payments_wallet_idx on public.payroll_payments (wallet_id);
create unique index payroll_payments_one_reversal_idx on public.payroll_payments (reverses_payroll_payment_id) where reverses_payroll_payment_id is not null;
create index partners_profile_idx on public.partners (profile_id) where profile_id is not null;
create index partner_ownership_periods_partner_idx on public.partner_ownership_periods (partner_id);
create index partner_ownership_periods_approval_idx on public.partner_ownership_periods (approval_request_id);
create index partner_capital_transactions_partner_date_idx on public.partner_capital_transactions (partner_id, accounting_date);
create index partner_capital_transactions_wallet_idx on public.partner_capital_transactions (wallet_id) where wallet_id is not null;
create index partner_capital_transactions_approval_idx on public.partner_capital_transactions (approval_request_id) where approval_request_id is not null;
create unique index partner_capital_transactions_one_reversal_idx on public.partner_capital_transactions (reverses_capital_transaction_id) where reverses_capital_transaction_id is not null;
create index partner_loans_partner_status_idx on public.partner_loans (partner_id, status);
create index partner_loans_approval_idx on public.partner_loans (approval_request_id) where approval_request_id is not null;
create index partner_withdrawals_partner_status_idx on public.partner_withdrawals (partner_id, status);
create index partner_withdrawals_rolling_24h_idx
  on public.partner_withdrawals (partner_id, requested_at)
  where status in ('submitted', 'approved', 'executed');
create index partner_withdrawals_approval_idx on public.partner_withdrawals (approval_request_id) where approval_request_id is not null;
create index partner_withdrawals_approver_idx on public.partner_withdrawals (approved_by_partner_id) where approved_by_partner_id is not null;
create index partner_withdrawals_wallet_idx on public.partner_withdrawals (wallet_id) where wallet_id is not null;
create index profit_distributions_approval_idx on public.profit_distributions (approval_request_id) where approval_request_id is not null;
create index profit_distributions_close_idx on public.profit_distributions (monthly_closing_id);
create index profit_distribution_lines_distribution_idx on public.profit_distribution_lines (profit_distribution_id);
create index profit_distribution_lines_partner_idx on public.profit_distribution_lines (partner_id);

create trigger employees_updated_at before update on public.employees
  for each row execute function private.set_updated_at();
create trigger employee_compensation_periods_updated_at before update on public.employee_compensation_periods
  for each row execute function private.set_updated_at();
create trigger employee_advances_updated_at before update on public.employee_advances
  for each row execute function private.set_updated_at();
create trigger bonus_schemes_updated_at before update on public.bonus_schemes
  for each row execute function private.set_updated_at();
create trigger bonus_metrics_updated_at before update on public.bonus_metrics
  for each row execute function private.set_updated_at();
create trigger bonus_slabs_updated_at before update on public.bonus_slabs
  for each row execute function private.set_updated_at();
create trigger employee_performance_reviews_updated_at before update on public.employee_performance_reviews
  for each row execute function private.set_updated_at();
create trigger employee_performance_scores_updated_at before update on public.employee_performance_scores
  for each row execute function private.set_updated_at();
create trigger bonus_adjustments_updated_at before update on public.bonus_adjustments
  for each row execute function private.set_updated_at();
create trigger payroll_periods_updated_at before update on public.payroll_periods
  for each row execute function private.set_updated_at();
create trigger payroll_entries_updated_at before update on public.payroll_entries
  for each row execute function private.set_updated_at();
create trigger payroll_payments_updated_at before update on public.payroll_payments
  for each row execute function private.set_updated_at();
create trigger partners_updated_at before update on public.partners
  for each row execute function private.set_updated_at();
create trigger partner_ownership_periods_updated_at before update on public.partner_ownership_periods
  for each row execute function private.set_updated_at();
create trigger partner_capital_transactions_updated_at before update on public.partner_capital_transactions
  for each row execute function private.set_updated_at();
create trigger partner_loans_updated_at before update on public.partner_loans
  for each row execute function private.set_updated_at();
create trigger partner_withdrawals_updated_at before update on public.partner_withdrawals
  for each row execute function private.set_updated_at();
create trigger profit_distributions_updated_at before update on public.profit_distributions
  for each row execute function private.set_updated_at();
create trigger profit_distribution_lines_updated_at before update on public.profit_distribution_lines
  for each row execute function private.set_updated_at();

create trigger employee_performance_scores_append_only before update or delete on public.employee_performance_scores
  for each row execute function private.reject_append_only_change();
create trigger bonus_adjustments_append_only before update or delete on public.bonus_adjustments
  for each row execute function private.reject_append_only_change();
create trigger payroll_payments_append_only before update or delete on public.payroll_payments
  for each row execute function private.reject_append_only_change();
create trigger partner_capital_transactions_append_only before update or delete on public.partner_capital_transactions
  for each row execute function private.reject_append_only_change();
create trigger profit_distribution_lines_append_only before update or delete on public.profit_distribution_lines
  for each row execute function private.reject_append_only_change();

alter table public.employees add constraint employees_organization_id_id_key unique (organization_id, id);
alter table public.employee_compensation_periods add constraint employee_compensation_periods_organization_id_id_key unique (organization_id, id);
alter table public.employee_advances add constraint employee_advances_organization_id_id_key unique (organization_id, id);
alter table public.bonus_schemes add constraint bonus_schemes_organization_id_id_key unique (organization_id, id);
alter table public.bonus_metrics add constraint bonus_metrics_organization_id_id_key unique (organization_id, id);
alter table public.bonus_slabs add constraint bonus_slabs_organization_id_id_key unique (organization_id, id);
alter table public.employee_performance_reviews add constraint employee_performance_reviews_organization_id_id_key unique (organization_id, id);
alter table public.employee_performance_scores add constraint employee_performance_scores_organization_id_id_key unique (organization_id, id);
alter table public.bonus_adjustments add constraint bonus_adjustments_organization_id_id_key unique (organization_id, id);
alter table public.payroll_periods add constraint payroll_periods_organization_id_id_key unique (organization_id, id);
alter table public.payroll_entries add constraint payroll_entries_organization_id_id_key unique (organization_id, id);
alter table public.payroll_payments add constraint payroll_payments_organization_id_id_key unique (organization_id, id);
alter table public.partners add constraint partners_organization_id_id_key unique (organization_id, id);
alter table public.partner_ownership_periods add constraint partner_ownership_periods_organization_id_id_key unique (organization_id, id);
alter table public.partner_capital_transactions add constraint partner_capital_transactions_organization_id_id_key unique (organization_id, id);
alter table public.partner_loans add constraint partner_loans_organization_id_id_key unique (organization_id, id);
alter table public.partner_withdrawals add constraint partner_withdrawals_organization_id_id_key unique (organization_id, id);
alter table public.profit_distributions add constraint profit_distributions_organization_id_id_key unique (organization_id, id);
alter table public.profit_distribution_lines add constraint profit_distribution_lines_organization_id_id_key unique (organization_id, id);

alter table public.employees add constraint employees_profile_org_fk
  foreign key (organization_id, profile_id) references public.profiles (organization_id, id);
alter table public.employee_compensation_periods add constraint employee_compensation_periods_employee_org_fk
  foreign key (organization_id, employee_id) references public.employees (organization_id, id);
alter table public.employee_compensation_periods add constraint employee_compensation_periods_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.employee_advances add constraint employee_advances_employee_org_fk
  foreign key (organization_id, employee_id) references public.employees (organization_id, id);
alter table public.employee_advances add constraint employee_advances_wallet_org_fk
  foreign key (organization_id, wallet_id) references public.wallets (organization_id, id);
alter table public.employee_advances add constraint employee_advances_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.bonus_schemes add constraint bonus_schemes_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.bonus_metrics add constraint bonus_metrics_scheme_org_fk
  foreign key (organization_id, bonus_scheme_id) references public.bonus_schemes (organization_id, id);
alter table public.bonus_slabs add constraint bonus_slabs_scheme_org_fk
  foreign key (organization_id, bonus_scheme_id) references public.bonus_schemes (organization_id, id);
alter table public.employee_performance_reviews add constraint employee_performance_reviews_employee_org_fk
  foreign key (organization_id, employee_id) references public.employees (organization_id, id);
alter table public.employee_performance_reviews add constraint employee_performance_reviews_scheme_org_fk
  foreign key (organization_id, bonus_scheme_id) references public.bonus_schemes (organization_id, id);
alter table public.employee_performance_scores add constraint employee_performance_scores_review_org_fk
  foreign key (organization_id, employee_performance_review_id) references public.employee_performance_reviews (organization_id, id);
alter table public.employee_performance_scores add constraint employee_performance_scores_metric_org_fk
  foreign key (organization_id, bonus_metric_id) references public.bonus_metrics (organization_id, id);
alter table public.bonus_adjustments add constraint bonus_adjustments_employee_org_fk
  foreign key (organization_id, employee_id) references public.employees (organization_id, id);
alter table public.bonus_adjustments add constraint bonus_adjustments_review_org_fk
  foreign key (organization_id, source_performance_review_id) references public.employee_performance_reviews (organization_id, id);
alter table public.bonus_adjustments add constraint bonus_adjustments_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.bonus_adjustments add constraint bonus_adjustments_payroll_entry_org_fk
  foreign key (organization_id, applied_payroll_entry_id) references public.payroll_entries (organization_id, id);
alter table public.payroll_entries add constraint payroll_entries_period_org_fk
  foreign key (organization_id, payroll_period_id) references public.payroll_periods (organization_id, id);
alter table public.payroll_entries add constraint payroll_entries_employee_org_fk
  foreign key (organization_id, employee_id) references public.employees (organization_id, id);
alter table public.payroll_entries add constraint payroll_entries_review_org_fk
  foreign key (organization_id, employee_performance_review_id) references public.employee_performance_reviews (organization_id, id);
alter table public.payroll_entries add constraint payroll_entries_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.payroll_payments add constraint payroll_payments_entry_org_fk
  foreign key (organization_id, payroll_entry_id) references public.payroll_entries (organization_id, id);
alter table public.payroll_payments add constraint payroll_payments_wallet_org_fk
  foreign key (organization_id, wallet_id) references public.wallets (organization_id, id);
alter table public.payroll_payments add constraint payroll_payments_reversal_org_fk
  foreign key (organization_id, reverses_payroll_payment_id) references public.payroll_payments (organization_id, id);
alter table public.partners add constraint partners_profile_org_fk
  foreign key (organization_id, profile_id) references public.profiles (organization_id, id);
alter table public.partner_ownership_periods add constraint partner_ownership_periods_partner_org_fk
  foreign key (organization_id, partner_id) references public.partners (organization_id, id);
alter table public.partner_ownership_periods add constraint partner_ownership_periods_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.partner_capital_transactions add constraint partner_capital_transactions_partner_org_fk
  foreign key (organization_id, partner_id) references public.partners (organization_id, id);
alter table public.partner_capital_transactions add constraint partner_capital_transactions_wallet_org_fk
  foreign key (organization_id, wallet_id) references public.wallets (organization_id, id);
alter table public.partner_capital_transactions add constraint partner_capital_transactions_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.partner_capital_transactions add constraint partner_capital_transactions_reversal_org_fk
  foreign key (organization_id, reverses_capital_transaction_id) references public.partner_capital_transactions (organization_id, id);
alter table public.partner_loans add constraint partner_loans_partner_org_fk
  foreign key (organization_id, partner_id) references public.partners (organization_id, id);
alter table public.partner_loans add constraint partner_loans_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.partner_withdrawals add constraint partner_withdrawals_partner_org_fk
  foreign key (organization_id, partner_id) references public.partners (organization_id, id);
alter table public.partner_withdrawals add constraint partner_withdrawals_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.partner_withdrawals add constraint partner_withdrawals_approver_partner_org_fk
  foreign key (organization_id, approved_by_partner_id) references public.partners (organization_id, id);
alter table public.partner_withdrawals add constraint partner_withdrawals_wallet_org_fk
  foreign key (organization_id, wallet_id) references public.wallets (organization_id, id);
alter table public.profit_distributions add constraint profit_distributions_approval_org_fk
  foreign key (organization_id, approval_request_id) references public.approval_requests (organization_id, id);
alter table public.profit_distribution_lines add constraint profit_distribution_lines_distribution_org_fk
  foreign key (organization_id, profit_distribution_id) references public.profit_distributions (organization_id, id);
alter table public.profit_distribution_lines add constraint profit_distribution_lines_partner_org_fk
  foreign key (organization_id, partner_id) references public.partners (organization_id, id);

alter table public.approval_requests add constraint approval_requests_requester_partner_org_fk
  foreign key (organization_id, requester_partner_id)
  references public.partners (organization_id, id) on delete restrict;
alter table public.approval_actions add constraint approval_actions_approver_partner_org_fk
  foreign key (organization_id, approver_partner_id)
  references public.partners (organization_id, id) on delete restrict;

create or replace function private.validate_partner_approval_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requester_partner_id uuid;
begin
  if new.approver_partner_id is not null and not exists (
    select 1 from public.partners as p
    where p.organization_id = new.organization_id
      and p.id = new.approver_partner_id
      and p.profile_id = (select auth.uid())
      and p.is_active
  ) then
    raise exception using errcode = '42501', message = 'APPROVER_PARTNER_IDENTITY_MISMATCH';
  end if;

  select ar.requester_partner_id into v_requester_partner_id
  from public.approval_requests as ar
  where ar.organization_id = new.organization_id and ar.id = new.approval_request_id;

  if v_requester_partner_id is not null and new.approver_partner_id is null then
    raise exception using errcode = '23514', message = 'APPROVER_PARTNER_IDENTITY_REQUIRED';
  end if;
  return new;
end;
$$;

revoke all on function private.validate_partner_approval_identity() from public, anon, authenticated;

create trigger approval_actions_validate_partner_identity
before insert on public.approval_actions
for each row execute function private.validate_partner_approval_identity();
