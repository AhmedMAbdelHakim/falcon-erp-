-- Forward-only repairs found by the first executable `supabase db lint` run.

do $$
declare
  v_definition text;
  v_old text := $fragment$payment_status = case
          when v_allocated = 0 then 'no_payment'
          when v_allocated < v_order.required_deposit_minor then 'partial'
          when v_allocated < v_total then 'required_deposit_paid'
          when v_allocated = v_total then 'fully_prepaid'
          else 'overpaid'
        end,$fragment$;
  v_new text := $fragment$payment_status = (case
          when v_allocated = 0 then 'no_payment'
          when v_allocated < v_order.required_deposit_minor then 'partial'
          when v_allocated < v_total then 'required_deposit_paid'
          when v_allocated = v_total then 'fully_prepaid'
          else 'overpaid'
        end)::public.payment_status,$fragment$;
begin
  select pg_get_functiondef(
    'private.command_confirm_order(uuid,uuid,bigint,text,text,uuid)'::regprocedure
  ) into strict v_definition;
  if strpos(v_definition, v_old) = 0 then
    raise exception using errcode = '55000', message = 'CONFIRM_ORDER_LINT_REPAIR_TARGET_NOT_FOUND';
  end if;
  execute replace(v_definition, v_old, v_new);
end;
$$;

do $$
declare
  v_definition text;
  v_old text := '  v_actor uuid := auth.uid();' || chr(10);
begin
  select pg_get_functiondef(
    'private.reverse_journal_entry(uuid,uuid,text,text,text,uuid,uuid,uuid)'::regprocedure
  ) into strict v_definition;
  if strpos(v_definition, v_old) = 0 then
    raise exception using errcode = '55000', message = 'REVERSE_JOURNAL_LINT_REPAIR_TARGET_NOT_FOUND';
  end if;
  execute replace(v_definition, v_old, '');
end;
$$;

