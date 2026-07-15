begin;
set local search_path=public,extensions;
select plan(21);

create temporary table test_supplier_context(key text primary key,j jsonb,t text,u uuid);
grant all on test_supplier_context to authenticated;

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous) values
('00000000-0000-0000-0000-000000000000','13000000-0000-4000-8000-000000000001','authenticated','authenticated','ops@supplier.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','13000000-0000-4000-8000-000000000002','authenticated','authenticated','finance1@supplier.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','13000000-0000-4000-8000-000000000003','authenticated','authenticated','finance2@supplier.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id::text like '13000000-%';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '00000000-0000-4000-8000-00000000f001',x.uid,r.id,statement_timestamp()-interval '1 minute',x.uid,'Supplier workflow fixture'
from(values('13000000-0000-4000-8000-000000000001'::uuid,'operations'),('13000000-0000-4000-8000-000000000002'::uuid,'finance_manager'),('13000000-0000-4000-8000-000000000003'::uuid,'finance_manager'))x(uid,role_key)
join private.roles r on r.organization_id='00000000-0000-4000-8000-00000000f001' and r.role_key=x.role_key;

insert into public.suppliers(id,organization_id,supplier_code,display_name,is_active,created_by)
values('31000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f001','PRINTER-P2','Synthetic Printer',true,'13000000-0000-4000-8000-000000000001');
insert into public.customers(id,organization_id,customer_number,full_name,created_by)
values('31000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000f001','PRINT-CUSTOMER','Printing Customer','13000000-0000-4000-8000-000000000001');
insert into public.products(id,organization_id,product_category_id,product_code,display_name,product_kind,default_item_type,requires_phone_model,tracks_inventory,created_by)
values('31000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f203','PRINT_CASE','Printed Case','custom_case','paid_product',false,true,'13000000-0000-4000-8000-000000000001');
insert into public.product_variants(id,organization_id,product_id,variant_code,display_name,attributes,created_by)
values('31000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-00000000f001','31000000-0000-4000-8000-000000000003','PRINT_CASE_1','Printed Case One','{}','13000000-0000-4000-8000-000000000001');
insert into public.orders(id,organization_id,order_number,customer_id,created_by,order_source,order_type,status,payment_status,products_subtotal_minor,order_total_minor,balance_due_minor,expected_cost_minor,expected_margin_minor,terms_frozen_at,confirmed_at,version)
values('31000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-00000000f001','PRINT-ORDER-1','31000000-0000-4000-8000-000000000002','13000000-0000-4000-8000-000000000001','fixture','custom','confirmed','no_payment',2000,2000,2000,600,1400,statement_timestamp(),statement_timestamp(),1);
insert into public.order_items(id,organization_id,order_id,line_number,product_id,product_variant_id,item_type,supply_method,fulfillment_status,costing_status,quantity,sku_snapshot,item_name_snapshot,unit_sale_price_minor,unit_expected_cost_minor,line_gross_minor,line_discount_minor,line_revenue_minor,custom_design_required,printing_required,price_source_snapshot,cost_source_snapshot,terms_frozen_at)
values('31000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000f001','31000000-0000-4000-8000-000000000005',1,'31000000-0000-4000-8000-000000000003','31000000-0000-4000-8000-000000000004','paid_product','supplier_case_and_print','planned','frozen',2,'PRINT_CASE_1','Printed Case One',1000,300,2000,0,2000,true,true,'{"source":"fixture"}','{"source":"fixture"}',statement_timestamp());

insert into test_supplier_context(key,j) values('batch_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'supplier_id','31000000-0000-4000-8000-000000000001'::uuid,'batch_number','PRINT-BATCH-P2-1','items',jsonb_build_array(jsonb_build_object('order_item_id','31000000-0000-4000-8000-000000000006'::uuid,'quantity',2,'expected_case_unit_cost_minor',200,'expected_print_unit_cost_minor',100)),'business_date',(transaction_timestamp() at time zone 'Africa/Cairo')::date));
insert into test_supplier_context(key,t) select 'batch_fp',private.canonical_request_fingerprint('print_batches.create',j,1::smallint) from test_supplier_context where key='batch_payload';
select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_supplier_context(key,j) select 'batch_result',api.create_print_batch('00000000-0000-4000-8000-00000000f001','31000000-0000-4000-8000-000000000001','PRINT-BATCH-P2-1',(select j->'items' from test_supplier_context where key='batch_payload'),(transaction_timestamp() at time zone 'Africa/Cairo')::date,'print-batch-create-0001',(select t from test_supplier_context where key='batch_fp'),'32000000-0000-4000-8000-000000000001');reset role;
insert into test_supplier_context(key,u) select 'batch_id',(j->>'entity_id')::uuid from test_supplier_context where key='batch_result';
insert into test_supplier_context(key,u) select 'batch_item_id',id from public.print_batch_items where print_batch_id=(select u from test_supplier_context where key='batch_id');
select ok((select status='sent' and expected_total_unit_cost_minor=300 and sent_quantity=2 from public.print_batch_items where id=(select u from test_supplier_context where key='batch_item_id')),'print dispatch freezes quantity and expected unit cost');
select is((select status::text from public.orders where id='31000000-0000-4000-8000-000000000005'),'printing','dispatch transitions the source order to printing');

insert into test_supplier_context(key,j) select 'receipt_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'print_batch_id',(select u from test_supplier_context where key='batch_id'),'receipt_number','PRINT-RECEIPT-P2-1','items',jsonb_build_array(jsonb_build_object('print_batch_item_id',(select u from test_supplier_context where key='batch_item_id'),'accepted_quantity',2,'rejected_quantity',0,'rejection_reason',null)),'received_at','2026-07-14 12:00:00+03'::timestamptz);
insert into test_supplier_context(key,t) select 'receipt_fp',private.canonical_request_fingerprint('print_batches.receive',j,1::smallint) from test_supplier_context where key='receipt_payload';
select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into test_supplier_context(key,j) select 'receipt_result',api.receive_print_batch('00000000-0000-4000-8000-00000000f001',(select u from test_supplier_context where key='batch_id'),'PRINT-RECEIPT-P2-1',(select j->'items' from test_supplier_context where key='receipt_payload'),'2026-07-14 12:00:00+03','print-batch-receive-0001',(select t from test_supplier_context where key='receipt_fp'),'32000000-0000-4000-8000-000000000002');reset role;
insert into test_supplier_context(key,u) select 'grni_id',id from public.grni_accruals where print_batch_item_id=(select u from test_supplier_context where key='batch_item_id');
select is((select accrued_amount_minor from public.grni_accruals where id=(select u from test_supplier_context where key='grni_id')),600::bigint,'accepted QC accrues exact frozen GRNI value');
select is((select quantity_on_hand from public.inventory_balance_by_location where organization_id='00000000-0000-4000-8000-00000000f001' and product_variant_id='31000000-0000-4000-8000-000000000004' and location_id='00000000-0000-4000-8000-00000000f221'),2::bigint,'accepted QC creates physical inventory exactly once');
select ok((select status='ready_for_invoice' from public.print_batches where id=(select u from test_supplier_context where key='batch_id')),'fully received batch becomes invoice-ready');
select ok(not exists(select 1 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id where je.source_type='print_receipt' group by je.id having sum(jl.debit_minor)<>sum(jl.credit_minor)),'GRNI receipt journal balances');

insert into test_supplier_context(key,j) select 'invoice_create_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'supplier_id','31000000-0000-4000-8000-000000000001'::uuid,'print_batch_id',(select u from test_supplier_context where key='batch_id'),'invoice_number','SUP-INV-P2-1','invoice_date',(transaction_timestamp() at time zone 'Africa/Cairo')::date,'due_date',(transaction_timestamp() at time zone 'Africa/Cairo')::date+7,'items',jsonb_build_array(jsonb_build_object('grni_accrual_id',(select u from test_supplier_context where key='grni_id'),'invoiced_quantity',2,'invoiced_unit_cost_minor',350,'description','Printed case production')),'tax_minor',98,'credit_minor',20);
insert into test_supplier_context(key,t) select 'invoice_create_fp',private.canonical_request_fingerprint('supplier_invoices.create',j,1::smallint) from test_supplier_context where key='invoice_create_payload';
select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000002',true);set local role authenticated;
insert into test_supplier_context(key,j) select 'invoice_create_result',api.create_supplier_invoice('00000000-0000-4000-8000-00000000f001','31000000-0000-4000-8000-000000000001',(select u from test_supplier_context where key='batch_id'),'SUP-INV-P2-1',(transaction_timestamp() at time zone 'Africa/Cairo')::date,(transaction_timestamp() at time zone 'Africa/Cairo')::date+7,(select j->'items' from test_supplier_context where key='invoice_create_payload'),98,20,'supplier-invoice-create-0001',(select t from test_supplier_context where key='invoice_create_fp'),'32000000-0000-4000-8000-000000000003');reset role;
insert into test_supplier_context(key,u) select 'invoice_id',(j->>'entity_id')::uuid from test_supplier_context where key='invoice_create_result';
insert into test_supplier_context(key,u) select 'approval_id',(j->>'approval_request_id')::uuid from test_supplier_context where key='invoice_create_result';
select ok((select subtotal_minor=700 and tax_minor=98 and credit_minor=20 and total_minor=778 and status='submitted' from public.supplier_invoices where id=(select u from test_supplier_context where key='invoice_id')),'supplier invoice totals are server-derived and approval-bound');
select is((select variance_minor from public.supplier_invoice_items where supplier_invoice_id=(select u from test_supplier_context where key='invoice_id')),100::bigint,'invoice line records price variance against matched GRNI');

select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000003',true);set local role authenticated;
select api.decide_approval('00000000-0000-4000-8000-00000000f001',(select u from test_supplier_context where key='approval_id'),'approve','Approved supplier invoice',null,'32000000-0000-4000-8000-000000000004');reset role;
insert into test_supplier_context(key,j) select 'invoice_approve_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'supplier_invoice_id',u) from test_supplier_context where key='invoice_id';
insert into test_supplier_context(key,t) select 'invoice_approve_fp',private.canonical_request_fingerprint('supplier_invoices.approve',j,1::smallint) from test_supplier_context where key='invoice_approve_payload';
select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000002',true);set local role authenticated;
insert into test_supplier_context(key,j) select 'invoice_same_actor_result',api.approve_supplier_invoice('00000000-0000-4000-8000-00000000f001',(select u from test_supplier_context where key='invoice_id'),'supplier-invoice-approve-same-actor',(select t from test_supplier_context where key='invoice_approve_fp'),'32000000-0000-4000-8000-000000000005');reset role;
select is((select j->>'error_code' from test_supplier_context where key='invoice_same_actor_result'),'SUPPLIER_INVOICE_APPROVAL_REJECTED','invoice creator cannot execute its approval');
select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000003',true);set local role authenticated;
insert into test_supplier_context(key,j) select 'invoice_approve_result',api.approve_supplier_invoice('00000000-0000-4000-8000-00000000f001',(select u from test_supplier_context where key='invoice_id'),'supplier-invoice-approve-0001',(select t from test_supplier_context where key='invoice_approve_fp'),'32000000-0000-4000-8000-000000000006');reset role;
select ok((select status='posted' and journal_entry_id is not null and approved_variance_minor=80 from public.supplier_invoices where id=(select u from test_supplier_context where key='invoice_id')),'separate approver posts matched GRNI, net variance, tax, and AP');
select ok((select sum(case a.code when'2210'then jl.debit_minor when'5110'then jl.debit_minor when'1410'then jl.debit_minor else 0 end)=778 and sum(case when a.code='2200' then jl.credit_minor else 0 end)=778 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id join accounting.accounts a on a.id=jl.account_id where je.source_type='supplier_invoice' and je.source_id=(select u from test_supplier_context where key='invoice_id')),'supplier invoice posting clears GRNI and recognizes controlled variance and tax against AP');

insert into test_supplier_context(key,j) select 'pay1_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'supplier_invoice_id',u,'wallet_id','00000000-0000-4000-8000-00000000f241'::uuid,'amount_minor',300,'provider_reference','SUP-PAY-P2-1','evidence_attachment_id',null) from test_supplier_context where key='invoice_id';
insert into test_supplier_context(key,t) select 'pay1_fp',private.canonical_request_fingerprint('supplier_payments.execute',j,1::smallint) from test_supplier_context where key='pay1_payload';
select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000002',true);set local role authenticated;
insert into test_supplier_context(key,j) select 'pay1_result',api.pay_supplier_invoice('00000000-0000-4000-8000-00000000f001',(select u from test_supplier_context where key='invoice_id'),'00000000-0000-4000-8000-00000000f241',300,'SUP-PAY-P2-1',null,'supplier-pay-0001',(select t from test_supplier_context where key='pay1_fp'),'32000000-0000-4000-8000-000000000007');
insert into test_supplier_context(key,j) select 'pay1_replay',api.pay_supplier_invoice('00000000-0000-4000-8000-00000000f001',(select u from test_supplier_context where key='invoice_id'),'00000000-0000-4000-8000-00000000f241',300,'SUP-PAY-P2-1',null,'supplier-pay-0001',(select t from test_supplier_context where key='pay1_fp'),'32000000-0000-4000-8000-000000000007');reset role;
select ok((select status='partially_paid' from public.supplier_invoices where id=(select u from test_supplier_context where key='invoice_id')),'bounded partial payment leaves invoice partially paid');
select ok((select (select j->>'entity_id' from test_supplier_context where key='pay1_result')=(select j->>'entity_id' from test_supplier_context where key='pay1_replay') and count(*)=1 from public.supplier_payments where supplier_invoice_id=(select u from test_supplier_context where key='invoice_id')),'supplier payment replay returns the original outcome without duplicate cash movement');

insert into test_supplier_context(key,j) select 'overpay_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'supplier_invoice_id',u,'wallet_id','00000000-0000-4000-8000-00000000f241'::uuid,'amount_minor',1000,'provider_reference','SUP-OVERPAY-P2','evidence_attachment_id',null) from test_supplier_context where key='invoice_id';
insert into test_supplier_context(key,t) select 'overpay_fp',private.canonical_request_fingerprint('supplier_payments.execute',j,1::smallint) from test_supplier_context where key='overpay_payload';
select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000002',true);set local role authenticated;
insert into test_supplier_context(key,j) select 'overpay_result',api.pay_supplier_invoice('00000000-0000-4000-8000-00000000f001',(select u from test_supplier_context where key='invoice_id'),'00000000-0000-4000-8000-00000000f241',1000,'SUP-OVERPAY-P2',null,'supplier-pay-over-0001',(select t from test_supplier_context where key='overpay_fp'),'32000000-0000-4000-8000-000000000008');reset role;
select is((select j->>'error_code' from test_supplier_context where key='overpay_result'),'SUPPLIER_PAYMENT_REJECTED','supplier payment rejects amount above open AP');

insert into test_supplier_context(key,j) select 'pay2_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'supplier_invoice_id',u,'wallet_id','00000000-0000-4000-8000-00000000f241'::uuid,'amount_minor',478,'provider_reference','SUP-PAY-P2-2','evidence_attachment_id',null) from test_supplier_context where key='invoice_id';
insert into test_supplier_context(key,t) select 'pay2_fp',private.canonical_request_fingerprint('supplier_payments.execute',j,1::smallint) from test_supplier_context where key='pay2_payload';
select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000003',true);set local role authenticated;
insert into test_supplier_context(key,j) select 'pay2_result',api.pay_supplier_invoice('00000000-0000-4000-8000-00000000f001',(select u from test_supplier_context where key='invoice_id'),'00000000-0000-4000-8000-00000000f241',478,'SUP-PAY-P2-2',null,'supplier-pay-0002',(select t from test_supplier_context where key='pay2_fp'),'32000000-0000-4000-8000-000000000009');reset role;
select ok((select status='paid' from public.supplier_invoices where id=(select u from test_supplier_context where key='invoice_id')) and (select status='fully_paid' from public.print_batches where id=(select u from test_supplier_context where key='batch_id')),'final bounded payment clears AP and advances batch lifecycle');
select is((select sum(amount_minor)::bigint from public.supplier_payments where supplier_invoice_id=(select u from test_supplier_context where key='invoice_id')),778::bigint,'supplier payment allocation exactly conserves invoice total');
select ok(not exists(select 1 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id where je.source_type in('supplier_invoice','supplier_payment') group by je.id having sum(jl.debit_minor)<>sum(jl.credit_minor)),'supplier invoice and payment journals all balance');

insert into test_supplier_context(key,j) select 'close_payload',jsonb_build_object('organization_id','00000000-0000-4000-8000-00000000f001'::uuid,'print_batch_id',u) from test_supplier_context where key='batch_id';
insert into test_supplier_context(key,t) select 'close_fp',private.canonical_request_fingerprint('print_batches.close',j,1::smallint) from test_supplier_context where key='close_payload';
select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000001',true);set local role authenticated;
select lives_ok(format('select api.close_print_batch(%L,%L,%L,%L,%L)','00000000-0000-4000-8000-00000000f001',(select u from test_supplier_context where key='batch_id'),'print-batch-close-0001',(select t from test_supplier_context where key='close_fp'),'32000000-0000-4000-8000-000000000010'),'fully paid and fully received print batch closes transactionally');reset role;
select ok((select status='closed' and closed_at is not null from public.print_batches where id=(select u from test_supplier_context where key='batch_id')) and (select bool_and(status='closed') from public.print_batch_items where print_batch_id=(select u from test_supplier_context where key='batch_id')),'print batch close is terminal across header and attempts');

insert into public.supplier_payments(
  id,organization_id,supplier_invoice_id,wallet_id,amount_minor,payment_date,
  provider_reference,reverses_supplier_payment_id,created_by,updated_by
)
select '32000000-0000-4000-8000-000000000020',organization_id,
  supplier_invoice_id,wallet_id,amount_minor,private.cairo_accounting_date(),
  'SUP-PAY-P2-1-REVERSAL',id,
  '13000000-0000-4000-8000-000000000003','13000000-0000-4000-8000-000000000003'
from public.supplier_payments
where id=((select j->>'entity_id' from test_supplier_context where key='pay1_result')::uuid);
select is(
  (select open_payable_minor from public.supplier_payable_summary
   where supplier_id='31000000-0000-4000-8000-000000000001'),
  300::bigint,
  'supplier payable report subtracts reversal rows instead of overstating paid amount'
);

select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000001',true);set local role authenticated;
select throws_ok($$insert into public.supplier_payments(organization_id,supplier_invoice_id,wallet_id,amount_minor,payment_date,created_by,updated_by)values('00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000f241',1,current_date,'13000000-0000-4000-8000-000000000001','13000000-0000-4000-8000-000000000001')$$,'42501',null,'authenticated clients cannot bypass the supplier payment command');reset role;

select * from finish();
rollback;
