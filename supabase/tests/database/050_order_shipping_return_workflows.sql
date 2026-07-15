begin;
set local search_path=public,extensions;
select plan(27);

create temporary table test_order_context(key text primary key,value_json jsonb,value_text text,value_uuid uuid);
grant all on table test_order_context to authenticated;

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous)
values
('00000000-0000-0000-0000-000000000000','11000000-0000-4000-8000-000000000001','authenticated','authenticated','ops@order.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','11000000-0000-4000-8000-000000000002','authenticated','authenticated','finance@order.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','11000000-0000-4000-8000-000000000003','authenticated','authenticated','finance2@order.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id::text like '11000000-%';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '00000000-0000-4000-8000-00000000f001',u.user_id,r.id,statement_timestamp()-interval '1 minute',u.user_id,'Order workflow fixture'
from (values('11000000-0000-4000-8000-000000000001'::uuid,'operations'),('11000000-0000-4000-8000-000000000002'::uuid,'finance_manager'),('11000000-0000-4000-8000-000000000003'::uuid,'finance_manager'))u(user_id,role_key)
join private.roles r on r.organization_id='00000000-0000-4000-8000-00000000f001' and r.role_key=u.role_key;
update private.organization_finance_settings
set effective_to=transaction_timestamp()
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
select md5('phase2-order-fixture-settings')::uuid,organization_id,version_no+1,
  transaction_timestamp(),currency_code,timezone_name,custom_deposit_bps,
  custom_shipping_prepaid_required,moderator_max_discount_bps,
  discount_applies_to_shipping_by_default,block_negative_margin_for_moderator,
  partner_withdrawal_approval_threshold_minor,withdrawal_aggregation_hours,
  withdrawal_execution_enabled,minimum_operating_capital_minor,
  protected_liability_horizon_days,reserve_requirement_bps,future_profit_advance_cap_minor,
  true,jsonb_build_object('fixture',true,'required_classification','operational'),
  payroll_execution_enabled,salary_window_start_day,salary_window_end_day,
  moderator_bonus_min_minor,moderator_bonus_max_minor,operations_bonus_min_minor,
  operations_bonus_max_minor,opening_balance_import_enabled,
  '11000000-0000-4000-8000-000000000002',transaction_timestamp(),
  'Enable synthetic delivery verification','11000000-0000-4000-8000-000000000002'
from private.organization_finance_settings
where organization_id='00000000-0000-4000-8000-00000000f001'
  and effective_to=transaction_timestamp();

insert into public.customers(id,organization_id,customer_number,full_name,created_by)
values('21000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f001','SHIP-CUSTOMER','Shipping Customer','11000000-0000-4000-8000-000000000001');
insert into public.products(id,organization_id,product_category_id,product_code,display_name,product_kind,default_item_type,requires_phone_model,tracks_inventory,created_by)
values('22000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f203','READY_CASE','Ready Case','ready_stock','paid_product',false,true,'11000000-0000-4000-8000-000000000001');
insert into public.product_variants(id,organization_id,product_id,variant_code,display_name,attributes,created_by)
values('22000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000f001','22000000-0000-4000-8000-000000000001','READY_CASE_BLACK','Ready Case Black','{}','11000000-0000-4000-8000-000000000001');
insert into public.orders(id,organization_id,order_number,customer_id,assigned_moderator_id,created_by,order_source,order_type,status,payment_status,payment_policy_code_snapshot,payment_policy_version_snapshot,deposit_bps_snapshot,shipping_prepaid_required_snapshot,products_subtotal_minor,discount_total_minor,shipping_charge_minor,order_total_minor,required_deposit_minor,confirmed_payment_minor,balance_due_minor,expected_cost_minor,expected_margin_minor,terms_frozen_at,confirmed_at,version)
values('23000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f001','SHIP-ORDER-1','21000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001','fixture','ready_stock','confirmed','required_deposit_paid','fixture','1',5000,false,10000,1000,500,9500,5000,5000,4500,600,8200,statement_timestamp(),statement_timestamp(),1);
insert into public.order_items(id,organization_id,order_id,line_number,product_id,product_variant_id,item_type,supply_method,fulfillment_status,costing_status,quantity,sku_snapshot,item_name_snapshot,unit_sale_price_minor,unit_expected_cost_minor,line_gross_minor,line_discount_minor,line_revenue_minor,custom_design_required,printing_required,price_source_snapshot,cost_source_snapshot,terms_frozen_at)
values('23000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000f001','23000000-0000-4000-8000-000000000001',1,'22000000-0000-4000-8000-000000000001','22000000-0000-4000-8000-000000000002','paid_product','ready_stock','fulfilled','frozen',2,'READY_CASE_BLACK','Ready Case Black',5000,300,10000,1000,9000,false,false,'{"source":"fixture"}','{"source":"fixture"}',statement_timestamp());
insert into public.inventory_movements(organization_id,movement_type,product_variant_id,to_location_id,quantity,unit_cost_minor,total_cost_minor,source_type,source_id,correlation_id,reason,occurred_at,accounting_date,created_by,updated_by)
values('00000000-0000-4000-8000-00000000f001','purchase_receipt','22000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000f221',10,300,3000,'fixture_opening','22000000-0000-4000-8000-000000000002','24000000-0000-4000-8000-000000000001','Synthetic opening stock',statement_timestamp(),private.cairo_accounting_date(),'11000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001');
insert into public.couriers(id,organization_id,courier_code,display_name,settlement_weekdays,created_by)
values('25000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f001','SHIP_TEST','Shipment Test Courier',array[1,3,5]::smallint[],'11000000-0000-4000-8000-000000000001');
insert into public.shipping_rate_rules(id,organization_id,courier_id,shipping_zone_id,service_type,delivery_fee_minor,return_fee_minor,cod_fixed_fee_minor,cod_fee_bps,effective_from,priority,created_by)
values('25000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000f001','25000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f211','standard',700,300,0,0,date '2026-01-01',1,'11000000-0000-4000-8000-000000000001');
insert into public.attachments(id,organization_id,bucket_id,object_name,entity_type,entity_id,classification,media_type,size_bytes,checksum_sha256,uploaded_by)
values
('26000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f001','falcon-operational','fixtures/dispatch.txt','order','23000000-0000-4000-8000-000000000001','operational','text/plain',10,repeat('a',64),'11000000-0000-4000-8000-000000000001'),
('26000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000f001','falcon-operational','fixtures/delivery.txt','order','23000000-0000-4000-8000-000000000001','operational','text/plain',10,repeat('b',64),'11000000-0000-4000-8000-000000000001'),
('26000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-00000000f001','falcon-operational','fixtures/return.txt','order','23000000-0000-4000-8000-000000000001','operational','text/plain',10,repeat('c',64),'11000000-0000-4000-8000-000000000001');

insert into test_order_context(key,value_json) values('shipment_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'order_id','23000000-0000-4000-8000-000000000001'::uuid,'courier_id','25000000-0000-4000-8000-000000000001'::uuid,'shipping_rate_rule_id','25000000-0000-4000-8000-000000000002'::uuid,'tracking_number','TRACK-P2-1','shipment_kind','primary','items',jsonb_build_array(jsonb_build_object('order_item_id','23000000-0000-4000-8000-000000000002'::uuid,'quantity',2)),'customer_shipping_charge_minor',500,'dispatch_evidence_attachment_id','26000000-0000-4000-8000-000000000001'::uuid,'expected_order_version',1));
insert into test_order_context(key,value_text) select 'shipment_fp',private.canonical_request_fingerprint('shipments.create',value_json,1::smallint) from test_order_context where key='shipment_payload';
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true); set local role authenticated;
insert into test_order_context(key,value_json) select 'shipment_result',api.create_shipment('00000000-0000-4000-8000-00000000f001','23000000-0000-4000-8000-000000000001','25000000-0000-4000-8000-000000000001','25000000-0000-4000-8000-000000000002','TRACK-P2-1','primary',(select value_json->'items' from test_order_context where key='shipment_payload'),500,'26000000-0000-4000-8000-000000000001',1,'shipment-create-0001',(select value_text from test_order_context where key='shipment_fp'),'24000000-0000-4000-8000-000000000002'); reset role;
insert into test_order_context(key,value_uuid) select 'shipment_id',(value_json->>'entity_id')::uuid from test_order_context where key='shipment_result';
select is((select expected_cod_minor from public.shipments where id=(select value_uuid from test_order_context where key='shipment_id')),4500::bigint,'shipment derives contractual COD independently');
select ok((select sum(shipping_revenue_allocation_minor)=500 and sum(deposit_allocation_minor)=5000 and sum(cod_obligation_minor)=4500 and sum(delivery_fee_allocation_minor)=700 from public.shipment_items where shipment_id=(select value_uuid from test_order_context where key='shipment_id')),'shipment allocations conserve shipping, deposit, COD, and fee');

insert into test_order_context(key,value_json) select 'delivery_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'shipment_id',value_uuid,'delivery_evidence_attachment_id','26000000-0000-4000-8000-000000000002'::uuid,'delivered_at',statement_timestamp(),'reported_collected_cod_minor',4200,'expected_shipment_version',1) from test_order_context where key='shipment_id';
insert into test_order_context(key,value_text) select 'delivery_fp',private.canonical_request_fingerprint('orders.deliver',value_json,1::smallint) from test_order_context where key='delivery_payload';
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000002',true); set local role authenticated;
insert into test_order_context(key,value_json) select 'delivery_result',api.mark_order_delivered('00000000-0000-4000-8000-00000000f001',(select value_uuid from test_order_context where key='shipment_id'),'26000000-0000-4000-8000-000000000002',(select (value_json->>'delivered_at')::timestamptz from test_order_context where key='delivery_payload'),4200,1,'shipment-deliver-0001',(select value_text from test_order_context where key='delivery_fp'),'24000000-0000-4000-8000-000000000003'); reset role;
select is((select status::text from public.orders where id='23000000-0000-4000-8000-000000000001'),'delivered','delivery owns the order delivered transition');
select is((select reported_collected_cod_minor from public.shipments where id=(select value_uuid from test_order_context where key='shipment_id')),4200::bigint,'courier reported cash remains separate from contractual COD');
select ok(not exists(select 1 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id where je.source_type='shipment' and je.source_id=(select value_uuid from test_order_context where key='shipment_id') group by je.id having sum(jl.debit_minor)<>sum(jl.credit_minor)),'delivery journal balances');
select is((select sum(case when a.code='4100' then jl.credit_minor-jl.debit_minor else 0 end) from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id join accounting.accounts a on a.id=jl.account_id where je.source_type='shipment' and je.source_id=(select value_uuid from test_order_context where key='shipment_id')),10500::numeric,'delivery recognizes gross product plus shipping revenue');
select is((select quantity_on_hand from public.inventory_balance_by_location where organization_id='00000000-0000-4000-8000-00000000f001' and product_variant_id='22000000-0000-4000-8000-000000000002' and location_id='00000000-0000-4000-8000-00000000f221'),8::bigint,'delivery conserves physical stock at the main location');

insert into test_order_context(key,value_json) select 'return_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'shipment_id',(select value_uuid from test_order_context where key='shipment_id'),'return_number','RETURN-P2-1','items',jsonb_build_array(jsonb_build_object('shipment_item_id',si.id,'quantity',1,'disposition','resellable','reason','Customer return')),'reason','Customer returned one unit','evidence_attachment_id','26000000-0000-4000-8000-000000000003'::uuid,'expected_shipment_version',2) from public.shipment_items si where si.shipment_id=(select value_uuid from test_order_context where key='shipment_id');
insert into test_order_context(key,value_text) select 'return_fp',private.canonical_request_fingerprint('orders.return',value_json,1::smallint) from test_order_context where key='return_payload';
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true); set local role authenticated;
insert into test_order_context(key,value_json) select 'return_result',api.record_order_return('00000000-0000-4000-8000-00000000f001',(select value_uuid from test_order_context where key='shipment_id'),'RETURN-P2-1',(select value_json->'items' from test_order_context where key='return_payload'),'Customer returned one unit','26000000-0000-4000-8000-000000000003',2,'order-return-0001',(select value_text from test_order_context where key='return_fp'),'24000000-0000-4000-8000-000000000004'); reset role;
insert into test_order_context(key,value_uuid) select 'return_id',(value_json->>'entity_id')::uuid from test_order_context where key='return_result';
insert into test_order_context(key,value_uuid) select 'return_credit_id',(value_json->>'customer_credit_id')::uuid from test_order_context where key='return_result';
select is((select refundable_amount_minor from public.return_items where return_id=(select value_uuid from test_order_context where key='return_id')),4750::bigint,'partial return derives its proportional customer consideration');
select ok((select original_amount_minor=4750 and remaining_amount_minor=4750 and status='available' from public.customer_credits where id=(select value_uuid from test_order_context where key='return_credit_id')),'resolved return issues an exact customer-credit liability');
select is((select status::text from public.orders where id='23000000-0000-4000-8000-000000000001'),'partially_returned','partial return updates order state without erasing delivery');
select is((select quantity_on_hand from public.inventory_balance_by_location where organization_id='00000000-0000-4000-8000-00000000f001' and product_variant_id='22000000-0000-4000-8000-000000000002' and location_id='00000000-0000-4000-8000-00000000f222'),1::bigint,'resellable return restores stock only to inspection');
select ok(not exists(select 1 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id where je.source_type='customer_return' and je.source_id=(select value_uuid from test_order_context where key='return_id') group by je.id having sum(jl.debit_minor)<>sum(jl.credit_minor)),'return journal balances');
select is((select sum(case when a.code='2220' then jl.credit_minor-jl.debit_minor else 0 end) from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id join accounting.accounts a on a.id=jl.account_id where je.source_type in('shipment','customer_return')),1000::numeric,'delivery and return fees accrue to courier payable at service events');
select is((select coalesce(sum(quantity),0) from public.inventory_movements where product_variant_id='22000000-0000-4000-8000-000000000002' and movement_type='sale'),2::bigint,'sale movement quantity equals delivered quantity');
select is((select count(*)::integer from public.customer_credit_movements where customer_credit_id=(select value_uuid from test_order_context where key='return_credit_id') and amount_minor=4750),1,'return credit has one immutable issuance movement');

insert into test_order_context(key,value_json) values('settlement_prepare_payload',jsonb_build_object(
  'organization_id','00000000-0000-4000-8000-00000000f001'::uuid,
  'courier_id','25000000-0000-4000-8000-000000000001'::uuid,
  'settlement_number','COURIER-SETTLEMENT-P2-1',
  'period_start',(transaction_timestamp() at time zone 'Africa/Cairo')::date,
  'period_end',(transaction_timestamp() at time zone 'Africa/Cairo')::date,
  'expected_settlement_date',(transaction_timestamp() at time zone 'Africa/Cairo')::date,
  'actual_settlement_date',(transaction_timestamp() at time zone 'Africa/Cairo')::date,
  'actual_transfer_minor',3400,'approved_deductions_minor',0,'adjustments_minor',0,
  'prior_carry_forward_minor',0,'difference_classification','courier_short_transfer',
  'difference_explanation','Synthetic approved difference','evidence_attachment_id','26000000-0000-4000-8000-000000000003'::uuid,
  'is_off_cycle',false,'off_cycle_reason',null));
insert into test_order_context(key,value_text) select 'settlement_prepare_fp',private.canonical_request_fingerprint('courier_settlements.prepare',value_json,1::smallint) from test_order_context where key='settlement_prepare_payload';
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_order_context(key,value_json) select 'settlement_prepare_result',api.prepare_courier_settlement(
  '00000000-0000-4000-8000-00000000f001','25000000-0000-4000-8000-000000000001','COURIER-SETTLEMENT-P2-1',
  (transaction_timestamp() at time zone 'Africa/Cairo')::date,(transaction_timestamp() at time zone 'Africa/Cairo')::date,
  (transaction_timestamp() at time zone 'Africa/Cairo')::date,(transaction_timestamp() at time zone 'Africa/Cairo')::date,
  3400,0,0,0,'courier_short_transfer','Synthetic approved difference','26000000-0000-4000-8000-000000000003',false,null,
  'courier-settlement-prepare-0001',(select value_text from test_order_context where key='settlement_prepare_fp'),'36000000-0000-4000-8000-000000000001');reset role;
insert into test_order_context(key,value_uuid) select 'settlement_id',(value_json->>'entity_id')::uuid from test_order_context where key='settlement_prepare_result';
insert into test_order_context(key,value_uuid) select 'settlement_approval_id',(value_json->>'approval_request_id')::uuid from test_order_context where key='settlement_prepare_result';
select ok((select contractual_cod_minor=4500 and delivery_fees_minor=700 and return_fees_minor=300 and expected_net_settlement_minor=3500 and actual_transfer_minor=3400 and difference_minor=-100 from public.courier_settlements where id=(select value_uuid from test_order_context where key='settlement_id')),'settlement derives contractual COD and actual service-event fees independently of reported cash');
select is((select count(*)::integer from public.courier_settlement_items where courier_settlement_id=(select value_uuid from test_order_context where key='settlement_id') and is_active),3,'settlement claims one COD, one delivery-fee, and one actual return-fee event');
select is((select amount_minor from public.courier_settlement_items where courier_settlement_id=(select value_uuid from test_order_context where key='settlement_id') and line_type='contractual_cod_receivable'),4500::bigint,'settlement line preserves contractual COD rather than courier report');

select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000002',true);set local role authenticated;
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select value_uuid from test_order_context where key='settlement_approval_id'),'approve','Approve courier reconciliation',null,'36000000-0000-4000-8000-000000000002');reset role;
insert into test_order_context(key,value_json) select 'settlement_approve_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'courier_settlement_id',value_uuid) from test_order_context where key='settlement_id';
insert into test_order_context(key,value_text) select 'settlement_approve_fp',private.canonical_request_fingerprint('courier_settlements.approve',value_json,1::smallint) from test_order_context where key='settlement_approve_payload';
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000002',true);set local role authenticated;
insert into test_order_context(key,value_json) select 'settlement_approve_result',api.approve_courier_settlement('00000000-0000-4000-8000-00000000f001',(select value_uuid from test_order_context where key='settlement_id'),'courier-settlement-approve-0001',(select value_text from test_order_context where key='settlement_approve_fp'),'36000000-0000-4000-8000-000000000003');reset role;
select is((select status::text from public.courier_settlements where id=(select value_uuid from test_order_context where key='settlement_id')),'approved','separate finance actor consumes the settlement approval');

insert into test_order_context(key,value_json) select 'settlement_finalize_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'courier_settlement_id',value_uuid,'wallet_id','00000000-0000-4000-8000-00000000f241'::uuid) from test_order_context where key='settlement_id';
insert into test_order_context(key,value_text) select 'settlement_finalize_fp',private.canonical_request_fingerprint('courier_settlements.finalize',value_json,1::smallint) from test_order_context where key='settlement_finalize_payload';
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000003',true);set local role authenticated;
insert into test_order_context(key,value_json) select 'settlement_finalize_result',api.finalize_courier_settlement('00000000-0000-4000-8000-00000000f001',(select value_uuid from test_order_context where key='settlement_id'),'00000000-0000-4000-8000-00000000f241','courier-settlement-finalize-0001',(select value_text from test_order_context where key='settlement_finalize_fp'),'36000000-0000-4000-8000-000000000004');reset role;
select ok((select status='posted' and journal_entry_id is not null and wallet_id='00000000-0000-4000-8000-00000000f241' from public.courier_settlements where id=(select value_uuid from test_order_context where key='settlement_id')),'third actor finalizes approved settlement into the wallet');
select ok((select sum(case when a.code='1100' then jl.debit_minor else 0 end)=3400 and sum(case when a.code='2220' then jl.debit_minor else 0 end)=1000 and sum(case when a.code='5290' then jl.debit_minor else 0 end)=100 and sum(case when a.code='1210' then jl.credit_minor else 0 end)=4500 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id join accounting.accounts a on a.id=jl.account_id where je.source_type='courier_settlement' and je.source_id=(select value_uuid from test_order_context where key='settlement_id')),'finalization clears courier AR and AP with approved short-transfer variance');
select is((select settlement_status from public.shipments where id=(select value_uuid from test_order_context where key='shipment_id')),'settled','finalization marks claimed shipment obligations settled');
select is((select accrued_courier_fees_minor from public.courier_receivable_summary where courier_id='25000000-0000-4000-8000-000000000001'),1000::bigint,'courier summary reports delivery plus actual resolved return fees only');
select ok(not exists(select 1 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id where je.source_type='courier_settlement' group by je.id having sum(jl.debit_minor)<>sum(jl.credit_minor)),'courier settlement journal balances');

select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true);set local role authenticated;
select throws_ok($$insert into public.courier_settlement_items(organization_id,courier_settlement_id,line_type,source_event_key,amount_minor,description,created_by,updated_by)values('00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-000000000001','adjustment','bypass',1,'bypass','11000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001')$$,'42501',null,'authenticated operations cannot bypass settlement commands');reset role;

insert into public.orders(id,organization_id,order_number,customer_id,created_by,order_source,order_type,status,products_subtotal_minor,order_total_minor,balance_due_minor,version)
values('23000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-00000000f001','CANCEL-ORDER-1','21000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000002','fixture','other','new',0,0,0,0);
insert into test_order_context(key,value_json) values('cancel_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'order_id','23000000-0000-4000-8000-000000000010'::uuid,'reason','Customer cancelled','expected_version',0));
insert into test_order_context(key,value_text) select 'cancel_fp',private.canonical_request_fingerprint('orders.cancel',value_json,1::smallint) from test_order_context where key='cancel_payload';
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000002',true); set local role authenticated;
select lives_ok(format('select api.cancel_order(%L,%L,%L,0,%L,%L,%L)','00000000-0000-4000-8000-00000000f001','23000000-0000-4000-8000-000000000010','Customer cancelled','cancel-order-0001',(select value_text from test_order_context where key='cancel_fp'),'24000000-0000-4000-8000-000000000005'),'unfunded unfulfilled order cancellation executes transactionally'); reset role;
select is((select status::text from public.orders where id='23000000-0000-4000-8000-000000000010'),'cancelled','cancellation records terminal state and reason');

select * from finish(); rollback;
