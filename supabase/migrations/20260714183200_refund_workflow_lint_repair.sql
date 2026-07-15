-- Remove a dead local identified by plpgsql_check without rewriting migration 2654.

do $$
declare
  v_definition text;
begin
  select pg_get_functiondef(p.oid) into strict v_definition
  from pg_proc as p
  where p.oid = 'private.command_execute_customer_refund(uuid,uuid,uuid,text,uuid,text,text,uuid)'::regprocedure;

  v_definition := replace(v_definition, E'  v_movement_id uuid;\n', '');
  v_definition := replace(v_definition, E'      ) returning id into v_movement_id;\n', E'      );\n');

  if position('v_movement_id' in v_definition) > 0 then
    raise exception 'Refund lint repair did not remove v_movement_id';
  end if;
  execute v_definition;
end;
$$;

revoke all on function private.command_execute_customer_refund(
  uuid, uuid, uuid, text, uuid, text, text, uuid
) from public, anon, authenticated;
