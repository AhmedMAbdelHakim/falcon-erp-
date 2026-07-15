begin;
set local search_path=public,extensions;
select plan(8);

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous)
values('00000000-0000-0000-0000-000000000000','17000000-0000-4000-8000-000000000001','authenticated','authenticated','legacy@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),'{"provider":"email","providers":["email"]}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false);
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id='17000000-0000-4000-8000-000000000001';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '00000000-0000-4000-8000-00000000f001','17000000-0000-4000-8000-000000000001',id,statement_timestamp()-interval '1 minute','17000000-0000-4000-8000-000000000001','Legacy preservation fixture'
from private.roles where organization_id='00000000-0000-4000-8000-00000000f001' and role_key='super_admin';

select set_config('request.jwt.claim.sub','17000000-0000-4000-8000-000000000001',true);set local role authenticated;
insert into public.labels(id,tracking_number,customer_name,primary_phone,secondary_phone,governorate,city,address,landmark,product_name,contents,pieces,weight,cod_amount,shipping_fee,payment_method,instructions,internal_notes,shipper_id,store_name,product_type,status,is_printed,printed_at)
values('17000000-0000-4000-8000-000000000010','LEGACY-P2-0001','Legacy Customer','01000000000','01100000000','Cairo','Nasr City','10 Test Street','Test landmark','Printed case','Phone case',2,1.250,1250.75,75.50,'Partial Deposit','Call before delivery','Preserve this note','6525','Falcon store','COD','Printed',true,'2026-07-01 10:00:00+03');
insert into public.shipping_settings(id,key,value) values('17000000-0000-4000-8000-000000000011','legacy_printer',jsonb_build_object('paper','a6','copies',2,'rtl',true));
insert into public.governorate_shipping_fees(id,governorate,shipping_fee) values('17000000-0000-4000-8000-000000000012','Legacy Cairo',88.25);
reset role;

select is((select tracking_number from public.labels where id='17000000-0000-4000-8000-000000000010'),'LEGACY-P2-0001','tracking identity is preserved');
select is((select row(customer_name,primary_phone,secondary_phone,governorate,city,address,landmark)::text from public.labels where id='17000000-0000-4000-8000-000000000010'),row('Legacy Customer','01000000000','01100000000','Cairo','Nasr City','10 Test Street','Test landmark')::text,'customer and address fields are preserved');
select is((select row(pieces,weight,cod_amount,shipping_fee)::text from public.labels where id='17000000-0000-4000-8000-000000000010'),row(2,1.250::numeric,1250.75::numeric,75.50::numeric)::text,'quantities and decimal legacy amounts are preserved exactly');
select ok((select status='Printed' and is_printed and printed_at='2026-07-01 10:00:00+03'::timestamptz from public.labels where id='17000000-0000-4000-8000-000000000010'),'print lifecycle fields are preserved');
select is((select value from public.shipping_settings where id='17000000-0000-4000-8000-000000000011'),jsonb_build_object('paper','a6','copies',2,'rtl',true),'shipping setting JSON is preserved');
select is((select shipping_fee from public.governorate_shipping_fees where id='17000000-0000-4000-8000-000000000012'),88.25::numeric,'governorate fee is preserved');
select ok((select organization_id='00000000-0000-4000-8000-00000000f001' and created_by='17000000-0000-4000-8000-000000000001' from public.labels where id='17000000-0000-4000-8000-000000000010'),'legacy row receives explicit organization and creator ownership');

select set_config('request.jwt.claim.sub','17000000-0000-4000-8000-000000000001',true);set local role authenticated;
select throws_ok($$update public.labels set organization_id='00000000-0000-4000-8000-00000000f002' where id='17000000-0000-4000-8000-000000000010'$$,'55000','ORGANIZATION_ID_IMMUTABLE','preserved legacy data cannot be moved across organizations');
reset role;
select * from finish();
rollback;
