begin;
set local search_path=public,extensions;
select plan(18);

create temporary table test_close_context(key text primary key,j jsonb,t text,u uuid);
grant all on test_close_context to authenticated;

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous) values
('00000000-0000-0000-0000-000000000000','15000000-0000-4000-8000-000000000001','authenticated','authenticated','close1@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','15000000-0000-4000-8000-000000000002','authenticated','authenticated','close2@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id::text like '15000000-%';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '00000000-0000-4000-8000-00000000f001',x.uid,r.id,statement_timestamp()-interval '1 minute',x.uid,'Monthly close fixture'
from(values('15000000-0000-4000-8000-000000000001'::uuid,'super_admin'),('15000000-0000-4000-8000-000000000002'::uuid,'super_admin'))x(uid,role_key)
join private.roles r on r.organization_id='00000000-0000-4000-8000-00000000f001' and r.role_key=x.role_key;

update private.organization_finance_settings set effective_to=transaction_timestamp()
where organization_id='00000000-0000-4000-8000-00000000f001' and effective_to is null;
insert into private.organization_finance_settings(
  id,organization_id,version_no,effective_from,currency_code,timezone_name,
  custom_deposit_bps,custom_shipping_prepaid_required,moderator_max_discount_bps,
  discount_applies_to_shipping_by_default,block_negative_margin_for_moderator,
  partner_withdrawal_approval_threshold_minor,withdrawal_aggregation_hours,
  withdrawal_execution_enabled,minimum_operating_capital_minor,
  protected_liability_horizon_days,reserve_requirement_bps,future_profit_advance_cap_minor,
  delivery_recognition_enabled,delivery_evidence_policy,payroll_execution_enabled,
  salary_window_start_day,salary_window_end_day,moderator_bonus_min_minor,
  moderator_bonus_max_minor,operations_bonus_min_minor,operations_bonus_max_minor,
  opening_balance_import_enabled,approved_by,approved_at,change_reason,created_by
)
select md5('phase2-close-settings')::uuid,organization_id,version_no+1,transaction_timestamp(),currency_code,timezone_name,
  custom_deposit_bps,custom_shipping_prepaid_required,moderator_max_discount_bps,
  discount_applies_to_shipping_by_default,block_negative_margin_for_moderator,
  partner_withdrawal_approval_threshold_minor,withdrawal_aggregation_hours,false,0,30,0,0,
  delivery_recognition_enabled,delivery_evidence_policy,payroll_execution_enabled,
  salary_window_start_day,salary_window_end_day,moderator_bonus_min_minor,
  moderator_bonus_max_minor,operations_bonus_min_minor,operations_bonus_max_minor,
  opening_balance_import_enabled,'15000000-0000-4000-8000-000000000001',transaction_timestamp(),
  'Complete synthetic close policy','15000000-0000-4000-8000-000000000001'
from private.organization_finance_settings
where organization_id='00000000-0000-4000-8000-00000000f001' and effective_to=transaction_timestamp();

insert into accounting.accounting_periods(id,organization_id,period_start,period_end,status)
values('37000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f001',date '2026-06-01',date '2026-06-30','open');
insert into test_close_context(key,u)
select 'expense_account_id',id from accounting.accounts
where organization_id='00000000-0000-4000-8000-00000000f001' and code='5200';
insert into test_close_context(key,u)
select 'equity_account_id',id from accounting.accounts
where organization_id='00000000-0000-4000-8000-00000000f001' and code='6200';
insert into test_close_context(key,j)
select 'closed_post_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,
  'source_type','manual_journal','source_id','37000000-0000-4000-8000-000000000010'::uuid,
  'posting_purpose','manual_adjustment','description','Must fail in closed month',
  'lines',jsonb_build_array(
    jsonb_build_object('account_id',(select u from test_close_context where key='expense_account_id'),'debit_minor','100','credit_minor','0'),
    jsonb_build_object('account_id',(select u from test_close_context where key='equity_account_id'),'debit_minor','0','credit_minor','100')
  ),
  'accounting_date',date '2026-06-15','approval_request_id',null,
  'corrects_entry_id',null,'affected_closed_period_id',null
);
insert into test_close_context(key,t)
select 'closed_post_fp',private.canonical_request_fingerprint('ledger.post',j,1::smallint)
from test_close_context where key='closed_post_payload';
insert into test_close_context(key,j)
select 'adjustment_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,
  'source_type','manual_journal','source_id','37000000-0000-4000-8000-000000000012'::uuid,
  'posting_purpose','manual_adjustment','description','Open-period adjustment referencing closed June',
  'lines',jsonb_build_array(
    jsonb_build_object('account_id',(select u from test_close_context where key='expense_account_id'),'debit_minor','75','credit_minor','0'),
    jsonb_build_object('account_id',(select u from test_close_context where key='equity_account_id'),'debit_minor','0','credit_minor','75')
  ),
  'accounting_date',private.cairo_accounting_date(),'approval_request_id',null,
  'corrects_entry_id',null,'affected_closed_period_id','37000000-0000-4000-8000-000000000001'::uuid
);
insert into test_close_context(key,t)
select 'adjustment_fp',private.canonical_request_fingerprint('ledger.post',j,1::smallint)
from test_close_context where key='adjustment_payload';

insert into test_close_context(key,j) values('start_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'period_start',date '2026-06-01','approval_request_id',null));
insert into test_close_context(key,t) select 'start_fp',private.canonical_request_fingerprint('accounting.start_close',j,1::smallint) from test_close_context where key='start_payload';
select set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_close_context(key,j) select 'start_result',api.start_monthly_close('00000000-0000-4000-8000-00000000f001',date '2026-06-01','close-start-0001',(select t from test_close_context where key='start_fp'),'37000000-0000-4000-8000-000000000002',null);reset role;
insert into test_close_context(key,u) select 'close_id',(j->>'entity_id')::uuid from test_close_context where key='start_result';
select ok((select status='closing' and close_requested_by='15000000-0000-4000-8000-000000000001' from accounting.accounting_periods where id='37000000-0000-4000-8000-000000000001'),'start command locks and transitions the accounting period');
select is((select count(*)::integer from accounting.closing_checklist_items where monthly_closing_id=(select u from test_close_context where key='close_id')),15,'start creates the complete close checklist');

insert into test_close_context(key,j) select 'attest_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'monthly_closing_id',u,'item_key','wallet_reconciliations','status','passed','expected_minor',0,'actual_minor',0,'evidence',jsonb_build_object('fixture','manual evidence attestation'),'notes','Runtime attestation proof','approval_request_id',null) from test_close_context where key='close_id';
insert into test_close_context(key,t) select 'attest_fp',private.canonical_request_fingerprint('accounting.attest_close_item',j,1::smallint) from test_close_context where key='attest_payload';
select set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000001',true);set local role authenticated;
select api.attest_monthly_close_item('00000000-0000-4000-8000-00000000f001',(select u from test_close_context where key='close_id'),'wallet_reconciliations','passed',0,0,jsonb_build_object('fixture','manual evidence attestation'),'Runtime attestation proof',null,'close-attest-0001',(select t from test_close_context where key='attest_fp'),'37000000-0000-4000-8000-000000000016');reset role;
select ok((select status='passed' and checked_by='15000000-0000-4000-8000-000000000001' and evidence->>'fixture'='manual evidence attestation' from accounting.closing_checklist_items where monthly_closing_id=(select u from test_close_context where key='close_id') and item_key='wallet_reconciliations'),'close item attestation records actor and nonempty evidence under the period lock');

insert into test_close_context(key,j) select 'cancel_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'monthly_closing_id',u,'action','cancel','reason','Exercise recovery path','approval_request_id',null) from test_close_context where key='close_id';
insert into test_close_context(key,t) select 'cancel_fp',private.canonical_request_fingerprint('accounting.cancel_close',j,1::smallint) from test_close_context where key='cancel_payload';
select set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_close_context(key,j) select 'cancel_result',api.cancel_monthly_close('00000000-0000-4000-8000-00000000f001',(select u from test_close_context where key='close_id'),'Exercise recovery path','close-cancel-0001',(select t from test_close_context where key='cancel_fp'),'37000000-0000-4000-8000-000000000003');reset role;
select ok((select status='cancelled' from accounting.monthly_closings where id=(select u from test_close_context where key='close_id')) and (select status='open' from accounting.accounting_periods where id='37000000-0000-4000-8000-000000000001'),'cancel returns a nonclosed period to open state');

insert into test_close_context(key,j) select 'recover_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'monthly_closing_id',u,'action','recover','reason','Resume deterministic close','approval_request_id',null) from test_close_context where key='close_id';
insert into test_close_context(key,t) select 'recover_fp',private.canonical_request_fingerprint('accounting.recover_close',j,1::smallint) from test_close_context where key='recover_payload';
select set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_close_context(key,j) select 'recover_result',api.recover_monthly_close('00000000-0000-4000-8000-00000000f001',(select u from test_close_context where key='close_id'),'Resume deterministic close','close-recover-0001',(select t from test_close_context where key='recover_fp'),'37000000-0000-4000-8000-000000000004');reset role;
select ok((select status='draft' from accounting.monthly_closings where id=(select u from test_close_context where key='close_id')) and (select status='closing' from accounting.accounting_periods where id='37000000-0000-4000-8000-000000000001'),'recovery resumes the same close under the shared period lock');

insert into test_close_context(key,j) select 'validate_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'monthly_closing_id',u) from test_close_context where key='close_id';
insert into test_close_context(key,t) select 'validate_fp',private.canonical_request_fingerprint('accounting.validate_close',j,1::smallint) from test_close_context where key='validate_payload';
select set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_close_context(key,j) select 'validate_result',api.validate_monthly_close('00000000-0000-4000-8000-00000000f001',(select u from test_close_context where key='close_id'),'close-validate-0001',(select t from test_close_context where key='validate_fp'),'37000000-0000-4000-8000-000000000005');reset role;
insert into test_close_context(key,u) select 'close_approval_id',(j->>'approval_request_id')::uuid from test_close_context where key='validate_result';
insert into test_close_context(key,t) select 'close_approval_fp',j->>'approval_request_fingerprint' from test_close_context where key='validate_result';
select is((select j->>'current_state' from test_close_context where key='validate_result'),'ready','server-derived close validation reaches ready without manual calculations');
select is((select count(*)::integer from accounting.closing_checklist_items where monthly_closing_id=(select u from test_close_context where key='close_id') and status='passed'),15,'all close controls are populated from executable evidence');
select ok((select validation_result->>'ready'='true' and distributable_profit_minor=0 and protected_reserve_minor=0 from accounting.monthly_closings where id=(select u from test_close_context where key='close_id')),'close snapshots cumulative result, reserve, and distributable basis');
select is((select status::text from public.approval_requests where id=(select u from test_close_context where key='close_approval_id')),'submitted','ready validation creates the close approval envelope');

select set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000002',true);set local role authenticated;
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select u from test_close_context where key='close_approval_id'),'approve','Approve deterministic close',null,'37000000-0000-4000-8000-000000000006');
insert into test_close_context(key,j) select 'close_result',api.close_accounting_period('00000000-0000-4000-8000-00000000f001',(select u from test_close_context where key='close_id'),(select u from test_close_context where key='close_approval_id'),'{}','{}','close-finalize-0001',(select t from test_close_context where key='close_approval_fp'),'37000000-0000-4000-8000-000000000007');reset role;
select ok((select status='closed' and closed_at is not null from accounting.accounting_periods where id='37000000-0000-4000-8000-000000000001') and (select status='closed' and closed_at is not null from accounting.monthly_closings where id=(select u from test_close_context where key='close_id')),'approved close atomically closes period and snapshot');
select is((select status::text from public.approval_requests where id=(select u from test_close_context where key='close_approval_id')),'consumed','close approval is consumed once');

select set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_close_context(key,j) select 'closed_post_result',api.post_journal_entry('00000000-0000-4000-8000-00000000f001','manual_journal','37000000-0000-4000-8000-000000000010','manual_adjustment','Must fail in closed month',(select j->'lines' from test_close_context where key='closed_post_payload'),'closed-period-probe-0001',(select t from test_close_context where key='closed_post_fp'),'37000000-0000-4000-8000-000000000011',date '2026-06-15',null,null,null);reset role;
select is((select j->>'error_code' from test_close_context where key='closed_post_result'),'POSTING_PERIOD_CLOSED','closed period rejects direct posting through the command boundary');
select is((select count(*)::integer from accounting.journal_entries where accounting_period_id='37000000-0000-4000-8000-000000000001'),0,'failed closed-period posting leaves no journal residue');

select set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_close_context(key,j) select 'adjustment_result',api.post_journal_entry('00000000-0000-4000-8000-00000000f001','manual_journal','37000000-0000-4000-8000-000000000012','manual_adjustment','Open-period adjustment referencing closed June',(select j->'lines' from test_close_context where key='adjustment_payload'),'closed-period-adjustment-0001',(select t from test_close_context where key='adjustment_fp'),'37000000-0000-4000-8000-000000000013',(select (j->>'accounting_date')::date from test_close_context where key='adjustment_payload'),null,null,'37000000-0000-4000-8000-000000000001');reset role;
select ok((select (j->>'success')::boolean from test_close_context where key='adjustment_result'),'approved adjustment posts in the open period');
select ok((select affected_closed_period_id='37000000-0000-4000-8000-000000000001' and accounting_date<>(date '2026-06-15') from accounting.journal_entries where id=((select j->'journal_entry_ids'->>0 from test_close_context where key='adjustment_result')::uuid)),'adjustment references but does not mutate the closed period');

select set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_close_context(key,j) select 'reopen_request_result',api.request_accounting_period_reopen('00000000-0000-4000-8000-00000000f001',(select u from test_close_context where key='close_id'),'Exceptional correction window');reset role;
insert into test_close_context(key,u) select 'reopen_approval_id',(j->>'approval_request_id')::uuid from test_close_context where key='reopen_request_result';
insert into test_close_context(key,t) select 'reopen_fp',j->>'approval_request_fingerprint' from test_close_context where key='reopen_request_result';
select set_config('request.jwt.claim.sub','15000000-0000-4000-8000-000000000002',true);set local role authenticated;
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select u from test_close_context where key='reopen_approval_id'),'approve','Approve exceptional reopen',null,'37000000-0000-4000-8000-000000000014');
insert into test_close_context(key,j) select 'reopen_result',api.reopen_accounting_period('00000000-0000-4000-8000-00000000f001',(select u from test_close_context where key='close_id'),'Exceptional correction window',(select u from test_close_context where key='reopen_approval_id'),'close-reopen-0001',(select t from test_close_context where key='reopen_fp'),'37000000-0000-4000-8000-000000000015');reset role;
select ok((select status='reopened_exceptionally' and reopen_reason='Exceptional correction window' and reopened_by='15000000-0000-4000-8000-000000000002' from accounting.accounting_periods where id='37000000-0000-4000-8000-000000000001'),'approved exceptional reopen records actor, reason, and state');
select is((select status::text from public.approval_requests where id=(select u from test_close_context where key='reopen_approval_id')),'consumed','reopen approval is consumed once');
select ok((select count(*)>=4 from audit.events where organization_id='00000000-0000-4000-8000-00000000f001' and action in('accounting.start_close','accounting.cancel_close','accounting.recover_close','accounting.close_period','accounting.reopen_close')),'close lifecycle emits append-only audit evidence');

select * from finish();
rollback;
