do $migration$
declare
  v_definition text;
  v_fixed text;
begin
  select pg_get_functiondef(
    'private.command_receive_print_batch(uuid,uuid,text,jsonb,timestamptz,text,text,uuid)'::regprocedure
  ) into v_definition;

  v_fixed := replace(
    v_definition,
    'status=case when received_quantity+v_row.accepted_quantity+v_row.rejected_quantity=sent_quantity then''qc_complete''else''partially_received''end,qc_completed_at=',
    'status=(case when received_quantity+v_row.accepted_quantity+v_row.rejected_quantity=sent_quantity then''qc_complete''else''partially_received''end)::public.production_attempt_status,qc_completed_at='
  );
  if v_fixed = v_definition then
    raise exception 'PRINTING_ITEM_STATUS_CAST_REPAIR_NOT_APPLIED';
  end if;

  v_definition := v_fixed;
  v_fixed := replace(
    v_definition,
    'set status=case when not exists(select 1 from public.print_batch_items where print_batch_id=v_batch.id and received_quantity<sent_quantity)then''ready_for_invoice''else''partially_received''end,version=',
    'set status=(case when not exists(select 1 from public.print_batch_items where print_batch_id=v_batch.id and received_quantity<sent_quantity)then''ready_for_invoice''else''partially_received''end)::public.print_batch_status,version='
  );
  if v_fixed = v_definition then
    raise exception 'PRINTING_BATCH_STATUS_CAST_REPAIR_NOT_APPLIED';
  end if;
  execute v_fixed;
end;
$migration$;
