begin;
set local search_path=public,extensions;
select plan(19);

create temporary table test_partner_context(key text primary key,j jsonb,t text,u uuid);
grant all on test_partner_context to authenticated;

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous) values
('00000000-0000-0000-0000-000000000000','14000000-0000-4000-8000-000000000001','authenticated','authenticated','finance1@partner.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','14000000-0000-4000-8000-000000000002','authenticated','authenticated','finance2@partner.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','14000000-0000-4000-8000-000000000003','authenticated','authenticated','partner1@partner.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','14000000-0000-4000-8000-000000000004','authenticated','authenticated','partner2@partner.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id::text like '14000000-%';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '00000000-0000-4000-8000-00000000f001',x.uid,r.id,statement_timestamp()-interval '1 minute',x.uid,'Partner workflow fixture'
from(values
  ('14000000-0000-4000-8000-000000000001'::uuid,'finance_manager'),
  ('14000000-0000-4000-8000-000000000002'::uuid,'finance_manager'),
  ('14000000-0000-4000-8000-000000000003'::uuid,'partner'),
  ('14000000-0000-4000-8000-000000000004'::uuid,'partner')
)x(uid,role_key)
join private.roles r on r.organization_id='00000000-0000-4000-8000-00000000f001' and r.role_key=x.role_key;
update public.partners set profile_id=case partner_code when'AHMED'then'14000000-0000-4000-8000-000000000003'::uuid else'14000000-0000-4000-8000-000000000004'::uuid end,updated_by='14000000-0000-4000-8000-000000000001' where organization_id='00000000-0000-4000-8000-00000000f001';

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
select md5('phase2-partner-settings')::uuid,organization_id,version_no+1,transaction_timestamp(),currency_code,timezone_name,
  custom_deposit_bps,custom_shipping_prepaid_required,moderator_max_discount_bps,
  discount_applies_to_shipping_by_default,block_negative_margin_for_moderator,
  30000,24,true,10000,30,1000,5000,
  delivery_recognition_enabled,delivery_evidence_policy,payroll_execution_enabled,
  salary_window_start_day,salary_window_end_day,moderator_bonus_min_minor,
  moderator_bonus_max_minor,operations_bonus_min_minor,operations_bonus_max_minor,
  opening_balance_import_enabled,'14000000-0000-4000-8000-000000000001',transaction_timestamp(),
  'Enable synthetic partner withdrawal verification','14000000-0000-4000-8000-000000000001'
from private.organization_finance_settings
where organization_id='00000000-0000-4000-8000-00000000f001' and effective_to=transaction_timestamp();

insert into test_partner_context(key,j) values('capital_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'partner_id','00000000-0000-4000-8000-00000000f251'::uuid,'wallet_id','00000000-0000-4000-8000-00000000f241'::uuid,'amount_minor',200000,'reason','Synthetic cleared contribution','evidence_attachment_id',null));
insert into test_partner_context(key,t) select 'capital_fp',private.canonical_request_fingerprint('partners.capital.record',j,1::smallint) from test_partner_context where key='capital_payload';
select set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_partner_context(key,j) select 'capital_result',api.record_partner_capital('00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f251','00000000-0000-4000-8000-00000000f241',200000,'Synthetic cleared contribution',null,'partner-capital-0001',(select t from test_partner_context where key='capital_fp'),'33000000-0000-4000-8000-000000000001');reset role;
select ok((select transaction_type='capital_contribution' and amount_minor=200000 and journal_entry_id is not null from public.partner_capital_transactions where id=(select (j->>'entity_id')::uuid from test_partner_context where key='capital_result')),'cleared partner contribution posts to capital, not revenue');

insert into test_partner_context(key,j) values('loan_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'partner_id','00000000-0000-4000-8000-00000000f252'::uuid,'wallet_id','00000000-0000-4000-8000-00000000f241'::uuid,'loan_number','PARTNER-LOAN-P2-1','principal_minor',20000,'due_date',(transaction_timestamp() at time zone 'Africa/Cairo')::date+90,'terms_snapshot',jsonb_build_object('interest_bps',0,'fixture',true)));
insert into test_partner_context(key,t) select 'loan_fp',private.canonical_request_fingerprint('partners.loan.record',j,1::smallint) from test_partner_context where key='loan_payload';
select set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_partner_context(key,j) select 'loan_result',api.record_partner_loan('00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f252','00000000-0000-4000-8000-00000000f241','PARTNER-LOAN-P2-1',20000,(transaction_timestamp() at time zone 'Africa/Cairo')::date+90,jsonb_build_object('interest_bps',0,'fixture',true),'partner-loan-0001',(select t from test_partner_context where key='loan_fp'),'33000000-0000-4000-8000-000000000002');reset role;
select ok((select direction='partner_to_falcon' and principal_minor=20000 and status='active' from public.partner_loans where id=(select (j->>'entity_id')::uuid from test_partner_context where key='loan_result')),'partner loan is a distinct active liability');
select ok(not exists(select 1 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id join accounting.accounts a on a.id=jl.account_id where je.source_type in('partner_capital','partner_loan') and a.account_type in('revenue','expense')),'capital and loan funding never touch P&L');

insert into accounting.accounting_periods(id,organization_id,period_start,period_end,status,closed_by,closed_at)
values('34000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f001',date '2026-06-01',date '2026-06-30','closed','14000000-0000-4000-8000-000000000001','2026-07-01 09:00:00+03');
insert into accounting.monthly_closings(id,organization_id,accounting_period_id,status,cumulative_profit_loss_minor,prior_distributions_minor,protected_reserve_minor,distributable_profit_minor,settings_snapshot,reconciliation_snapshot,validation_result,requested_by,closed_by,closed_at,correlation_id)
values('34000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000f001','34000000-0000-4000-8000-000000000001','closed',110001,0,10000,100001,'{"fixture":true}','{"fixture":true}','{"ready":true}','14000000-0000-4000-8000-000000000001','14000000-0000-4000-8000-000000000001','2026-07-01 09:00:00+03','34000000-0000-4000-8000-000000000003');

insert into test_partner_context(key,j) values('distribution_calc_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'action','calculate','monthly_closing_id','34000000-0000-4000-8000-000000000002'::uuid,'profit_distribution_id',null,'distribution_no','DIST-P2-1','distribution_amount_minor',100001,'approval_request_id',null));
insert into test_partner_context(key,t) select 'distribution_calc_fp',private.canonical_request_fingerprint('partners.profit_distribution.calculate',j,1::smallint) from test_partner_context where key='distribution_calc_payload';
select set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_partner_context(key,j) select 'distribution_calc_result',api.calculate_profit_distribution('00000000-0000-4000-8000-00000000f001','34000000-0000-4000-8000-000000000002','DIST-P2-1',100001,'distribution-calculate-0001',(select t from test_partner_context where key='distribution_calc_fp'),'34000000-0000-4000-8000-000000000004');reset role;
insert into test_partner_context(key,u) select 'distribution_id',(j->>'entity_id')::uuid from test_partner_context where key='distribution_calc_result';
insert into test_partner_context(key,u) select 'distribution_approval_id',(j->>'approval_request_id')::uuid from test_partner_context where key='distribution_calc_result';
insert into test_partner_context(key,t) select 'distribution_approval_fp',j->>'approval_request_fingerprint' from test_partner_context where key='distribution_calc_result';
select ok((select allocated_minor=100000 and retained_remainder_minor=1 and status='submitted' from public.profit_distributions where id=(select u from test_partner_context where key='distribution_id')),'50/50 floor allocation retains the odd minor unit');
select is((select count(*)::integer from public.profit_distribution_lines where profit_distribution_id=(select u from test_partner_context where key='distribution_id') and allocated_amount_minor=50000),2,'distribution snapshots both 50 percent ownership lines');
select is((select status::text from public.approval_requests where id=(select u from test_partner_context where key='distribution_approval_id')),'submitted','distribution calculation creates a bound approval envelope');

select set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000002',true);set local role authenticated;
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select u from test_partner_context where key='distribution_approval_id'),'approve','Approve closed-basis distribution',null,'34000000-0000-4000-8000-000000000005');
insert into test_partner_context(key,j) select 'distribution_approve_result',api.approve_profit_distribution('00000000-0000-4000-8000-00000000f001',(select u from test_partner_context where key='distribution_id'),(select u from test_partner_context where key='distribution_approval_id'),'distribution-approve-0001',(select t from test_partner_context where key='distribution_approval_fp'),'34000000-0000-4000-8000-000000000006');reset role;
select is((select status::text from public.profit_distributions where id=(select u from test_partner_context where key='distribution_id')),'approved','separate actor consumes distribution approval');

insert into test_partner_context(key,j) select 'distribution_post_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'action','post','monthly_closing_id',null,'profit_distribution_id',u,'distribution_no',null,'distribution_amount_minor',null,'approval_request_id',null) from test_partner_context where key='distribution_id';
insert into test_partner_context(key,t) select 'distribution_post_fp',private.canonical_request_fingerprint('partners.profit_distribution.post',j,1::smallint) from test_partner_context where key='distribution_post_payload';
select set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_partner_context(key,j) select 'distribution_post_result',api.post_profit_distribution('00000000-0000-4000-8000-00000000f001',(select u from test_partner_context where key='distribution_id'),'distribution-post-0001',(select t from test_partner_context where key='distribution_post_fp'),'34000000-0000-4000-8000-000000000007');reset role;
select ok((select status='posted' and journal_entry_id is not null from public.profit_distributions where id=(select u from test_partner_context where key='distribution_id')),'third actor stage posts approved distribution');
select ok((select sum(allocated_amount_minor)=allocated_minor and allocated_minor+retained_remainder_minor=approved_distribution_minor from public.profit_distribution_lines l join public.profit_distributions d on d.id=l.profit_distribution_id where d.id=(select u from test_partner_context where key='distribution_id') group by d.allocated_minor,d.retained_remainder_minor,d.approved_distribution_minor),'posted distribution conserves allocated and retained amounts');
select is((select coalesce(sum(jl.credit_minor-jl.debit_minor),0)::bigint from accounting.journal_lines jl join accounting.journal_entries je on je.id=jl.journal_entry_id join accounting.accounts a on a.id=jl.account_id where je.source_type='profit_distribution' and a.code='3200' and jl.partner_id='00000000-0000-4000-8000-00000000f251'),50000::bigint,'posted distribution creates Ahmed current-account source balance');

insert into test_partner_context(key,j) values('withdrawal_request_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'partner_id','00000000-0000-4000-8000-00000000f251'::uuid,'withdrawal_number','WD-P2-1','withdrawal_type','available_profit_draw'::public.partner_withdrawal_type,'requested_amount_minor',40000,'reason','Draw approved distributed profit','evidence_attachment_id',null));
insert into test_partner_context(key,t) select 'withdrawal_request_fp',private.canonical_request_fingerprint('partner_withdrawals.request',j,1::smallint) from test_partner_context where key='withdrawal_request_payload';
select set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000003',true);set local role authenticated;
insert into test_partner_context(key,j) select 'withdrawal_request_result',api.request_partner_withdrawal('00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f251','WD-P2-1','available_profit_draw',40000,'Draw approved distributed profit',null,'withdrawal-request-0001',(select t from test_partner_context where key='withdrawal_request_fp'),'35000000-0000-4000-8000-000000000001');reset role;
insert into test_partner_context(key,u) select 'withdrawal_id',(j->>'entity_id')::uuid from test_partner_context where key='withdrawal_request_result';
insert into test_partner_context(key,u) select 'withdrawal_approval_id',(j->>'approval_request_id')::uuid from test_partner_context where key='withdrawal_request_result';
select ok((select rolling_24h_existing_minor=0 and rolling_24h_total_minor=40000 and approval_threshold_minor=30000 and requires_other_partner_approval from public.partner_withdrawals where id=(select u from test_partner_context where key='withdrawal_id')),'request snapshots server-derived rolling threshold under the partner lock');

select set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000004',true);set local role authenticated;
select throws_ok(format('select api.decide_approval(%L,%L,%L,%L,%L,%L)','00000000-0000-4000-8000-00000000f001',(select u from test_partner_context where key='withdrawal_approval_id'),'approve','Spoof attempt','00000000-0000-4000-8000-00000000f251','35000000-0000-4000-8000-000000000002'),'42501',null,'caller cannot spoof a different partner identity');
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select u from test_partner_context where key='withdrawal_approval_id'),'approve','Other partner approves',null,'35000000-0000-4000-8000-000000000003');reset role;

insert into test_partner_context(key,j) select 'withdrawal_approve_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'partner_withdrawal_id',u) from test_partner_context where key='withdrawal_id';
insert into test_partner_context(key,t) select 'withdrawal_approve_fp',private.canonical_request_fingerprint('partner_withdrawals.approve',j,1::smallint) from test_partner_context where key='withdrawal_approve_payload';
select set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000004',true);set local role authenticated;
insert into test_partner_context(key,j) select 'withdrawal_approve_result',api.approve_partner_withdrawal('00000000-0000-4000-8000-00000000f001',(select u from test_partner_context where key='withdrawal_id'),'withdrawal-approve-0001',(select t from test_partner_context where key='withdrawal_approve_fp'),'35000000-0000-4000-8000-000000000004');reset role;
select ok((select status='approved' and approved_by_partner_id='00000000-0000-4000-8000-00000000f252' from public.partner_withdrawals where id=(select u from test_partner_context where key='withdrawal_id')),'authenticated other partner identity is persisted on approval');

insert into test_partner_context(key,j) select 'withdrawal_execute_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'partner_withdrawal_id',u,'wallet_id','00000000-0000-4000-8000-00000000f241'::uuid,'provider_reference','WD-P2-EXEC-1') from test_partner_context where key='withdrawal_id';
insert into test_partner_context(key,t) select 'withdrawal_execute_fp',private.canonical_request_fingerprint('partner_withdrawals.execute',j,1::smallint) from test_partner_context where key='withdrawal_execute_payload';
select set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_partner_context(key,j) select 'withdrawal_execute_result',api.execute_partner_withdrawal('00000000-0000-4000-8000-00000000f001',(select u from test_partner_context where key='withdrawal_id'),'00000000-0000-4000-8000-00000000f241','WD-P2-EXEC-1','withdrawal-execute-0001',(select t from test_partner_context where key='withdrawal_execute_fp'),'35000000-0000-4000-8000-000000000005');
insert into test_partner_context(key,j) select 'withdrawal_execute_replay',api.execute_partner_withdrawal('00000000-0000-4000-8000-00000000f001',(select u from test_partner_context where key='withdrawal_id'),'00000000-0000-4000-8000-00000000f241','WD-P2-EXEC-1','withdrawal-execute-0001',(select t from test_partner_context where key='withdrawal_execute_fp'),'35000000-0000-4000-8000-000000000005');reset role;
select ok((select status='executed' and available_source_balance_minor=50000 and safe_withdrawal_amount_minor=50000 and journal_entry_id is not null from public.partner_withdrawals where id=(select u from test_partner_context where key='withdrawal_id')),'execution snapshots source and conservative safe liquidity before payment');
select ok((select (select j->>'entity_id' from test_partner_context where key='withdrawal_execute_result')=(select j->>'entity_id' from test_partner_context where key='withdrawal_execute_replay') and count(*)=1 from accounting.journal_entries where source_type='partner_withdrawal' and source_id=(select u from test_partner_context where key='withdrawal_id')),'withdrawal replay cannot duplicate the journal');
select is((select coalesce(sum(jl.credit_minor-jl.debit_minor),0)::bigint from accounting.journal_lines jl join accounting.journal_entries je on je.id=jl.journal_entry_id join accounting.accounts a on a.id=jl.account_id where a.code='3200' and jl.partner_id='00000000-0000-4000-8000-00000000f251' and je.status in('posted','reversed')),10000::bigint,'withdrawal reduces only the partner current-account balance');
select ok(not exists(select 1 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id join accounting.accounts a on a.id=jl.account_id where je.source_type in('profit_distribution','partner_withdrawal') and a.account_type in('revenue','expense')),'distribution and withdrawal remain outside operating P&L');
select ok(not exists(select 1 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id where je.source_type in('partner_capital','partner_loan','profit_distribution','partner_withdrawal') group by je.id having sum(jl.debit_minor)<>sum(jl.credit_minor)),'every partner workflow journal balances');
select is((select (liquidity_snapshot->>'protected_liabilities_minor')::bigint from public.partner_withdrawals where id=(select u from test_partner_context where key='withdrawal_id')),20000::bigint,'liquidity snapshot protects the outstanding partner loan liability');

select * from finish();
rollback;
