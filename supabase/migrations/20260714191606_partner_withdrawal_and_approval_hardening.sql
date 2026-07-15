-- Bind partner approval identity to the authenticated profile. A caller-supplied
-- partner id is accepted only when it is the actor's own stable partner row.
create or replace function private.command_decide_approval(
  p_organization_id uuid,
  p_approval_request_id uuid,
  p_action public.approval_action_type,
  p_comment text default null,
  p_approver_partner_id uuid default null,
  p_correlation_id uuid default extensions.gen_random_uuid()
)
returns public.approval_status
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_request public.approval_requests;
  v_actor_partner_id uuid;
  v_required_permission text;
  v_prior_approvals integer;
  v_result public.approval_status;
begin
  if v_actor is null or p_organization_id is distinct from private.current_organization_id() then
    raise exception using errcode = '42501', message = 'APPROVAL_DECISION_ORGANIZATION_DENIED';
  end if;

  select request.* into strict v_request
  from public.approval_requests as request
  where request.organization_id = p_organization_id and request.id = p_approval_request_id
  for update;

  select permission.permission_key into strict v_required_permission
  from private.permissions as permission
  where permission.id = v_request.required_permission_id;

  if p_action in ('approve','reject') then
    perform private.require_permission(p_organization_id, v_required_permission);
  elsif p_action = 'cancel' and v_request.requested_by <> v_actor then
    perform private.require_permission(p_organization_id, v_required_permission);
  end if;

  if v_request.status <> 'submitted'
     or (v_request.expires_at is not null and v_request.expires_at <= statement_timestamp()) then
    raise exception using errcode = '55000', message = 'APPROVAL_NOT_DECIDABLE';
  end if;

  select partner.id into v_actor_partner_id
  from public.partners as partner
  where partner.organization_id = p_organization_id
    and partner.profile_id = v_actor
    and partner.is_active;

  if p_approver_partner_id is not null
     and p_approver_partner_id is distinct from v_actor_partner_id then
    raise exception using errcode = '42501', message = 'APPROVER_PARTNER_IDENTITY_MISMATCH';
  end if;
  if v_request.requester_partner_id is not null and p_action in ('approve','reject')
     and (v_actor_partner_id is null or v_actor_partner_id = v_request.requester_partner_id) then
    raise exception using errcode = '42501', message = 'OTHER_PARTNER_APPROVAL_REQUIRED';
  end if;

  select count(*) into v_prior_approvals
  from public.approval_actions as action
  where action.approval_request_id = v_request.id and action.action_type = 'approve';

  v_result := case
    when p_action = 'approve' and v_prior_approvals + 1 >= v_request.required_approval_count then 'approved'::public.approval_status
    when p_action = 'approve' then 'submitted'::public.approval_status
    when p_action = 'reject' then 'rejected'::public.approval_status
    else 'cancelled'::public.approval_status
  end;

  insert into public.approval_actions(
    organization_id,approval_request_id,action_type,acted_by,approver_partner_id,
    comment,previous_status,resulting_status,subject_fingerprint,correlation_id
  ) values (
    p_organization_id,v_request.id,p_action,v_actor,v_actor_partner_id,
    p_comment,v_request.status,v_result,v_request.subject_fingerprint,p_correlation_id
  );

  if v_result <> 'submitted' then
    update public.approval_requests
    set status=v_result,resolved_at=statement_timestamp(),resolved_by=v_actor,
        resolution_reason=case when v_result in ('rejected','cancelled') then p_comment else null end
    where id=v_request.id;
  end if;
  return v_result;
end;
$$;

create or replace function private.command_request_partner_withdrawal(
  p_organization_id uuid,p_partner_id uuid,p_withdrawal_number text,
  p_withdrawal_type public.partner_withdrawal_type,p_requested_amount_minor bigint,
  p_reason text,p_evidence_attachment_id uuid,p_idempotency_key text,
  p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_claim record;v_partner public.partners;v_settings private.organization_finance_settings;
  v_existing bigint;v_total bigint;v_requires_other boolean;v_withdrawal_id uuid;
  v_approval_payload jsonb;v_approval_fingerprint text;v_approval_id uuid;
  v_result jsonb;v_sqlstate text;
  v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'partner_id',p_partner_id,'withdrawal_number',p_withdrawal_number,'withdrawal_type',p_withdrawal_type,'requested_amount_minor',p_requested_amount_minor,'reason',p_reason,'evidence_attachment_id',p_evidence_attachment_id);
begin
  perform private.require_permission(p_organization_id,'partner_withdrawals.request');
  perform private.assert_request_fingerprint('partner_withdrawals.request',v_payload,p_request_fingerprint,1::smallint);
  if p_requested_amount_minor<=0 or nullif(btrim(p_withdrawal_number),'') is null or nullif(btrim(p_reason),'') is null then raise exception using errcode='22023',message='INVALID_PARTNER_WITHDRAWAL_REQUEST';end if;
  select * into v_claim from private.claim_command(p_organization_id,'partner_withdrawals.request',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);
  if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
  begin
    -- This stable row is always locked before the rolling-window aggregate.
    select p.* into strict v_partner from public.partners p where p.organization_id=p_organization_id and p.id=p_partner_id and p.is_active for update;
    if v_partner.profile_id is distinct from auth.uid() then raise exception using errcode='42501',message='PARTNER_CAN_ONLY_REQUEST_OWN_WITHDRAWAL';end if;
    select s.* into strict v_settings from private.organization_finance_settings s where s.organization_id=p_organization_id and s.effective_from<=statement_timestamp() and(s.effective_to is null or s.effective_to>statement_timestamp()) order by s.version_no desc limit 1;
    if v_settings.partner_withdrawal_approval_threshold_minor<=0 then raise exception using errcode='55000',message='WITHDRAWAL_THRESHOLD_NOT_CONFIGURED';end if;
    select coalesce(sum(w.requested_amount_minor),0) into v_existing
      from public.partner_withdrawals w
      where w.organization_id=p_organization_id and w.partner_id=p_partner_id
        and w.requested_at>=statement_timestamp()-make_interval(hours=>v_settings.withdrawal_aggregation_hours)
        and w.status not in('rejected','cancelled','expired','reversed');
    v_total:=v_existing+p_requested_amount_minor;
    v_requires_other:=v_total>v_settings.partner_withdrawal_approval_threshold_minor;
    insert into public.partner_withdrawals(
      organization_id,partner_id,withdrawal_no,withdrawal_type,status,requested_amount_minor,
      rolling_24h_existing_minor,rolling_24h_total_minor,approval_threshold_minor,
      requires_other_partner_approval,request_fingerprint,requested_at,reason,
      evidence_attachment_id,created_by,updated_by
    ) values (
      p_organization_id,p_partner_id,p_withdrawal_number,p_withdrawal_type,'submitted',p_requested_amount_minor,
      v_existing,v_total,v_settings.partner_withdrawal_approval_threshold_minor,
      v_requires_other,p_request_fingerprint,statement_timestamp(),p_reason,
      p_evidence_attachment_id,auth.uid(),auth.uid()
    ) returning id into v_withdrawal_id;
    v_approval_payload:=jsonb_build_object(
      'organization_id',p_organization_id,'partner_withdrawal_id',v_withdrawal_id,
      'partner_id',p_partner_id,'withdrawal_type',p_withdrawal_type,
      'requested_amount_minor',p_requested_amount_minor,'rolling_existing_minor',v_existing,
      'rolling_total_minor',v_total,'approval_threshold_minor',v_settings.partner_withdrawal_approval_threshold_minor,
      'requires_other_partner_approval',v_requires_other,'reason',p_reason
    );
    v_approval_fingerprint:=encode(extensions.digest(convert_to(v_approval_payload::text,'UTF8'),'sha256'),'hex');
    v_approval_id:=private.command_submit_approval_request(
      p_organization_id,'partner_withdrawal.approve','partner_withdrawal',v_withdrawal_id,
      'partner_withdrawals.approve','Approve bounded partner withdrawal',v_approval_payload,
      v_approval_fingerprint,p_requested_amount_minor,
      case when v_requires_other then p_partner_id else null end,
      statement_timestamp()+interval '7 days'
    );
    update public.partner_withdrawals set approval_request_id=v_approval_id where id=v_withdrawal_id;
    v_result:=private.command_success_response(v_claim.command_execution_id,v_withdrawal_id,'submitted','partner_withdrawal.requested','[]'::jsonb,jsonb_build_object('approval_request_id',v_approval_id,'rolling_24h_total_minor',v_total,'requires_other_partner_approval',v_requires_other));
    perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
  exception when others then
    v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate)then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'partner_withdrawals.request','partner',p_partner_id,p_idempotency_key,p_correlation_id);end if;
    perform private.complete_command_failure(v_claim.command_execution_id,'PARTNER_WITHDRAWAL_REQUEST_REJECTED',null);return private.command_replay_response('failed_terminal',null,'PARTNER_WITHDRAWAL_REQUEST_REJECTED',v_claim.command_execution_id);
  end;
end;$$;

create or replace function private.command_approve_partner_withdrawal(
  p_organization_id uuid,p_partner_withdrawal_id uuid,p_idempotency_key text,
  p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_claim record;v_partner_id uuid;v_withdrawal public.partner_withdrawals;v_approval public.approval_requests;
  v_approval_payload jsonb;v_approval_fingerprint text;v_approver_partner_id uuid;
  v_result jsonb;v_sqlstate text;
  v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'partner_withdrawal_id',p_partner_withdrawal_id);
begin
  perform private.require_permission(p_organization_id,'partner_withdrawals.approve');perform private.assert_request_fingerprint('partner_withdrawals.approve',v_payload,p_request_fingerprint,1::smallint);
  select * into v_claim from private.claim_command(p_organization_id,'partner_withdrawals.approve',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
  begin
    select w.partner_id into strict v_partner_id from public.partner_withdrawals w where w.organization_id=p_organization_id and w.id=p_partner_withdrawal_id;
    perform 1 from public.partners p where p.organization_id=p_organization_id and p.id=v_partner_id for update;
    select w.* into strict v_withdrawal from public.partner_withdrawals w where w.organization_id=p_organization_id and w.id=p_partner_withdrawal_id for update;
    if v_withdrawal.status<>'submitted' or v_withdrawal.created_by=auth.uid() then raise exception using errcode='42501',message='WITHDRAWAL_APPROVAL_SOD_OR_STATE_INVALID';end if;
    v_approval_payload:=jsonb_build_object(
      'organization_id',p_organization_id,'partner_withdrawal_id',v_withdrawal.id,
      'partner_id',v_withdrawal.partner_id,'withdrawal_type',v_withdrawal.withdrawal_type,
      'requested_amount_minor',v_withdrawal.requested_amount_minor,
      'rolling_existing_minor',v_withdrawal.rolling_24h_existing_minor,
      'rolling_total_minor',v_withdrawal.rolling_24h_total_minor,
      'approval_threshold_minor',v_withdrawal.approval_threshold_minor,
      'requires_other_partner_approval',v_withdrawal.requires_other_partner_approval,
      'reason',v_withdrawal.reason
    );
    v_approval_fingerprint:=encode(extensions.digest(convert_to(v_approval_payload::text,'UTF8'),'sha256'),'hex');
    select ar.* into strict v_approval from public.approval_requests ar where ar.organization_id=p_organization_id and ar.id=v_withdrawal.approval_request_id;
    if v_approval.payload_snapshot<>v_approval_payload or v_approval.subject_fingerprint<>v_approval_fingerprint then raise exception using errcode='55000',message='WITHDRAWAL_APPROVAL_SCOPE_CHANGED';end if;
    select aa.approver_partner_id into v_approver_partner_id from public.approval_actions aa where aa.organization_id=p_organization_id and aa.approval_request_id=v_approval.id and aa.action_type='approve' order by aa.acted_at desc limit 1;
    if v_withdrawal.requires_other_partner_approval and(v_approver_partner_id is null or v_approver_partner_id=v_withdrawal.partner_id)then raise exception using errcode='42501',message='OTHER_PARTNER_APPROVAL_REQUIRED';end if;
    perform private.consume_approval(p_organization_id,v_approval.id,'partner_withdrawal.approve','partner_withdrawal',v_withdrawal.id,v_approval_fingerprint,v_claim.command_execution_id,v_withdrawal.requested_amount_minor);
    update public.partner_withdrawals set status='approved',approved_at=statement_timestamp(),approved_by_partner_id=v_approver_partner_id,version=version+1 where id=v_withdrawal.id;
    v_result:=private.command_success_response(v_claim.command_execution_id,v_withdrawal.id,'approved','partner_withdrawal.approved');perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
  exception when others then v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate)then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'partner_withdrawals.approve','partner_withdrawal',p_partner_withdrawal_id,p_idempotency_key,p_correlation_id);end if;perform private.complete_command_failure(v_claim.command_execution_id,'PARTNER_WITHDRAWAL_APPROVAL_REJECTED',null);return private.command_replay_response('failed_terminal',null,'PARTNER_WITHDRAWAL_APPROVAL_REJECTED',v_claim.command_execution_id);end;
end;$$;

create or replace function private.command_execute_partner_withdrawal(
  p_organization_id uuid,p_partner_withdrawal_id uuid,p_wallet_id uuid,
  p_provider_reference text,p_idempotency_key text,p_request_fingerprint text,
  p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_claim record;v_partner_id uuid;v_withdrawal public.partner_withdrawals;v_settings private.organization_finance_settings;v_wallet public.wallets;
  v_current_account_id uuid;v_loan_account_id uuid;v_source_account_role text;v_source_balance bigint;
  v_wallet_cash bigint;v_protected_liabilities bigint;v_pending_withdrawals bigint;v_protected_reserve bigint;v_safe_cash bigint;v_safe_amount bigint;
  v_journal uuid;v_snapshot jsonb;v_result jsonb;v_sqlstate text;
  v_payload jsonb:=jsonb_build_object('organization_id',p_organization_id,'partner_withdrawal_id',p_partner_withdrawal_id,'wallet_id',p_wallet_id,'provider_reference',p_provider_reference);
begin
  perform private.require_permission(p_organization_id,'partner_withdrawals.execute');perform private.assert_request_fingerprint('partner_withdrawals.execute',v_payload,p_request_fingerprint,1::smallint);
  if nullif(btrim(p_provider_reference),'') is null then raise exception using errcode='22023',message='WITHDRAWAL_PROVIDER_REFERENCE_REQUIRED';end if;
  select * into v_claim from private.claim_command(p_organization_id,'partner_withdrawals.execute',p_idempotency_key,p_request_fingerprint,1::smallint,p_correlation_id);if v_claim.is_replay then return private.command_replay_response(v_claim.command_status,v_claim.result_reference,v_claim.error_code,v_claim.command_execution_id);end if;
  begin
    select w.partner_id into strict v_partner_id from public.partner_withdrawals w where w.organization_id=p_organization_id and w.id=p_partner_withdrawal_id;
    -- Same stable row and lock order as request aggregation.
    perform 1 from public.partners p where p.organization_id=p_organization_id and p.id=v_partner_id and p.is_active for update;
    select w.* into strict v_withdrawal from public.partner_withdrawals w where w.organization_id=p_organization_id and w.id=p_partner_withdrawal_id for update;
    select wallet.* into strict v_wallet from public.wallets wallet where wallet.organization_id=p_organization_id and wallet.id=p_wallet_id and wallet.is_active for update;
    select s.* into strict v_settings from private.organization_finance_settings s where s.organization_id=p_organization_id and s.effective_from<=statement_timestamp() and(s.effective_to is null or s.effective_to>statement_timestamp()) order by s.version_no desc limit 1;
    if not v_settings.withdrawal_execution_enabled then raise exception using errcode='55000',message='WITHDRAWAL_EXECUTION_DISABLED';end if;
    if v_withdrawal.status<>'approved' then raise exception using errcode='55000',message='WITHDRAWAL_NOT_APPROVED';end if;

    select arm.account_id into strict v_current_account_id
      from accounting.account_roles ar join accounting.account_role_mappings arm on arm.organization_id=ar.organization_id and arm.account_role_id=ar.id
      where ar.organization_id=p_organization_id and ar.role_key='partner_current_accounts'
        and arm.valid_from<=private.cairo_accounting_date() and(arm.valid_to is null or arm.valid_to>private.cairo_accounting_date());
    select arm.account_id into strict v_loan_account_id
      from accounting.account_roles ar join accounting.account_role_mappings arm on arm.organization_id=ar.organization_id and arm.account_role_id=ar.id
      where ar.organization_id=p_organization_id and ar.role_key='partner_loans_payable'
        and arm.valid_from<=private.cairo_accounting_date() and(arm.valid_to is null or arm.valid_to>private.cairo_accounting_date());

    if v_withdrawal.withdrawal_type='partner_loan_repayment' then
      v_source_account_role:='partner_loans_payable';
      select coalesce(sum(jl.credit_minor-jl.debit_minor),0)::bigint into v_source_balance from accounting.journal_lines jl join accounting.journal_entries je on je.id=jl.journal_entry_id where je.organization_id=p_organization_id and je.status in('posted','reversed') and jl.account_id=v_loan_account_id and jl.partner_id=v_partner_id;
    elsif v_withdrawal.withdrawal_type='future_profit_advance' then
      v_source_account_role:='partner_current_accounts';
      select greatest(v_settings.future_profit_advance_cap_minor-coalesce(sum(w.requested_amount_minor)filter(where w.status='executed'),0),0)::bigint into v_source_balance from public.partner_withdrawals w where w.organization_id=p_organization_id and w.partner_id=v_partner_id and w.withdrawal_type='future_profit_advance' and w.id<>v_withdrawal.id;
    else
      v_source_account_role:='partner_current_accounts';
      select coalesce(sum(jl.credit_minor-jl.debit_minor),0)::bigint into v_source_balance from accounting.journal_lines jl join accounting.journal_entries je on je.id=jl.journal_entry_id where je.organization_id=p_organization_id and je.status in('posted','reversed') and jl.account_id=v_current_account_id and jl.partner_id=v_partner_id;
    end if;

    select coalesce(sum(jl.debit_minor-jl.credit_minor),0)::bigint into v_wallet_cash
      from accounting.journal_lines jl join accounting.journal_entries je on je.id=jl.journal_entry_id
      where je.organization_id=p_organization_id and je.status in('posted','reversed') and jl.wallet_id=p_wallet_id;
    select greatest(coalesce(sum(jl.credit_minor-jl.debit_minor),0),0)::bigint into v_protected_liabilities
      from accounting.journal_lines jl join accounting.journal_entries je on je.id=jl.journal_entry_id join accounting.accounts a on a.id=jl.account_id
      where je.organization_id=p_organization_id and je.status in('posted','reversed') and a.account_type='liability' and a.is_control_account;
    select coalesce(sum(w.requested_amount_minor),0)::bigint into v_pending_withdrawals
      from public.partner_withdrawals w where w.organization_id=p_organization_id and w.id<>v_withdrawal.id and w.status in('submitted','approved');
    select greatest(v_settings.minimum_operating_capital_minor,coalesce((select mc.protected_reserve_minor from accounting.monthly_closings mc where mc.organization_id=p_organization_id and mc.status='closed' order by mc.closed_at desc limit 1),0)) into v_protected_reserve;
    v_safe_cash:=greatest(v_wallet_cash-v_protected_liabilities-v_pending_withdrawals-v_protected_reserve,0);
    v_safe_amount:=least(greatest(v_source_balance,0),v_safe_cash);
    if v_withdrawal.requested_amount_minor>v_safe_amount then raise exception using errcode='23514',message='WITHDRAWAL_EXCEEDS_SAFE_AMOUNT';end if;
    v_snapshot:=jsonb_build_object('settings_id',v_settings.id,'settings_version_no',v_settings.version_no,'wallet_cash_minor',v_wallet_cash,'protected_liabilities_minor',v_protected_liabilities,'pending_withdrawals_minor',v_pending_withdrawals,'protected_reserve_minor',v_protected_reserve,'source_balance_minor',v_source_balance,'safe_cash_minor',v_safe_cash,'safe_withdrawal_amount_minor',v_safe_amount,'provider_reference',p_provider_reference,'calculated_at',statement_timestamp());
    v_journal:=private.post_journal_entry(p_organization_id=>p_organization_id,p_source_type=>'partner_withdrawal',p_source_id=>v_withdrawal.id,p_posting_purpose=>'withdrawal',p_description=>'Execute approved partner withdrawal',p_lines=>jsonb_build_array(
      jsonb_build_object('account_role',v_source_account_role,'debit_minor',v_withdrawal.requested_amount_minor::text,'credit_minor','0','partner_id',v_partner_id,'subledger_type','partner_withdrawal','subledger_id',v_withdrawal.id),
      jsonb_build_object('account_role','wallet_'||lower(regexp_replace(v_wallet.code,'[^a-zA-Z0-9]+','_','g')),'debit_minor','0','credit_minor',v_withdrawal.requested_amount_minor::text,'partner_id',v_partner_id,'wallet_id',p_wallet_id,'subledger_type','partner_withdrawal','subledger_id',v_withdrawal.id)
    ),p_idempotency_key=>p_idempotency_key,p_request_hash=>p_request_fingerprint,p_correlation_id=>p_correlation_id,p_command_type=>'partner_withdrawals.execute',p_command_execution_id=>v_claim.command_execution_id,p_require_manual_permission=>false);
    update public.partner_withdrawals set status='executed',available_source_balance_minor=v_source_balance,safe_withdrawal_amount_minor=v_safe_amount,liquidity_snapshot=v_snapshot,wallet_id=p_wallet_id,executed_at=statement_timestamp(),journal_entry_id=v_journal,version=version+1 where id=v_withdrawal.id;
    v_result:=private.command_success_response(v_claim.command_execution_id,v_withdrawal.id,'executed','partner_withdrawal.executed',jsonb_build_array(v_journal),jsonb_build_object('safe_withdrawal_amount_minor',v_safe_amount,'liquidity_snapshot',v_snapshot));perform private.complete_command_success(v_claim.command_execution_id,v_result);return v_result;
  exception when others then v_sqlstate:=sqlstate;if private.is_retryable_sqlstate(v_sqlstate)then return private.release_retryable_command(v_claim.command_execution_id,v_sqlstate,'partner_withdrawals.execute','partner_withdrawal',p_partner_withdrawal_id,p_idempotency_key,p_correlation_id);end if;perform private.complete_command_failure(v_claim.command_execution_id,'PARTNER_WITHDRAWAL_EXECUTION_REJECTED',null);return private.command_replay_response('failed_terminal',null,'PARTNER_WITHDRAWAL_EXECUTION_REJECTED',v_claim.command_execution_id);end;
end;$$;

create or replace function api.request_partner_withdrawal(p_organization_id uuid,p_partner_id uuid,p_withdrawal_number text,p_withdrawal_type public.partner_withdrawal_type,p_requested_amount_minor bigint,p_reason text,p_evidence_attachment_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_request_partner_withdrawal(p_organization_id,p_partner_id,p_withdrawal_number,p_withdrawal_type,p_requested_amount_minor,p_reason,p_evidence_attachment_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.approve_partner_withdrawal(p_organization_id uuid,p_partner_withdrawal_id uuid,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_approve_partner_withdrawal(p_organization_id,p_partner_withdrawal_id,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;
create or replace function api.execute_partner_withdrawal(p_organization_id uuid,p_partner_withdrawal_id uuid,p_wallet_id uuid,p_provider_reference text,p_idempotency_key text,p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid())returns jsonb language sql volatile security invoker set search_path='' as $$select private.command_execute_partner_withdrawal(p_organization_id,p_partner_withdrawal_id,p_wallet_id,p_provider_reference,p_idempotency_key,p_request_fingerprint,p_correlation_id)$$;

revoke all on function private.command_request_partner_withdrawal(uuid,uuid,text,public.partner_withdrawal_type,bigint,text,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_approve_partner_withdrawal(uuid,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function private.command_execute_partner_withdrawal(uuid,uuid,uuid,text,text,text,uuid) from public,anon,authenticated;
grant execute on function private.command_request_partner_withdrawal(uuid,uuid,text,public.partner_withdrawal_type,bigint,text,uuid,text,text,uuid) to authenticated;
grant execute on function private.command_approve_partner_withdrawal(uuid,uuid,text,text,uuid) to authenticated;
grant execute on function private.command_execute_partner_withdrawal(uuid,uuid,uuid,text,text,text,uuid) to authenticated;
revoke all on function api.request_partner_withdrawal(uuid,uuid,text,public.partner_withdrawal_type,bigint,text,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function api.approve_partner_withdrawal(uuid,uuid,text,text,uuid) from public,anon,authenticated;
revoke all on function api.execute_partner_withdrawal(uuid,uuid,uuid,text,text,text,uuid) from public,anon,authenticated;
grant execute on function api.request_partner_withdrawal(uuid,uuid,text,public.partner_withdrawal_type,bigint,text,uuid,text,text,uuid) to authenticated;
grant execute on function api.approve_partner_withdrawal(uuid,uuid,text,text,uuid) to authenticated;
grant execute on function api.execute_partner_withdrawal(uuid,uuid,uuid,text,text,text,uuid) to authenticated;

-- Existing distribution wrappers are security-invoker functions and therefore
-- require the same narrow implementation grant as the other API commands.
grant execute on function private.command_profit_distribution(uuid,text,uuid,uuid,text,bigint,uuid,text,text,uuid) to authenticated;
