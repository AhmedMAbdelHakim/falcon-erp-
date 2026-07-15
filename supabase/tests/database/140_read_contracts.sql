begin;
set local search_path = public, extensions;
select no_plan();

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at,
  confirmation_token,recovery_token,email_change_token_new,email_change,
  is_sso_user,is_anonymous
) values
('00000000-0000-0000-0000-000000000000','1e000000-0000-4000-8000-000000000001','authenticated','authenticated','read-finance@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','1e000000-0000-4000-8000-000000000002','authenticated','authenticated','read-partner@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','1e000000-0000-4000-8000-000000000003','authenticated','authenticated','read-auditor@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','1e000000-0000-4000-8000-000000000004','authenticated','authenticated','read-operations@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','1e000000-0000-4000-8000-000000000005','authenticated','authenticated','read-moderator@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','1e000000-0000-4000-8000-000000000006','authenticated','authenticated','read-only@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','1e000000-0000-4000-8000-000000000007','authenticated','authenticated','read-super@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','1e000000-0000-4000-8000-000000000008','authenticated','authenticated','read-norole@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);

update public.profiles
set status='active',activated_at=statement_timestamp(),activated_by=id
where id::text like '1e000000-%';

insert into private.user_roles(
  organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason
)
select '00000000-0000-4000-8000-00000000f001', fixture.user_id, role.id,
  statement_timestamp()-interval '1 minute',fixture.user_id,'Read contract fixture'
from (values
  ('1e000000-0000-4000-8000-000000000001'::uuid,'finance_manager'),
  ('1e000000-0000-4000-8000-000000000002'::uuid,'partner'),
  ('1e000000-0000-4000-8000-000000000003'::uuid,'auditor'),
  ('1e000000-0000-4000-8000-000000000004'::uuid,'operations'),
  ('1e000000-0000-4000-8000-000000000005'::uuid,'moderator'),
  ('1e000000-0000-4000-8000-000000000006'::uuid,'read_only'),
  ('1e000000-0000-4000-8000-000000000007'::uuid,'super_admin')
) as fixture(user_id,role_key)
join private.roles as role
  on role.organization_id='00000000-0000-4000-8000-00000000f001'
 and role.role_key=fixture.role_key;

insert into public.organizations(
  id,organization_code,display_name,legal_name,currency_code,timezone_name,is_default,is_active
) values(
  '1e000000-0000-4000-8000-000000000100','read_contract_other','Other synthetic org',
  'Other synthetic org','EGP','Africa/Cairo',false,true
);

insert into public.customers(
  id,organization_id,customer_number,full_name,phone_original,phone_normalized,
  assigned_to_user_id,created_by,updated_by
) values(
  '1e000000-0000-4000-8000-000000000110','00000000-0000-4000-8000-00000000f001',
  'READ-CUST-1','Synthetic read customer','01000000001','+201000000001',
  '1e000000-0000-4000-8000-000000000005','1e000000-0000-4000-8000-000000000005',
  '1e000000-0000-4000-8000-000000000005'
);

insert into accounting.journal_entries(
  id,organization_id,accounting_period_id,status,posting_date,accounting_date,
  description,source_type,source_id,posting_purpose,currency_code,
  total_debit_minor,total_credit_minor,idempotency_key,request_hash,correlation_id,
  created_by,posted_by,posted_at
)
select fixture.id,'00000000-0000-4000-8000-00000000f001',period.id,'draft',
  statement_timestamp(),(transaction_timestamp() at time zone 'Africa/Cairo')::date,
  fixture.description,fixture.source_type,fixture.source_id,fixture.purpose,'EGP',
  0,0,fixture.idempotency_key,repeat(fixture.hash_char,64),
  fixture.correlation_id,'1e000000-0000-4000-8000-000000000001',null::uuid,null::timestamptz
from (values
  ('1e000000-0000-4000-8000-000000000201'::uuid,'Synthetic delivery revenue','shipment_delivery','1e000000-0000-4000-8000-000000000301'::uuid,'revenue',10000::bigint,'read-revenue-001','a','1e000000-0000-4000-8000-000000000401'::uuid),
  ('1e000000-0000-4000-8000-000000000202'::uuid,'Synthetic customer deposit','customer_payment','1e000000-0000-4000-8000-000000000302'::uuid,'receipt',5000::bigint,'read-deposit-001','b','1e000000-0000-4000-8000-000000000402'::uuid),
  ('1e000000-0000-4000-8000-000000000203'::uuid,'Synthetic operating expense','expense','1e000000-0000-4000-8000-000000000303'::uuid,'approval',2000::bigint,'read-expense-001','c','1e000000-0000-4000-8000-000000000403'::uuid),
  ('1e000000-0000-4000-8000-000000000204'::uuid,'Synthetic wallet transfer','wallet_transfer','1e000000-0000-4000-8000-000000000304'::uuid,'transfer',1000::bigint,'read-transfer-001','d','1e000000-0000-4000-8000-000000000404'::uuid),
  ('1e000000-0000-4000-8000-000000000205'::uuid,'Synthetic partner withdrawal','partner_withdrawal','1e000000-0000-4000-8000-000000000305'::uuid,'withdrawal',500::bigint,'read-withdrawal-001','e','1e000000-0000-4000-8000-000000000405'::uuid),
  ('1e000000-0000-4000-8000-000000000206'::uuid,'Synthetic payroll accrual','payroll_period','1e000000-0000-4000-8000-000000000306'::uuid,'accrual',1000::bigint,'read-payroll-001','f','1e000000-0000-4000-8000-000000000406'::uuid)
) as fixture(id,description,source_type,source_id,purpose,amount_minor,idempotency_key,hash_char,correlation_id)
cross join lateral (
  select id from accounting.accounting_periods
  where organization_id='00000000-0000-4000-8000-00000000f001'
    and (transaction_timestamp() at time zone 'Africa/Cairo')::date between period_start and period_end
) as period;

insert into accounting.journal_lines(
  id,journal_entry_id,line_number,account_id,debit_minor,credit_minor,description,
  subledger_type,subledger_id,customer_id,partner_id,wallet_id
) values
('1e000000-0000-4000-8000-000000000501','1e000000-0000-4000-8000-000000000201',1,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='1100'),10000,0,'Wallet proceeds','shipment','1e000000-0000-4000-8000-000000000301',null,null,'00000000-0000-4000-8000-00000000f241'),
('1e000000-0000-4000-8000-000000000502','1e000000-0000-4000-8000-000000000201',2,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='4100'),0,10000,'Delivery revenue','shipment','1e000000-0000-4000-8000-000000000301',null,null,null),
('1e000000-0000-4000-8000-000000000503','1e000000-0000-4000-8000-000000000202',1,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='1100'),5000,0,'Deposit wallet','customer_payment','1e000000-0000-4000-8000-000000000302','1e000000-0000-4000-8000-000000000110',null,'00000000-0000-4000-8000-00000000f241'),
('1e000000-0000-4000-8000-000000000504','1e000000-0000-4000-8000-000000000202',2,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='2100'),0,5000,'Customer deposit liability','customer_payment','1e000000-0000-4000-8000-000000000302','1e000000-0000-4000-8000-000000000110',null,null),
('1e000000-0000-4000-8000-000000000505','1e000000-0000-4000-8000-000000000203',1,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='6200'),2000,0,'Operating expense','expense','1e000000-0000-4000-8000-000000000303',null,null,null),
('1e000000-0000-4000-8000-000000000506','1e000000-0000-4000-8000-000000000203',2,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='1100'),0,2000,'Expense payment','expense','1e000000-0000-4000-8000-000000000303',null,null,'00000000-0000-4000-8000-00000000f241'),
('1e000000-0000-4000-8000-000000000507','1e000000-0000-4000-8000-000000000204',1,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='1110'),1000,0,'Destination wallet','wallet_transfer','1e000000-0000-4000-8000-000000000304',null,null,'00000000-0000-4000-8000-00000000f242'),
('1e000000-0000-4000-8000-000000000508','1e000000-0000-4000-8000-000000000204',2,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='1100'),0,1000,'Source wallet','wallet_transfer','1e000000-0000-4000-8000-000000000304',null,null,'00000000-0000-4000-8000-00000000f241'),
('1e000000-0000-4000-8000-000000000509','1e000000-0000-4000-8000-000000000205',1,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='3200'),500,0,'Partner current account','partner_withdrawal','1e000000-0000-4000-8000-000000000305',null,'00000000-0000-4000-8000-00000000f251',null),
('1e000000-0000-4000-8000-000000000510','1e000000-0000-4000-8000-000000000205',2,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='1100'),0,500,'Withdrawal wallet','partner_withdrawal','1e000000-0000-4000-8000-000000000305',null,'00000000-0000-4000-8000-00000000f251','00000000-0000-4000-8000-00000000f241'),
('1e000000-0000-4000-8000-000000000511','1e000000-0000-4000-8000-000000000206',1,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='6100'),1000,0,'Payroll expense','payroll_period','1e000000-0000-4000-8000-000000000306',null,null,null),
('1e000000-0000-4000-8000-000000000512','1e000000-0000-4000-8000-000000000206',2,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='2230'),0,1000,'Payroll liability without employee dimension','payroll_period','1e000000-0000-4000-8000-000000000306',null,null,null);

update accounting.journal_entries as entry
set status='posted',
    total_debit_minor=totals.debit_minor,
    total_credit_minor=totals.credit_minor,
    posted_by='1e000000-0000-4000-8000-000000000001',
    posted_at=statement_timestamp()
from (
  select line.journal_entry_id,sum(line.debit_minor)::bigint as debit_minor,
    sum(line.credit_minor)::bigint as credit_minor
  from accounting.journal_lines as line
  where line.journal_entry_id::text like '1e000000-0000-4000-8000-00000000020_'
  group by line.journal_entry_id
) as totals
where entry.id=totals.journal_entry_id;

insert into accounting.journal_entries(
  id,organization_id,accounting_period_id,status,posting_date,accounting_date,
  description,source_type,source_id,posting_purpose,currency_code,total_debit_minor,
  total_credit_minor,idempotency_key,request_hash,correlation_id,created_by
)
select
  '1e000000-0000-4000-8000-000000000208','00000000-0000-4000-8000-00000000f001',
  period.id,'draft',statement_timestamp(),(transaction_timestamp() at time zone 'Africa/Cairo')::date,
  'Draft payroll must not appear in reports','payroll_period',
  '1e000000-0000-4000-8000-000000000308','accrual','EGP',0,0,
  'read-draft-001',repeat('8',64),'1e000000-0000-4000-8000-000000000408',
  '1e000000-0000-4000-8000-000000000001'
from accounting.accounting_periods as period
where period.organization_id='00000000-0000-4000-8000-00000000f001'
  and (transaction_timestamp() at time zone 'Africa/Cairo')::date between period.period_start and period.period_end;

insert into accounting.journal_lines(
  id,journal_entry_id,line_number,account_id,debit_minor,credit_minor,description,
  subledger_type,subledger_id
) values
('1e000000-0000-4000-8000-000000000515','1e000000-0000-4000-8000-000000000208',1,
 (select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='6100'),
 500,0,'Draft payroll expense','payroll_period','1e000000-0000-4000-8000-000000000308'),
('1e000000-0000-4000-8000-000000000516','1e000000-0000-4000-8000-000000000208',2,
 (select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='2230'),
 0,500,'Draft payroll payable','payroll_period','1e000000-0000-4000-8000-000000000308');

insert into accounting.accounting_periods(
  id,organization_id,period_start,period_end,status,closed_by,closed_at
) values(
  '1e000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-00000000f001',
  (date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)-interval '1 month')::date,
  (date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)-interval '1 day')::date,
  'closed','1e000000-0000-4000-8000-000000000001',statement_timestamp()
);

insert into accounting.journal_entries(
  id,organization_id,accounting_period_id,status,posting_date,accounting_date,
  description,source_type,source_id,posting_purpose,currency_code,total_debit_minor,
  total_credit_minor,idempotency_key,request_hash,correlation_id,created_by,posted_by,posted_at
) values(
  '1e000000-0000-4000-8000-000000000207','00000000-0000-4000-8000-00000000f001',
  '1e000000-0000-4000-8000-000000000601','draft',statement_timestamp(),
  (date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)-interval '1 month')::date,
  'Synthetic closed-period revenue','shipment_delivery','1e000000-0000-4000-8000-000000000307',
  'revenue','EGP',0,0,'read-closed-001',repeat('9',64),
  '1e000000-0000-4000-8000-000000000407','1e000000-0000-4000-8000-000000000001',
  null,null
);

insert into accounting.journal_lines(
  id,journal_entry_id,line_number,account_id,debit_minor,credit_minor,description,
  subledger_type,subledger_id,wallet_id
) values
('1e000000-0000-4000-8000-000000000513','1e000000-0000-4000-8000-000000000207',1,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='1100'),100,0,'Closed wallet proceeds','shipment','1e000000-0000-4000-8000-000000000307','00000000-0000-4000-8000-00000000f241'),
('1e000000-0000-4000-8000-000000000514','1e000000-0000-4000-8000-000000000207',2,(select id from accounting.accounts where organization_id='00000000-0000-4000-8000-00000000f001' and code='4100'),0,100,'Closed revenue','shipment','1e000000-0000-4000-8000-000000000307',null);

update accounting.journal_entries
set status='posted',total_debit_minor=100,total_credit_minor=100,
    posted_by='1e000000-0000-4000-8000-000000000001',posted_at=statement_timestamp()
where id='1e000000-0000-4000-8000-000000000207';

insert into accounting.monthly_closings(
  id,organization_id,accounting_period_id,status,checklist_version,
  trial_balance_debit_minor,trial_balance_credit_minor,period_revenue_minor,
  period_expense_minor,period_profit_loss_minor,cumulative_profit_loss_minor,
  prior_distributions_minor,protected_reserve_minor,distributable_profit_minor,
  settings_snapshot,reconciliation_snapshot,validation_result,requested_by,
  requested_at,validated_by,validated_at,approval_request_id,correlation_id
)
select
  '1e000000-0000-4000-8000-000000000610','00000000-0000-4000-8000-00000000f001',
  period.id,'ready',1,19500,19500,10000,3000,7000,7000,0,0,7000,
  '{"settings_version_no":1,"secret":"must-not-leak"}',
  '{"wallets":"checked"}',
  '{"ready":true,"path":"must-not-leak","source_checks":6}',
  '1e000000-0000-4000-8000-000000000001',statement_timestamp(),
  '1e000000-0000-4000-8000-000000000001',statement_timestamp(),null,
  '1e000000-0000-4000-8000-000000000411'
from accounting.accounting_periods as period
where period.organization_id='00000000-0000-4000-8000-00000000f001'
  and (transaction_timestamp() at time zone 'Africa/Cairo')::date between period.period_start and period.period_end;

insert into accounting.closing_checklist_items(
  id,monthly_closing_id,item_key,status,is_blocking,expected_minor,actual_minor,
  evidence,notes,checked_by,checked_at
) values
('1e000000-0000-4000-8000-000000000611','1e000000-0000-4000-8000-000000000610',
 'wallets','passed',true,12500,12500,
 '{"evidence_type":"reconciliation","path":"private/path","signed_url":"https://forbidden.test","token":"forbidden","checksum_sha256":"forbidden"}',
 'Synthetic evidence','1e000000-0000-4000-8000-000000000001',statement_timestamp()),
('1e000000-0000-4000-8000-000000000612','1e000000-0000-4000-8000-000000000610',
 'payroll','failed',true,0,1000,'{"evidence_type":"ledger_dimension"}',
 'Missing employee dimension fixture','1e000000-0000-4000-8000-000000000001',statement_timestamp());

insert into audit.events(
  id,organization_id,event_category,action,subject_type,subject_id,actor_type,
  actor_user_id,actor_role_keys,result,reason,correlation_id,before_state,after_state,
  event_metadata,request_ip,user_agent,occurred_at
) values
('1e000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-00000000f001',
 'financial_command','journal.posted','journal_entry','1e000000-0000-4000-8000-000000000201',
 'user','1e000000-0000-4000-8000-000000000001','["finance_manager"]','succeeded',
 'Synthetic audit reason','1e000000-0000-4000-8000-000000000401',
 '{"token":"raw-before"}','{"secret":"raw-after"}','{"provider_reference":"raw-metadata"}',
 '127.0.0.1','forbidden-agent',statement_timestamp()),
('1e000000-0000-4000-8000-000000000702','00000000-0000-4000-8000-00000000f001',
 'security','ledger.denied','journal_entry','1e000000-0000-4000-8000-000000000201',
 'user','1e000000-0000-4000-8000-000000000005','["moderator"]','denied',
 'Permission denied','1e000000-0000-4000-8000-000000000412','{}','{}','{}',
 '127.0.0.2','forbidden-agent-2',statement_timestamp()-interval '1 second');

select is(
  (select count(*)::integer from pg_proc as procedure
    join pg_namespace as namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='api' and procedure.proname in(
      'read_dashboard_summary','read_profit_and_loss','read_trial_balance',
      'read_control_account_reconciliation','read_liquidity_summary',
      'list_journal_entries','list_journal_lines','list_monthly_closes',
      'list_monthly_close_checklist','search_audit_events'
    )),10,'all ten typed read RPCs exist');

select is(
  (select count(*)::integer from pg_proc as procedure
    join pg_namespace as namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='api' and procedure.proname in(
      'read_dashboard_summary','read_profit_and_loss','read_trial_balance',
      'read_control_account_reconciliation','read_liquidity_summary',
      'list_journal_entries','list_journal_lines','list_monthly_closes',
      'list_monthly_close_checklist','search_audit_events'
    ) and not procedure.prosecdef and procedure.proconfig @> array['search_path=""']),10,
  'API read wrappers are security-invoker functions with an empty search path');

select is(
  (select count(*)::integer from pg_proc as procedure
    join pg_namespace as namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='api' and procedure.proname in(
      'read_dashboard_summary','read_profit_and_loss','read_trial_balance',
      'read_control_account_reconciliation','read_liquidity_summary',
      'list_journal_entries','list_journal_lines','list_monthly_closes',
      'list_monthly_close_checklist','search_audit_events'
    ) and has_function_privilege('authenticated',procedure.oid,'EXECUTE')
      and not has_function_privilege('anon',procedure.oid,'EXECUTE')),10,
  'only authenticated receives the exposed read RPC grants');

select set_config('request.jwt.claim.sub','1e000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select lives_ok($$select * from api.read_dashboard_summary('00000000-0000-4000-8000-00000000f001',date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)::date,(transaction_timestamp() at time zone 'Africa/Cairo')::date)$$,'finance reads dashboard');
select lives_ok($$select * from api.read_profit_and_loss('00000000-0000-4000-8000-00000000f001',date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)::date,(transaction_timestamp() at time zone 'Africa/Cairo')::date)$$,'finance reads P&L');
select lives_ok($$select * from api.read_trial_balance('00000000-0000-4000-8000-00000000f001',date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)::date,(transaction_timestamp() at time zone 'Africa/Cairo')::date)$$,'finance reads trial balance');
select lives_ok($$select * from api.read_control_account_reconciliation('00000000-0000-4000-8000-00000000f001',(transaction_timestamp() at time zone 'Africa/Cairo')::date)$$,'finance reads control reconciliation');
select lives_ok($$select * from api.read_liquidity_summary('00000000-0000-4000-8000-00000000f001',(transaction_timestamp() at time zone 'Africa/Cairo')::date)$$,'finance reads liquidity');
select lives_ok($$select * from api.list_journal_entries('00000000-0000-4000-8000-00000000f001')$$,'finance reads journal headers');
select lives_ok($$select * from api.list_journal_lines('00000000-0000-4000-8000-00000000f001','1e000000-0000-4000-8000-000000000201')$$,'finance reads journal lines');
select lives_ok($$select * from api.list_monthly_closes('00000000-0000-4000-8000-00000000f001')$$,'finance reads monthly closes');
select lives_ok($$select * from api.list_monthly_close_checklist('00000000-0000-4000-8000-00000000f001','1e000000-0000-4000-8000-000000000610')$$,'finance reads close checklist');
select throws_ok($$select * from api.search_audit_events('00000000-0000-4000-8000-00000000f001')$$,'42501','Permission denied','finance cannot read unrestricted audit');

select ok((select gross_revenue_minor=10000 and contra_revenue_minor=0
  and expense_minor=3000 and profit_loss_minor=7000
  and wallet_book_balance_minor=12600 and protected_liabilities_minor=6000
  and safe_cash_minor=6600
  from api.read_dashboard_summary(
    '00000000-0000-4000-8000-00000000f001',
    date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)::date,
    (transaction_timestamp() at time zone 'Africa/Cairo')::date
  )),'dashboard derives financial truth from ledger and excludes deposits, transfers, and withdrawals from P&L');

select ok((select gross_revenue_minor=10000 and expense_minor=3000 and profit_loss_minor=7000
  from api.read_profit_and_loss(
    '00000000-0000-4000-8000-00000000f001',
    date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)::date,
    (transaction_timestamp() at time zone 'Africa/Cairo')::date
  )),'P&L reconciles to posted ledger account types');

select ok((select sum(period_debit_minor)=sum(period_credit_minor)
  and sum(closing_debit_minor)=sum(closing_credit_minor)
  from api.read_trial_balance(
    '00000000-0000-4000-8000-00000000f001',
    date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)::date,
    (transaction_timestamp() at time zone 'Africa/Cairo')::date
  )),'trial balance debit and credit totals reconcile');

select ok((select difference_minor=1000 and reconciliation_status='difference'
  from api.read_control_account_reconciliation(
    '00000000-0000-4000-8000-00000000f001',
    (transaction_timestamp() at time zone 'Africa/Cairo')::date
  ) where account_role='payroll_payable'),
  'control reconciliation exposes a missing payroll dimension without employee PII');

select ok(not exists(select 1 from api.read_control_account_reconciliation(
    '00000000-0000-4000-8000-00000000f001',
    (transaction_timestamp() at time zone 'Africa/Cairo')::date
  ) where account_role<>'payroll_payable' and difference_minor<>0),
  'all fully dimensioned control accounts reconcile to ledger');

select is((select sum(book_balance_minor)::bigint from api.read_liquidity_summary(
  '00000000-0000-4000-8000-00000000f001',
  (transaction_timestamp() at time zone 'Africa/Cairo')::date
)),12600::bigint,'wallet liquidity book balance equals cumulative wallet-dimension ledger lines');

select is((select count(*)::integer from api.list_journal_entries(
  '00000000-0000-4000-8000-00000000f001',null,null,null,null,null,null,2
)),2,'journal keyset first page obeys page size');

select is((select count(*)::integer from api.list_journal_entries(
  '00000000-0000-4000-8000-00000000f001',null,null,null,'customer_payment',null,null,50
)),1,'journal source filter executes server-side');

select is((select count(*)::integer from api.list_journal_lines(
  '00000000-0000-4000-8000-00000000f001','1e000000-0000-4000-8000-000000000201',1::smallint,100
)),1,'journal line cursor returns only following lines');

select ok((select sum(debit_minor)=sum(credit_minor) from api.list_journal_lines(
  '00000000-0000-4000-8000-00000000f001','1e000000-0000-4000-8000-000000000201'
)),'journal detail reconciles its lines');

select is((select count(*)::integer from api.list_journal_entries(
  '00000000-0000-4000-8000-00000000f001',(current_date+interval '1 year')::date,(current_date+interval '1 year')::date
)),0,'journal empty range returns an empty set');

select ok((select period_status='closed' and gross_revenue_minor=100
  from api.read_profit_and_loss(
    '00000000-0000-4000-8000-00000000f001',
    (date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)-interval '1 month')::date,
    (date_trunc('month',(transaction_timestamp() at time zone 'Africa/Cairo')::date)-interval '1 day')::date
  )),'closed-period P&L remains readable with explicit period state');

select ok((select closing_status='ready' and period_profit_loss_minor=7000
  and validation_summary ? 'source_checks' and not validation_summary ? 'path'
  from api.list_monthly_closes('00000000-0000-4000-8000-00000000f001','ready')),
  'monthly close exposes computed results and masks forbidden validation metadata');

select ok((select evidence_metadata ? 'evidence_type'
  and not evidence_metadata ? 'path' and not evidence_metadata ? 'signed_url'
  and not evidence_metadata ? 'token' and not evidence_metadata ? 'checksum_sha256'
  from api.list_monthly_close_checklist(
    '00000000-0000-4000-8000-00000000f001','1e000000-0000-4000-8000-000000000610','passed'
  )),'checklist evidence metadata omits attachment and secret-bearing fields');

select is((select count(*)::integer from api.list_monthly_close_checklist(
  '00000000-0000-4000-8000-00000000f001','1e000000-0000-4000-8000-000000000699'
)),0,'unknown close checklist returns an empty set');

select throws_ok($$select * from accounting.journal_entries$$,'42501',null,
  'finance cannot directly read private ledger tables');
select throws_ok($$select * from audit.events$$,'42501',null,
  'finance cannot directly read private audit tables');
reset role;

select set_config('request.jwt.claim.sub','1e000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select lives_ok($$select * from api.read_dashboard_summary('00000000-0000-4000-8000-00000000f001',current_date,current_date)$$,'partner reads authorized financial dashboard');
select lives_ok($$select * from api.list_journal_entries('00000000-0000-4000-8000-00000000f001')$$,'partner reads authorized ledger');
select lives_ok($$select * from api.read_liquidity_summary('00000000-0000-4000-8000-00000000f001',current_date)$$,'partner reads liquidity summary');
select throws_ok($$select * from api.search_audit_events('00000000-0000-4000-8000-00000000f001')$$,'42501','Permission denied','partner cannot read unrestricted audit');
reset role;

select set_config('request.jwt.claim.sub','1e000000-0000-4000-8000-000000000003',true);
set local role authenticated;
select lives_ok($$select * from api.read_dashboard_summary('00000000-0000-4000-8000-00000000f001',current_date,current_date)$$,'auditor reads authorized financial dashboard');
select lives_ok($$select * from api.list_journal_entries('00000000-0000-4000-8000-00000000f001')$$,'auditor reads ledger');
select lives_ok($$select * from api.read_liquidity_summary('00000000-0000-4000-8000-00000000f001',current_date)$$,'auditor reads liquidity from ledger permission');
select lives_ok($$select * from api.search_audit_events('00000000-0000-4000-8000-00000000f001')$$,'auditor reads scoped audit timeline');
select is((select count(*)::integer from api.search_audit_events(
  '00000000-0000-4000-8000-00000000f001',null,null,null,'journal.posted',null,null,null,null,null,null,50
)),1,'audit action filter executes server-side');
select ok((select has_state_change and has_metadata
  from api.search_audit_events(
    '00000000-0000-4000-8000-00000000f001',null,null,null,'journal.posted'
  )),'audit contract reports state/metadata presence without exposing raw payloads');
select is((select count(*)::integer from api.search_audit_events(
  '00000000-0000-4000-8000-00000000f001',null,null,null,null,null,null,null,null,null,null,1
)),1,'audit keyset first page obeys page size');
select is((select count(*)::integer from api.search_audit_events(
  '00000000-0000-4000-8000-00000000f001',null,null,'missing-category'
)),0,'audit empty filter returns an empty set');
reset role;

select set_config('request.jwt.claim.sub','1e000000-0000-4000-8000-000000000007',true);
set local role authenticated;
select lives_ok($$select * from api.read_dashboard_summary('00000000-0000-4000-8000-00000000f001',current_date,current_date)$$,'super admin reads authorized financial dashboard');
select lives_ok($$select * from api.list_journal_entries('00000000-0000-4000-8000-00000000f001')$$,'super admin reads ledger');
select lives_ok($$select * from api.read_liquidity_summary('00000000-0000-4000-8000-00000000f001',current_date)$$,'super admin reads liquidity');
select lives_ok($$select * from api.search_audit_events('00000000-0000-4000-8000-00000000f001')$$,'super admin reads audit');
reset role;

select set_config('request.jwt.claim.sub','1e000000-0000-4000-8000-000000000006',true);
set local role authenticated;
select lives_ok($$select * from api.read_liquidity_summary('00000000-0000-4000-8000-00000000f001',current_date)$$,'read-only role reads non-sensitive liquidity summary');
select throws_ok($$select * from api.read_dashboard_summary('00000000-0000-4000-8000-00000000f001',current_date,current_date)$$,'42501','Permission denied','read-only role cannot read confidential dashboard profit');
select throws_ok($$select * from api.list_journal_entries('00000000-0000-4000-8000-00000000f001')$$,'42501','Permission denied','read-only role cannot read ledger details');
select throws_ok($$select * from api.search_audit_events('00000000-0000-4000-8000-00000000f001')$$,'42501','Permission denied','read-only role cannot read audit');
reset role;

select set_config('request.jwt.claim.sub','1e000000-0000-4000-8000-000000000004',true);
set local role authenticated;
select throws_ok($$select * from api.read_dashboard_summary('00000000-0000-4000-8000-00000000f001',current_date,current_date)$$,'42501','Permission denied','operations cannot read confidential profit');
select throws_ok($$select * from api.read_liquidity_summary('00000000-0000-4000-8000-00000000f001',current_date)$$,'42501','Permission denied','operations cannot read wallet balances');
select throws_ok($$select * from api.list_journal_entries('00000000-0000-4000-8000-00000000f001')$$,'42501','Permission denied','operations cannot read ledger');
select throws_ok($$select * from api.read_control_account_reconciliation('00000000-0000-4000-8000-00000000f001',current_date)$$,'42501','Permission denied','operations cannot read payroll or partner aggregates');
select throws_ok($$select * from api.search_audit_events('00000000-0000-4000-8000-00000000f001')$$,'42501','Permission denied','operations cannot read unrestricted audit');
reset role;

select set_config('request.jwt.claim.sub','1e000000-0000-4000-8000-000000000005',true);
set local role authenticated;
select throws_ok($$select * from api.read_dashboard_summary('00000000-0000-4000-8000-00000000f001',current_date,current_date)$$,'42501','Permission denied','moderator cannot read confidential profit');
select throws_ok($$select * from api.read_liquidity_summary('00000000-0000-4000-8000-00000000f001',current_date)$$,'42501','Permission denied','moderator cannot read wallet balances');
select throws_ok($$select * from api.list_journal_entries('00000000-0000-4000-8000-00000000f001')$$,'42501','Permission denied','moderator cannot read ledger');
select throws_ok($$select * from api.read_control_account_reconciliation('00000000-0000-4000-8000-00000000f001',current_date)$$,'42501','Permission denied','moderator cannot read payroll or partner aggregates');
select throws_ok($$select * from api.search_audit_events('00000000-0000-4000-8000-00000000f001')$$,'42501','Permission denied','moderator cannot read audit');
reset role;

select set_config('request.jwt.claim.sub','1e000000-0000-4000-8000-000000000008',true);
set local role authenticated;
select throws_ok($$select * from api.read_dashboard_summary('00000000-0000-4000-8000-00000000f001',current_date,current_date)$$,'42501','Permission denied','user without an active role receives no financial data');
select throws_ok($$select * from api.read_liquidity_summary('00000000-0000-4000-8000-00000000f001',current_date)$$,'42501','Permission denied','user without an active role receives no liquidity data');
select throws_ok($$select * from api.search_audit_events('00000000-0000-4000-8000-00000000f001')$$,'42501','Permission denied','user without an active role receives no audit data');
reset role;

select set_config('request.jwt.claim.sub','1e000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select throws_ok($$select * from api.read_dashboard_summary('1e000000-0000-4000-8000-000000000100',current_date,current_date)$$,'42501','Permission denied','cross-organization dashboard read fails');
select throws_ok($$select * from api.list_journal_entries('1e000000-0000-4000-8000-000000000100')$$,'42501','Permission denied','cross-organization ledger read fails');
select throws_ok($$select * from api.search_audit_events('1e000000-0000-4000-8000-000000000100')$$,'42501','Permission denied','cross-organization audit read fails');
reset role;

select ok(position('before_state' in pg_get_function_result('api.search_audit_events(uuid,timestamptz,timestamptz,text,text,text,text,uuid,uuid,timestamptz,uuid,integer)'::regprocedure))=0
  and position('after_state' in pg_get_function_result('api.search_audit_events(uuid,timestamptz,timestamptz,text,text,text,text,uuid,uuid,timestamptz,uuid,integer)'::regprocedure))=0
  and position('request_ip' in pg_get_function_result('api.search_audit_events(uuid,timestamptz,timestamptz,text,text,text,text,uuid,uuid,timestamptz,uuid,integer)'::regprocedure))=0
  and position('user_agent' in pg_get_function_result('api.search_audit_events(uuid,timestamptz,timestamptz,text,text,text,text,uuid,uuid,timestamptz,uuid,integer)'::regprocedure))=0,
  'audit return type omits raw state, IP, and user-agent fields');

select ok(position('employee_id' in pg_get_function_result('api.read_control_account_reconciliation(uuid,date)'::regprocedure))=0
  and position('partner_id' in pg_get_function_result('api.read_control_account_reconciliation(uuid,date)'::regprocedure))=0,
  'aggregate reconciliation omits employee and partner identity fields');

select * from finish();
rollback;
