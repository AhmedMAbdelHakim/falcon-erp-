begin;
set local search_path=public,extensions;
select plan(14);

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous) values
('00000000-0000-0000-0000-000000000000','1a000000-0000-4000-8000-000000000001','authenticated','authenticated','mod1@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','1a000000-0000-4000-8000-000000000002','authenticated','authenticated','mod2@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','1a000000-0000-4000-8000-000000000003','authenticated','authenticated','finance@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','1a000000-0000-4000-8000-000000000004','authenticated','authenticated','partner@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id::text like '1a000000-%';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '00000000-0000-4000-8000-00000000f001',x.uid,r.id,statement_timestamp()-interval '1 minute',x.uid,'RLS fixture'
from(values
 ('1a000000-0000-4000-8000-000000000001'::uuid,'moderator'),
 ('1a000000-0000-4000-8000-000000000002'::uuid,'moderator'),
 ('1a000000-0000-4000-8000-000000000003'::uuid,'finance_manager'),
 ('1a000000-0000-4000-8000-000000000004'::uuid,'partner')
)x(uid,role_key) join private.roles r on r.organization_id='00000000-0000-4000-8000-00000000f001' and r.role_key=x.role_key;
update public.partners set profile_id='1a000000-0000-4000-8000-000000000004' where id='00000000-0000-4000-8000-00000000f251';

insert into public.customers(id,organization_id,customer_number,full_name,phone_original,phone_normalized,assigned_to_user_id,created_by,updated_by) values
('1a000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-00000000f001','RLS-CUST-1','Assigned Customer 1','01010000001','+201010000001','1a000000-0000-4000-8000-000000000001','1a000000-0000-4000-8000-000000000001','1a000000-0000-4000-8000-000000000001'),
('1a000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-00000000f001','RLS-CUST-2','Assigned Customer 2','01010000002','+201010000002','1a000000-0000-4000-8000-000000000002','1a000000-0000-4000-8000-000000000002','1a000000-0000-4000-8000-000000000002');
insert into public.orders(id,organization_id,order_number,customer_id,assigned_moderator_id,created_by,order_source,order_type,status,payment_status,payment_policy_code_snapshot,payment_policy_version_snapshot,deposit_bps_snapshot,shipping_prepaid_required_snapshot,products_subtotal_minor,shipping_charge_minor,order_total_minor,required_deposit_minor,balance_due_minor) values
('1a000000-0000-4000-8000-000000000020','00000000-0000-4000-8000-00000000f001','RLS-ORDER-1','1a000000-0000-4000-8000-000000000010','1a000000-0000-4000-8000-000000000001','1a000000-0000-4000-8000-000000000001','rls_fixture','ready_stock','new','no_payment','fixture','1',5000,false,1000,0,1000,500,1000),
('1a000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-00000000f001','RLS-ORDER-2','1a000000-0000-4000-8000-000000000011','1a000000-0000-4000-8000-000000000002','1a000000-0000-4000-8000-000000000002','rls_fixture','ready_stock','new','no_payment','fixture','1',5000,false,1000,0,1000,500,1000);

select set_config('request.jwt.claim.sub','1a000000-0000-4000-8000-000000000001',true);set local role authenticated;
select is((select count(*)::integer from public.orders where order_number like 'RLS-ORDER-%'),1,'moderator sees only their assigned order');
select is((select max(order_number) from public.orders where order_number like 'RLS-ORDER-%'),'RLS-ORDER-1','moderator cannot infer the other assigned order');
select is((select count(*)::integer from public.customers where customer_number like 'RLS-CUST-%'),1,'moderator sees only their assigned customer');
select is((select count(*)::integer from public.wallets),0,'moderator cannot read wallet balances or metadata');
select is((select count(*)::integer from public.payroll_entries),0,'moderator cannot read payroll');
select is((select count(*)::integer from public.partner_capital_transactions),0,'moderator cannot read partner accounts');
select throws_ok($$insert into public.customer_payments(organization_id,customer_id,wallet_id,amount_minor,payment_method,paid_at,recorded_by,status,idempotency_key,request_fingerprint,correlation_id)values('00000000-0000-4000-8000-00000000f001','1a000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-00000000f241',1,'cash',statement_timestamp(),'1a000000-0000-4000-8000-000000000001','pending_review','rls-bypass-payment',repeat('a',64),gen_random_uuid())$$,'42501',null,'moderator cannot bypass payment command with direct insert');
reset role;

select set_config('request.jwt.claim.sub','1a000000-0000-4000-8000-000000000003',true);set local role authenticated;
select is((select count(*)::integer from public.orders where order_number like 'RLS-ORDER-%'),2,'finance role sees organization-wide orders');
select is((select count(*)::integer from public.wallets),2,'finance role sees authorized wallets');
select throws_ok($$update public.orders set order_total_minor=999 where id='1a000000-0000-4000-8000-000000000020'$$,'42501',null,'finance role cannot bypass order commands with direct update');
reset role;

select set_config('request.jwt.claim.sub','1a000000-0000-4000-8000-000000000004',true);set local role authenticated;
select is((select count(*)::integer from public.partners),1,'partner sees only their own partner row');
select is((select id from public.partners),'00000000-0000-4000-8000-00000000f251'::uuid,'partner cannot see the other partner identity');
reset role;

select is((select count(*)::integer from pg_policies where schemaname='public' and tablename in('orders','order_items','order_status_history','order_exceptions','order_discounts','order_discount_allocations','order_problems','order_problem_costs') and qual like '%can_read_order_row%'),8,'every order-family relation uses assigned-order scope');
select is((select count(*)::integer from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='v' and coalesce(c.reloptions,array[]::text[])@>array['security_invoker=true']),15,'all exposed public views execute with invoker security');
select * from finish();
rollback;
