begin;
set local search_path=public,extensions;
select plan(7);

create temporary table test_order_terms_context(key text primary key,j jsonb,t text,u uuid);
grant all on test_order_terms_context to authenticated;

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous) values
('00000000-0000-0000-0000-000000000000','18000000-0000-4000-8000-000000000001','authenticated','authenticated','moderator@terms.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','18000000-0000-4000-8000-000000000002','authenticated','authenticated','finance@terms.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id::text like '18000000-%';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '00000000-0000-4000-8000-00000000f001',x.uid,r.id,statement_timestamp()-interval '1 minute',x.uid,'Order terms verification'
from(values('18000000-0000-4000-8000-000000000001'::uuid,'moderator'),('18000000-0000-4000-8000-000000000002'::uuid,'finance_manager'))x(uid,role_key)
join private.roles r on r.organization_id='00000000-0000-4000-8000-00000000f001' and r.role_key=x.role_key;

insert into public.customers(id,organization_id,customer_number,full_name,created_by)
values('38000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f001','TERMS-CUSTOMER','Order Terms Customer','18000000-0000-4000-8000-000000000001');
insert into public.products(id,organization_id,product_category_id,product_code,display_name,product_kind,default_item_type,requires_phone_model,tracks_inventory,created_by)
values('38000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f203','TERMS_PRODUCT','Terms Product','ready_stock','paid_product',false,true,'18000000-0000-4000-8000-000000000001');
insert into public.product_variants(id,organization_id,product_id,variant_code,display_name,attributes,created_by)
values('38000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-00000000f001','38000000-0000-4000-8000-000000000002','TERMS_VARIANT','Terms Variant','{}','18000000-0000-4000-8000-000000000001');
insert into public.orders(id,organization_id,order_number,customer_id,assigned_moderator_id,created_by,order_source,order_type,status,payment_status,payment_policy_code_snapshot,payment_policy_version_snapshot,deposit_bps_snapshot,shipping_prepaid_required_snapshot,products_subtotal_minor,discount_total_minor,shipping_charge_minor,order_total_minor,required_deposit_minor,confirmed_payment_minor,balance_due_minor,expected_cost_minor,expected_margin_minor,version)
values('38000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-00000000f001','TERMS-ORDER-1','38000000-0000-4000-8000-000000000001','18000000-0000-4000-8000-000000000001','18000000-0000-4000-8000-000000000001','fixture','ready_stock','new','no_payment','fixture','1',0,false,3003,0,0,3003,0,0,3003,900,2103,1);
insert into public.order_items(id,organization_id,order_id,line_number,product_id,product_variant_id,item_type,supply_method,fulfillment_status,costing_status,quantity,sku_snapshot,item_name_snapshot,unit_sale_price_minor,unit_expected_cost_minor,line_gross_minor,line_discount_minor,line_revenue_minor,custom_design_required,printing_required,price_source_snapshot,cost_source_snapshot)
values
('38000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-00000000f001','38000000-0000-4000-8000-000000000004',1,'38000000-0000-4000-8000-000000000002','38000000-0000-4000-8000-000000000003','paid_product','ready_stock','draft','estimated',1,'TERMS-A','Terms A',1001,300,1001,0,1001,false,false,'{"source":"fixture"}','{"source":"fixture"}'),
('38000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000f001','38000000-0000-4000-8000-000000000004',2,'38000000-0000-4000-8000-000000000002','38000000-0000-4000-8000-000000000003','paid_product','ready_stock','draft','estimated',1,'TERMS-B','Terms B',2002,600,2002,0,2002,false,false,'{"source":"fixture"}','{"source":"fixture"}');

insert into test_order_terms_context(key,j) values('discount_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'order_id','38000000-0000-4000-8000-000000000004'::uuid,'amount_minor',3,'includes_shipping',false,'source','moderator','reason','Deterministic minor-unit allocation','expected_version',1,'approval_request_id',null));
insert into test_order_terms_context(key,t) select 'discount_fp',private.canonical_request_fingerprint('orders.grant_discount',j,1::smallint) from test_order_terms_context where key='discount_payload';
select set_config('request.jwt.claim.sub','18000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_order_terms_context(key,j) select 'discount_result',api.grant_order_discount('00000000-0000-4000-8000-00000000f001','38000000-0000-4000-8000-000000000004',3,false,'moderator','Deterministic minor-unit allocation',1,null,'terms-discount-0001',(select t from test_order_terms_context where key='discount_fp'),'38000000-0000-4000-8000-000000000010');reset role;
insert into test_order_terms_context(key,u) select 'discount_id',(j->>'entity_id')::uuid from test_order_terms_context where key='discount_result';
select ok((select (j->>'success')::boolean and j->>'current_state'='granted' from test_order_terms_context where key='discount_result'),'policy-compliant discount command succeeds');
select is((select sum(allocated_amount_minor) from public.order_discount_allocations where order_discount_id=(select u from test_order_terms_context where key='discount_id')),3::numeric,'largest-remainder allocations conserve the exact discount');
select set_config('request.jwt.claim.sub','18000000-0000-4000-8000-000000000001',true);set local role authenticated;
select is((api.grant_order_discount('00000000-0000-4000-8000-00000000f001','38000000-0000-4000-8000-000000000004',3,false,'moderator','Deterministic minor-unit allocation',1,null,'terms-discount-0001',(select t from test_order_terms_context where key='discount_fp'),'38000000-0000-4000-8000-000000000011')->>'entity_id')::uuid,(select u from test_order_terms_context where key='discount_id'),'discount replay returns the original immutable result');reset role;

insert into test_order_terms_context(key,j) values('confirm_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'order_id','38000000-0000-4000-8000-000000000004'::uuid,'expected_version',2));
insert into test_order_terms_context(key,t) select 'confirm_fp',private.canonical_request_fingerprint('orders.confirm',j,1::smallint) from test_order_terms_context where key='confirm_payload';
select set_config('request.jwt.claim.sub','18000000-0000-4000-8000-000000000002',true);set local role authenticated;
insert into test_order_terms_context(key,j) select 'confirm_result',api.confirm_order('00000000-0000-4000-8000-00000000f001','38000000-0000-4000-8000-000000000004',2,'terms-confirm-0001',(select t from test_order_terms_context where key='confirm_fp'),'38000000-0000-4000-8000-000000000012');reset role;
select ok((select status='confirmed' and order_total_minor=3000 and expected_cost_minor=900 and version=3 from public.orders where id='38000000-0000-4000-8000-000000000004'),'confirmation freezes server-derived total, cost, and version');
select ok((select bool_and(terms_frozen_at is not null and fulfillment_status='planned' and costing_status='frozen') from public.order_items where order_id='38000000-0000-4000-8000-000000000004'),'confirmation freezes every item term and fulfillment state');
select set_config('request.jwt.claim.sub','18000000-0000-4000-8000-000000000002',true);set local role authenticated;
select is((api.confirm_order('00000000-0000-4000-8000-00000000f001','38000000-0000-4000-8000-000000000004',2,'terms-confirm-0001',(select t from test_order_terms_context where key='confirm_fp'),'38000000-0000-4000-8000-000000000013')->>'entity_id')::uuid,'38000000-0000-4000-8000-000000000004'::uuid,'confirmation replay returns the original order despite the advanced version');
select throws_ok($$select api.confirm_order('00000000-0000-4000-8000-00000000f001','38000000-0000-4000-8000-000000000004',2,'terms-confirm-tamper',repeat('0',64),'38000000-0000-4000-8000-000000000014')$$,'22023',null,'tampered confirmation fingerprint is rejected');reset role;

select * from finish();
rollback;
