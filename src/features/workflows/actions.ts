export interface WorkflowField { name: string; label: string; optional?: boolean; kind?: 'text' | 'number' | 'date' | 'datetime' | 'boolean' | 'json' }
export interface WorkflowAction { label: string; rpc: string; commandType: string; permission: string; fields: WorkflowField[]; tone?: 'primary' | 'danger' }

const labels: Record<string, string> = {
  order_id: 'معرف الأوردر', expected_version: 'الإصدار المتوقع', reason: 'السبب', amount_minor: 'المبلغ بالوحدات الصغرى', approval_request_id: 'معرف الموافقة', includes_shipping: 'يشمل الشحن', source: 'المصدر',
  customer_id: 'معرف العميل', customer_payment_id: 'معرف الدفعة', customer_credit_id: 'معرف رصيد العميل', primary_order_id: 'الأوردر الأساسي', wallet_id: 'معرف المحفظة', source_wallet_id: 'محفظة المصدر', destination_wallet_id: 'محفظة الوجهة',
  evidence_attachment_id: 'معرف مستند الإثبات', external_transaction_reference: 'مرجع العملية الخارجي', provider_reference: 'مرجع المزود', provider_name_snapshot: 'اسم المزود المثبت', payment_method: 'وسيلة الدفع', paid_at: 'وقت الدفع',
  allocations: 'توزيعات الدفعة', credit_remainder: 'تحويل الباقي إلى رصيد', requested_amount_minor: 'المبلغ المطلوب', destination_method: 'وسيلة الاسترداد', destination_reference_snapshot: 'مرجع الوجهة المثبت', refund_id: 'معرف الاسترداد',
  batch_number: 'رقم دفعة الطباعة', business_date: 'تاريخ العمل', supplier_id: 'معرف المورد', items: 'البنود', print_batch_id: 'معرف دفعة الطباعة', receipt_number: 'رقم الاستلام', received_at: 'وقت الاستلام',
  invoice_number: 'رقم الفاتورة', invoice_date: 'تاريخ الفاتورة', due_date: 'تاريخ الاستحقاق', tax_minor: 'الضريبة بالوحدات الصغرى', credit_minor: 'الرصيد الدائن بالوحدات الصغرى', supplier_invoice_id: 'معرف فاتورة المورد',
  courier_id: 'معرف شركة الشحن', shipping_rate_rule_id: 'قاعدة سعر الشحن', tracking_number: 'رقم التتبع', shipment_kind: 'نوع الشحنة', customer_shipping_charge_minor: 'رسوم العميل للشحن', dispatch_evidence_attachment_id: 'إثبات الإرسال', expected_order_version: 'إصدار الأوردر المتوقع',
  shipment_id: 'معرف الشحنة', delivered_at: 'وقت التسليم', delivery_evidence_attachment_id: 'إثبات التسليم', expected_shipment_version: 'إصدار الشحنة المتوقع', reported_collected_cod_minor: 'COD المحصل المبلغ عنه', return_number: 'رقم المرتجع',
  settlement_number: 'رقم التسوية', period_start: 'بداية الفترة', period_end: 'نهاية الفترة', expected_settlement_date: 'تاريخ التسوية المتوقع', actual_settlement_date: 'تاريخ التسوية الفعلي', actual_transfer_minor: 'المحول فعليًا', approved_deductions_minor: 'خصومات معتمدة', adjustments_minor: 'تسويات', prior_carry_forward_minor: 'مرحل سابق', difference_classification: 'تصنيف الفرق', difference_explanation: 'شرح الفرق', is_off_cycle: 'خارج الدورة', off_cycle_reason: 'سبب الخروج عن الدورة', courier_settlement_id: 'معرف تسوية الشحن',
  fee_minor: 'رسوم التحويل', fee_reference: 'مرجع الرسوم', transfer_reference: 'مرجع التحويل', wallet_transfer_id: 'معرف تحويل المحفظة', actual_closing_balance_minor: 'الرصيد الفعلي الختامي', period_started_at: 'بداية فترة المطابقة', period_ended_at: 'نهاية فترة المطابقة', wallet_reconciliation_id: 'معرف المطابقة',
  expense_number: 'رقم المصروف', expense_category_id: 'فئة المصروف', description: 'البيان', payable_name_snapshot: 'اسم المستفيد المثبت', subtotal_minor: 'صافي المصروف', expense_id: 'معرف المصروف',
  payroll_period_id: 'معرف فترة الرواتب', payroll_entry_id: 'معرف بند الراتب', partner_id: 'معرف الشريك', loan_number: 'رقم القرض', principal_minor: 'أصل القرض', terms_snapshot: 'شروط القرض المثبتة', withdrawal_number: 'رقم السحب', withdrawal_type: 'نوع السحب', partner_withdrawal_id: 'معرف طلب السحب',
  monthly_closing_id: 'معرف الإقفال الشهري', distribution_amount_minor: 'مبلغ التوزيع', distribution_no: 'رقم التوزيع', profit_distribution_id: 'معرف توزيع الأرباح',
  accounting_date: 'التاريخ المحاسبي', source_type: 'نوع المصدر', source_id: 'معرف المصدر', posting_purpose: 'غرض الترحيل', lines: 'سطور القيد', affected_closed_period_id: 'الفترة المغلقة المتأثرة', corrects_entry_id: 'القيد المصحح', original_entry_id: 'معرف القيد الأصلي',
  item_key: 'بند قائمة الإقفال', expected_minor: 'القيمة المتوقعة', actual_minor: 'القيمة الفعلية', status: 'الحالة', notes: 'ملاحظات', evidence: 'بيانات الإثبات', reconciliation_snapshot: 'لقطة المطابقات', settings_snapshot: 'لقطة الإعدادات',
}

const autoKind = (name: string): WorkflowField['kind'] => name === 'items' || name === 'allocations' || name === 'lines' || name.endsWith('_snapshot') || name === 'evidence' ? 'json' : name.startsWith('is_') || name === 'includes_shipping' || name === 'credit_remainder' ? 'boolean' : name.endsWith('_minor') || name.endsWith('_version') ? 'number' : name.endsWith('_at') ? 'datetime' : name.endsWith('_date') || name === 'period_start' || name === 'period_end' || name === 'accounting_date' || name === 'due_date' || name === 'invoice_date' || name === 'business_date' ? 'date' : 'text'
const fields = (names: string, optional = ''): WorkflowField[] => names.split(' ').filter(Boolean).map((name) => ({ name, label: labels[name] ?? name.replaceAll('_', ' '), kind: autoKind(name), optional: optional.split(' ').includes(name) }))
const action = (label: string, rpc: string, commandType: string, permission: string, names: string, optional = '', tone?: 'primary' | 'danger'): WorkflowAction => ({ label, rpc, commandType, permission, fields: fields(names, optional), tone })

export const workflowActions: Record<string, WorkflowAction[]> = {
  orders: [
    action('تأكيد الأوردر', 'confirm_order', 'orders.confirm', 'orders.confirm', 'order_id expected_version'),
    action('منح خصم', 'grant_order_discount', 'orders.grant_discount', 'discounts.grant', 'order_id expected_version amount_minor includes_shipping source reason approval_request_id', 'approval_request_id'),
    action('إلغاء الأوردر', 'cancel_order', 'orders.cancel', 'orders.cancel', 'order_id expected_version reason', '', 'danger'),
  ],
  payments: [
    action('تسجيل دفعة', 'record_customer_payment', 'payments.record', 'payments.record', 'customer_id primary_order_id wallet_id amount_minor payment_method paid_at provider_name_snapshot external_transaction_reference evidence_attachment_id', 'primary_order_id evidence_attachment_id'),
    action('تأكيد دفعة', 'confirm_customer_payment', 'payments.confirm', 'payments.review', 'customer_payment_id'),
    action('توزيع دفعة', 'allocate_customer_payment', 'payments.allocate', 'payments.review', 'customer_payment_id allocations credit_remainder'),
    action('استخدام رصيد عميل', 'apply_customer_credit', 'payments.allocate.credit', 'payments.review', 'customer_credit_id order_id amount_minor'),
    action('عكس دفعة', 'reverse_customer_payment', 'payments.reverse', 'ledger.reverse', 'customer_payment_id approval_request_id reason', '', 'danger'),
  ],
  refunds: [
    action('طلب استرداد', 'request_customer_refund', 'refunds.request', 'refunds.request', 'customer_id order_id customer_payment_id customer_credit_id requested_amount_minor destination_method destination_reference_snapshot reason', 'customer_payment_id customer_credit_id'),
    action('اعتماد الاسترداد', 'approve_customer_refund', 'refunds.approve', 'refunds.approve', 'refund_id'),
    action('تنفيذ الاسترداد', 'execute_customer_refund', 'refunds.execute', 'refunds.execute', 'refund_id source_wallet_id external_transaction_reference evidence_attachment_id'),
    action('عكس الاسترداد', 'reverse_customer_refund', 'refunds.reverse', 'ledger.reverse', 'refund_id approval_request_id reason', '', 'danger'),
  ],
  printBatches: [
    action('إنشاء دفعة طباعة', 'create_print_batch', 'print_batches.create', 'print_batches.create', 'batch_number business_date supplier_id items'),
    action('استلام دفعة', 'receive_print_batch', 'print_batches.receive', 'print_batches.receive', 'print_batch_id receipt_number received_at items'),
    action('إغلاق دفعة', 'close_print_batch', 'print_batches.close', 'print_batches.close', 'print_batch_id'),
  ],
  suppliers: [
    action('إنشاء فاتورة مورد', 'create_supplier_invoice', 'supplier_invoices.create', 'supplier_invoices.create', 'supplier_id print_batch_id invoice_number invoice_date due_date tax_minor credit_minor items', 'print_batch_id'),
    action('اعتماد فاتورة', 'approve_supplier_invoice', 'supplier_invoices.approve', 'supplier_invoices.approve', 'supplier_invoice_id'),
    action('سداد فاتورة', 'pay_supplier_invoice', 'supplier_payments.execute', 'supplier_payments.execute', 'supplier_invoice_id wallet_id amount_minor provider_reference evidence_attachment_id'),
  ],
  shipments: [
    action('إنشاء شحنة', 'create_shipment', 'shipments.create', 'shipments.create', 'order_id expected_order_version courier_id shipping_rate_rule_id tracking_number shipment_kind customer_shipping_charge_minor dispatch_evidence_attachment_id items'),
    action('تأكيد التسليم', 'mark_order_delivered', 'orders.deliver', 'orders.deliver', 'shipment_id expected_shipment_version delivered_at reported_collected_cod_minor delivery_evidence_attachment_id'),
  ],
  returns: [action('تسجيل مرتجع', 'record_order_return', 'orders.return', 'orders.return', 'shipment_id expected_shipment_version return_number reason evidence_attachment_id items')],
  settlements: [
    action('إعداد تسوية', 'prepare_courier_settlement', 'courier_settlements.prepare', 'courier_settlements.prepare', 'courier_id settlement_number period_start period_end expected_settlement_date actual_settlement_date actual_transfer_minor approved_deductions_minor adjustments_minor prior_carry_forward_minor difference_classification difference_explanation is_off_cycle off_cycle_reason evidence_attachment_id', 'actual_settlement_date off_cycle_reason evidence_attachment_id'),
    action('اعتماد تسوية', 'approve_courier_settlement', 'courier_settlements.approve', 'courier_settlements.approve', 'courier_settlement_id'),
    action('ترحيل تسوية', 'finalize_courier_settlement', 'courier_settlements.finalize', 'courier_settlements.finalize', 'courier_settlement_id wallet_id'),
  ],
  wallets: [
    action('طلب تحويل', 'request_wallet_transfer', 'wallets.transfer', 'wallets.transfer', 'source_wallet_id destination_wallet_id amount_minor fee_minor transfer_reference fee_reference reason evidence_attachment_id', 'evidence_attachment_id'),
    action('تنفيذ تحويل', 'transfer_between_wallets', 'wallets.transfer', 'wallets.transfer', 'wallet_transfer_id'),
    action('إعداد مطابقة', 'prepare_wallet_reconciliation', 'wallets.reconcile.prepare', 'wallets.reconcile', 'wallet_id period_started_at period_ended_at actual_closing_balance_minor difference_explanation evidence_attachment_id', 'difference_explanation evidence_attachment_id'),
    action('إنهاء مطابقة', 'finalize_wallet_reconciliation', 'wallets.reconcile.finalize', 'wallets.reconcile', 'wallet_reconciliation_id'),
  ],
  expenses: [
    action('تسجيل مصروف', 'record_expense', 'expenses.record', 'expenses.create', 'expense_number expense_category_id business_date due_date description payable_name_snapshot subtotal_minor tax_minor evidence_attachment_id', 'evidence_attachment_id'),
    action('اعتماد مصروف', 'approve_expense', 'expenses.approve', 'expenses.approve', 'expense_id'),
    action('سداد مصروف', 'pay_expense', 'expenses.pay', 'expenses.pay', 'expense_id wallet_id provider_reference evidence_attachment_id'),
  ],
  payroll: [
    action('احتساب الرواتب', 'calculate_payroll_period', 'payroll.calculate', 'payroll.calculate', 'period_start'),
    action('اعتماد الرواتب', 'approve_payroll_period', 'payroll.approve', 'payroll.approve', 'payroll_period_id'),
    action('سداد راتب', 'pay_payroll_entry', 'payroll.pay', 'payroll.pay', 'payroll_entry_id wallet_id provider_reference evidence_attachment_id'),
  ],
  partners: [
    action('إثبات مساهمة رأسمالية', 'record_partner_capital', 'partners.capital.record', 'partners.capital.record', 'partner_id wallet_id amount_minor reason evidence_attachment_id', 'evidence_attachment_id'),
    action('إثبات قرض شريك', 'record_partner_loan', 'partners.loan.record', 'partners.loan.record', 'partner_id wallet_id loan_number principal_minor due_date terms_snapshot'),
  ],
  withdrawals: [
    action('طلب سحب', 'request_partner_withdrawal', 'partner_withdrawals.request', 'partner_withdrawals.request', 'partner_id withdrawal_number withdrawal_type requested_amount_minor reason evidence_attachment_id', 'evidence_attachment_id'),
    action('اعتماد سحب', 'approve_partner_withdrawal', 'partner_withdrawals.approve', 'partner_withdrawals.approve', 'partner_withdrawal_id'),
    action('تنفيذ سحب', 'execute_partner_withdrawal', 'partner_withdrawals.execute', 'partner_withdrawals.execute', 'partner_withdrawal_id wallet_id provider_reference'),
  ],
  distributions: [
    action('احتساب توزيع', 'calculate_profit_distribution', 'profit_distributions.calculate', 'profit_distributions.calculate', 'monthly_closing_id distribution_no distribution_amount_minor'),
    action('اعتماد توزيع', 'approve_profit_distribution', 'profit_distributions.approve', 'profit_distributions.approve', 'profit_distribution_id approval_request_id'),
    action('ترحيل توزيع', 'post_profit_distribution', 'profit_distributions.post', 'profit_distributions.post', 'profit_distribution_id'),
  ],
  ledger: [
    action('ترحيل قيد يدوي', 'post_journal_entry', 'ledger.post', 'ledger.post', 'accounting_date source_type source_id posting_purpose description lines approval_request_id affected_closed_period_id corrects_entry_id', 'approval_request_id affected_closed_period_id corrects_entry_id'),
    action('طلب عكس قيد', 'request_journal_reversal', 'ledger.reverse.request', 'ledger.reverse', 'original_entry_id reason'),
    action('تنفيذ عكس قيد', 'reverse_journal_entry', 'ledger.reverse', 'ledger.reverse', 'original_entry_id reason approval_request_id', 'approval_request_id', 'danger'),
  ],
  monthlyClose: [
    action('بدء الإقفال', 'start_monthly_close', 'accounting.start_close', 'accounting.close_period', 'period_start approval_request_id', 'approval_request_id'),
    action('إثبات بند', 'attest_monthly_close_item', 'accounting.attest_close_item', 'accounting.close_period', 'monthly_closing_id item_key expected_minor actual_minor status notes evidence approval_request_id', 'approval_request_id notes'),
    action('التحقق من الإقفال', 'validate_monthly_close', 'accounting.validate_close', 'accounting.close_period', 'monthly_closing_id'),
    action('إغلاق الفترة', 'close_accounting_period', 'accounting.close_period', 'accounting.close_period', 'monthly_closing_id approval_request_id reconciliation_snapshot settings_snapshot'),
    action('إلغاء دورة الإقفال', 'cancel_monthly_close', 'accounting.cancel_close', 'accounting.close_period', 'monthly_closing_id reason', '', 'danger'),
    action('استعادة دورة الإقفال', 'recover_monthly_close', 'accounting.recover_close', 'accounting.close_period', 'monthly_closing_id reason'),
    action('إعادة فتح فترة', 'reopen_accounting_period', 'accounting.reopen_close', 'accounting.reopen_period', 'monthly_closing_id approval_request_id reason', '', 'danger'),
  ],
}
