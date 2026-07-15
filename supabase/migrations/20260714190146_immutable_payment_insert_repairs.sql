do $$
declare d text;
begin
 select pg_get_functiondef('private.command_pay_expense(uuid,uuid,uuid,text,uuid,text,text,uuid)'::regprocedure) into strict d;
 d:=replace(d,'v_payment uuid;','v_payment uuid:=extensions.gen_random_uuid();');
 d:=replace(d,'  insert into public.expense_payments(organization_id,expense_id,wallet_id,amount_minor,payment_date,provider_reference,evidence_attachment_id,created_by,updated_by) values(p_organization_id,v_expense.id,v_wallet.id,v_amount,private.cairo_accounting_date(),p_provider_reference,p_evidence_attachment_id,auth.uid(),auth.uid()) returning id into v_payment;','');
 d:=replace(d,'  update public.expense_payments set journal_entry_id=v_journal where id=v_payment;update public.expenses set paid_minor=total_minor,status=''paid'',version=version+1 where id=v_expense.id;',
 '  insert into public.expense_payments(id,organization_id,expense_id,wallet_id,amount_minor,payment_date,provider_reference,evidence_attachment_id,journal_entry_id,created_by,updated_by) values(v_payment,p_organization_id,v_expense.id,v_wallet.id,v_amount,private.cairo_accounting_date(),p_provider_reference,p_evidence_attachment_id,v_journal,auth.uid(),auth.uid());update public.expenses set paid_minor=total_minor,status=''paid'',version=version+1 where id=v_expense.id;');
 d:=replace(d,'raise notice ''EXPENSE_PAY_DEBUG [%] %'',sqlstate,sqlerrm;','');
 if position('returning id into v_payment' in d)>0 then raise exception 'Expense immutable payment repair failed';end if;execute d;

 select pg_get_functiondef('private.command_pay_payroll_entry(uuid,uuid,uuid,text,uuid,text,text,uuid)'::regprocedure) into strict d;
 d:=replace(d,'v_payment uuid;','v_payment uuid:=extensions.gen_random_uuid();');
 d:=replace(d,'  insert into public.payroll_payments(organization_id,payroll_entry_id,wallet_id,amount_minor,payment_date,provider_reference,evidence_attachment_id,created_by,updated_by) values(p_organization_id,v_entry.id,v_wallet.id,v_amount,private.cairo_accounting_date(),p_provider_reference,p_evidence_attachment_id,auth.uid(),auth.uid()) returning id into v_payment;','');
 d:=replace(d,'  update public.payroll_payments set journal_entry_id=v_journal where id=v_payment;update public.payroll_entries set paid_minor=net_payroll_minor,status=''paid'',version=version+1 where id=v_entry.id;',
 '  insert into public.payroll_payments(id,organization_id,payroll_entry_id,wallet_id,amount_minor,payment_date,provider_reference,evidence_attachment_id,journal_entry_id,created_by,updated_by) values(v_payment,p_organization_id,v_entry.id,v_wallet.id,v_amount,private.cairo_accounting_date(),p_provider_reference,p_evidence_attachment_id,v_journal,auth.uid(),auth.uid());update public.payroll_entries set paid_minor=net_payroll_minor,status=''paid'',version=version+1 where id=v_entry.id;');
 d:=replace(d,'raise notice ''PAYROLL_PAY_DEBUG [%] %'',sqlstate,sqlerrm;','');
 if position('returning id into v_payment' in d)>0 then raise exception 'Payroll immutable payment repair failed';end if;execute d;
end$$;

grant execute on function private.command_pay_expense(uuid,uuid,uuid,text,uuid,text,text,uuid) to authenticated;
grant execute on function private.command_pay_payroll_entry(uuid,uuid,uuid,text,uuid,text,text,uuid) to authenticated;
