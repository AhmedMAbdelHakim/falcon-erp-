insert into public.organizations(id,organization_code,display_name,legal_name,currency_code,timezone_name,is_default,is_active)
values ('2f000000-0000-4000-8000-00000000f001','falcon_sandbox','Falcon Sandbox','Falcon Sandbox','EGP','Africa/Cairo',false,true)
on conflict (id) do update set is_active=true;

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous)
values
('00000000-0000-0000-0000-000000000000','2f000000-0000-4000-8000-000000000001','authenticated','authenticated','qa-admin@falcon.test',crypt('FalconQA-2026',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false),
('00000000-0000-0000-0000-000000000000','2f000000-0000-4000-8000-000000000002','authenticated','authenticated','qa-moderator@falcon.test',crypt('FalconQA-2026',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false)
on conflict (id) do update set encrypted_password=excluded.encrypted_password,email_confirmed_at=excluded.email_confirmed_at,updated_at=statement_timestamp();

update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id,display_name=case id
  when '2f000000-0000-4000-8000-000000000001' then 'QA Administrator'
  when '2f000000-0000-4000-8000-000000000002' then 'QA Moderator'
  else 'QA Moderator' end
where id in ('2f000000-0000-4000-8000-000000000001','2f000000-0000-4000-8000-000000000002');

update public.organizations set is_default=false where id='00000000-0000-4000-8000-00000000f001';
update public.organizations set is_default=true where id='2f000000-0000-4000-8000-00000000f001';

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous)
values ('00000000-0000-0000-0000-000000000000','2f000000-0000-4000-8000-000000000003','authenticated','authenticated','qa-cross-org@falcon.test',crypt('FalconQA-2026',gen_salt('bf')),statement_timestamp(),'{}','{}',statement_timestamp(),statement_timestamp(),'','','','',false,false)
on conflict (id) do update set encrypted_password=excluded.encrypted_password,email_confirmed_at=excluded.email_confirmed_at,updated_at=statement_timestamp();

update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id,display_name='QA Cross Organization'
where id='2f000000-0000-4000-8000-000000000003';

update public.organizations set is_default=false where id='2f000000-0000-4000-8000-00000000f001';
update public.organizations set is_default=true where id='00000000-0000-4000-8000-00000000f001';

insert into private.roles(id,organization_id,role_key,display_name,description,is_system)
values ('2f000000-0000-4000-8000-00000000f101','2f000000-0000-4000-8000-00000000f001','read_only','Read only','Synthetic cross-organization QA role',true)
on conflict (organization_id,role_key) do nothing;

insert into private.role_permissions(organization_id,role_id,permission_id)
select '2f000000-0000-4000-8000-00000000f001','2f000000-0000-4000-8000-00000000f101',id
from private.permissions where permission_key in ('customers.read','orders.read','wallets.read_summary')
on conflict do nothing;

insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select organization_id,user_id,role_id,statement_timestamp()-interval '1 minute',user_id,'Synthetic Phase 3.5 E2E fixture'
from (values
('00000000-0000-4000-8000-00000000f001'::uuid,'2f000000-0000-4000-8000-000000000001'::uuid,(select id from private.roles where organization_id='00000000-0000-4000-8000-00000000f001' and role_key='super_admin')),
('00000000-0000-4000-8000-00000000f001'::uuid,'2f000000-0000-4000-8000-000000000002'::uuid,(select id from private.roles where organization_id='00000000-0000-4000-8000-00000000f001' and role_key='moderator')),
('2f000000-0000-4000-8000-00000000f001'::uuid,'2f000000-0000-4000-8000-000000000003'::uuid,'2f000000-0000-4000-8000-00000000f101'::uuid)
) as fixture(organization_id,user_id,role_id)
on conflict do nothing;
