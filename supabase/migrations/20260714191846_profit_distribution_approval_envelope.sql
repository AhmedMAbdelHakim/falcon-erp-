create or replace function private.command_calculate_profit_distribution_with_approval(
  p_organization_id uuid,p_monthly_closing_id uuid,p_distribution_no text,
  p_distribution_amount_minor bigint,p_idempotency_key text,
  p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql volatile security definer set search_path=''
as $$
declare
  v_result jsonb;v_distribution public.profit_distributions;v_approval_id uuid;
  v_permission_id uuid;v_approval_payload jsonb;v_approval_fingerprint text;
begin
  v_result:=private.command_profit_distribution(
    p_organization_id,'calculate',p_monthly_closing_id,null,p_distribution_no,
    p_distribution_amount_minor,null,p_idempotency_key,p_request_fingerprint,p_correlation_id
  );
  if not coalesce((v_result->>'success')::boolean,false) then return v_result;end if;

  select pd.* into strict v_distribution
  from public.profit_distributions pd
  where pd.organization_id=p_organization_id and pd.id=(v_result->>'entity_id')::uuid
  for update;

  if v_distribution.approval_request_id is null then
    v_approval_id:=extensions.gen_random_uuid();
    v_approval_payload:=jsonb_build_object(
      'organization_id',p_organization_id,'action','approve',
      'monthly_closing_id',null,'profit_distribution_id',v_distribution.id,
      'distribution_no',null,'distribution_amount_minor',null,
      'approval_request_id',v_approval_id
    );
    v_approval_fingerprint:=private.canonical_request_fingerprint(
      'partners.profit_distribution.approve',v_approval_payload,1::smallint
    );
    select id into strict v_permission_id from private.permissions where permission_key='profit_distributions.approve';
    insert into public.approval_requests(
      id,organization_id,request_type,entity_type,entity_id,requested_by,
      submitted_at,status,required_permission_id,requires_separation_of_duties,
      required_approval_count,reason,subject_fingerprint,fingerprint_version,
      requested_amount_minor,approved_min_amount_minor,approved_max_amount_minor,
      payload_snapshot,expires_at
    ) values (
      v_approval_id,p_organization_id,'profit_distribution.approve','profit_distribution',
      v_distribution.id,auth.uid(),statement_timestamp(),'submitted',v_permission_id,true,
      1,'Approve closed-basis profit distribution',v_approval_fingerprint,1,
      v_distribution.allocated_minor,v_distribution.allocated_minor,v_distribution.allocated_minor,
      v_approval_payload,statement_timestamp()+interval '14 days'
    );
    update public.profit_distributions set approval_request_id=v_approval_id,version=version+1,updated_by=auth.uid() where id=v_distribution.id;
  else
    v_approval_id:=v_distribution.approval_request_id;
    select ar.subject_fingerprint into strict v_approval_fingerprint from public.approval_requests ar where ar.organization_id=p_organization_id and ar.id=v_approval_id;
  end if;

  return v_result||jsonb_build_object(
    'approval_request_id',v_approval_id,
    'approval_request_fingerprint',v_approval_fingerprint
  );
end;$$;

create or replace function api.calculate_profit_distribution(
  p_organization_id uuid,p_monthly_closing_id uuid,p_distribution_no text,
  p_distribution_amount_minor bigint,p_idempotency_key text,
  p_request_fingerprint text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language sql volatile security invoker set search_path=''
as $$select private.command_calculate_profit_distribution_with_approval(
  p_organization_id,p_monthly_closing_id,p_distribution_no,p_distribution_amount_minor,
  p_idempotency_key,p_request_fingerprint,p_correlation_id
)$$;

revoke all on function private.command_calculate_profit_distribution_with_approval(uuid,uuid,text,bigint,text,text,uuid) from public,anon,authenticated;
grant execute on function private.command_calculate_profit_distribution_with_approval(uuid,uuid,text,bigint,text,text,uuid) to authenticated;
revoke all on function api.calculate_profit_distribution(uuid,uuid,text,bigint,text,text,uuid) from public,anon,authenticated;
grant execute on function api.calculate_profit_distribution(uuid,uuid,text,bigint,text,text,uuid) to authenticated;
