-- Repair the enum inference in the previously applied receipt command without
-- changing its signature or grants.
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
    'case when v_row.rejected_quantity=0 then''accepted''when v_row.accepted_quantity=0 then''rejected''else''partially_accepted''end,v_row.accepted_quantity',
    '(case when v_row.rejected_quantity=0 then''accepted''when v_row.accepted_quantity=0 then''rejected''else''partially_accepted''end)::public.qc_status,v_row.accepted_quantity'
  );

  if v_fixed = v_definition then
    raise exception 'PRINTING_QC_STATUS_CAST_REPAIR_NOT_APPLIED';
  end if;
  execute v_fixed;
end;
$migration$;
