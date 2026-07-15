-- Resolve the authoritative effective-dated role mapping, not account metadata.

do $$
declare
  v_signature regprocedure;
  v_definition text;
begin
  foreach v_signature in array array[
    'private.command_allocate_customer_payment(uuid,uuid,jsonb,boolean,text,text,uuid)'::regprocedure,
    'private.command_approve_customer_refund(uuid,uuid,text,text,uuid)'::regprocedure
  ]
  loop
    select pg_get_functiondef(v_signature) into strict v_definition;
    v_definition := replace(
      v_definition,
      'select a.metadata ->> ''system_role'' into strict v_source_role_key',
      'select ar.role_key into strict v_source_role_key'
    );
    v_definition := replace(
      v_definition,
      'join accounting.accounts as a on a.id = jl.account_id',
      E'join accounting.accounts as a on a.id = jl.account_id\n'
      || E'    join accounting.account_role_mappings as arm\n'
      || E'      on arm.organization_id = je.organization_id\n'
      || E'     and arm.account_id = a.id\n'
      || E'     and arm.valid_from <= private.cairo_accounting_date()\n'
      || E'     and (arm.valid_to is null or arm.valid_to > private.cairo_accounting_date())\n'
      || E'    join accounting.account_roles as ar\n'
      || E'      on ar.organization_id = arm.organization_id\n'
      || E'     and ar.id = arm.account_role_id'
    );
    if position('a.metadata' in v_definition) > 0
       or position('account_role_mappings' in v_definition) = 0 then
      raise exception 'Effective role lookup repair failed for %', v_signature;
    end if;
    execute v_definition;
  end loop;
end;
$$;

revoke all on function private.command_allocate_customer_payment(
  uuid, uuid, jsonb, boolean, text, text, uuid
) from public, anon, authenticated;
grant execute on function private.command_allocate_customer_payment(
  uuid, uuid, jsonb, boolean, text, text, uuid
) to authenticated;
revoke all on function private.command_approve_customer_refund(
  uuid, uuid, text, text, uuid
) from public, anon, authenticated;
grant execute on function private.command_approve_customer_refund(
  uuid, uuid, text, text, uuid
) to authenticated;
