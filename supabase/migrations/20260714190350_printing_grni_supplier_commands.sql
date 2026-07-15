-- Printing dispatch and QC receipt with GRNI ownership.
create or replace function private.command_create_print_batch(p_organization_id uuid,p_supplier_id uuid,p_batch_number text,p_items jsonb,p_business_date date,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql volatile security definer set search_path=''
as $$declare v_claim record;v_id uuid;v_result jsonb;v_sqlstate text;v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'supplier_id',p_supplier_id,'batch_number',p_batch_number,'items',p_items,'business_date',p_business_date);begin
perform private.require_permission(p_organization_id,'print_batches.create');perform private.assert_request_fingerprint('print_batches.create',v_payload,p_request_fingerprint,1::smallint);if jsonb_typeof(p_items)<>'array'or jsonb_array_length(p_items)=0 then raise exception using errcode='22023',message='PRINT_BATCH_ITEMS_REQUIRED';end if;select * into v_claim from private.claim_command(p_organization_id,'print_batches.create',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
begin perform 1 from public.suppliers where organization_id=p_organization_id and id=p_supplier_id and is_active for update;if not found then raise exception using errcode='23503',message='ACTIVE_SUPPLIER_REQUIRED';end if;
if exists(select 1 from jsonb_to_recordset(p_items)x(order_item_id uuid,quantity integer,expected_case_unit_cost_minor bigint,expected_print_unit_cost_minor bigint)left join public.order_items oi on oi.organization_id=p_organization_id and oi.id=x.order_item_id where oi.id is null or x.quantity<=0 or x.quantity>oi.quantity or x.expected_case_unit_cost_minor<0 or x.expected_print_unit_cost_minor<0)then raise exception using errcode='23514',message='INVALID_PRINT_BATCH_ITEM';end if;
insert into public.print_batches(organization_id,supplier_id,batch_no,status,business_date,sent_at,created_by,updated_by)values(p_organization_id,p_supplier_id,p_batch_number,'sent',p_business_date,statement_timestamp(),auth.uid(),auth.uid())returning id into v_id;
insert into public.print_batch_items(organization_id,print_batch_id,order_item_id,attempt_no,supply_method,status,requested_quantity,sent_quantity,expected_case_unit_cost_minor,expected_print_unit_cost_minor,expected_total_unit_cost_minor,queued_at,sent_at,created_by,updated_by)
select p_organization_id,v_id,x.order_item_id,coalesce((select max(attempt_no)+1 from public.print_batch_items where organization_id=p_organization_id and order_item_id=x.order_item_id),1),oi.supply_method,'sent',x.quantity,x.quantity,x.expected_case_unit_cost_minor,x.expected_print_unit_cost_minor,x.expected_case_unit_cost_minor+x.expected_print_unit_cost_minor,statement_timestamp(),statement_timestamp(),auth.uid(),auth.uid()from jsonb_to_recordset(p_items)x(order_item_id uuid,quantity integer,expected_case_unit_cost_minor bigint,expected_print_unit_cost_minor bigint)join public.order_items oi on oi.id=x.order_item_id;
update public.orders o set status='printing',version=version+1 where o.id in(select distinct oi.order_id from public.order_items oi join public.print_batch_items bi on bi.order_item_id=oi.id where bi.print_batch_id=v_id);
v_result:=private.command_success_response(v_claim.command_execution_id,v_id,'sent','print_batch.sent');perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
exception when others then v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate)then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'print_batches.create','print_batch',null,p_idempotency_key,p_correlation_id);end if;perform private.complete_command_failure(v_claim.command_execution_id,'PRINT_BATCH_CREATION_REJECTED',null);return private.command_replay_response('failed_terminal',null,'PRINT_BATCH_CREATION_REJECTED',v_claim.command_execution_id);end;end$$;

create or replace function private.command_receive_print_batch(p_organization_id uuid,p_print_batch_id uuid,p_receipt_number text,p_items jsonb,p_received_at timestamptz,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language plpgsql volatile security definer set search_path=''
as $$declare v_claim record;v_batch public.print_batches;v_receipt uuid:=extensions.gen_random_uuid();v_total bigint;v_journal uuid;v_main uuid;v_row record;v_receipt_item uuid;v_qc uuid;v_result jsonb;v_sqlstate text;v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'print_batch_id',p_print_batch_id,'receipt_number',p_receipt_number,'items',p_items,'received_at',p_received_at);begin
perform private.require_permission(p_organization_id,'print_batches.receive');perform private.assert_request_fingerprint('print_batches.receive',v_payload,p_request_fingerprint,1::smallint);if jsonb_typeof(p_items)<>'array'or jsonb_array_length(p_items)=0 then raise exception using errcode='22023',message='PRINT_RECEIPT_ITEMS_REQUIRED';end if;select * into v_claim from private.claim_command(p_organization_id,'print_batches.receive',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
begin select b.* into strict v_batch from public.print_batches b where b.organization_id=p_organization_id and b.id=p_print_batch_id for update;if v_batch.status not in('sent','acknowledged','in_production','partially_received')then raise exception using errcode='55000',message='PRINT_BATCH_NOT_RECEIVABLE';end if;perform 1 from public.print_batch_items bi join(select x.print_batch_item_id from jsonb_to_recordset(p_items)x(print_batch_item_id uuid,accepted_quantity integer,rejected_quantity integer,rejection_reason text))q on q.print_batch_item_id=bi.id where bi.organization_id=p_organization_id and bi.print_batch_id=p_print_batch_id order by bi.id for update of bi;
if exists(select 1 from jsonb_to_recordset(p_items)x(print_batch_item_id uuid,accepted_quantity integer,rejected_quantity integer,rejection_reason text)left join public.print_batch_items bi on bi.organization_id=p_organization_id and bi.print_batch_id=p_print_batch_id and bi.id=x.print_batch_item_id where bi.id is null or x.accepted_quantity<0 or x.rejected_quantity<0 or x.accepted_quantity+x.rejected_quantity<=0 or x.accepted_quantity+x.rejected_quantity>bi.sent_quantity-bi.received_quantity or(x.rejected_quantity>0 and nullif(btrim(x.rejection_reason),'')is null))then raise exception using errcode='23514',message='INVALID_PRINT_RECEIPT_QUANTITY';end if;
select coalesce(sum(x.accepted_quantity*bi.expected_total_unit_cost_minor),0)into v_total from jsonb_to_recordset(p_items)x(print_batch_item_id uuid,accepted_quantity integer,rejected_quantity integer,rejection_reason text)join public.print_batch_items bi on bi.id=x.print_batch_item_id;if v_total<=0 then raise exception using errcode='23514',message='ACCEPTED_PRINT_VALUE_REQUIRED';end if;
v_journal:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'print_receipt',p_source_id=>v_receipt,p_posting_purpose=>'grni',p_description=>'Accepted print receipt and GRNI',p_lines=>jsonb_build_array(jsonb_build_object('account_role','inventory','debit_minor',v_total::text,'credit_minor','0','print_batch_id',v_batch.id,'subledger_type','print_receipt','subledger_id',v_receipt),jsonb_build_object('account_role','goods_received_not_invoiced','debit_minor','0','credit_minor',v_total::text,'supplier_id',v_batch.supplier_id,'print_batch_id',v_batch.id,'subledger_type','print_receipt','subledger_id',v_receipt)),p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_command_type=>'print_batches.receive',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);
insert into public.print_batch_receipts(id,organization_id,print_batch_id,receipt_no,received_at,received_by,created_by,updated_by)values(v_receipt,p_organization_id,v_batch.id,p_receipt_number,p_received_at,auth.uid(),auth.uid(),auth.uid());select id into strict v_main from public.inventory_locations where organization_id=p_organization_id and code='FALCON_MAIN';
for v_row in select x.*,bi.order_item_id,bi.expected_total_unit_cost_minor,oi.product_variant_id from jsonb_to_recordset(p_items)x(print_batch_item_id uuid,accepted_quantity integer,rejected_quantity integer,rejection_reason text)join public.print_batch_items bi on bi.id=x.print_batch_item_id join public.order_items oi on oi.id=bi.order_item_id order by bi.id loop
 insert into public.print_batch_receipt_items(organization_id,print_batch_receipt_id,print_batch_item_id,received_quantity,created_by,updated_by)values(p_organization_id,v_receipt,v_row.print_batch_item_id,v_row.accepted_quantity+v_row.rejected_quantity,auth.uid(),auth.uid())returning id into v_receipt_item;
 insert into public.print_batch_qc_events(organization_id,print_batch_receipt_item_id,print_batch_item_id,status,inspected_quantity,accepted_quantity,rejected_quantity,rejection_reason,inspected_at,inspected_by,created_by,updated_by)values(p_organization_id,v_receipt_item,v_row.print_batch_item_id,case when v_row.rejected_quantity=0 then'accepted'when v_row.accepted_quantity=0 then'rejected'else'partially_accepted'end,v_row.accepted_quantity+v_row.rejected_quantity,v_row.accepted_quantity,v_row.rejected_quantity,v_row.rejection_reason,p_received_at,auth.uid(),auth.uid(),auth.uid())returning id into v_qc;
 if v_row.accepted_quantity>0 then insert into public.grni_accruals(organization_id,print_batch_qc_event_id,print_batch_item_id,entry_kind,accepted_quantity,unit_cost_minor,accrued_amount_minor,accounting_date,journal_entry_id,created_by,updated_by)values(p_organization_id,v_qc,v_row.print_batch_item_id,'accrual',v_row.accepted_quantity,v_row.expected_total_unit_cost_minor,v_row.accepted_quantity*v_row.expected_total_unit_cost_minor,private.cairo_accounting_date(),v_journal,auth.uid(),auth.uid());if v_row.product_variant_id is not null then insert into public.inventory_movements(organization_id,movement_type,product_variant_id,to_location_id,quantity,unit_cost_minor,total_cost_minor,print_batch_item_id,order_item_id,source_type,source_id,correlation_id,reason,occurred_at,accounting_date,journal_entry_id,created_by,updated_by)values(p_organization_id,'production_receipt',v_row.product_variant_id,v_main,v_row.accepted_quantity,v_row.expected_total_unit_cost_minor,v_row.accepted_quantity*v_row.expected_total_unit_cost_minor,v_row.print_batch_item_id,v_row.order_item_id,'print_qc_event',v_qc,p_correlation_id,'Accepted supplier production',p_received_at,private.cairo_accounting_date(),v_journal,auth.uid(),auth.uid());end if;end if;
 update public.print_batch_items set received_quantity=received_quantity+v_row.accepted_quantity+v_row.rejected_quantity,accepted_quantity=accepted_quantity+v_row.accepted_quantity,rejected_quantity=rejected_quantity+v_row.rejected_quantity,status=case when received_quantity+v_row.accepted_quantity+v_row.rejected_quantity=sent_quantity then'qc_complete'else'partially_received'end,qc_completed_at=case when received_quantity+v_row.accepted_quantity+v_row.rejected_quantity=sent_quantity then p_received_at else null end,version=version+1 where id=v_row.print_batch_item_id;
end loop;
update public.print_batches set status=case when not exists(select 1 from public.print_batch_items where print_batch_id=v_batch.id and received_quantity<sent_quantity)then'ready_for_invoice'else'partially_received'end,version=version+1 where id=v_batch.id;
v_result:=private.command_success_response(v_claim.command_execution_id,v_receipt,'received','print_batch.received',jsonb_build_array(v_journal),jsonb_build_object('grni_minor',v_total));perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
exception when others then v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate)then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'print_batches.receive','print_batch',p_print_batch_id,p_idempotency_key,p_correlation_id);end if;perform private.complete_command_failure(v_claim.command_execution_id,'PRINT_RECEIPT_REJECTED',null);return private.command_replay_response('failed_terminal',null,'PRINT_RECEIPT_REJECTED',v_claim.command_execution_id);end;end$$;

create unique index supplier_invoice_items_one_grni_idx
  on public.supplier_invoice_items(grni_accrual_id)
  where grni_accrual_id is not null;

create or replace function private.command_create_supplier_invoice(
  p_organization_id uuid,p_supplier_id uuid,p_print_batch_id uuid,p_invoice_number text,
  p_invoice_date date,p_due_date date,p_items jsonb,p_tax_minor bigint,p_credit_minor bigint,
  p_idempotency_key text,p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_claim record;v_invoice_id uuid;v_subtotal bigint;v_total bigint;v_approval_id uuid;
  v_approval_payload jsonb;v_approval_fingerprint text;v_result jsonb;v_sqlstate text;
  v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'supplier_id',p_supplier_id,'print_batch_id',p_print_batch_id,'invoice_number',p_invoice_number,'invoice_date',p_invoice_date,'due_date',p_due_date,'items',p_items,'tax_minor',p_tax_minor,'credit_minor',p_credit_minor);
begin
  perform private.require_permission(p_organization_id,'supplier_invoices.create');
  perform private.assert_request_fingerprint('supplier_invoices.create',v_payload,p_request_fingerprint,1::smallint);
  if nullif(btrim(p_invoice_number),'') is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 or p_tax_minor<0 or p_credit_minor<0 or p_due_date<p_invoice_date then
    raise exception using errcode='22023',message='INVALID_SUPPLIER_INVOICE';
  end if;
  select * into v_claim from private.claim_command(p_organization_id,'supplier_invoices.create',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);
  if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
  begin
    perform 1 from public.suppliers where organization_id=p_organization_id and id=p_supplier_id and is_active for update;
    if not found then raise exception using errcode='23503',message='ACTIVE_SUPPLIER_REQUIRED';end if;
    perform 1 from public.print_batches where organization_id=p_organization_id and id=p_print_batch_id and supplier_id=p_supplier_id and status='ready_for_invoice' for update;
    if not found then raise exception using errcode='55000',message='PRINT_BATCH_NOT_READY_FOR_INVOICE';end if;
    perform 1
      from public.grni_accruals ga
      join (select x.grni_accrual_id from jsonb_to_recordset(p_items)x(grni_accrual_id uuid,invoiced_quantity integer,invoiced_unit_cost_minor bigint,description text)) requested on requested.grni_accrual_id=ga.id
      where ga.organization_id=p_organization_id
      order by ga.id for update of ga;
    if exists(
      select 1
      from jsonb_to_recordset(p_items)x(grni_accrual_id uuid,invoiced_quantity integer,invoiced_unit_cost_minor bigint,description text)
      left join public.grni_accruals ga on ga.organization_id=p_organization_id and ga.id=x.grni_accrual_id and ga.entry_kind='accrual'
      left join public.print_batch_items bi on bi.organization_id=p_organization_id and bi.id=ga.print_batch_item_id and bi.print_batch_id=p_print_batch_id
      where ga.id is null or bi.id is null or x.invoiced_quantity<>ga.accepted_quantity or x.invoiced_unit_cost_minor<0 or nullif(btrim(x.description),'') is null
    ) or (select count(*) from jsonb_to_recordset(p_items)x(grni_accrual_id uuid))<>(select count(distinct x.grni_accrual_id) from jsonb_to_recordset(p_items)x(grni_accrual_id uuid)) then
      raise exception using errcode='23514',message='INVALID_GRNI_MATCH';
    end if;
    select coalesce(sum(x.invoiced_quantity::bigint*x.invoiced_unit_cost_minor),0) into v_subtotal
      from jsonb_to_recordset(p_items)x(grni_accrual_id uuid,invoiced_quantity integer,invoiced_unit_cost_minor bigint,description text);
    v_total:=v_subtotal+p_tax_minor-p_credit_minor;
    if v_total<=0 or p_credit_minor>v_subtotal+p_tax_minor then raise exception using errcode='23514',message='INVALID_SUPPLIER_INVOICE_TOTAL';end if;
    insert into public.supplier_invoices(organization_id,supplier_id,print_batch_id,invoice_no,invoice_date,due_date,status,subtotal_minor,tax_minor,credit_minor,total_minor,created_by,updated_by)
    values(p_organization_id,p_supplier_id,p_print_batch_id,p_invoice_number,p_invoice_date,p_due_date,'submitted',v_subtotal,p_tax_minor,p_credit_minor,v_total,auth.uid(),auth.uid()) returning id into v_invoice_id;
    insert into public.supplier_invoice_items(organization_id,supplier_invoice_id,print_batch_item_id,grni_accrual_id,description,invoiced_quantity,invoiced_unit_cost_minor,line_amount_minor,matched_grni_minor,variance_minor,created_by,updated_by)
    select p_organization_id,v_invoice_id,ga.print_batch_item_id,ga.id,x.description,x.invoiced_quantity,x.invoiced_unit_cost_minor,x.invoiced_quantity::bigint*x.invoiced_unit_cost_minor,ga.accrued_amount_minor,x.invoiced_quantity::bigint*x.invoiced_unit_cost_minor-ga.accrued_amount_minor,auth.uid(),auth.uid()
      from jsonb_to_recordset(p_items)x(grni_accrual_id uuid,invoiced_quantity integer,invoiced_unit_cost_minor bigint,description text)
      join public.grni_accruals ga on ga.id=x.grni_accrual_id;
    select jsonb_build_object(
      'organization_id',i.organization_id,'supplier_invoice_id',i.id,'supplier_id',i.supplier_id,'print_batch_id',i.print_batch_id,
      'invoice_number',i.invoice_no,'invoice_date',i.invoice_date,'due_date',i.due_date,'subtotal_minor',i.subtotal_minor,'tax_minor',i.tax_minor,'credit_minor',i.credit_minor,'total_minor',i.total_minor,
      'items',(select jsonb_agg(jsonb_build_object('grni_accrual_id',ii.grni_accrual_id,'print_batch_item_id',ii.print_batch_item_id,'invoiced_quantity',ii.invoiced_quantity,'invoiced_unit_cost_minor',ii.invoiced_unit_cost_minor,'line_amount_minor',ii.line_amount_minor,'matched_grni_minor',ii.matched_grni_minor,'variance_minor',ii.variance_minor) order by ii.grni_accrual_id) from public.supplier_invoice_items ii where ii.supplier_invoice_id=i.id)
    ) into v_approval_payload from public.supplier_invoices i where i.id=v_invoice_id;
    v_approval_fingerprint:=encode(extensions.digest(convert_to(v_approval_payload::text,'UTF8'),'sha256'),'hex');
    v_approval_id:=private.command_submit_approval_request(p_organization_id,'supplier_invoice.approve','supplier_invoice',v_invoice_id,'supplier_invoices.approve','Approve GRNI-matched supplier invoice',v_approval_payload,v_approval_fingerprint,v_total,null,statement_timestamp()+interval '14 days');
    update public.supplier_invoices set approval_request_id=v_approval_id where id=v_invoice_id;
    v_result:=private.command_success_response(v_claim.command_execution_id,v_invoice_id,'submitted','supplier_invoice.created','[]'::jsonb,jsonb_build_object('approval_request_id',v_approval_id,'total_minor',v_total));
    perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
  exception when others then
    v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate)then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'supplier_invoices.create','supplier_invoice',null,p_idempotency_key,p_correlation_id);end if;
    perform private.complete_command_failure(v_claim.command_execution_id,'SUPPLIER_INVOICE_CREATION_REJECTED',null);return private.command_replay_response('failed_terminal',null,'SUPPLIER_INVOICE_CREATION_REJECTED',v_claim.command_execution_id);
  end;
end;$$;

create or replace function private.command_approve_supplier_invoice(
  p_organization_id uuid,p_supplier_invoice_id uuid,p_idempotency_key text,p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_claim record;v_invoice public.supplier_invoices;v_approval public.approval_requests;
  v_approval_payload jsonb;v_approval_fingerprint text;v_matched bigint;v_variance bigint;v_lines jsonb;
  v_journal uuid;v_result jsonb;v_sqlstate text;
  v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'supplier_invoice_id',p_supplier_invoice_id);
begin
  perform private.require_permission(p_organization_id,'supplier_invoices.approve');
  perform private.assert_request_fingerprint('supplier_invoices.approve',v_payload,p_request_fingerprint,1::smallint);
  select * into v_claim from private.claim_command(p_organization_id,'supplier_invoices.approve',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);
  if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
  begin
    select i.* into strict v_invoice from public.supplier_invoices i where i.organization_id=p_organization_id and i.id=p_supplier_invoice_id for update;
    if v_invoice.status<>'submitted' or v_invoice.created_by=auth.uid() then raise exception using errcode='42501',message='SUPPLIER_INVOICE_APPROVAL_SOD_OR_STATE_INVALID';end if;
    perform 1 from public.supplier_invoice_items ii where ii.organization_id=p_organization_id and ii.supplier_invoice_id=v_invoice.id order by ii.id for update;
    select jsonb_build_object(
      'organization_id',i.organization_id,'supplier_invoice_id',i.id,'supplier_id',i.supplier_id,'print_batch_id',i.print_batch_id,
      'invoice_number',i.invoice_no,'invoice_date',i.invoice_date,'due_date',i.due_date,'subtotal_minor',i.subtotal_minor,'tax_minor',i.tax_minor,'credit_minor',i.credit_minor,'total_minor',i.total_minor,
      'items',(select jsonb_agg(jsonb_build_object('grni_accrual_id',ii.grni_accrual_id,'print_batch_item_id',ii.print_batch_item_id,'invoiced_quantity',ii.invoiced_quantity,'invoiced_unit_cost_minor',ii.invoiced_unit_cost_minor,'line_amount_minor',ii.line_amount_minor,'matched_grni_minor',ii.matched_grni_minor,'variance_minor',ii.variance_minor) order by ii.grni_accrual_id) from public.supplier_invoice_items ii where ii.supplier_invoice_id=i.id)
    ) into v_approval_payload from public.supplier_invoices i where i.id=v_invoice.id;
    v_approval_fingerprint:=encode(extensions.digest(convert_to(v_approval_payload::text,'UTF8'),'sha256'),'hex');
    select ar.* into strict v_approval from public.approval_requests ar where ar.organization_id=p_organization_id and ar.id=v_invoice.approval_request_id;
    if v_approval.subject_fingerprint<>v_approval_fingerprint or v_approval.payload_snapshot<>v_approval_payload then raise exception using errcode='55000',message='SUPPLIER_INVOICE_APPROVAL_SCOPE_CHANGED';end if;
    perform private.consume_approval(p_organization_id,v_approval.id,'supplier_invoice.approve','supplier_invoice',v_invoice.id,v_approval_fingerprint,v_claim.command_execution_id,v_invoice.total_minor);
    select sum(matched_grni_minor),sum(variance_minor)-v_invoice.credit_minor into v_matched,v_variance from public.supplier_invoice_items where supplier_invoice_id=v_invoice.id;
    v_lines:=jsonb_build_array(jsonb_build_object('account_role','goods_received_not_invoiced','debit_minor',v_matched::text,'credit_minor','0','supplier_id',v_invoice.supplier_id,'print_batch_id',v_invoice.print_batch_id,'subledger_type','supplier_invoice','subledger_id',v_invoice.id));
    if v_variance>0 then v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_role','production_cost_variance','debit_minor',v_variance::text,'credit_minor','0','supplier_id',v_invoice.supplier_id,'print_batch_id',v_invoice.print_batch_id,'subledger_type','supplier_invoice','subledger_id',v_invoice.id));
    elsif v_variance<0 then v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_role','production_cost_variance','debit_minor','0','credit_minor',(-v_variance)::text,'supplier_id',v_invoice.supplier_id,'print_batch_id',v_invoice.print_batch_id,'subledger_type','supplier_invoice','subledger_id',v_invoice.id));end if;
    if v_invoice.tax_minor>0 then v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_role','recoverable_input_tax','debit_minor',v_invoice.tax_minor::text,'credit_minor','0','supplier_id',v_invoice.supplier_id,'subledger_type','supplier_invoice','subledger_id',v_invoice.id));end if;
    v_lines:=v_lines||jsonb_build_array(jsonb_build_object('account_role','supplier_payables','debit_minor','0','credit_minor',v_invoice.total_minor::text,'supplier_id',v_invoice.supplier_id,'print_batch_id',v_invoice.print_batch_id,'subledger_type','supplier_invoice','subledger_id',v_invoice.id));
    v_journal:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'supplier_invoice',p_source_id=>v_invoice.id,p_posting_purpose=>'invoice',p_description=>'Post GRNI-matched supplier invoice',p_lines=>v_lines,p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_approval_request_id=>v_approval.id,p_command_type=>'supplier_invoices.approve',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);
    update public.supplier_invoices set status='posted',approved_variance_minor=v_variance,posted_at=statement_timestamp(),posted_by=auth.uid(),journal_entry_id=v_journal,version=version+1 where id=v_invoice.id;
    v_result:=private.command_success_response(v_claim.command_execution_id,v_invoice.id,'posted','supplier_invoice.posted',jsonb_build_array(v_journal),jsonb_build_object('matched_grni_minor',v_matched,'variance_minor',v_variance,'total_minor',v_invoice.total_minor));
    perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
  exception when others then
    v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate)then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'supplier_invoices.approve','supplier_invoice',p_supplier_invoice_id,p_idempotency_key,p_correlation_id);end if;
    perform private.complete_command_failure(v_claim.command_execution_id,'SUPPLIER_INVOICE_APPROVAL_REJECTED',null);return private.command_replay_response('failed_terminal',null,'SUPPLIER_INVOICE_APPROVAL_REJECTED',v_claim.command_execution_id);
  end;
end;$$;

create or replace function private.command_pay_supplier_invoice(
  p_organization_id uuid,p_supplier_invoice_id uuid,p_wallet_id uuid,p_amount_minor bigint,
  p_provider_reference text,p_evidence_attachment_id uuid,p_idempotency_key text,p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_claim record;v_invoice public.supplier_invoices;v_wallet public.wallets;v_paid bigint;v_payment uuid:=extensions.gen_random_uuid();
  v_journal uuid;v_result jsonb;v_sqlstate text;
  v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'supplier_invoice_id',p_supplier_invoice_id,'wallet_id',p_wallet_id,'amount_minor',p_amount_minor,'provider_reference',p_provider_reference,'evidence_attachment_id',p_evidence_attachment_id);
begin
  perform private.require_permission(p_organization_id,'supplier_payments.execute');
  perform private.assert_request_fingerprint('supplier_payments.execute',v_payload,p_request_fingerprint,1::smallint);
  if p_amount_minor<=0 then raise exception using errcode='22023',message='SUPPLIER_PAYMENT_AMOUNT_INVALID';end if;
  select * into v_claim from private.claim_command(p_organization_id,'supplier_payments.execute',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);
  if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
  begin
    select i.* into strict v_invoice from public.supplier_invoices i where i.organization_id=p_organization_id and i.id=p_supplier_invoice_id for update;
    select w.* into strict v_wallet from public.wallets w where w.organization_id=p_organization_id and w.id=p_wallet_id and w.is_active for update;
    if v_invoice.status not in('posted','partially_paid') then raise exception using errcode='55000',message='SUPPLIER_INVOICE_NOT_PAYABLE';end if;
    select coalesce(sum(case when reverses_supplier_payment_id is null then amount_minor else -amount_minor end),0) into v_paid from public.supplier_payments where organization_id=p_organization_id and supplier_invoice_id=v_invoice.id;
    if p_amount_minor>v_invoice.total_minor-v_paid then raise exception using errcode='23514',message='SUPPLIER_PAYMENT_EXCEEDS_OPEN_PAYABLE';end if;
    v_journal:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'supplier_payment',p_source_id=>v_payment,p_posting_purpose=>'payment',p_description=>'Pay posted supplier invoice',p_lines=>jsonb_build_array(
      jsonb_build_object('account_role','supplier_payables','debit_minor',p_amount_minor::text,'credit_minor','0','supplier_id',v_invoice.supplier_id,'print_batch_id',v_invoice.print_batch_id,'subledger_type','supplier_invoice','subledger_id',v_invoice.id),
      jsonb_build_object('account_role','wallet_'||lower(regexp_replace(v_wallet.code,'[^a-zA-Z0-9]+','_','g')),'debit_minor','0','credit_minor',p_amount_minor::text,'supplier_id',v_invoice.supplier_id,'wallet_id',v_wallet.id,'subledger_type','supplier_payment','subledger_id',v_payment)
    ),p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_command_type=>'supplier_payments.execute',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);
    insert into public.supplier_payments(id,organization_id,supplier_invoice_id,wallet_id,amount_minor,payment_date,provider_reference,evidence_attachment_id,journal_entry_id,created_by,updated_by)
    values(v_payment,p_organization_id,v_invoice.id,v_wallet.id,p_amount_minor,private.cairo_accounting_date(),p_provider_reference,p_evidence_attachment_id,v_journal,auth.uid(),auth.uid());
    update public.supplier_invoices set status=case when v_paid+p_amount_minor=total_minor then'paid'::public.supplier_invoice_status else'partially_paid'::public.supplier_invoice_status end,version=version+1 where id=v_invoice.id;
    update public.print_batches set status=case when v_paid+p_amount_minor=v_invoice.total_minor then'fully_paid'::public.print_batch_status else'partially_paid'::public.print_batch_status end,version=version+1 where id=v_invoice.print_batch_id;
    v_result:=private.command_success_response(v_claim.command_execution_id,v_payment,'paid','supplier_invoice.payment_recorded',jsonb_build_array(v_journal),jsonb_build_object('supplier_invoice_id',v_invoice.id,'amount_minor',p_amount_minor,'remaining_minor',v_invoice.total_minor-v_paid-p_amount_minor));
    perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
  exception when others then
    v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate)then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'supplier_payments.execute','supplier_invoice',p_supplier_invoice_id,p_idempotency_key,p_correlation_id);end if;
    perform private.complete_command_failure(v_claim.command_execution_id,'SUPPLIER_PAYMENT_REJECTED',null);return private.command_replay_response('failed_terminal',null,'SUPPLIER_PAYMENT_REJECTED',v_claim.command_execution_id);
  end;
end;$$;

create or replace function private.command_close_print_batch(
  p_organization_id uuid,p_print_batch_id uuid,p_idempotency_key text,p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare v_claim record;v_result jsonb;v_sqlstate text;v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'print_batch_id',p_print_batch_id);
begin
  perform private.require_permission(p_organization_id,'print_batches.close');perform private.assert_request_fingerprint('print_batches.close',v_payload,p_request_fingerprint,1::smallint);
  select * into v_claim from private.claim_command(p_organization_id,'print_batches.close',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
  begin
    perform 1 from public.print_batches where organization_id=p_organization_id and id=p_print_batch_id and status='fully_paid' for update;if not found then raise exception using errcode='55000',message='PRINT_BATCH_NOT_FULLY_PAID';end if;
    perform 1 from public.print_batch_items where organization_id=p_organization_id and print_batch_id=p_print_batch_id order by id for update;
    if exists(select 1 from public.print_batch_items where print_batch_id=p_print_batch_id and(received_quantity<>sent_quantity or status<>'qc_complete')) or exists(select 1 from public.supplier_invoices where print_batch_id=p_print_batch_id and status<>'paid') then raise exception using errcode='55000',message='PRINT_BATCH_CLOSE_INCOMPLETE';end if;
    update public.print_batch_items set status='closed',closed_at=statement_timestamp(),version=version+1 where print_batch_id=p_print_batch_id;
    update public.print_batches set status='closed',closed_at=statement_timestamp(),version=version+1 where id=p_print_batch_id;
    v_result:=private.command_success_response(v_claim.command_execution_id,p_print_batch_id,'closed','print_batch.closed');perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
  exception when others then v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate)then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'print_batches.close','print_batch',p_print_batch_id,p_idempotency_key,p_correlation_id);end if;perform private.complete_command_failure(v_claim.command_execution_id,'PRINT_BATCH_CLOSE_REJECTED',null);return private.command_replay_response('failed_terminal',null,'PRINT_BATCH_CLOSE_REJECTED',v_claim.command_execution_id);end;
end;$$;

create or replace function api.create_print_batch(p_organization_id uuid,p_supplier_id uuid,p_batch_number text,p_items jsonb,p_business_date date,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_create_print_batch(p_organization_id,p_supplier_id,p_batch_number,p_items,p_business_date,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.receive_print_batch(p_organization_id uuid,p_print_batch_id uuid,p_receipt_number text,p_items jsonb,p_received_at timestamptz,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_receive_print_batch(p_organization_id,p_print_batch_id,p_receipt_number,p_items,p_received_at,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.create_supplier_invoice(p_organization_id uuid,p_supplier_id uuid,p_print_batch_id uuid,p_invoice_number text,p_invoice_date date,p_due_date date,p_items jsonb,p_tax_minor bigint,p_credit_minor bigint,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_create_supplier_invoice(p_organization_id,p_supplier_id,p_print_batch_id,p_invoice_number,p_invoice_date,p_due_date,p_items,p_tax_minor,p_credit_minor,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.approve_supplier_invoice(p_organization_id uuid,p_supplier_invoice_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_approve_supplier_invoice(p_organization_id,p_supplier_invoice_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.pay_supplier_invoice(p_organization_id uuid,p_supplier_invoice_id uuid,p_wallet_id uuid,p_amount_minor bigint,p_provider_reference text,p_evidence_attachment_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_pay_supplier_invoice(p_organization_id,p_supplier_invoice_id,p_wallet_id,p_amount_minor,p_provider_reference,p_evidence_attachment_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.close_print_batch(p_organization_id uuid,p_print_batch_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_close_print_batch(p_organization_id,p_print_batch_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;

revoke all on function private.command_create_print_batch(uuid,uuid,text,jsonb,date,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_receive_print_batch(uuid,uuid,text,jsonb,timestamptz,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_create_supplier_invoice(uuid,uuid,uuid,text,date,date,jsonb,bigint,bigint,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_approve_supplier_invoice(uuid,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_pay_supplier_invoice(uuid,uuid,uuid,bigint,text,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_close_print_batch(uuid,uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function private.command_create_print_batch(uuid,uuid,text,jsonb,date,text,text,uuid) to authenticated;
grant execute on function private.command_receive_print_batch(uuid,uuid,text,jsonb,timestamptz,text,text,uuid) to authenticated;
grant execute on function private.command_create_supplier_invoice(uuid,uuid,uuid,text,date,date,jsonb,bigint,bigint,text,text,uuid) to authenticated;
grant execute on function private.command_approve_supplier_invoice(uuid,uuid,text,text,uuid) to authenticated;
grant execute on function private.command_pay_supplier_invoice(uuid,uuid,uuid,bigint,text,uuid,text,text,uuid) to authenticated;
grant execute on function private.command_close_print_batch(uuid,uuid,text,text,uuid) to authenticated;
revoke all on function api.create_print_batch(uuid,uuid,text,jsonb,date,text,text,uuid) from public,anon,authenticated;
revoke all on function api.receive_print_batch(uuid,uuid,text,jsonb,timestamptz,text,text,uuid) from public,anon,authenticated;
revoke all on function api.create_supplier_invoice(uuid,uuid,uuid,text,date,date,jsonb,bigint,bigint,text,text,uuid) from public,anon,authenticated;
revoke all on function api.approve_supplier_invoice(uuid,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function api.pay_supplier_invoice(uuid,uuid,uuid,bigint,text,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function api.close_print_batch(uuid,uuid,text,text,uuid) from public,anon,authenticated;
grant execute on function api.create_print_batch(uuid,uuid,text,jsonb,date,text,text,uuid) to authenticated;
grant execute on function api.receive_print_batch(uuid,uuid,text,jsonb,timestamptz,text,text,uuid) to authenticated;
grant execute on function api.create_supplier_invoice(uuid,uuid,uuid,text,date,date,jsonb,bigint,bigint,text,text,uuid) to authenticated;
grant execute on function api.approve_supplier_invoice(uuid,uuid,text,text,uuid) to authenticated;
grant execute on function api.pay_supplier_invoice(uuid,uuid,uuid,bigint,text,uuid,text,text,uuid) to authenticated;
grant execute on function api.close_print_batch(uuid,uuid,text,text,uuid) to authenticated;
