do $$
declare x record;d text;r text;
begin
  for x in
    select p.oid::regprocedure s
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='private'and p.proname in(
      'command_request_employee_advance','command_record_employee_advance',
      'command_request_expense_reversal','command_reverse_expense'
    )
  loop
    d:=pg_get_functiondef(x.s);
    r:=replace(replace(d,',p_request_fingerprint,1);',',p_request_fingerprint,1::smallint);'),',p_request_fingerprint,1,',',p_request_fingerprint,1::smallint,');
    if r=d then raise exception 'CAST_REPAIR_TARGET_NOT_FOUND: %',x.s;end if;
    execute r;
  end loop;
end$$;
