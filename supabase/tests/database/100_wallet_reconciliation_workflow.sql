begin;
set local search_path=public,extensions;
select plan(13);

create temporary table test_wallet_context(key text primary key,j jsonb,u uuid,t text);
grant all on test_wallet_context to authenticated;

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous) values
('00000000-0000-0000-0000-000000000000','16000000-0000-4000-8000-000000000001','authenticated','authenticated','wallet1@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','16000000-0000-4000-8000-000000000002','authenticated','authenticated','wallet2@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id::text like '16000000-%';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '00000000-0000-4000-8000-00000000f001',x.uid,r.id,statement_timestamp()-interval '1 minute',x.uid,'Wallet reconciliation fixture'
from(values('16000000-0000-4000-8000-000000000001'::uuid,'super_admin'),('16000000-0000-4000-8000-000000000002'::uuid,'super_admin'))x(uid,role_key)
join private.roles r on r.organization_id='00000000-0000-4000-8000-00000000f001' and r.role_key=x.role_key;

insert into test_wallet_context(key,j) values('capital_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,
  'partner_id','00000000-0000-4000-8000-00000000f251'::uuid,
  'wallet_id','00000000-0000-4000-8000-00000000f241'::uuid,
  'amount_minor',1000,'reason','Wallet reconciliation movement fixture','evidence_attachment_id',null));
insert into test_wallet_context(key,t) select 'capital_fp',private.canonical_request_fingerprint('partners.capital.record',j,1::smallint) from test_wallet_context where key='capital_payload';
select set_config('request.jwt.claim.sub','16000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_wallet_context(key,j) select 'capital_result',api.record_partner_capital(
  '00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f251',
  '00000000-0000-4000-8000-00000000f241',1000,'Wallet reconciliation movement fixture',null,
  'wallet-reconcile-capital-0001',(select t from test_wallet_context where key='capital_fp'),
  '38000000-0000-4000-8000-000000000001');reset role;
select ok((select (j->>'success')::boolean from test_wallet_context where key='capital_result'),'fixture posts a real wallet movement through its business command');

insert into test_wallet_context(key,j) select 'prepare_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,
  'wallet_id','00000000-0000-4000-8000-00000000f241'::uuid,
  'period_started_at',date_trunc('month',statement_timestamp()),
  'period_ended_at',statement_timestamp()+interval '1 minute',
  'actual_closing_balance_minor',900,'evidence_attachment_id',null,
  'difference_explanation','Provider balance is EGP 1.00 below the ledger');
insert into test_wallet_context(key,t) select 'prepare_fp',private.canonical_request_fingerprint('wallets.reconcile.prepare',j,1::smallint) from test_wallet_context where key='prepare_payload';
select set_config('request.jwt.claim.sub','16000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_wallet_context(key,j) select 'prepare_result',api.prepare_wallet_reconciliation(
  '00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f241',
  (select (j->>'period_started_at')::timestamptz from test_wallet_context where key='prepare_payload'),
  (select (j->>'period_ended_at')::timestamptz from test_wallet_context where key='prepare_payload'),
  900,null,'Provider balance is EGP 1.00 below the ledger','wallet-reconcile-prepare-0001',
  (select t from test_wallet_context where key='prepare_fp'),'38000000-0000-4000-8000-000000000002');reset role;
insert into test_wallet_context(key,u) select 'reconciliation_id',(j->>'entity_id')::uuid from test_wallet_context where key='prepare_result';
insert into test_wallet_context(key,u) select 'approval_id',(j->>'approval_request_id')::uuid from test_wallet_context where key='prepare_result';
select ok((select status='prepared' and opening_book_balance_minor=0 and system_movements_minor=1000 and expected_closing_balance_minor=1000 and actual_closing_balance_minor=900 and difference_minor=-100 from public.wallet_reconciliations where id=(select u from test_wallet_context where key='reconciliation_id')),'preparation derives all book totals and the difference from posted ledger lines');
select is((select count(*)::integer from public.wallet_reconciliation_items where wallet_reconciliation_id=(select u from test_wallet_context where key='reconciliation_id') and source_type='partner_capital' and movement_amount_minor=1000 and book_balance_after_minor=1000),1,'preparation freezes source movement and running balance');
select is((select status::text from public.approval_requests where id=(select u from test_wallet_context where key='approval_id')),'submitted','preparation creates an immutable approval envelope');

insert into test_wallet_context(key,j) select 'finalize_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'wallet_reconciliation_id',u) from test_wallet_context where key='reconciliation_id';
insert into test_wallet_context(key,t) select 'finalize_fp',private.canonical_request_fingerprint('wallets.reconcile.finalize',j,1::smallint) from test_wallet_context where key='finalize_payload';
select set_config('request.jwt.claim.sub','16000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_wallet_context(key,j) select 'self_finalize_result',api.finalize_wallet_reconciliation(
  '00000000-0000-4000-8000-00000000f001',(select u from test_wallet_context where key='reconciliation_id'),
  'wallet-reconcile-self-finalize-0001',(select t from test_wallet_context where key='finalize_fp'),
  '38000000-0000-4000-8000-000000000003');reset role;
select is((select j->>'error_code' from test_wallet_context where key='self_finalize_result'),'WALLET_RECONCILIATION_FINALIZE_REJECTED','preparer cannot finalize their own reconciliation');

select set_config('request.jwt.claim.sub','16000000-0000-4000-8000-000000000002',true);set local role authenticated;
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select u from test_wallet_context where key='approval_id'),'approve','Provider evidence reviewed',null,'38000000-0000-4000-8000-000000000004');
insert into test_wallet_context(key,j) select 'finalize_result',api.finalize_wallet_reconciliation(
  '00000000-0000-4000-8000-00000000f001',(select u from test_wallet_context where key='reconciliation_id'),
  'wallet-reconcile-finalize-0001',(select t from test_wallet_context where key='finalize_fp'),
  '38000000-0000-4000-8000-000000000005');reset role;
select ok((select status='finalized' and reviewed_by='16000000-0000-4000-8000-000000000002' and adjustment_reference_type='journal_entry' and adjustment_reference_id is not null from public.wallet_reconciliations where id=(select u from test_wallet_context where key='reconciliation_id')),'separate reviewer finalizes and links the variance journal');
select is((select status::text from public.approval_requests where id=(select u from test_wallet_context where key='approval_id')),'consumed','finalization atomically consumes approval');
select ok((select je.status='posted' and je.total_debit_minor=100 and je.total_credit_minor=100 from accounting.journal_entries je where je.id=(select adjustment_reference_id from public.wallet_reconciliations where id=(select u from test_wallet_context where key='reconciliation_id'))),'difference posts one balanced approved adjustment');
select is((select coalesce(sum(jl.debit_minor-jl.credit_minor),0)::bigint from accounting.journal_lines jl join accounting.journal_entries je on je.id=jl.journal_entry_id where je.organization_id='00000000-0000-4000-8000-00000000f001' and je.status='posted' and jl.wallet_id='00000000-0000-4000-8000-00000000f241'),900::bigint,'authoritative wallet ledger equals provider balance');
select is((select coalesce(sum(jl.debit_minor-jl.credit_minor),0)::bigint from accounting.journal_lines jl join accounting.journal_entries je on je.id=jl.journal_entry_id join accounting.accounts a on a.id=jl.account_id where je.source_type='wallet_reconciliation' and je.source_id=(select u from test_wallet_context where key='reconciliation_id') and a.code='5295'),100::bigint,'wallet shortage debits dedicated variance account');

select set_config('request.jwt.claim.sub','16000000-0000-4000-8000-000000000002',true);set local role authenticated;
insert into test_wallet_context(key,j) select 'replay_result',api.finalize_wallet_reconciliation(
  '00000000-0000-4000-8000-00000000f001',(select u from test_wallet_context where key='reconciliation_id'),
  'wallet-reconcile-finalize-0001',(select t from test_wallet_context where key='finalize_fp'),
  '38000000-0000-4000-8000-000000000006');reset role;
select is((select j->'journal_entry_ids'->>0 from test_wallet_context where key='replay_result'),(select j->'journal_entry_ids'->>0 from test_wallet_context where key='finalize_result'),'same key and payload replay stored outcome');
select is((select count(*)::integer from accounting.journal_entries where source_type='wallet_reconciliation' and source_id=(select u from test_wallet_context where key='reconciliation_id')),1,'replay creates no duplicate adjustment');
select ok((select count(*)>=2 from audit.events where organization_id='00000000-0000-4000-8000-00000000f001' and action in('wallets.reconcile.prepare','wallets.reconcile.finalize')),'workflow emits append-only audit evidence');

select * from finish();
rollback;
