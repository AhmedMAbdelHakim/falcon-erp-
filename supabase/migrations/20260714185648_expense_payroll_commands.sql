-- Expense and payroll payable workflows with server-derived posting amounts.

alter table public.payroll_periods
  add column approval_request_id uuid,
  add constraint payroll_periods_approval_request_fk
    foreign key (organization_id, approval_request_id)
    references public.approval_requests(organization_id, id) on delete restrict;

create or replace function private.command_record_expense(
  p_organization_id uuid,p_expense_number text,p_expense_category_id uuid,
  p_business_date date,p_due_date date,p_description text,p_subtotal_minor bigint,
  p_tax_minor bigint,p_payable_name_snapshot text,p_evidence_attachment_id uuid,
  p_idempotency_key text,p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_claim record;v_expense_id uuid;v_approval_id uuid;v_approval_fp text;v_result jsonb;v_sqlstate text;
v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'expense_number',p_expense_number,'expense_category_id',p_expense_category_id,'business_date',p_business_date,'due_date',p_due_date,'description',p_description,'subtotal_minor',p_subtotal_minor,'tax_minor',p_tax_minor,'payable_name_snapshot',p_payable_name_snapshot,'evidence_attachment_id',p_evidence_attachment_id);
begin
 perform private.require_permission(p_organization_id,'expenses.create');
 perform private.assert_request_fingerprint('expenses.record',v_payload,p_request_fingerprint,1::smallint);
 if p_subtotal_minor<0 or p_tax_minor<0 or p_subtotal_minor+p_tax_minor<=0 or nullif(btrim(p_description),'') is null then raise exception using errcode='22023',message='INVALID_EXPENSE';end if;
 select * into v_claim from private.claim_command(p_organization_id,'expenses.record',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);
 if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
 begin
  if not exists(select 1 from public.expense_categories c where c.organization_id=p_organization_id and c.id=p_expense_category_id and c.is_active) then raise exception using errcode='23503',message='EXPENSE_CATEGORY_INVALID';end if;
  insert into public.expenses(organization_id,expense_no,expense_category_id,business_date,due_date,status,description,subtotal_minor,tax_minor,total_minor,payable_counterparty_type,payable_name_snapshot,evidence_required,evidence_attachment_id,created_by,updated_by)
  select p_organization_id,p_expense_number,p_expense_category_id,p_business_date,p_due_date,'submitted',p_description,p_subtotal_minor,p_tax_minor,p_subtotal_minor+p_tax_minor,case when p_payable_name_snapshot is null then null else 'named_payee' end,p_payable_name_snapshot,c.requires_evidence,p_evidence_attachment_id,auth.uid(),auth.uid()
  from public.expense_categories c where c.id=p_expense_category_id returning id into v_expense_id;
  v_approval_fp:=encode(extensions.digest(convert_to(v_payload::text,'UTF8'),'sha256'),'hex');
  v_approval_id:=private.command_submit_approval_request(p_organization_id,'expense.approve','expense',v_expense_id,'expenses.approve',p_description,v_payload,v_approval_fp,p_subtotal_minor+p_tax_minor,null,statement_timestamp()+interval '14 days');
  update public.expenses set approval_request_id=v_approval_id where id=v_expense_id;
  v_result:=private.command_success_response(v_claim.command_execution_id,v_expense_id,'submitted','expense.recorded','[]'::jsonb,jsonb_build_object('approval_request_id',v_approval_id));
  perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
 exception when others then
  v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate) then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'expenses.record','expense',null,p_idempotency_key,p_correlation_id);end if;
  perform private.complete_command_failure(v_claim.command_execution_id,'EXPENSE_RECORD_REJECTED',null);return private.command_replay_response('failed_terminal',null,'EXPENSE_RECORD_REJECTED',v_claim.command_execution_id);
 end;
end;$$;

create or replace function private.command_approve_expense(p_organization_id uuid,p_expense_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_claim record;v_expense public.expenses;v_ar public.approval_requests;v_journal uuid;v_result jsonb;v_sqlstate text;
v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'expense_id',p_expense_id);
begin
 perform private.require_permission(p_organization_id,'expenses.approve');perform private.assert_request_fingerprint('expenses.approve',v_payload,p_request_fingerprint,1::smallint);
 select * into v_claim from private.claim_command(p_organization_id,'expenses.approve',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
 begin
  select e.* into strict v_expense from public.expenses e where e.organization_id=p_organization_id and e.id=p_expense_id for update;
  if v_expense.status<>'submitted' or v_expense.created_by=auth.uid() then raise exception using errcode='42501',message='EXPENSE_APPROVAL_SOD_OR_STATE_INVALID';end if;
  select ar.* into strict v_ar from public.approval_requests ar where ar.id=v_expense.approval_request_id;
  perform private.consume_approval(p_organization_id,v_ar.id,'expense.approve','expense',v_expense.id,v_ar.subject_fingerprint,v_claim.command_execution_id,v_expense.total_minor);
  v_journal:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'expense',p_source_id=>v_expense.id,p_posting_purpose=>'approval',p_description=>'Approve operating expense',p_lines=>jsonb_build_array(
   jsonb_build_object('account_role','operating_expenses','debit_minor',v_expense.total_minor::text,'credit_minor','0','order_id',v_expense.order_id,'subledger_type','expense','subledger_id',v_expense.id),
   jsonb_build_object('account_role','expense_payable','debit_minor','0','credit_minor',v_expense.total_minor::text,'order_id',v_expense.order_id,'subledger_type','expense','subledger_id',v_expense.id)),p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_approval_request_id=>v_ar.id,p_command_type=>'expenses.approve',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);
  update public.expenses set status='approved',journal_entry_id=v_journal,version=version+1 where id=v_expense.id;
  v_result:=private.command_success_response(v_claim.command_execution_id,v_expense.id,'approved','expense.approved',jsonb_build_array(v_journal));perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
 exception when others then v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate) then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'expenses.approve','expense',p_expense_id,p_idempotency_key,p_correlation_id);end if;perform private.complete_command_failure(v_claim.command_execution_id,'EXPENSE_APPROVAL_REJECTED',null);return private.command_replay_response('failed_terminal',null,'EXPENSE_APPROVAL_REJECTED',v_claim.command_execution_id);end;
end;$$;

create or replace function private.command_pay_expense(p_organization_id uuid,p_expense_id uuid,p_wallet_id uuid,p_provider_reference text,p_evidence_attachment_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_claim record;v_expense public.expenses;v_wallet public.wallets;v_amount bigint;v_payment uuid;v_journal uuid;v_result jsonb;v_sqlstate text;
v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'expense_id',p_expense_id,'wallet_id',p_wallet_id,'provider_reference',p_provider_reference,'evidence_attachment_id',p_evidence_attachment_id);
begin
 perform private.require_permission(p_organization_id,'expenses.pay');perform private.assert_request_fingerprint('expenses.pay',v_payload,p_request_fingerprint,1::smallint);
 select * into v_claim from private.claim_command(p_organization_id,'expenses.pay',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
 begin
  select e.* into strict v_expense from public.expenses e where e.organization_id=p_organization_id and e.id=p_expense_id for update;select w.* into strict v_wallet from public.wallets w where w.organization_id=p_organization_id and w.id=p_wallet_id and w.is_active for update;
  if v_expense.status not in('approved','partially_paid') then raise exception using errcode='55000',message='EXPENSE_NOT_PAYABLE';end if;v_amount:=v_expense.total_minor-v_expense.paid_minor;if v_amount<=0 then raise exception using errcode='55000',message='EXPENSE_ALREADY_PAID';end if;
  insert into public.expense_payments(organization_id,expense_id,wallet_id,amount_minor,payment_date,provider_reference,evidence_attachment_id,created_by,updated_by) values(p_organization_id,v_expense.id,v_wallet.id,v_amount,private.cairo_accounting_date(),p_provider_reference,p_evidence_attachment_id,auth.uid(),auth.uid()) returning id into v_payment;
  v_journal:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'expense_payment',p_source_id=>v_payment,p_posting_purpose=>'payment',p_description=>'Pay approved expense',p_lines=>jsonb_build_array(
   jsonb_build_object('account_role','expense_payable','debit_minor',v_amount::text,'credit_minor','0','subledger_type','expense','subledger_id',v_expense.id),
   jsonb_build_object('account_role','wallet_'||lower(regexp_replace(v_wallet.code,'[^a-zA-Z0-9]+','_','g')),'debit_minor','0','credit_minor',v_amount::text,'wallet_id',v_wallet.id,'subledger_type','expense_payment','subledger_id',v_payment)),p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_command_type=>'expenses.pay',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);
  update public.expense_payments set journal_entry_id=v_journal where id=v_payment;update public.expenses set paid_minor=total_minor,status='paid',version=version+1 where id=v_expense.id;
  v_result:=private.command_success_response(v_claim.command_execution_id,v_payment,'paid','expense.paid',jsonb_build_array(v_journal),jsonb_build_object('expense_id',v_expense.id,'amount_minor',v_amount));perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
 exception when others then v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate) then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'expenses.pay','expense',p_expense_id,p_idempotency_key,p_correlation_id);end if;perform private.complete_command_failure(v_claim.command_execution_id,'EXPENSE_PAYMENT_REJECTED',null);return private.command_replay_response('failed_terminal',null,'EXPENSE_PAYMENT_REJECTED',v_claim.command_execution_id);end;
end;$$;

create or replace function private.command_calculate_payroll_period(p_organization_id uuid,p_period_start date,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_claim record;v_period uuid;v_approval uuid;v_total bigint;v_count integer;v_approval_payload jsonb;v_approval_fp text;v_result jsonb;v_sqlstate text;
v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'period_start',p_period_start);
begin
 perform private.require_permission(p_organization_id,'payroll.calculate');perform private.assert_request_fingerprint('payroll.calculate',v_payload,p_request_fingerprint,1::smallint);
 if extract(day from p_period_start)<>1 then raise exception using errcode='22023',message='PAYROLL_PERIOD_MUST_START_FIRST_DAY';end if;
 select * into v_claim from private.claim_command(p_organization_id,'payroll.calculate',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
 begin
  insert into public.payroll_periods(organization_id,period_start,period_end,due_date,payment_deadline,source_cutoff_at,status,calculation_policy_snapshot,created_by,updated_by)
  values(p_organization_id,p_period_start,(p_period_start+interval '1 month-1 day')::date,p_period_start,p_period_start+9,statement_timestamp(),'calculated',jsonb_build_object('source','effective_compensation','calculated_at',statement_timestamp()),auth.uid(),auth.uid()) returning id into v_period;
  insert into public.payroll_entries(organization_id,payroll_period_id,employee_id,status,base_salary_minor,bonus_minor,approved_allowances_minor,advance_deductions_minor,approved_deductions_minor,net_payroll_minor,compensation_snapshot,bonus_scheme_snapshot,deduction_snapshot,created_by,updated_by)
  select p_organization_id,v_period,e.id,'calculated',c.base_salary_minor,0,0,0,0,c.base_salary_minor,
    jsonb_build_object('compensation_period_id',c.id,'base_salary_minor',c.base_salary_minor,'proration_policy',c.proration_policy_snapshot,'final_pay_policy',c.final_pay_policy_snapshot),null,'[]'::jsonb,auth.uid(),auth.uid()
  from public.employees e join public.employee_compensation_periods c on c.organization_id=e.organization_id and c.employee_id=e.id
  where e.organization_id=p_organization_id and e.payroll_enabled and e.status in('active','on_leave') and c.effective_from<=p_period_start and (c.effective_to is null or c.effective_to>=p_period_start);
  select coalesce(sum(net_payroll_minor),0),count(*) into v_total,v_count from public.payroll_entries where payroll_period_id=v_period;
  if v_count=0 or v_total<=0 then raise exception using errcode='23514',message='NO_ELIGIBLE_PAYROLL_ENTRIES';end if;
  v_approval_payload:=jsonb_build_object('organization_id',p_organization_id,'payroll_period_id',v_period,'total_payroll_minor',v_total,'entry_count',v_count);
  v_approval_fp:=encode(extensions.digest(convert_to(v_approval_payload::text,'UTF8'),'sha256'),'hex');
  v_approval:=private.command_submit_approval_request(p_organization_id,'payroll.approve','payroll_period',v_period,'payroll.approve','Approve server-calculated payroll',v_approval_payload,v_approval_fp,v_total,null,statement_timestamp()+interval '14 days');
  update public.payroll_periods set approval_request_id=v_approval where id=v_period;update public.payroll_entries set approval_request_id=v_approval where payroll_period_id=v_period;
  v_result:=private.command_success_response(v_claim.command_execution_id,v_period,'calculated','payroll.calculated','[]'::jsonb,jsonb_build_object('approval_request_id',v_approval,'total_payroll_minor',v_total,'entry_count',v_count));perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
 exception when others then v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate) then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'payroll.calculate','payroll_period',null,p_idempotency_key,p_correlation_id);end if;perform private.complete_command_failure(v_claim.command_execution_id,'PAYROLL_CALCULATION_REJECTED',null);return private.command_replay_response('failed_terminal',null,'PAYROLL_CALCULATION_REJECTED',v_claim.command_execution_id);end;
end;$$;

create or replace function private.command_approve_payroll_period(p_organization_id uuid,p_payroll_period_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_claim record;v_period public.payroll_periods;v_ar public.approval_requests;v_total bigint;v_journal uuid;v_result jsonb;v_sqlstate text;
v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'payroll_period_id',p_payroll_period_id);
begin
 perform private.require_permission(p_organization_id,'payroll.approve');perform private.assert_request_fingerprint('payroll.approve',v_payload,p_request_fingerprint,1::smallint);
 select * into v_claim from private.claim_command(p_organization_id,'payroll.approve',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
 begin
  select p.* into strict v_period from public.payroll_periods p where p.organization_id=p_organization_id and p.id=p_payroll_period_id for update;
  if v_period.status<>'calculated' or v_period.created_by=auth.uid() then raise exception using errcode='42501',message='PAYROLL_APPROVAL_SOD_OR_STATE_INVALID';end if;
  perform 1 from public.payroll_entries e where e.organization_id=p_organization_id and e.payroll_period_id=v_period.id order by e.id for update;
  select coalesce(sum(net_payroll_minor),0) into v_total from public.payroll_entries where payroll_period_id=v_period.id;
  select ar.* into strict v_ar from public.approval_requests ar where ar.id=v_period.approval_request_id;
  perform private.consume_approval(p_organization_id,v_ar.id,'payroll.approve','payroll_period',v_period.id,v_ar.subject_fingerprint,v_claim.command_execution_id,v_total);
  v_journal:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'payroll_period',p_source_id=>v_period.id,p_posting_purpose=>'accrual',p_description=>'Approve payroll period',p_lines=>jsonb_build_array(
   jsonb_build_object('account_role','payroll_expense','debit_minor',v_total::text,'credit_minor','0','subledger_type','payroll_period','subledger_id',v_period.id),
   jsonb_build_object('account_role','payroll_payable','debit_minor','0','credit_minor',v_total::text,'subledger_type','payroll_period','subledger_id',v_period.id)),p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_approval_request_id=>v_ar.id,p_command_type=>'payroll.approve',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);
  update public.payroll_entries set status='approved',approved_at=statement_timestamp(),approved_by=auth.uid(),accrual_journal_entry_id=v_journal,version=version+1 where payroll_period_id=v_period.id;
  update public.payroll_periods set status='approved',approved_at=statement_timestamp(),approved_by=auth.uid(),version=version+1 where id=v_period.id;
  v_result:=private.command_success_response(v_claim.command_execution_id,v_period.id,'approved','payroll.approved',jsonb_build_array(v_journal),jsonb_build_object('total_payroll_minor',v_total));perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
 exception when others then v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate) then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'payroll.approve','payroll_period',p_payroll_period_id,p_idempotency_key,p_correlation_id);end if;perform private.complete_command_failure(v_claim.command_execution_id,'PAYROLL_APPROVAL_REJECTED',null);return private.command_replay_response('failed_terminal',null,'PAYROLL_APPROVAL_REJECTED',v_claim.command_execution_id);end;
end;$$;

create or replace function private.command_pay_payroll_entry(p_organization_id uuid,p_payroll_entry_id uuid,p_wallet_id uuid,p_provider_reference text,p_evidence_attachment_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_claim record;v_entry public.payroll_entries;v_wallet public.wallets;v_amount bigint;v_payment uuid;v_journal uuid;v_result jsonb;v_sqlstate text;
v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'payroll_entry_id',p_payroll_entry_id,'wallet_id',p_wallet_id,'provider_reference',p_provider_reference,'evidence_attachment_id',p_evidence_attachment_id);
begin
 perform private.require_permission(p_organization_id,'payroll.pay');perform private.assert_request_fingerprint('payroll.pay',v_payload,p_request_fingerprint,1::smallint);
 select * into v_claim from private.claim_command(p_organization_id,'payroll.pay',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
 begin
  if not exists(select 1 from private.organization_finance_settings s where s.organization_id=p_organization_id and s.payroll_execution_enabled and s.effective_from<=statement_timestamp() and(s.effective_to is null or s.effective_to>statement_timestamp())) then raise exception using errcode='55000',message='PAYROLL_EXECUTION_DISABLED';end if;
  select e.* into strict v_entry from public.payroll_entries e where e.organization_id=p_organization_id and e.id=p_payroll_entry_id for update;select w.* into strict v_wallet from public.wallets w where w.organization_id=p_organization_id and w.id=p_wallet_id and w.is_active for update;
  if v_entry.status not in('approved','partially_paid','overdue') then raise exception using errcode='55000',message='PAYROLL_ENTRY_NOT_PAYABLE';end if;v_amount:=v_entry.net_payroll_minor-v_entry.paid_minor;if v_amount<=0 then raise exception using errcode='55000',message='PAYROLL_ALREADY_PAID';end if;
  insert into public.payroll_payments(organization_id,payroll_entry_id,wallet_id,amount_minor,payment_date,provider_reference,evidence_attachment_id,created_by,updated_by) values(p_organization_id,v_entry.id,v_wallet.id,v_amount,private.cairo_accounting_date(),p_provider_reference,p_evidence_attachment_id,auth.uid(),auth.uid()) returning id into v_payment;
  v_journal:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'payroll_payment',p_source_id=>v_payment,p_posting_purpose=>'payment',p_description=>'Pay approved payroll entry',p_lines=>jsonb_build_array(
   jsonb_build_object('account_role','payroll_payable','debit_minor',v_amount::text,'credit_minor','0','employee_id',v_entry.employee_id,'subledger_type','payroll_entry','subledger_id',v_entry.id),
   jsonb_build_object('account_role','wallet_'||lower(regexp_replace(v_wallet.code,'[^a-zA-Z0-9]+','_','g')),'debit_minor','0','credit_minor',v_amount::text,'employee_id',v_entry.employee_id,'wallet_id',v_wallet.id,'subledger_type','payroll_payment','subledger_id',v_payment)),p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_command_type=>'payroll.pay',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);
  update public.payroll_payments set journal_entry_id=v_journal where id=v_payment;update public.payroll_entries set paid_minor=net_payroll_minor,status='paid',version=version+1 where id=v_entry.id;
  if not exists(select 1 from public.payroll_entries where payroll_period_id=v_entry.payroll_period_id and status<>'paid') then update public.payroll_periods set status='paid',version=version+1 where id=v_entry.payroll_period_id;else update public.payroll_periods set status='partially_paid',version=version+1 where id=v_entry.payroll_period_id;end if;
  v_result:=private.command_success_response(v_claim.command_execution_id,v_payment,'paid','payroll.paid',jsonb_build_array(v_journal),jsonb_build_object('payroll_entry_id',v_entry.id,'amount_minor',v_amount));perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
 exception when others then v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate) then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'payroll.pay','payroll_entry',p_payroll_entry_id,p_idempotency_key,p_correlation_id);end if;perform private.complete_command_failure(v_claim.command_execution_id,'PAYROLL_PAYMENT_REJECTED',null);return private.command_replay_response('failed_terminal',null,'PAYROLL_PAYMENT_REJECTED',v_claim.command_execution_id);end;
end;$$;

create or replace function api.record_expense(p_organization_id uuid,p_expense_number text,p_expense_category_id uuid,p_business_date date,p_due_date date,p_description text,p_subtotal_minor bigint,p_tax_minor bigint,p_payable_name_snapshot text,p_evidence_attachment_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_record_expense(p_organization_id,p_expense_number,p_expense_category_id,p_business_date,p_due_date,p_description,p_subtotal_minor,p_tax_minor,p_payable_name_snapshot,p_evidence_attachment_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.approve_expense(p_organization_id uuid,p_expense_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_approve_expense(p_organization_id,p_expense_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.pay_expense(p_organization_id uuid,p_expense_id uuid,p_wallet_id uuid,p_provider_reference text,p_evidence_attachment_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_pay_expense(p_organization_id,p_expense_id,p_wallet_id,p_provider_reference,p_evidence_attachment_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.calculate_payroll_period(p_organization_id uuid,p_period_start date,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_calculate_payroll_period(p_organization_id,p_period_start,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.approve_payroll_period(p_organization_id uuid,p_payroll_period_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_approve_payroll_period(p_organization_id,p_payroll_period_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.pay_payroll_entry(p_organization_id uuid,p_payroll_entry_id uuid,p_wallet_id uuid,p_provider_reference text,p_evidence_attachment_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()) returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_pay_payroll_entry(p_organization_id,p_payroll_entry_id,p_wallet_id,p_provider_reference,p_evidence_attachment_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;

revoke all on function private.command_record_expense(uuid,text,uuid,date,date,text,bigint,bigint,text,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_approve_expense(uuid,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_pay_expense(uuid,uuid,uuid,text,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_calculate_payroll_period(uuid,date,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_approve_payroll_period(uuid,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_pay_payroll_entry(uuid,uuid,uuid,text,uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function private.command_record_expense(uuid,text,uuid,date,date,text,bigint,bigint,text,uuid,text,text,uuid) to authenticated;
grant execute on function private.command_approve_expense(uuid,uuid,text,text,uuid) to authenticated;
grant execute on function private.command_pay_expense(uuid,uuid,uuid,text,uuid,text,text,uuid) to authenticated;
grant execute on function private.command_calculate_payroll_period(uuid,date,text,text,uuid) to authenticated;
grant execute on function private.command_approve_payroll_period(uuid,uuid,text,text,uuid) to authenticated;
grant execute on function private.command_pay_payroll_entry(uuid,uuid,uuid,text,uuid,text,text,uuid) to authenticated;
revoke all on function api.record_expense(uuid,text,uuid,date,date,text,bigint,bigint,text,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function api.approve_expense(uuid,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function api.pay_expense(uuid,uuid,uuid,text,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function api.calculate_payroll_period(uuid,date,text,text,uuid) from public,anon,authenticated;
revoke all on function api.approve_payroll_period(uuid,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function api.pay_payroll_entry(uuid,uuid,uuid,text,uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function api.record_expense(uuid,text,uuid,date,date,text,bigint,bigint,text,uuid,text,text,uuid) to authenticated;
grant execute on function api.approve_expense(uuid,uuid,text,text,uuid) to authenticated;
grant execute on function api.pay_expense(uuid,uuid,uuid,text,uuid,text,text,uuid) to authenticated;
grant execute on function api.calculate_payroll_period(uuid,date,text,text,uuid) to authenticated;
grant execute on function api.approve_payroll_period(uuid,uuid,text,text,uuid) to authenticated;
grant execute on function api.pay_payroll_entry(uuid,uuid,uuid,text,uuid,text,text,uuid) to authenticated;
