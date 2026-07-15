begin;
set local search_path = public, extensions;
select plan(28);

create temporary table test_context (
  key text primary key,
  value_json jsonb,
  value_text text,
  value_uuid uuid,
  value_timestamptz timestamptz
);
grant all on table test_context to authenticated;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  is_sso_user, is_anonymous
)
values
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'moderator@phase2.test', crypt('phase2', gen_salt('bf')), statement_timestamp(),
   '{"provider":"email","providers":["email"]}', '{}', statement_timestamp(), statement_timestamp(),
   '', '', '', '', false, false),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'finance1@phase2.test', crypt('phase2', gen_salt('bf')), statement_timestamp(),
   '{"provider":"email","providers":["email"]}', '{}', statement_timestamp(), statement_timestamp(),
   '', '', '', '', false, false),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'finance2@phase2.test', crypt('phase2', gen_salt('bf')), statement_timestamp(),
   '{"provider":"email","providers":["email"]}', '{}', statement_timestamp(), statement_timestamp(),
   '', '', '', '', false, false);

update public.profiles
set status = 'active', activated_at = statement_timestamp(), activated_by = id
where id in (
  '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000003'
);

insert into private.user_roles (
  organization_id, user_id, role_id, effective_from, assigned_by, assignment_reason
)
select '00000000-0000-4000-8000-00000000f001', u.user_id, r.id,
       statement_timestamp() - interval '1 minute', u.user_id, 'Phase 2 workflow fixture'
from (values
  ('10000000-0000-4000-8000-000000000001'::uuid, 'moderator'::text),
  ('10000000-0000-4000-8000-000000000002'::uuid, 'finance_manager'::text),
  ('10000000-0000-4000-8000-000000000003'::uuid, 'finance_manager'::text)
) as u(user_id, role_key)
join private.roles as r
  on r.organization_id = '00000000-0000-4000-8000-00000000f001'
 and r.role_key = u.role_key;

insert into public.customers (
  id, organization_id, customer_number, full_name, created_by
) values (
  '20000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-00000000f001',
  'P2-CUSTOMER-1', 'Phase 2 Customer',
  '10000000-0000-4000-8000-000000000001'
);

insert into public.orders (
  id, organization_id, order_number, customer_id, assigned_moderator_id,
  created_by, order_source, order_type, status, payment_status,
  payment_policy_code_snapshot, payment_policy_version_snapshot,
  deposit_bps_snapshot, shipping_prepaid_required_snapshot,
  products_subtotal_minor, shipping_charge_minor, order_total_minor,
  required_deposit_minor, balance_due_minor
) values (
  '30000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-00000000f001', 'P2-ORDER-1',
  '20000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'phase2_fixture', 'ready_stock', 'new', 'no_payment',
  'fixture', '1', 5000, false, 10000, 0, 10000, 5000, 10000
);

insert into test_context(key, value_timestamptz)
values ('paid_at', date_trunc('minute', statement_timestamp()) - interval '1 minute');

insert into test_context(key, value_json)
select 'record_payload', jsonb_build_object(
  'organization_id', '00000000-0000-4000-8000-00000000f001'::uuid,
  'customer_id', '20000000-0000-4000-8000-000000000001'::uuid,
  'primary_order_id', null,
  'wallet_id', '00000000-0000-4000-8000-00000000f241'::uuid,
  'amount_minor', 15000,
  'payment_method', 'wallet',
  'external_transaction_reference', 'P2-PAYMENT-1',
  'provider_name_snapshot', 'Fixture provider',
  'paid_at', (select value_timestamptz from test_context where key = 'paid_at'),
  'evidence_attachment_id', null
);
insert into test_context(key, value_text)
select 'record_fp', private.canonical_request_fingerprint(
  'payments.record', value_json, 1::smallint
) from test_context where key = 'record_payload';

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
set local role authenticated;
insert into test_context(key, value_json)
select 'record_result', api.record_customer_payment(
  '00000000-0000-4000-8000-00000000f001',
  '20000000-0000-4000-8000-000000000001', null,
  '00000000-0000-4000-8000-00000000f241', 15000, 'wallet',
  'P2-PAYMENT-1', 'Fixture provider',
  (select value_timestamptz from test_context where key = 'paid_at'),
  null, 'payment-record-0001',
  (select value_text from test_context where key = 'record_fp'),
  '40000000-0000-4000-8000-000000000001'
);
reset role;
insert into test_context(key, value_uuid)
select 'payment_id', (value_json->>'entity_id')::uuid
from test_context where key = 'record_result';

select is(
  (select status::text from public.customer_payments where id = (select value_uuid from test_context where key = 'payment_id')),
  'pending_review', 'payment intake creates pending review evidence'
);

insert into test_context(key, value_json)
select 'confirm_payload', jsonb_build_object(
  'organization_id', '00000000-0000-4000-8000-00000000f001'::uuid,
  'customer_payment_id', value_uuid
) from test_context where key = 'payment_id';
insert into test_context(key, value_text)
select 'confirm_fp', private.canonical_request_fingerprint(
  'payments.confirm', value_json, 1::smallint
) from test_context where key = 'confirm_payload';

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
set local role authenticated;
insert into test_context(key, value_json)
select 'confirm_result', api.confirm_customer_payment(
  '00000000-0000-4000-8000-00000000f001',
  (select value_uuid from test_context where key = 'payment_id'),
  'payment-confirm-0001',
  (select value_text from test_context where key = 'confirm_fp'),
  '40000000-0000-4000-8000-000000000002'
);
reset role;

select is(
  (select status::text from public.customer_payments where id = (select value_uuid from test_context where key = 'payment_id')),
  'confirmed', 'separate finance actor confirms the receipt'
);
select ok(
  (select coalesce(sum(jl.debit_minor),0) = coalesce(sum(jl.credit_minor),0)
   from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id = je.id
   where je.source_type = 'customer_payment' and je.source_id = (select value_uuid from test_context where key = 'payment_id')),
  'receipt journal balances'
);

insert into test_context(key, value_json) values (
  'allocation_payload', jsonb_build_object(
    'organization_id', '00000000-0000-4000-8000-00000000f001'::uuid,
    'customer_payment_id', (select value_uuid from test_context where key = 'payment_id'),
    'allocations', jsonb_build_array(jsonb_build_object(
      'order_id', '30000000-0000-4000-8000-000000000001'::uuid,
      'allocation_type', 'product_deposit', 'amount_minor', 8000
    )),
    'credit_remainder', true
  )
);
insert into test_context(key, value_text)
select 'allocation_fp', private.canonical_request_fingerprint(
  'payments.allocate', value_json, 1::smallint
) from test_context where key = 'allocation_payload';

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
set local role authenticated;
insert into test_context(key, value_json)
select 'allocation_result', api.allocate_customer_payment(
  '00000000-0000-4000-8000-00000000f001',
  (select value_uuid from test_context where key = 'payment_id'),
  (select value_json->'allocations' from test_context where key = 'allocation_payload'),
  true, 'payment-allocate-0001',
  (select value_text from test_context where key = 'allocation_fp'),
  '40000000-0000-4000-8000-000000000003'
);
reset role;
insert into test_context(key, value_uuid)
select 'batch_id', (value_json->>'entity_id')::uuid
from test_context where key = 'allocation_result';
insert into test_context(key, value_uuid)
select 'credit_id', (value_json->>'customer_credit_id')::uuid
from test_context where key = 'allocation_result';

select is(
  (select allocated_to_orders_minor from public.payment_allocation_batches where id = (select value_uuid from test_context where key = 'batch_id')),
  8000::bigint, 'allocation batch conserves the order amount'
);
select is(
  (select original_amount_minor from public.customer_credits where id = (select value_uuid from test_context where key = 'credit_id')),
  7000::bigint, 'unallocated receipt remainder becomes customer credit'
);
select is(
  (select confirmed_payment_minor from public.orders where id = '30000000-0000-4000-8000-000000000001'),
  8000::bigint, 'order payment projection reflects confirmed allocation'
);

insert into test_context(key, value_json) values (
  'credit_apply_payload', jsonb_build_object(
    'organization_id', '00000000-0000-4000-8000-00000000f001'::uuid,
    'customer_credit_id', (select value_uuid from test_context where key = 'credit_id'),
    'order_id', '30000000-0000-4000-8000-000000000001'::uuid,
    'amount_minor', 2000
  )
);
insert into test_context(key, value_text)
select 'credit_apply_fp', private.canonical_request_fingerprint(
  'credits.apply', value_json, 1::smallint
) from test_context where key = 'credit_apply_payload';

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
set local role authenticated;
insert into test_context(key, value_json)
select 'credit_apply_result', api.apply_customer_credit(
  '00000000-0000-4000-8000-00000000f001',
  (select value_uuid from test_context where key = 'credit_id'),
  '30000000-0000-4000-8000-000000000001', 2000,
  'credit-apply-0001',
  (select value_text from test_context where key = 'credit_apply_fp'),
  '40000000-0000-4000-8000-000000000004'
);
reset role;

select is(
  (select confirmed_payment_minor from public.orders where id = '30000000-0000-4000-8000-000000000001'),
  10000::bigint, 'credit application fully funds the order'
);
select is(
  (select remaining_amount_minor from public.customer_credits where id = (select value_uuid from test_context where key = 'credit_id')),
  5000::bigint, 'credit remaining amount is conserved after application'
);

insert into test_context(key, value_json) values (
  'refund_request_payload', jsonb_build_object(
    'organization_id', '00000000-0000-4000-8000-00000000f001'::uuid,
    'customer_id', '20000000-0000-4000-8000-000000000001'::uuid,
    'order_id', null, 'customer_payment_id', null,
    'customer_credit_id', (select value_uuid from test_context where key = 'credit_id'),
    'requested_amount_minor', 5000, 'reason', 'Customer requested credit payout',
    'destination_method', 'wallet',
    'destination_reference_snapshot', 'customer-wallet-ending-1111'
  )
);
insert into test_context(key, value_text)
select 'refund_request_fp', private.canonical_request_fingerprint(
  'refunds.request', value_json, 1::smallint
) from test_context where key = 'refund_request_payload';

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
set local role authenticated;
insert into test_context(key, value_json)
select 'refund_request_result', api.request_customer_refund(
  '00000000-0000-4000-8000-00000000f001',
  '20000000-0000-4000-8000-000000000001', null, null,
  (select value_uuid from test_context where key = 'credit_id'), 5000,
  'Customer requested credit payout', 'wallet', 'customer-wallet-ending-1111',
  'refund-request-0001',
  (select value_text from test_context where key = 'refund_request_fp'),
  '40000000-0000-4000-8000-000000000005'
);
reset role;
insert into test_context(key, value_uuid)
select 'refund_id', (value_json->>'entity_id')::uuid
from test_context where key = 'refund_request_result';
insert into test_context(key, value_uuid)
select 'refund_approval_id', (value_json->>'approval_request_id')::uuid
from test_context where key = 'refund_request_result';

select is(
  (select status::text from public.approval_requests where id = (select value_uuid from test_context where key = 'refund_approval_id')),
  'submitted', 'refund request creates a bound approval request'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
set local role authenticated;
select api.decide_approval(
  '00000000-0000-4000-8000-00000000f001',
  (select value_uuid from test_context where key = 'refund_approval_id'),
  'approve', 'Approved fixture refund', null,
  '40000000-0000-4000-8000-000000000006'
);
reset role;

insert into test_context(key, value_json) values (
  'refund_approve_payload', jsonb_build_object(
    'organization_id', '00000000-0000-4000-8000-00000000f001'::uuid,
    'refund_id', (select value_uuid from test_context where key = 'refund_id')
  )
);
insert into test_context(key, value_text)
select 'refund_approve_fp', private.canonical_request_fingerprint(
  'refunds.approve', value_json, 1::smallint
) from test_context where key = 'refund_approve_payload';

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
set local role authenticated;
insert into test_context(key, value_json)
select 'refund_approve_result', api.approve_customer_refund(
  '00000000-0000-4000-8000-00000000f001',
  (select value_uuid from test_context where key = 'refund_id'),
  'refund-approve-0001',
  (select value_text from test_context where key = 'refund_approve_fp'),
  '40000000-0000-4000-8000-000000000007'
);
reset role;

select results_eq(
  $$ select r.status, ar.status::text from public.refunds r join public.approval_requests ar on ar.id = r.approval_request_id where r.id = (select value_uuid from test_context where key = 'refund_id') $$,
  $$ values ('approved'::text, 'consumed'::text) $$,
  'refund approval consumes its exact approval envelope'
);

insert into test_context(key, value_json) values (
  'refund_execute_payload', jsonb_build_object(
    'organization_id', '00000000-0000-4000-8000-00000000f001'::uuid,
    'refund_id', (select value_uuid from test_context where key = 'refund_id'),
    'source_wallet_id', '00000000-0000-4000-8000-00000000f241'::uuid,
    'external_transaction_reference', 'P2-REFUND-1',
    'evidence_attachment_id', null
  )
);
insert into test_context(key, value_text)
select 'refund_execute_fp', private.canonical_request_fingerprint(
  'refunds.execute', value_json, 1::smallint
) from test_context where key = 'refund_execute_payload';

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
set local role authenticated;
insert into test_context(key, value_json)
select 'refund_execute_result', api.execute_customer_refund(
  '00000000-0000-4000-8000-00000000f001',
  (select value_uuid from test_context where key = 'refund_id'),
  '00000000-0000-4000-8000-00000000f241', 'P2-REFUND-1', null,
  'refund-execute-0001',
  (select value_text from test_context where key = 'refund_execute_fp'),
  '40000000-0000-4000-8000-000000000008'
);
reset role;

select is(
  (select status from public.refunds where id = (select value_uuid from test_context where key = 'refund_id')),
  'executed', 'separate finance actor executes the approved refund'
);
select results_eq(
  $$ select remaining_amount_minor, status from public.customer_credits where id = (select value_uuid from test_context where key = 'credit_id') $$,
  $$ values (0::bigint, 'refunded'::text) $$,
  'credit refund closes the liability lot'
);
select is(
  (select coalesce(sum(amount_minor), 0)::numeric from public.customer_credit_movements where customer_credit_id = (select value_uuid from test_context where key = 'credit_id')),
  0::numeric, 'credit movement ledger conserves issued, applied, and refunded amounts'
);
select ok(
  not exists (
    select 1 from accounting.journal_entries je
    join accounting.journal_lines jl on jl.journal_entry_id = je.id
    where je.source_type in ('customer_payment','payment_allocation_batch','customer_credit_movement','refund')
    group by je.id having sum(jl.debit_minor) <> sum(jl.credit_minor)
  ), 'every workflow journal is balanced'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
set local role authenticated;
insert into test_context(key, value_json)
select 'allocation_replay_result', api.allocate_customer_payment(
  '00000000-0000-4000-8000-00000000f001',
  (select value_uuid from test_context where key = 'payment_id'),
  (select value_json->'allocations' from test_context where key = 'allocation_payload'),
  true, 'payment-allocate-0001',
  (select value_text from test_context where key = 'allocation_fp'),
  '40000000-0000-4000-8000-000000000099'
);
reset role;
select is(
  (select value_json->>'entity_id' from test_context where key = 'allocation_replay_result'),
  (select value_uuid::text from test_context where key = 'batch_id'),
  'idempotent replay returns the original allocation batch'
);

select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
set local role authenticated;
select throws_ok(
  $$ select api.allocate_customer_payment(
    '00000000-0000-4000-8000-00000000f001',
    (select value_uuid from test_context where key = 'payment_id'),
    '[{"order_id":"30000000-0000-4000-8000-000000000001","allocation_type":"product_deposit","amount_minor":7000}]'::jsonb,
    true, 'payment-allocate-0001', repeat('0',64),
    '40000000-0000-4000-8000-000000000100'
  ) $$,
  '22023', null, 'tampered allocation fingerprint is rejected'
);
reset role;

select is(
  (select count(*)::integer from public.profiles where status = 'active' and id::text like '10000000-%'),
  3, 'fixture uses three active database-authorized actors'
);
select ok(
  private.has_permission(
    '00000000-0000-4000-8000-00000000f001', 'payments.allocate'
  ), 'finance role receives the new allocation capability'
);
select ok(
  not has_table_privilege('authenticated', 'public.customer_payments', 'INSERT'),
  'authenticated callers cannot bypass payment commands with direct DML'
);
select ok(
  (select requested_by <> approved_by and approved_by <> executed_by
   from public.refunds where id = (select value_uuid from test_context where key = 'refund_id')),
  'refund request, approval, and execution use distinct actors'
);

insert into test_context(key,value_json) values(
  'refund_reverse_approval_payload',jsonb_build_object(
    'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,
    'refund_id',(select value_uuid from test_context where key='refund_id'),
    'reason','Correct synthetic refund execution'
  )
);
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
set local role authenticated;
insert into test_context(key,value_uuid)
select 'refund_reverse_approval_id',api.submit_approval_request(
  '00000000-0000-4000-8000-00000000f001','refund.reverse','refund',
  (select value_uuid from test_context where key='refund_id'),'refunds.reverse',
  'Correct synthetic refund execution',
  (select value_json from test_context where key='refund_reverse_approval_payload'),
  (select encode(digest(convert_to(value_json::text,'UTF8'),'sha256'),'hex') from test_context where key='refund_reverse_approval_payload'),
  5000,null,statement_timestamp()+interval '1 day'
);
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
set local role authenticated;
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select value_uuid from test_context where key='refund_reverse_approval_id'),'approve','Approve refund correction',null,'40000000-0000-4000-8000-000000000101');
reset role;
insert into test_context(key,value_json) select 'refund_reverse_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,
  'refund_id',(select value_uuid from test_context where key='refund_id'),
  'reason','Correct synthetic refund execution','approval_request_id',value_uuid
) from test_context where key='refund_reverse_approval_id';
insert into test_context(key,value_text) select 'refund_reverse_fp',private.canonical_request_fingerprint('refunds.reverse',value_json,1::smallint) from test_context where key='refund_reverse_payload';
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
set local role authenticated;
insert into test_context(key,value_json) select 'refund_reverse_result',api.reverse_customer_refund(
  '00000000-0000-4000-8000-00000000f001',(select value_uuid from test_context where key='refund_id'),
  'Correct synthetic refund execution',(select value_uuid from test_context where key='refund_reverse_approval_id'),
  'refund-reverse-0001',(select value_text from test_context where key='refund_reverse_fp'),
  '40000000-0000-4000-8000-000000000102'
);
reset role;
select is((select status from public.refunds where id=(select value_uuid from test_context where key='refund_id')),'reversed','approved refund reversal updates operational state');
select ok((select remaining_amount_minor=5000 and status='partially_used' from public.customer_credits where id=(select value_uuid from test_context where key='credit_id')),'refund reversal restores the unrefunded customer credit liability');
select is((select count(*)::integer from accounting.journal_entries where reversal_of in(
  (select execution_journal_entry_id from public.refunds where id=(select value_uuid from test_context where key='refund_id')),
  (select approval_journal_entry_id from public.refunds where id=(select value_uuid from test_context where key='refund_id'))
)),2,'refund reversal creates exact inverses for approval and execution journals');
select is((select status::text from public.approval_requests where id=(select value_uuid from test_context where key='refund_reverse_approval_id')),'consumed','refund reversal consumes its dedicated approval');

insert into test_context(key,value_json) select 'payment2_record_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,
  'customer_id','20000000-0000-4000-8000-000000000001'::uuid,'primary_order_id',null,
  'wallet_id','00000000-0000-4000-8000-00000000f241'::uuid,'amount_minor',1200,
  'payment_method','wallet','external_transaction_reference','P2-PAYMENT-REV-1',
  'provider_name_snapshot','Fixture provider','paid_at',value_timestamptz,'evidence_attachment_id',null
) from test_context where key='paid_at';
insert into test_context(key,value_text) select 'payment2_record_fp',private.canonical_request_fingerprint('payments.record',value_json,1::smallint) from test_context where key='payment2_record_payload';
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
set local role authenticated;
insert into test_context(key,value_json) select 'payment2_record_result',api.record_customer_payment(
  '00000000-0000-4000-8000-00000000f001','20000000-0000-4000-8000-000000000001',null,
  '00000000-0000-4000-8000-00000000f241',1200,'wallet','P2-PAYMENT-REV-1','Fixture provider',
  (select value_timestamptz from test_context where key='paid_at'),null,'payment2-record-0001',
  (select value_text from test_context where key='payment2_record_fp'),'40000000-0000-4000-8000-000000000103'
);
reset role;
insert into test_context(key,value_uuid) select 'payment2_id',(value_json->>'entity_id')::uuid from test_context where key='payment2_record_result';
insert into test_context(key,value_json) select 'payment2_confirm_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'customer_payment_id',value_uuid) from test_context where key='payment2_id';
insert into test_context(key,value_text) select 'payment2_confirm_fp',private.canonical_request_fingerprint('payments.confirm',value_json,1::smallint) from test_context where key='payment2_confirm_payload';
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select api.confirm_customer_payment('00000000-0000-4000-8000-00000000f001',(select value_uuid from test_context where key='payment2_id'),'payment2-confirm-0001',(select value_text from test_context where key='payment2_confirm_fp'),'40000000-0000-4000-8000-000000000104');
reset role;
insert into test_context(key,value_json) select 'payment_reverse_approval_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'customer_payment_id',value_uuid,
  'reason','Reverse unallocated synthetic receipt'
) from test_context where key='payment2_id';
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
set local role authenticated;
insert into test_context(key,value_uuid) select 'payment_reverse_approval_id',api.submit_approval_request(
  '00000000-0000-4000-8000-00000000f001','payment.reverse','customer_payment',
  (select value_uuid from test_context where key='payment2_id'),'payments.reverse','Reverse unallocated synthetic receipt',
  value_json,encode(digest(convert_to(value_json::text,'UTF8'),'sha256'),'hex'),1200,null,statement_timestamp()+interval '1 day'
) from test_context where key='payment_reverse_approval_payload';
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select value_uuid from test_context where key='payment_reverse_approval_id'),'approve','Approve receipt correction',null,'40000000-0000-4000-8000-000000000105');
reset role;
insert into test_context(key,value_json) select 'payment_reverse_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,
  'customer_payment_id',(select value_uuid from test_context where key='payment2_id'),
  'reason','Reverse unallocated synthetic receipt','approval_request_id',value_uuid
) from test_context where key='payment_reverse_approval_id';
insert into test_context(key,value_text) select 'payment_reverse_fp',private.canonical_request_fingerprint('payments.reverse',value_json,1::smallint) from test_context where key='payment_reverse_payload';
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
set local role authenticated;
insert into test_context(key,value_json) select 'payment_reverse_result',api.reverse_customer_payment(
  '00000000-0000-4000-8000-00000000f001',(select value_uuid from test_context where key='payment2_id'),
  'Reverse unallocated synthetic receipt',(select value_uuid from test_context where key='payment_reverse_approval_id'),
  'payment-reverse-0001',(select value_text from test_context where key='payment_reverse_fp'),
  '40000000-0000-4000-8000-000000000106'
);
reset role;
select is((select status::text from public.customer_payments where id=(select value_uuid from test_context where key='payment2_id')),'reversed','approved payment reversal updates receipt state');
select is((select count(*)::integer from public.payment_reversal_events where customer_payment_id=(select value_uuid from test_context where key='payment2_id')),1,'payment reversal records one immutable reversal event');
select ok((select exists(select 1 from accounting.journal_entries reversal join accounting.journal_entries original on original.id=reversal.reversal_of where original.source_type='customer_payment' and original.source_id=(select value_uuid from test_context where key='payment2_id'))),'payment reversal posts an exact inverse of the receipt journal');
select is((select status::text from public.approval_requests where id=(select value_uuid from test_context where key='payment_reverse_approval_id')),'consumed','payment reversal consumes its dedicated approval');

select * from finish();
rollback;
