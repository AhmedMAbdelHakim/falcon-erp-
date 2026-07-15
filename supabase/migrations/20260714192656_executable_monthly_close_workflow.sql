create or replace function private.refresh_monthly_close_reconciliations(p_monthly_closing_id uuid)
returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_close accounting.monthly_closings;v_period accounting.accounting_periods;
  v_customer_issues bigint;v_courier_issues bigint;v_supplier_issues bigint;
  v_wallet_activity bigint;v_wallet_unreconciled bigint;v_payroll_issues bigint;v_partner_issues bigint;
begin
  select mc.* into strict v_close from accounting.monthly_closings mc where mc.id=p_monthly_closing_id for update;
  perform private.require_permission(v_close.organization_id,'accounting.close_period');
  select ap.* into strict v_period from accounting.accounting_periods ap where ap.organization_id=v_close.organization_id and ap.id=v_close.accounting_period_id for update;
  if v_period.status<>'closing' or v_close.status='closed' then raise exception using errcode='55000',message='CLOSE_RECONCILIATION_NOT_EDITABLE';end if;

  select
    (select count(*) from public.customer_credits c where c.organization_id=v_close.organization_id and(c.remaining_amount_minor<0 or c.remaining_amount_minor>c.original_amount_minor))+
    (select count(*) from(select pa.customer_payment_id from public.payment_allocations pa join public.customer_payments cp on cp.organization_id=pa.organization_id and cp.id=pa.customer_payment_id where pa.organization_id=v_close.organization_id group by pa.customer_payment_id,cp.amount_minor having sum(pa.amount_minor)>cp.amount_minor)over_allocated)
  into v_customer_issues;

  select
    (select count(*) from public.shipments s where s.organization_id=v_close.organization_id and s.status in('partially_delivered','delivered','returned') and(s.delivered_at at time zone 'Africa/Cairo')::date<=v_period.period_end and s.delivery_journal_entry_id is null)+
    (select count(*) from public.returns r where r.organization_id=v_close.organization_id and r.status='resolved' and(r.inspected_at at time zone 'Africa/Cairo')::date<=v_period.period_end and r.journal_entry_id is null)
  into v_courier_issues;

  select
    (select count(*) from public.grni_accruals g where g.organization_id=v_close.organization_id and g.accounting_date<=v_period.period_end and g.journal_entry_id is null)+
    (select count(*) from public.supplier_invoices i where i.organization_id=v_close.organization_id and i.invoice_date<=v_period.period_end and i.status in('posted','partially_paid','paid') and i.journal_entry_id is null)
  into v_supplier_issues;

  select count(*) into v_wallet_activity
  from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id
  where je.organization_id=v_close.organization_id and je.accounting_period_id=v_period.id and je.status in('posted','reversed') and jl.wallet_id is not null;
  select count(*) into v_wallet_unreconciled
  from public.wallets w where w.organization_id=v_close.organization_id and exists(
    select 1 from accounting.journal_entries je join accounting.journal_lines jl on jl.journal_entry_id=je.id where je.accounting_period_id=v_period.id and je.status in('posted','reversed') and jl.wallet_id=w.id
  ) and not exists(
    select 1 from public.wallet_reconciliations wr where wr.organization_id=v_close.organization_id and wr.wallet_id=w.id and wr.status='finalized' and wr.reconciliation_date>=v_period.period_end
  );

  select count(*) into v_payroll_issues from public.payroll_entries pe join public.payroll_periods pp on pp.organization_id=pe.organization_id and pp.id=pe.payroll_period_id where pe.organization_id=v_close.organization_id and pp.period_end<=v_period.period_end and pe.status in('approved','partially_paid','paid','overdue') and pe.accrual_journal_entry_id is null;
  select
    (select count(*) from public.profit_distributions d where d.organization_id=v_close.organization_id and d.status='posted' and d.posted_at::date<=v_period.period_end and d.journal_entry_id is null)+
    (select count(*) from public.partner_withdrawals w where w.organization_id=v_close.organization_id and w.status='executed' and w.executed_at::date<=v_period.period_end and w.journal_entry_id is null)
  into v_partner_issues;

  update accounting.closing_checklist_items set status=case when v_customer_issues=0 then'passed'else'failed'end,expected_minor=0,actual_minor=v_customer_issues,evidence=jsonb_build_object('calculation','customer_subledger_conservation','issue_count',v_customer_issues),checked_by=auth.uid(),checked_at=statement_timestamp() where monthly_closing_id=v_close.id and item_key='customer_deposits_credits_ar';
  update accounting.closing_checklist_items set status=case when v_courier_issues=0 then'passed'else'failed'end,expected_minor=0,actual_minor=v_courier_issues,evidence=jsonb_build_object('calculation','courier_service_event_posting','issue_count',v_courier_issues),checked_by=auth.uid(),checked_at=statement_timestamp() where monthly_closing_id=v_close.id and item_key='courier_ar_payable';
  update accounting.closing_checklist_items set status=case when v_supplier_issues=0 then'passed'else'failed'end,expected_minor=0,actual_minor=v_supplier_issues,evidence=jsonb_build_object('calculation','supplier_grni_ap_posting','issue_count',v_supplier_issues),checked_by=auth.uid(),checked_at=statement_timestamp() where monthly_closing_id=v_close.id and item_key='supplier_grni_ap';
  update accounting.closing_checklist_items set status=case when v_wallet_unreconciled=0 then'passed'else'failed'end,expected_minor=0,actual_minor=v_wallet_unreconciled,evidence=jsonb_build_object('calculation','wallet_activity_requires_finalized_reconciliation','wallet_activity_line_count',v_wallet_activity,'unreconciled_wallet_count',v_wallet_unreconciled),checked_by=auth.uid(),checked_at=statement_timestamp() where monthly_closing_id=v_close.id and item_key='wallet_reconciliations';
  update accounting.closing_checklist_items set status=case when v_payroll_issues=0 then'passed'else'failed'end,expected_minor=0,actual_minor=v_payroll_issues,evidence=jsonb_build_object('calculation','approved_payroll_accrual_completeness','issue_count',v_payroll_issues),checked_by=auth.uid(),checked_at=statement_timestamp() where monthly_closing_id=v_close.id and item_key='payroll';
  update accounting.closing_checklist_items set status=case when v_partner_issues=0 then'passed'else'failed'end,expected_minor=0,actual_minor=v_partner_issues,evidence=jsonb_build_object('calculation','partner_posting_completeness','issue_count',v_partner_issues),checked_by=auth.uid(),checked_at=statement_timestamp() where monthly_closing_id=v_close.id and item_key='partner_accounts';
  return jsonb_build_object('customer_issue_count',v_customer_issues,'courier_issue_count',v_courier_issues,'supplier_issue_count',v_supplier_issues,'wallet_activity_line_count',v_wallet_activity,'unreconciled_wallet_count',v_wallet_unreconciled,'payroll_issue_count',v_payroll_issues,'partner_issue_count',v_partner_issues);
end;$$;
revoke all on function private.refresh_monthly_close_reconciliations(uuid)from public,anon,authenticated;

do $repair$
declare d text;f text;
begin
  select pg_get_functiondef('private.validate_monthly_close(uuid)'::regprocedure)into d;
  f:=replace(d,'v_evidence := private.refresh_monthly_close_evidence(p_monthly_closing_id);','v_evidence := private.refresh_monthly_close_evidence(p_monthly_closing_id);perform private.refresh_monthly_close_reconciliations(p_monthly_closing_id);');
  if f=d then raise exception 'MONTHLY_CLOSE_RECONCILIATION_HOOK_NOT_APPLIED';end if;execute f;
end;$repair$;

do $fingerprints$
declare d text;f text;
begin
  select pg_get_functiondef('private.command_start_monthly_close(uuid,date,text,text,uuid,uuid)'::regprocedure)into d;
  f:=replace(d,'v_item_key text;','v_item_key text;v_payload jsonb:=jsonb_build_object(''organization_id'',p_organization_id,''period_start'',p_period_start,''approval_request_id'',p_approval_request_id);');
  f:=replace(f,'perform private.require_permission(p_organization_id, ''accounting.close_period'');','perform private.require_permission(p_organization_id, ''accounting.close_period'');perform private.assert_request_fingerprint(''accounting.start_close'',v_payload,p_request_fingerprint,1::smallint);');
  if f=d then raise exception 'START_CLOSE_FINGERPRINT_REPAIR_NOT_APPLIED';end if;execute f;

  select pg_get_functiondef('private.command_validate_monthly_close(uuid,uuid,text,text,uuid)'::regprocedure)into d;
  f:=replace(d,'v_result jsonb;','v_result jsonb;v_payload jsonb:=jsonb_build_object(''organization_id'',p_organization_id,''monthly_closing_id'',p_monthly_closing_id);');
  f:=replace(f,'perform private.require_permission(p_organization_id, ''accounting.close_period'');','perform private.require_permission(p_organization_id, ''accounting.close_period'');perform private.assert_request_fingerprint(''accounting.validate_close'',v_payload,p_request_fingerprint,1::smallint);');
  if f=d then raise exception 'VALIDATE_CLOSE_FINGERPRINT_REPAIR_NOT_APPLIED';end if;execute f;

  select pg_get_functiondef('private.command_close_accounting_period(uuid,uuid,uuid,jsonb,jsonb,text,text,uuid)'::regprocedure)into d;
  f:=replace(d,'v_result jsonb;','v_result jsonb;v_payload jsonb:=jsonb_build_object(''organization_id'',p_organization_id,''monthly_closing_id'',p_monthly_closing_id,''approval_request_id'',p_approval_request_id);');
  f:=replace(f,'perform private.require_permission(p_organization_id, ''accounting.close_period'');','perform private.require_permission(p_organization_id, ''accounting.close_period'');perform private.assert_request_fingerprint(''accounting.close_period'',v_payload,p_request_fingerprint,1::smallint);');
  if f=d then raise exception 'FINALIZE_CLOSE_FINGERPRINT_REPAIR_NOT_APPLIED';end if;execute f;
end;$fingerprints$;

create or replace function private.command_validate_monthly_close_with_approval(p_organization_id uuid,p_monthly_closing_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql volatile security definer set search_path=''
as $$declare v_result jsonb;v_close accounting.monthly_closings;v_approval_id uuid;v_permission_id uuid;v_payload jsonb;v_fp text;begin
v_result:=private.command_validate_monthly_close(p_organization_id,p_monthly_closing_id,p_idempotency_key,p_request_fingerprint,p_correlation_id);if not coalesce((v_result->>'success')::boolean,false)or v_result->>'current_state'<>'ready'then return v_result;end if;
select mc.* into strict v_close from accounting.monthly_closings mc where mc.organization_id=p_organization_id and mc.id=p_monthly_closing_id for update;
if v_close.approval_request_id is null then v_approval_id:=extensions.gen_random_uuid();v_payload:=jsonb_build_object('organization_id',p_organization_id,'monthly_closing_id',p_monthly_closing_id,'approval_request_id',v_approval_id);v_fp:=private.canonical_request_fingerprint('accounting.close_period',v_payload,1::smallint);select id into strict v_permission_id from private.permissions where permission_key='accounting.close_period';insert into public.approval_requests(id,organization_id,request_type,entity_type,entity_id,requested_by,submitted_at,status,required_permission_id,requires_separation_of_duties,reason,subject_fingerprint,requested_amount_minor,payload_snapshot,expires_at)values(v_approval_id,p_organization_id,'period.close','monthly_closing',p_monthly_closing_id,auth.uid(),statement_timestamp(),'submitted',v_permission_id,true,'Approve deterministic monthly close',v_fp,null,v_payload,statement_timestamp()+interval '14 days');update accounting.monthly_closings set approval_request_id=v_approval_id where id=p_monthly_closing_id;else v_approval_id:=v_close.approval_request_id;select subject_fingerprint into strict v_fp from public.approval_requests where id=v_approval_id;end if;return v_result||jsonb_build_object('approval_request_id',v_approval_id,'approval_request_fingerprint',v_fp);end;$$;

create or replace function private.command_request_accounting_period_reopen(p_organization_id uuid,p_monthly_closing_id uuid,p_reason text)returns jsonb language plpgsql volatile security definer set search_path=''
as $$declare v_close accounting.monthly_closings;v_period accounting.accounting_periods;v_approval_id uuid:=extensions.gen_random_uuid();v_permission_id uuid;v_payload jsonb;v_fp text;begin
perform private.require_permission(p_organization_id,'accounting.reopen_period');if nullif(btrim(p_reason),'')is null then raise exception using errcode='22023',message='REOPEN_REASON_REQUIRED';end if;select mc.* into strict v_close from accounting.monthly_closings mc where mc.organization_id=p_organization_id and mc.id=p_monthly_closing_id for update;select ap.* into strict v_period from accounting.accounting_periods ap where ap.organization_id=p_organization_id and ap.id=v_close.accounting_period_id for update;if v_close.status<>'closed'or v_period.status<>'closed'then raise exception using errcode='55000',message='PERIOD_NOT_REOPENABLE';end if;v_payload:=jsonb_build_object('organization_id',p_organization_id,'monthly_closing_id',p_monthly_closing_id,'action','reopen','reason',p_reason,'approval_request_id',v_approval_id);v_fp:=private.canonical_request_fingerprint('accounting.reopen_close',v_payload,1::smallint);select id into strict v_permission_id from private.permissions where permission_key='accounting.reopen_period';insert into public.approval_requests(id,organization_id,request_type,entity_type,entity_id,requested_by,submitted_at,status,required_permission_id,requires_separation_of_duties,reason,subject_fingerprint,payload_snapshot,expires_at)values(v_approval_id,p_organization_id,'period.reopen','accounting_period',v_period.id,auth.uid(),statement_timestamp(),'submitted',v_permission_id,true,p_reason,v_fp,v_payload,statement_timestamp()+interval '7 days');return jsonb_build_object('success',true,'entity_id',v_period.id,'approval_request_id',v_approval_id,'approval_request_fingerprint',v_fp,'current_state','submitted');end;$$;

create or replace function api.validate_monthly_close(p_organization_id uuid,p_monthly_closing_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language sql volatile security invoker set search_path=''as $$select private.command_validate_monthly_close_with_approval(p_organization_id,p_monthly_closing_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.request_accounting_period_reopen(p_organization_id uuid,p_monthly_closing_id uuid,p_reason text)returns jsonb language sql volatile security invoker set search_path=''as $$select private.command_request_accounting_period_reopen(p_organization_id,p_monthly_closing_id,p_reason)$$;

revoke all on function private.command_validate_monthly_close_with_approval(uuid,uuid,text,text,uuid)from public,anon,authenticated;grant execute on function private.command_validate_monthly_close_with_approval(uuid,uuid,text,text,uuid)to authenticated;
revoke all on function private.command_request_accounting_period_reopen(uuid,uuid,text)from public,anon,authenticated;grant execute on function private.command_request_accounting_period_reopen(uuid,uuid,text)to authenticated;
revoke all on function api.validate_monthly_close(uuid,uuid,text,text,uuid)from public,anon,authenticated;grant execute on function api.validate_monthly_close(uuid,uuid,text,text,uuid)to authenticated;
revoke all on function api.request_accounting_period_reopen(uuid,uuid,text)from public,anon,authenticated;grant execute on function api.request_accounting_period_reopen(uuid,uuid,text)to authenticated;

grant execute on function private.command_attest_monthly_close_item(uuid,uuid,text,text,bigint,bigint,jsonb,text,uuid,text,text,uuid)to authenticated;
grant execute on function private.command_change_monthly_close_state(uuid,uuid,text,text,uuid,text,text,uuid)to authenticated;
grant execute on function private.command_start_monthly_close(uuid,date,text,text,uuid,uuid)to authenticated;
grant execute on function private.command_validate_monthly_close(uuid,uuid,text,text,uuid)to authenticated;
grant execute on function private.command_close_accounting_period(uuid,uuid,uuid,jsonb,jsonb,text,text,uuid)to authenticated;
