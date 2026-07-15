do $$
declare
  d text;r text;a_start integer;a_end integer;q_start integer;q_end integer;
begin
  d:=pg_get_functiondef('private.command_request_employee_advance(uuid,uuid,uuid,bigint,text,text,text,uuid)'::regprocedure);
  a_start:=position('    insert into public.employee_advances' in d);
  q_start:=position('    insert into public.approval_requests' in d);
  if a_start=0 or q_start=0 or q_start<a_start then raise exception 'ADVANCE_APPROVAL_ORDER_TARGET_NOT_FOUND';end if;
  a_end:=a_start+position(';' in substring(d from a_start))-1;
  q_end:=q_start+position(';' in substring(d from q_start))-1;
  r:=substring(d from 1 for a_start-1)
    ||substring(d from q_start for q_end-q_start+1)
    ||substring(d from a_end+1 for q_start-a_end-1)
    ||substring(d from a_start for a_end-a_start+1)
    ||substring(d from q_end+1);
  execute r;
end$$;
