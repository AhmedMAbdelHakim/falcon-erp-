begin;
set local search_path=public,extensions;
select plan(11);
create temporary table test_transfer_context(key text primary key,j jsonb,u uuid,t text);
grant all on test_transfer_context to authenticated;
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous) values
('00000000-0000-0000-0000-000000000000','19000000-0000-4000-8000-000000000001','authenticated','authenticated','transfer1@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','19000000-0000-4000-8000-000000000002','authenticated','authenticated','transfer2@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id::text like '19000000-%';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '00000000-0000-4000-8000-00000000f001',x.uid,r.id,statement_timestamp()-interval '1 minute',x.uid,'Wallet transfer fixture'
from(values('19000000-0000-4000-8000-000000000001'::uuid,'super_admin'),('19000000-0000-4000-8000-000000000002'::uuid,'super_admin'))x(uid,role_key)
join private.roles r on r.organization_id='00000000-0000-4000-8000-00000000f001' and r.role_key=x.role_key;

insert into test_transfer_context(key,j) values('request_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,
  'source_wallet_id','00000000-0000-4000-8000-00000000f241'::uuid,
  'destination_wallet_id','00000000-0000-4000-8000-00000000f242'::uuid,
  'amount_minor',5000,'fee_minor',125,'transfer_reference','TRANSFER-P2-1',
  'fee_reference','TRANSFER-FEE-P2-1','reason','Move operating cash',
  'evidence_attachment_id',null));
insert into test_transfer_context(key,t) select 'request_fp',private.canonical_request_fingerprint('wallets.transfer',j,1::smallint) from test_transfer_context where key='request_payload';
select set_config('request.jwt.claim.sub','19000000-0000-4000-8000-000000000001',true);set local role authenticated;
select throws_ok($$select api.request_wallet_transfer('00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f241','00000000-0000-4000-8000-00000000f242',5000,125,'TRANSFER-P2-1','TRANSFER-FEE-P2-1','Move operating cash',null,'wallet-transfer-tamper-0001',repeat('f',64),'39000000-0000-4000-8000-000000000001')$$,'22023','REQUEST_FINGERPRINT_MISMATCH','tampered transfer fingerprint is rejected before command claim');
insert into test_transfer_context(key,j) select 'request_result',api.request_wallet_transfer(
  '00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f241','00000000-0000-4000-8000-00000000f242',
  5000,125,'TRANSFER-P2-1','TRANSFER-FEE-P2-1','Move operating cash',null,
  'wallet-transfer-request-0001',(select t from test_transfer_context where key='request_fp'),'39000000-0000-4000-8000-000000000002');reset role;
insert into test_transfer_context(key,u) select 'transfer_id',(j->>'entity_id')::uuid from test_transfer_context where key='request_result';
insert into test_transfer_context(key,u) select 'approval_id',(j->>'approval_request_id')::uuid from test_transfer_context where key='request_result';
select ok((select status='submitted' and amount_minor=5000 and fee_minor=125 and request_fingerprint=(select t from test_transfer_context where key='request_fp') from public.wallet_transfers where id=(select u from test_transfer_context where key='transfer_id')),'request freezes transfer principal, fee, and canonical fingerprint');
select is((select status::text from public.approval_requests where id=(select u from test_transfer_context where key='approval_id')),'submitted','request creates a separate approval envelope');

select set_config('request.jwt.claim.sub','19000000-0000-4000-8000-000000000001',true);set local role authenticated;
select throws_ok($$select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select u from test_transfer_context where key='approval_id'),'approve','Self approval attempt',null,'39000000-0000-4000-8000-000000000003')$$,'42501','Self-approval is not permitted','requester cannot approve their own transfer');reset role;

select set_config('request.jwt.claim.sub','19000000-0000-4000-8000-000000000002',true);set local role authenticated;
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select u from test_transfer_context where key='approval_id'),'approve','Independent transfer review',null,'39000000-0000-4000-8000-000000000004');
insert into test_transfer_context(key,j) select 'execute_result',api.transfer_between_wallets(
  '00000000-0000-4000-8000-00000000f001',(select u from test_transfer_context where key='transfer_id'),
  'wallet-transfer-execute-0001',(select t from test_transfer_context where key='request_fp'),'39000000-0000-4000-8000-000000000005');reset role;
select ok((select status='executed' and approved_by='19000000-0000-4000-8000-000000000002' and executed_by='19000000-0000-4000-8000-000000000002' from public.wallet_transfers where id=(select u from test_transfer_context where key='transfer_id')),'approved transfer executes with recorded reviewer and executor');
select is((select status::text from public.approval_requests where id=(select u from test_transfer_context where key='approval_id')),'consumed','transfer execution consumes approval exactly once');
select results_eq(
  $$select a.code,jl.debit_minor,jl.credit_minor from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id join accounting.accounts a on a.id=jl.account_id where je.source_type='wallet_transfer' and je.source_id=(select u from test_transfer_context where key='transfer_id') order by a.code$$,
  $$select * from(values('1100'::text,0::bigint,5125::bigint),('1110'::text,5000::bigint,0::bigint),('6290'::text,125::bigint,0::bigint))v(code,debit_minor,credit_minor)$$,
  'principal moves between wallet accounts and fee posts separately');
select is((select sum(jl.debit_minor-jl.credit_minor)::bigint from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id where je.source_type='wallet_transfer' and je.source_id=(select u from test_transfer_context where key='transfer_id') and jl.wallet_id is not null),(-125)::bigint,'wallet principal nets to zero apart from the explicit fee');
select is((select sum(jl.debit_minor-jl.credit_minor)::bigint from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id join accounting.accounts a on a.id=jl.account_id where je.source_type='wallet_transfer' and je.source_id=(select u from test_transfer_context where key='transfer_id') and a.account_type in('revenue','contra_revenue','expense')),125::bigint,'only the transfer fee affects profit');

select set_config('request.jwt.claim.sub','19000000-0000-4000-8000-000000000002',true);set local role authenticated;
insert into test_transfer_context(key,j) select 'replay_result',api.transfer_between_wallets(
  '00000000-0000-4000-8000-00000000f001',(select u from test_transfer_context where key='transfer_id'),
  'wallet-transfer-execute-0001',(select t from test_transfer_context where key='request_fp'),'39000000-0000-4000-8000-000000000006');reset role;
select is((select j->'journal_entry_ids'->>0 from test_transfer_context where key='replay_result'),(select j->'journal_entry_ids'->>0 from test_transfer_context where key='execute_result'),'same key and payload replay the stored transfer result');
select is((select count(*)::integer from accounting.journal_entries where source_type='wallet_transfer' and source_id=(select u from test_transfer_context where key='transfer_id')),1,'transfer replay creates no duplicate journal');
select * from finish();
rollback;
