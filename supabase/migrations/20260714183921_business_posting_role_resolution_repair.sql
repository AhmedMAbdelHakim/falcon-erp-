-- Business commands resolve control accounts by role. Explicit account IDs remain
-- reserved for manual journals and mirror reversals in the posting primitive.

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
      v_definition, 'v_source_account_id uuid', 'v_source_role_key text'
    );
    v_definition := replace(
      v_definition,
      'select jl.account_id into strict v_source_account_id',
      'select a.metadata ->> ''system_role'' into strict v_source_role_key'
    );
    v_definition := replace(
      v_definition,
      'join accounting.journal_lines as jl on jl.journal_entry_id = je.id',
      E'join accounting.journal_lines as jl on jl.journal_entry_id = je.id\n    join accounting.accounts as a on a.id = jl.account_id'
    );
    v_definition := replace(
      v_definition,
      '''account_id'', v_source_account_id',
      '''account_role'', v_source_role_key'
    );
    if position('v_source_account_id' in v_definition) > 0
       or position('v_source_role_key' in v_definition) = 0 then
      raise exception 'Role-resolution repair failed for %', v_signature;
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
