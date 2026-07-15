do $$
declare v_signature regprocedure; v_definition text;
begin
  foreach v_signature in array array[
    'private.command_mark_order_delivered(uuid,uuid,uuid,timestamptz,bigint,integer,text,text,uuid)'::regprocedure,
    'private.command_record_order_return(uuid,uuid,text,jsonb,text,uuid,integer,text,text,uuid)'::regprocedure
  ] loop
    select pg_get_functiondef(v_signature) into strict v_definition;
    v_definition:=replace(v_definition,
      'reason,accounting_date,journal_entry_id,created_by,updated_by)',
      'reason,occurred_at,accounting_date,journal_entry_id,created_by,updated_by)');
    v_definition:=replace(v_definition,
      '''Delivered to customer'',private.cairo_accounting_date()',
      '''Delivered to customer'',p_delivered_at,private.cairo_accounting_date()');
    v_definition:=replace(v_definition,
      'p_correlation_id,v_row.reason,private.cairo_accounting_date()',
      'p_correlation_id,v_row.reason,statement_timestamp(),private.cairo_accounting_date()');
    if position('reason,occurred_at,accounting_date' in v_definition)=0 then
      raise exception 'Inventory timestamp repair failed for %',v_signature;
    end if;
    execute v_definition;
  end loop;
end;
$$;

grant execute on function private.command_mark_order_delivered(uuid,uuid,uuid,timestamptz,bigint,integer,text,text,uuid) to authenticated;
grant execute on function private.command_record_order_return(uuid,uuid,text,jsonb,text,uuid,integer,text,text,uuid) to authenticated;
