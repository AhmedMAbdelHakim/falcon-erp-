insert into private.permissions(id,permission_key,description,is_sensitive) values
(md5('falcon-permission:payroll.advance.record')::uuid,'payroll.advance.record','Record approved employee advances',true),
(md5('falcon-permission:expenses.reverse')::uuid,'expenses.reverse','Reverse approved unpaid expenses',true)
on conflict(permission_key)do nothing;

create or replace function private.command_request_employee_advance(
  p_organization_id uuid,p_employee_id uuid,p_wallet_id uuid,p_amount_minor bigint,
  p_reason text,p_idempotency_key text,p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare
  c record;a uuid:=extensions.gen_random_uuid();q uuid:=extensions.gen_random_uuid();perm uuid;
  payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'employee_id',p_employee_id,'wallet_id',p_wallet_id,'amount_minor',p_amount_minor,'reason',p_reason);
  result jsonb;s text;
begin
  perform private.require_permission(p_organization_id,'payroll.advance.record');
  perform private.assert_request_fingerprint('payroll.advance.record',payload,p_request_fingerprint,1);
  if p_amount_minor<=0 or nullif(btrim(p_reason),'')is null then raise exception using errcode='22023',message='EMPLOYEE_ADVANCE_REQUEST_INVALID';end if;
  select * into c from private.claim_command(p_organization_id,'payroll.advance.request',p_idempotency_key,p_request_fingerprint,1,p_correlation_id);
  if c.is_replay then return private.command_replay_response(c.command_status,c.result_reference,c.error_code,c.command_execution_id);end if;
  begin
    perform 1 from public.employees where organization_id=p_organization_id and id=p_employee_id and status='active' for update;
    if not found then raise exception using errcode='P0002',message='EMPLOYEE_NOT_ACTIVE';end if;
    perform 1 from public.wallets where organization_id=p_organization_id and id=p_wallet_id and is_active for update;
    if not found then raise exception using errcode='P0002',message='WALLET_NOT_ACTIVE';end if;
    select id into strict perm from private.permissions where permission_key='payroll.advance.record'and is_active;
    insert into public.employee_advances(id,organization_id,employee_id,wallet_id,request_date,amount_minor,status,reason,approval_request_id,created_by,updated_by)
    values(a,p_organization_id,p_employee_id,p_wallet_id,private.cairo_accounting_date(),p_amount_minor,'draft',p_reason,q,auth.uid(),auth.uid());
    insert into public.approval_requests(id,organization_id,request_type,entity_type,entity_id,requested_by,submitted_at,status,required_permission_id,requires_separation_of_duties,reason,subject_fingerprint,requested_amount_minor,approved_min_amount_minor,approved_max_amount_minor,payload_snapshot,expires_at)
    values(q,p_organization_id,'employee.advance','employee_advance',a,auth.uid(),statement_timestamp(),'submitted',perm,true,p_reason,p_request_fingerprint,p_amount_minor,p_amount_minor,p_amount_minor,payload,statement_timestamp()+interval'14 days');
    result:=private.command_success_response(c.command_execution_id,a,'submitted','employee.advance_requested','[]',jsonb_build_object('approval_request_id',q,'approval_request_fingerprint',p_request_fingerprint));
    perform private.complete_command_success(c.command_execution_id,result);return result;
  exception when others then
    s:=sqlstate;if private.is_retryable_sqlstate(s)then return private.release_retryable_command(c.command_execution_id,s,'payroll.advance.request','employee',p_employee_id,p_idempotency_key,p_correlation_id);end if;
    perform private.complete_command_failure(c.command_execution_id,'EMPLOYEE_ADVANCE_REQUEST_REJECTED',null);return private.command_replay_response('failed_terminal',null,'EMPLOYEE_ADVANCE_REQUEST_REJECTED',c.command_execution_id);
  end;
end;$$;

create or replace function private.command_record_employee_advance(
  p_organization_id uuid,p_employee_advance_id uuid,p_idempotency_key text,
  p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare
  c record;a public.employee_advances;w public.wallets;q public.approval_requests;
  payload jsonb;j uuid;result jsonb;s text;
begin
  perform private.require_permission(p_organization_id,'payroll.advance.record');
  select * into strict a from public.employee_advances where organization_id=p_organization_id and id=p_employee_advance_id;
  payload:=jsonb_build_object('organization_id',a.organization_id,'employee_id',a.employee_id,'wallet_id',a.wallet_id,'amount_minor',a.amount_minor,'reason',a.reason);
  perform private.assert_request_fingerprint('payroll.advance.record',payload,p_request_fingerprint,1);
  select * into c from private.claim_command(p_organization_id,'payroll.advance.record',p_idempotency_key,p_request_fingerprint,1,p_correlation_id);
  if c.is_replay then return private.command_replay_response(c.command_status,c.result_reference,c.error_code,c.command_execution_id);end if;
  begin
    select * into strict a from public.employee_advances where organization_id=p_organization_id and id=p_employee_advance_id for update;
    select * into strict w from public.wallets where organization_id=p_organization_id and id=a.wallet_id and is_active for update;
    select * into strict q from public.approval_requests where organization_id=p_organization_id and id=a.approval_request_id for update;
    if a.status<>'draft'or q.payload_snapshot<>payload or q.subject_fingerprint<>p_request_fingerprint then raise exception using errcode='55000',message='EMPLOYEE_ADVANCE_APPROVAL_SCOPE_INVALID';end if;
    perform private.consume_approval(p_organization_id,q.id,'employee.advance','employee_advance',a.id,p_request_fingerprint,c.command_execution_id,a.amount_minor);
    j:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'employee_advance',p_source_id=>a.id,p_posting_purpose=>'payment',p_description=>'Approved employee advance',p_lines=>jsonb_build_array(
      jsonb_build_object('account_role','employee_advances','debit_minor',a.amount_minor::text,'credit_minor','0','employee_id',a.employee_id,'subledger_type','employee_advance','subledger_id',a.id),
      jsonb_build_object('account_role','wallet_'||lower(regexp_replace(w.code,'[^a-zA-Z0-9]+','_','g')),'debit_minor','0','credit_minor',a.amount_minor::text,'wallet_id',w.id,'employee_id',a.employee_id,'subledger_type','employee_advance','subledger_id',a.id)
    ),p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_approval_request_id=>q.id,p_command_type=>'payroll.advance.record',p_command_execution_id=>c.command_execution_id,p_require_manual_permission=>false);
    update public.employee_advances set status='paid',paid_date=private.cairo_accounting_date(),journal_entry_id=j,updated_by=auth.uid(),version=version+1 where id=a.id;
    result:=private.command_success_response(c.command_execution_id,a.id,'paid','employee.advance_paid',jsonb_build_array(j));perform private.complete_command_success(c.command_execution_id,result);return result;
  exception when others then
    s:=sqlstate;if private.is_retryable_sqlstate(s)then return private.release_retryable_command(c.command_execution_id,s,'payroll.advance.record','employee_advance',p_employee_advance_id,p_idempotency_key,p_correlation_id);end if;
    perform private.complete_command_failure(c.command_execution_id,'EMPLOYEE_ADVANCE_RECORD_REJECTED',null);return private.command_replay_response('failed_terminal',null,'EMPLOYEE_ADVANCE_RECORD_REJECTED',c.command_execution_id);
  end;
end;$$;

create or replace function api.request_employee_advance(uuid,uuid,uuid,bigint,text,text,text,uuid)returns jsonb language sql volatile security invoker set search_path=''as $$select private.command_request_employee_advance($1,$2,$3,$4,$5,$6,$7,$8)$$;
create or replace function api.record_employee_advance(uuid,uuid,text,text,uuid)returns jsonb language sql volatile security invoker set search_path=''as $$select private.command_record_employee_advance($1,$2,$3,$4,$5)$$;

create or replace function private.command_request_expense_reversal(
  p_organization_id uuid,p_expense_id uuid,p_reason text,p_idempotency_key text,
  p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare
  c record;e public.expenses;q uuid:=extensions.gen_random_uuid();perm uuid;
  payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'expense_id',p_expense_id,'reason',p_reason);
  result jsonb;s text;
begin
  perform private.require_permission(p_organization_id,'expenses.reverse');
  perform private.assert_request_fingerprint('expenses.reverse',payload,p_request_fingerprint,1);
  select * into c from private.claim_command(p_organization_id,'expenses.reverse.request',p_idempotency_key,p_request_fingerprint,1,p_correlation_id);
  if c.is_replay then return private.command_replay_response(c.command_status,c.result_reference,c.error_code,c.command_execution_id);end if;
  begin
    select * into strict e from public.expenses where organization_id=p_organization_id and id=p_expense_id for update;
    if e.status<>'approved'or e.paid_minor<>0 or e.journal_entry_id is null or nullif(btrim(p_reason),'')is null then raise exception using errcode='55000',message='EXPENSE_NOT_REVERSIBLE';end if;
    select id into strict perm from private.permissions where permission_key='expenses.reverse'and is_active;
    insert into public.approval_requests(id,organization_id,request_type,entity_type,entity_id,requested_by,submitted_at,status,required_permission_id,requires_separation_of_duties,reason,subject_fingerprint,requested_amount_minor,approved_min_amount_minor,approved_max_amount_minor,payload_snapshot,expires_at)
    values(q,p_organization_id,'expense.reverse','expense',e.id,auth.uid(),statement_timestamp(),'submitted',perm,true,p_reason,p_request_fingerprint,e.total_minor,e.total_minor,e.total_minor,payload,statement_timestamp()+interval'14 days');
    result:=private.command_success_response(c.command_execution_id,e.id,'submitted','expense.reversal_requested','[]',jsonb_build_object('approval_request_id',q,'approval_request_fingerprint',p_request_fingerprint));
    perform private.complete_command_success(c.command_execution_id,result);return result;
  exception when others then
    s:=sqlstate;if private.is_retryable_sqlstate(s)then return private.release_retryable_command(c.command_execution_id,s,'expenses.reverse.request','expense',p_expense_id,p_idempotency_key,p_correlation_id);end if;
    perform private.complete_command_failure(c.command_execution_id,'EXPENSE_REVERSAL_REQUEST_REJECTED',null);return private.command_replay_response('failed_terminal',null,'EXPENSE_REVERSAL_REQUEST_REJECTED',c.command_execution_id);
  end;
end;$$;

create or replace function private.command_reverse_expense(
  p_organization_id uuid,p_expense_id uuid,p_reason text,p_approval_request_id uuid,
  p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()
)returns jsonb language plpgsql volatile security definer set search_path=''as $$
declare
  c record;e public.expenses;r uuid;result jsonb;s text;
  payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'expense_id',p_expense_id,'reason',p_reason);
begin
  perform private.require_permission(p_organization_id,'expenses.reverse');
  perform private.assert_request_fingerprint('expenses.reverse',payload,p_request_fingerprint,1);
  select * into c from private.claim_command(p_organization_id,'expenses.reverse',p_idempotency_key,p_request_fingerprint,1,p_correlation_id);
  if c.is_replay then return private.command_replay_response(c.command_status,c.result_reference,c.error_code,c.command_execution_id);end if;
  begin
    select * into strict e from public.expenses where organization_id=p_organization_id and id=p_expense_id for update;
    if e.status<>'approved'or e.paid_minor<>0 or e.journal_entry_id is null then raise exception using errcode='55000',message='EXPENSE_NOT_REVERSIBLE';end if;
    perform private.consume_approval(p_organization_id,p_approval_request_id,'expense.reverse','expense',e.id,p_request_fingerprint,c.command_execution_id,e.total_minor);
    r:=private.reverse_journal_entry(p_organization_id,e.journal_entry_id,p_reason,p_idempotency_key,p_request_fingerprint,p_correlation_id,p_approval_request_id,c.command_execution_id);
    update public.expenses set status='reversed',updated_by=auth.uid(),version=version+1 where id=e.id;
    result:=private.command_success_response(c.command_execution_id,e.id,'reversed','expense.reversed',jsonb_build_array(r));perform private.complete_command_success(c.command_execution_id,result);return result;
  exception when others then
    s:=sqlstate;if private.is_retryable_sqlstate(s)then return private.release_retryable_command(c.command_execution_id,s,'expenses.reverse','expense',p_expense_id,p_idempotency_key,p_correlation_id);end if;
    perform private.complete_command_failure(c.command_execution_id,'EXPENSE_REVERSAL_REJECTED',null);return private.command_replay_response('failed_terminal',null,'EXPENSE_REVERSAL_REJECTED',c.command_execution_id);
  end;
end;$$;

create or replace function api.request_expense_reversal(uuid,uuid,text,text,text,uuid)returns jsonb language sql volatile security invoker set search_path=''as $$select private.command_request_expense_reversal($1,$2,$3,$4,$5,$6)$$;
create or replace function api.reverse_expense(uuid,uuid,text,uuid,text,text,uuid)returns jsonb language sql volatile security invoker set search_path=''as $$select private.command_reverse_expense($1,$2,$3,$4,$5,$6,$7)$$;

do $$declare x record;begin for x in select p.oid::regprocedure s from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('api','private')and p.proname in('request_employee_advance','record_employee_advance','request_expense_reversal','reverse_expense','command_request_employee_advance','command_record_employee_advance','command_request_expense_reversal','command_reverse_expense')loop execute format('revoke all on function %s from public,anon',x.s);execute format('grant execute on function %s to authenticated',x.s);end loop;end$$;
