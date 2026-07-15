do $migration$
declare
  v_definition text;
  v_repaired text;
begin
  v_definition := pg_get_functiondef(
    'private.command_confirm_customer_payment(uuid,uuid,text,text,uuid)'::regprocedure
  );
  v_repaired := replace(v_definition, E'declare\n', E'declare\n  v_retry_sqlstate text;\n');
  v_repaired := replace(
    v_repaired,
    E'  perform private.require_permission(p_organization_id, ''payments.review'');\n',
    E'  perform private.require_permission(p_organization_id, ''payments.review'');\n  perform private.assert_request_fingerprint(\n    ''payments.confirm'',\n    jsonb_build_object(\n      ''organization_id'', p_organization_id,\n      ''customer_payment_id'', p_customer_payment_id\n    ),\n    p_request_fingerprint, 1::smallint\n  );\n'
  );
  v_repaired := replace(
    v_repaired,
    E'    if v_payment.status <> ''pending_review'' or v_payment.request_fingerprint <> p_request_fingerprint then\n',
    E'    if v_payment.status <> ''pending_review'' then\n'
  );
  v_repaired := replace(
    v_repaired,
    E'  exception when others then\n',
    E'  exception when others then\n    v_retry_sqlstate := sqlstate;\n    if private.is_retryable_sqlstate(v_retry_sqlstate) then\n      return private.release_retryable_command(\n        v_claim.command_execution_id, v_retry_sqlstate, ''payments.confirm'',\n        ''customer_payment'', p_customer_payment_id, p_idempotency_key,\n        p_correlation_id\n      );\n    end if;\n'
  );
  if v_repaired = v_definition
     or position('assert_request_fingerprint' in v_repaired) = 0
     or position('release_retryable_command' in v_repaired) = 0 then
    raise exception 'PAYMENT_CONFIRMATION_HARDENING_TARGET_NOT_FOUND';
  end if;
  execute v_repaired;
end;
$migration$;

create or replace function private.command_request_wallet_transfer(
  p_organization_id uuid,
  p_source_wallet_id uuid,
  p_destination_wallet_id uuid,
  p_amount_minor bigint,
  p_fee_minor bigint,
  p_transfer_reference text,
  p_fee_reference text,
  p_reason text,
  p_evidence_attachment_id uuid,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_claim record;
  v_transfer_id uuid := extensions.gen_random_uuid();
  v_approval_id uuid := extensions.gen_random_uuid();
  v_permission_id uuid;
  v_payload jsonb := jsonb_build_object(
    'organization_id', p_organization_id,
    'source_wallet_id', p_source_wallet_id,
    'destination_wallet_id', p_destination_wallet_id,
    'amount_minor', p_amount_minor,
    'fee_minor', p_fee_minor,
    'transfer_reference', p_transfer_reference,
    'fee_reference', p_fee_reference,
    'reason', p_reason,
    'evidence_attachment_id', p_evidence_attachment_id
  );
  v_result jsonb;
  v_sqlstate text;
begin
  perform private.require_permission(p_organization_id, 'wallets.transfer');
  perform private.assert_request_fingerprint(
    'wallets.transfer', v_payload, p_request_fingerprint, 1::smallint
  );
  if p_source_wallet_id = p_destination_wallet_id
     or p_amount_minor <= 0 or p_fee_minor < 0
     or nullif(btrim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'WALLET_TRANSFER_REQUEST_INVALID';
  end if;
  select * into v_claim from private.claim_command(
    p_organization_id, 'wallets.transfer.request', p_idempotency_key,
    p_request_fingerprint, 1::smallint, p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status, v_claim.result_reference,
      v_claim.error_code, v_claim.command_execution_id
    );
  end if;
  begin
    perform 1 from public.wallets as w
    where w.organization_id = p_organization_id
      and w.id in (p_source_wallet_id, p_destination_wallet_id)
      and w.is_active
    order by w.id
    for update;
    if (select count(*) from public.wallets as w
        where w.organization_id = p_organization_id
          and w.id in (p_source_wallet_id, p_destination_wallet_id)
          and w.is_active) <> 2 then
      raise exception using errcode = 'P0002', message = 'WALLET_TRANSFER_WALLET_NOT_FOUND';
    end if;
    select id into strict v_permission_id from private.permissions
    where permission_key = 'wallets.transfer' and is_active;
    insert into public.approval_requests(
      id,organization_id,request_type,entity_type,entity_id,requested_by,
      submitted_at,status,required_permission_id,requires_separation_of_duties,
      required_approval_count,reason,subject_fingerprint,requested_amount_minor,
      approved_min_amount_minor,approved_max_amount_minor,payload_snapshot,expires_at
    ) values (
      v_approval_id,p_organization_id,'wallet.transfer','wallet_transfer',
      v_transfer_id,auth.uid(),statement_timestamp(),'submitted',v_permission_id,
      true,1,p_reason,p_request_fingerprint,p_amount_minor+p_fee_minor,
      p_amount_minor+p_fee_minor,p_amount_minor+p_fee_minor,v_payload,
      statement_timestamp()+interval '14 days'
    );
    insert into public.wallet_transfers(
      id,organization_id,source_wallet_id,destination_wallet_id,amount_minor,
      fee_minor,status,transfer_reference,fee_reference,reason,requested_by,
      approval_request_id,evidence_attachment_id,idempotency_key,
      request_fingerprint,correlation_id
    ) values (
      v_transfer_id,p_organization_id,p_source_wallet_id,p_destination_wallet_id,
      p_amount_minor,p_fee_minor,'submitted',nullif(btrim(p_transfer_reference),''),
      nullif(btrim(p_fee_reference),''),p_reason,auth.uid(),v_approval_id,
      p_evidence_attachment_id,p_idempotency_key,p_request_fingerprint,p_correlation_id
    );
    v_result := private.command_success_response(
      v_claim.command_execution_id,v_transfer_id,'submitted',
      'wallet.transfer_requested','[]'::jsonb,
      jsonb_build_object('approval_request_id',v_approval_id,
        'approval_request_fingerprint',p_request_fingerprint)
    );
    perform private.complete_command_success(v_claim.command_execution_id,v_result);
    perform private.record_financial_command_audit(
      p_organization_id,'wallets.transfer.request','wallet_transfer',v_transfer_id,
      'succeeded',p_reason,p_correlation_id,v_claim.command_execution_id,
      p_idempotency_key,jsonb_build_object('approval_request_id',v_approval_id)
    );
    return v_result;
  exception when others then
    v_sqlstate:=sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id,v_sqlstate,'wallets.transfer.request',
        'wallet',p_source_wallet_id,p_idempotency_key,p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id,'WALLET_TRANSFER_REQUEST_REJECTED',null
    );
    return private.command_replay_response(
      'failed_terminal',null,'WALLET_TRANSFER_REQUEST_REJECTED',
      v_claim.command_execution_id
    );
  end;
end;
$$;

create or replace function private.command_transfer_between_wallets(
  p_organization_id uuid,
  p_wallet_transfer_id uuid,
  p_idempotency_key text,
  p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_claim record;
  v_transfer public.wallet_transfers;
  v_source public.wallets;
  v_destination public.wallets;
  v_approval public.approval_requests;
  v_payload jsonb;
  v_lines jsonb;
  v_journal_entry_id uuid;
  v_result jsonb;
  v_sqlstate text;
begin
  perform private.require_permission(p_organization_id, 'wallets.transfer');
  select wt.* into strict v_transfer
  from public.wallet_transfers as wt
  where wt.organization_id=p_organization_id and wt.id=p_wallet_transfer_id;
  v_payload:=jsonb_build_object(
    'organization_id',v_transfer.organization_id,
    'source_wallet_id',v_transfer.source_wallet_id,
    'destination_wallet_id',v_transfer.destination_wallet_id,
    'amount_minor',v_transfer.amount_minor,'fee_minor',v_transfer.fee_minor,
    'transfer_reference',v_transfer.transfer_reference,
    'fee_reference',v_transfer.fee_reference,'reason',v_transfer.reason,
    'evidence_attachment_id',v_transfer.evidence_attachment_id
  );
  perform private.assert_request_fingerprint(
    'wallets.transfer',v_payload,p_request_fingerprint,1::smallint
  );
  select * into v_claim from private.claim_command(
    p_organization_id,'wallets.transfer',p_idempotency_key,
    p_request_fingerprint,1::smallint,p_correlation_id
  );
  if v_claim.is_replay then
    return private.command_replay_response(
      v_claim.command_status,v_claim.result_reference,
      v_claim.error_code,v_claim.command_execution_id
    );
  end if;
  begin
    perform private.lock_accounting_period(
      p_organization_id,private.cairo_accounting_date(),false
    );
    select wt.* into strict v_transfer from public.wallet_transfers as wt
    where wt.organization_id=p_organization_id and wt.id=p_wallet_transfer_id
    for update;
    if v_transfer.status<>'submitted'
       or v_transfer.request_fingerprint<>p_request_fingerprint then
      raise exception using errcode='55000',message='WALLET_TRANSFER_NOT_EXECUTABLE';
    end if;
    perform 1 from public.wallets as w
    where w.organization_id=p_organization_id
      and w.id in(v_transfer.source_wallet_id,v_transfer.destination_wallet_id)
    order by w.id for update;
    select w.* into strict v_source from public.wallets as w
    where w.organization_id=p_organization_id and w.id=v_transfer.source_wallet_id and w.is_active;
    select w.* into strict v_destination from public.wallets as w
    where w.organization_id=p_organization_id and w.id=v_transfer.destination_wallet_id and w.is_active;
    select ar.* into strict v_approval from public.approval_requests as ar
    where ar.organization_id=p_organization_id and ar.id=v_transfer.approval_request_id
    for update;
    if v_approval.payload_snapshot<>v_payload
       or v_approval.subject_fingerprint<>p_request_fingerprint then
      raise exception using errcode='55000',message='WALLET_TRANSFER_APPROVAL_SCOPE_CHANGED';
    end if;
    perform private.consume_approval(
      p_organization_id,v_approval.id,'wallet.transfer','wallet_transfer',
      v_transfer.id,p_request_fingerprint,v_claim.command_execution_id,
      v_transfer.amount_minor+v_transfer.fee_minor
    );
    v_lines:=jsonb_build_array(
      jsonb_build_object('account_role','wallet_'||lower(regexp_replace(v_destination.code,'[^a-zA-Z0-9]+','_','g')),
        'debit_minor',v_transfer.amount_minor::text,'credit_minor','0','wallet_id',v_destination.id,
        'subledger_type','wallet_transfer','subledger_id',v_transfer.id),
      jsonb_build_object('account_role','wallet_'||lower(regexp_replace(v_source.code,'[^a-zA-Z0-9]+','_','g')),
        'debit_minor','0','credit_minor',(v_transfer.amount_minor+v_transfer.fee_minor)::text,'wallet_id',v_source.id,
        'subledger_type','wallet_transfer','subledger_id',v_transfer.id)
    );
    if v_transfer.fee_minor>0 then
      v_lines:=v_lines||jsonb_build_array(jsonb_build_object(
        'account_role','financial_transfer_fees','debit_minor',v_transfer.fee_minor::text,
        'credit_minor','0','subledger_type','wallet_transfer_fee','subledger_id',v_transfer.id));
    end if;
    v_journal_entry_id:=private.post_journal_entry(
      p_organization_id=>p_organization_id,p_source_type=>'wallet_transfer',
      p_source_id=>v_transfer.id,p_posting_purpose=>'execution',
      p_description=>'Wallet transfer',p_lines=>v_lines,
      p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,
      p_correlation_id=>p_correlation_id,p_approval_request_id=>v_approval.id,
      p_command_type=>'wallets.transfer',p_command_execution_id=>v_claim.command_execution_id,
      p_require_manual_permission=>false
    );
    update public.wallet_transfers set status='executed',
      approved_by=v_approval.resolved_by,approved_at=v_approval.resolved_at,
      executed_by=auth.uid(),executed_at=statement_timestamp(),
      correlation_id=p_correlation_id where id=v_transfer.id;
    v_result:=private.command_success_response(
      v_claim.command_execution_id,v_transfer.id,'executed',
      'wallet.transfer_executed',jsonb_build_array(v_journal_entry_id)
    );
    perform private.complete_command_success(v_claim.command_execution_id,v_result);
    perform private.record_financial_command_audit(
      p_organization_id,'wallets.transfer','wallet_transfer',v_transfer.id,
      'succeeded',null,p_correlation_id,v_claim.command_execution_id,
      p_idempotency_key,jsonb_build_object('journal_entry_id',v_journal_entry_id)
    );
    return v_result;
  exception when others then
    v_sqlstate:=sqlstate;
    if private.is_retryable_sqlstate(v_sqlstate) then
      return private.release_retryable_command(
        v_claim.command_execution_id,v_sqlstate,'wallets.transfer',
        'wallet_transfer',p_wallet_transfer_id,p_idempotency_key,p_correlation_id
      );
    end if;
    perform private.complete_command_failure(
      v_claim.command_execution_id,'WALLET_TRANSFER_REJECTED',null
    );
    return private.command_replay_response(
      'failed_terminal',null,'WALLET_TRANSFER_REJECTED',
      v_claim.command_execution_id
    );
  end;
end;
$$;

create or replace function api.request_wallet_transfer(
  p_organization_id uuid,p_source_wallet_id uuid,p_destination_wallet_id uuid,
  p_amount_minor bigint,p_fee_minor bigint,p_transfer_reference text,
  p_fee_reference text,p_reason text,p_evidence_attachment_id uuid,
  p_idempotency_key text,p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns jsonb language sql volatile security invoker set search_path=''
as $$
  select private.command_request_wallet_transfer(
    p_organization_id,p_source_wallet_id,p_destination_wallet_id,p_amount_minor,
    p_fee_minor,p_transfer_reference,p_fee_reference,p_reason,
    p_evidence_attachment_id,p_idempotency_key,p_request_fingerprint,p_correlation_id
  )
$$;

revoke all on function private.command_request_wallet_transfer(
  uuid,uuid,uuid,bigint,bigint,text,text,text,uuid,text,text,uuid
) from public,anon;
grant execute on function private.command_request_wallet_transfer(
  uuid,uuid,uuid,bigint,bigint,text,text,text,uuid,text,text,uuid
) to authenticated;
revoke all on function private.command_transfer_between_wallets(
  uuid,uuid,text,text,uuid
) from public,anon;
grant execute on function private.command_transfer_between_wallets(
  uuid,uuid,text,text,uuid
) to authenticated;
revoke all on function api.request_wallet_transfer(
  uuid,uuid,uuid,bigint,bigint,text,text,text,uuid,text,text,uuid
) from public,anon;
grant execute on function api.request_wallet_transfer(
  uuid,uuid,uuid,bigint,bigint,text,text,text,uuid,text,text,uuid
) to authenticated;
