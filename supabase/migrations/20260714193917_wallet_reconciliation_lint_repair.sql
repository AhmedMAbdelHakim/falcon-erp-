do $$
declare
  v_definition text;
  v_repaired text;
begin
  v_definition := pg_get_functiondef(
    'private.command_prepare_wallet_reconciliation(uuid,uuid,timestamptz,timestamptz,bigint,uuid,text,text,text,uuid)'::regprocedure
  );
  v_repaired := replace(
    v_definition,
    E'    for update;\n\n    if exists (',
    E'    for update;\n    perform v_wallet.id;\n\n    if exists ('
  );
  if v_repaired = v_definition then
    raise exception 'WALLET_RECONCILIATION_LINT_REPAIR_TARGET_NOT_FOUND';
  end if;
  execute v_repaired;
end;
$$;
