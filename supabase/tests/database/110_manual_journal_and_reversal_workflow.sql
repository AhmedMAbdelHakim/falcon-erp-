begin;
set local search_path=public,extensions;
select plan(12);
create temporary table test_journal_context(key text primary key,j jsonb,u uuid,t text);
grant all on test_journal_context to authenticated;

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous) values
('00000000-0000-0000-0000-000000000000','18000000-0000-4000-8000-000000000001','authenticated','authenticated','journal1@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','18000000-0000-4000-8000-000000000002','authenticated','authenticated','journal2@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id::text like '18000000-%';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '00000000-0000-4000-8000-00000000f001',x.uid,r.id,statement_timestamp()-interval '1 minute',x.uid,'Journal fixture'
from(values('18000000-0000-4000-8000-000000000001'::uuid,'super_admin'),('18000000-0000-4000-8000-000000000002'::uuid,'super_admin'))x(uid,role_key)
join private.roles r on r.organization_id='00000000-0000-4000-8000-00000000f001' and r.role_key=x.role_key;
insert into test_journal_context(key,u) select 'wallet_account',id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='1100';
insert into test_journal_context(key,u) select 'expense_account',id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='5200';
insert into test_journal_context(key,u) select 'other_expense_account',id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='6200';

insert into test_journal_context(key,j) select 'control_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'source_type','manual_journal',
  'source_id','18000000-0000-4000-8000-000000000010'::uuid,'posting_purpose','manual_adjustment',
  'description','Hostile control account probe','lines',jsonb_build_array(
    jsonb_build_object('account_id',(select u from test_journal_context where key='wallet_account'),'debit_minor','100','credit_minor','0'),
    jsonb_build_object('account_id',(select u from test_journal_context where key='expense_account'),'debit_minor','0','credit_minor','100')),
  'accounting_date',null,'approval_request_id',null,'corrects_entry_id',null,'affected_closed_period_id',null);
insert into test_journal_context(key,t) select 'control_fp',private.canonical_request_fingerprint('ledger.post',j,1::smallint) from test_journal_context where key='control_payload';
select set_config('request.jwt.claim.sub','18000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_journal_context(key,j) select 'control_result',api.post_journal_entry(
  '00000000-0000-4000-8000-00000000f001','manual_journal','18000000-0000-4000-8000-000000000010','manual_adjustment','Hostile control account probe',
  (select j->'lines' from test_journal_context where key='control_payload'),'hostile-control-0001',(select t from test_journal_context where key='control_fp'),'18000000-0000-4000-8000-000000000011',null,null,null,null);reset role;
select is((select j->>'error_code' from test_journal_context where key='control_result'),'MANUAL_POSTING_ACCOUNT_DENIED','manual posting cannot target a wallet control account');
select is((select count(*)::integer from accounting.journal_entries where source_id='18000000-0000-4000-8000-000000000010'),0,'denied control posting leaves no journal residue');

insert into test_journal_context(key,j) select 'valid_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'source_type','manual_journal',
  'source_id','18000000-0000-4000-8000-000000000020'::uuid,'posting_purpose','manual_adjustment',
  'description','Approved manual reclassification','lines',jsonb_build_array(
    jsonb_build_object('account_id',(select u from test_journal_context where key='expense_account'),'debit_minor','125','credit_minor','0'),
    jsonb_build_object('account_id',(select u from test_journal_context where key='other_expense_account'),'debit_minor','0','credit_minor','125')),
  'accounting_date',null,'approval_request_id',null,'corrects_entry_id',null,'affected_closed_period_id',null);
insert into test_journal_context(key,t) select 'valid_fp',private.canonical_request_fingerprint('ledger.post',j,1::smallint) from test_journal_context where key='valid_payload';
select set_config('request.jwt.claim.sub','18000000-0000-4000-8000-000000000001',true);set local role authenticated;
select throws_ok($$select api.post_journal_entry('00000000-0000-4000-8000-00000000f001','manual_journal','18000000-0000-4000-8000-000000000020','manual_adjustment','Approved manual reclassification',(select j->'lines' from test_journal_context where key='valid_payload'),'tampered-fp-0001',repeat('a',64),'18000000-0000-4000-8000-000000000021',null,null,null,null)$$,'22023','REQUEST_FINGERPRINT_MISMATCH','tampered manual journal fingerprint is rejected before claiming idempotency');
insert into test_journal_context(key,j) select 'post_result',api.post_journal_entry(
  '00000000-0000-4000-8000-00000000f001','manual_journal','18000000-0000-4000-8000-000000000020','manual_adjustment','Approved manual reclassification',
  (select j->'lines' from test_journal_context where key='valid_payload'),'valid-manual-post-0001',(select t from test_journal_context where key='valid_fp'),'18000000-0000-4000-8000-000000000022',null,null,null,null);reset role;
insert into test_journal_context(key,u) select 'journal_id',(j->'journal_entry_ids'->>0)::uuid from test_journal_context where key='post_result';
select ok((select status='posted' and total_debit_minor=125 and total_credit_minor=125 from accounting.journal_entries where id=(select u from test_journal_context where key='journal_id')),'valid non-control manual reclassification posts balanced');

insert into test_journal_context(key,j) select 'reverse_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'original_entry_id',u,'reason','Correct classification error') from test_journal_context where key='journal_id';
insert into test_journal_context(key,t) select 'reverse_fp',private.canonical_request_fingerprint('ledger.reverse',j,1::smallint) from test_journal_context where key='reverse_payload';
select set_config('request.jwt.claim.sub','18000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_journal_context(key,j) select 'request_result',api.request_journal_reversal(
  '00000000-0000-4000-8000-00000000f001',(select u from test_journal_context where key='journal_id'),'Correct classification error',
  'reversal-request-0001',(select t from test_journal_context where key='reverse_fp'),'18000000-0000-4000-8000-000000000023');reset role;
insert into test_journal_context(key,u) select 'approval_id',(j->>'approval_request_id')::uuid from test_journal_context where key='request_result';
select is((select status::text from public.approval_requests where id=(select u from test_journal_context where key='approval_id')),'submitted','reversal request creates approval envelope');

select set_config('request.jwt.claim.sub','18000000-0000-4000-8000-000000000002',true);set local role authenticated;
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select u from test_journal_context where key='approval_id'),'approve','Independent reversal review',null,'18000000-0000-4000-8000-000000000024');
insert into test_journal_context(key,j) select 'reverse_result',api.reverse_journal_entry(
  '00000000-0000-4000-8000-00000000f001',(select u from test_journal_context where key='journal_id'),'Correct classification error',
  'reversal-execute-0001',(select t from test_journal_context where key='reverse_fp'),'18000000-0000-4000-8000-000000000025',(select u from test_journal_context where key='approval_id'));reset role;
insert into test_journal_context(key,u) select 'reversal_id',(j->'journal_entry_ids'->>0)::uuid from test_journal_context where key='reverse_result';
select ok((select status='reversed' from accounting.journal_entries where id=(select u from test_journal_context where key='journal_id')) and (select status='posted' and reversal_of=(select u from test_journal_context where key='journal_id') from accounting.journal_entries where id=(select u from test_journal_context where key='reversal_id')),'approved command marks original reversed and posts linked inverse');
select is((select status::text from public.approval_requests where id=(select u from test_journal_context where key='approval_id')),'consumed','reversal consumes approval once');
select results_eq(
  $$select o.line_number,o.debit_minor,o.credit_minor,r.debit_minor,r.credit_minor from accounting.journal_lines o join accounting.journal_lines r on r.journal_entry_id=(select u from test_journal_context where key='reversal_id') and r.line_number=o.line_number where o.journal_entry_id=(select u from test_journal_context where key='journal_id') order by o.line_number$$,
  $$select * from (values(1::smallint,125::bigint,0::bigint,0::bigint,125::bigint),(2::smallint,0::bigint,125::bigint,125::bigint,0::bigint)) as expected(line_number,debit_minor,credit_minor,reversal_debit_minor,reversal_credit_minor)$$,
  'reversal mirrors every original line exactly');
select is((select count(*)::integer from accounting.journal_entries where reversal_of=(select u from test_journal_context where key='journal_id')),1,'only one reversal exists');
select is((select count(*)::integer from private.command_executions where command_type='ledger.reverse' and idempotency_key='reversal-execute-0001' and status='succeeded'),1,'reversal idempotency outcome is stored');
select ok((select count(*)>=2 from audit.events where subject_id=(select u from test_journal_context where key='journal_id') and action in('ledger.reverse.request','ledger.reverse')),'request and execution emit audit evidence');
select is((select count(*)::integer from accounting.journal_entries je where je.id in((select u from test_journal_context where key='journal_id'),(select u from test_journal_context where key='reversal_id')) and je.total_debit_minor<>je.total_credit_minor),0,'original and reversal remain balanced');

select * from finish();
rollback;
