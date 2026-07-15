-- Close organization-scope gaps on evidence and journal references.

do $$
declare
  v_reference record;
  v_constraint_name text;
  v_index_name text;
begin
  for v_reference in
    select * from (values
      ('public','courier_settlements','evidence_attachment_id','public','attachments'),
      ('public','customer_payments','evidence_attachment_id','public','attachments'),
      ('public','expense_payments','evidence_attachment_id','public','attachments'),
      ('public','expenses','evidence_attachment_id','public','attachments'),
      ('public','order_problem_costs','evidence_attachment_id','public','attachments'),
      ('public','order_problems','evidence_attachment_id','public','attachments'),
      ('public','partner_capital_transactions','evidence_attachment_id','public','attachments'),
      ('public','partner_withdrawals','evidence_attachment_id','public','attachments'),
      ('public','payroll_payments','evidence_attachment_id','public','attachments'),
      ('public','refunds','evidence_attachment_id','public','attachments'),
      ('public','returns','evidence_attachment_id','public','attachments'),
      ('public','shipment_status_history','evidence_attachment_id','public','attachments'),
      ('public','shipments','delivery_evidence_attachment_id','public','attachments'),
      ('public','shipments','dispatch_evidence_attachment_id','public','attachments'),
      ('public','shipments','return_evidence_attachment_id','public','attachments'),
      ('public','supplier_payments','evidence_attachment_id','public','attachments'),
      ('public','wallet_reconciliations','evidence_attachment_id','public','attachments'),
      ('public','wallet_transfers','evidence_attachment_id','public','attachments'),
      ('public','courier_settlements','journal_entry_id','accounting','journal_entries'),
      ('public','employee_advances','journal_entry_id','accounting','journal_entries'),
      ('public','expense_payments','journal_entry_id','accounting','journal_entries'),
      ('public','expenses','journal_entry_id','accounting','journal_entries'),
      ('public','grni_accruals','journal_entry_id','accounting','journal_entries'),
      ('public','inventory_movements','journal_entry_id','accounting','journal_entries'),
      ('public','partner_capital_transactions','journal_entry_id','accounting','journal_entries'),
      ('public','partner_loans','journal_entry_id','accounting','journal_entries'),
      ('public','partner_withdrawals','journal_entry_id','accounting','journal_entries'),
      ('public','payroll_entries','accrual_journal_entry_id','accounting','journal_entries'),
      ('public','payroll_payments','journal_entry_id','accounting','journal_entries'),
      ('public','profit_distributions','journal_entry_id','accounting','journal_entries'),
      ('public','shipment_items','return_journal_entry_id','accounting','journal_entries'),
      ('public','shipment_items','revenue_journal_entry_id','accounting','journal_entries'),
      ('public','supplier_invoices','journal_entry_id','accounting','journal_entries'),
      ('public','supplier_payments','journal_entry_id','accounting','journal_entries')
    ) as refs(table_schema, table_name, column_name, target_schema, target_table)
  loop
    v_constraint_name := v_reference.table_name || '_' || v_reference.column_name || '_org_fk';
    execute format(
      'alter table %I.%I add constraint %I foreign key (organization_id, %I) references %I.%I(organization_id, id) on delete restrict',
      v_reference.table_schema, v_reference.table_name, v_constraint_name,
      v_reference.column_name, v_reference.target_schema, v_reference.target_table
    );
    v_index_name := v_reference.table_name || '_' || v_reference.column_name || '_org_idx';
    execute format(
      'create index if not exists %I on %I.%I (organization_id, %I) where %I is not null',
      v_index_name, v_reference.table_schema, v_reference.table_name,
      v_reference.column_name, v_reference.column_name
    );
  end loop;
end;
$$;

