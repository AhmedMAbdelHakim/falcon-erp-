do $$
declare v_definition text;
begin
  select pg_get_functiondef('private.command_cancel_order(uuid,uuid,text,bigint,text,text,uuid)'::regprocedure)
  into strict v_definition;
  v_definition := replace(v_definition, 'status = ''released'', version = version + 1',
    'status = ''released'', version = ir.version + 1');
  execute v_definition;
end;
$$;

grant execute on function private.command_cancel_order(uuid,uuid,text,bigint,text,text,uuid) to authenticated;
