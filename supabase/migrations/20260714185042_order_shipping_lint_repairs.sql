-- Repairs identified by plpgsql_check after the order lifecycle migration.

do $$
declare
  v_signature regprocedure;
  v_definition text;
begin
  v_signature := 'private.command_cancel_order(uuid,uuid,text,bigint,text,text,uuid)'::regprocedure;
  select pg_get_functiondef(v_signature) into strict v_definition;
  v_definition := replace(v_definition,
    'released_quantity = quantity - consumed_quantity',
    'released_quantity = ir.quantity - ir.consumed_quantity');
  execute v_definition;

  v_signature := 'private.command_mark_order_delivered(uuid,uuid,uuid,timestamptz,bigint,integer,text,text,uuid)'::regprocedure;
  select pg_get_functiondef(v_signature) into strict v_definition;
  v_definition := replace(v_definition,
    'then ''partially_delivered'' else ''delivered'' end;',
    'then ''partially_delivered'' else ''delivered'' end)::public.order_status;');
  v_definition := replace(v_definition,
    'v_order_state:=case when exists(',
    'v_order_state:=(case when exists(');
  execute v_definition;

  v_signature := 'private.command_record_order_return(uuid,uuid,text,jsonb,text,uuid,integer,text,text,uuid)'::regprocedure;
  select pg_get_functiondef(v_signature) into strict v_definition;
  v_definition := replace(v_definition,
    'then ''returned'' else ''partially_returned'' end,payment_status=',
    'then ''returned'' else ''partially_returned'' end)::public.order_status,payment_status=');
  v_definition := replace(v_definition,
    'update public.orders set status=case when not exists(',
    'update public.orders set status=(case when not exists(');
  execute v_definition;
end;
$$;

grant execute on function private.command_cancel_order(uuid,uuid,text,bigint,text,text,uuid) to authenticated;
grant execute on function private.command_mark_order_delivered(uuid,uuid,uuid,timestamptz,bigint,integer,text,text,uuid) to authenticated;
grant execute on function private.command_record_order_return(uuid,uuid,text,jsonb,text,uuid,integer,text,text,uuid) to authenticated;
