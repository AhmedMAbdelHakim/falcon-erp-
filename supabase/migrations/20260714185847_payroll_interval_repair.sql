do $$ declare d text;begin
 select pg_get_functiondef('private.command_calculate_payroll_period(uuid,date,text,text,uuid)'::regprocedure) into strict d;
 d:=replace(d,'interval ''1 month-1 day''','interval ''1 month - 1 day''');execute d;
end$$;
grant execute on function private.command_calculate_payroll_period(uuid,date,text,text,uuid) to authenticated;
