import type { DataColumn } from '../../components/ui/DataTable'
import type { Database } from '../../types/database.generated'

type PublicTable = keyof Database['public']['Tables'] & string
type PublicView = keyof Database['public']['Views'] & string

export interface ResourceConfig {
  key: string
  title: string
  description: string
  source: PublicTable | PublicView
  permission: readonly string[]
  searchColumns?: readonly string[]
  statusColumn?: string
  columns: readonly DataColumn[]
}

export const resourceCatalog: Record<string, ResourceConfig> = {
  customers: {
    key: 'customers', title: 'العملاء', description: 'بيانات العملاء المعتمدة ونطاق الإسناد التشغيلي.', source: 'customers', permission: ['customers.read'],
    searchColumns: ['customer_number', 'full_name', 'phone_normalized'], statusColumn: 'is_active',
    columns: [
      { key: 'customer_number', label: 'رقم العميل' }, { key: 'full_name', label: 'الاسم' },
      { key: 'phone_original', label: 'الهاتف' }, { key: 'source_channel', label: 'المصدر' },
      { key: 'is_active', label: 'نشط', kind: 'status' }, { key: 'created_at', label: 'تاريخ الإنشاء', kind: 'datetime' },
    ],
  },
  orders: {
    key: 'orders', title: 'الأوردرات', description: 'حالة التنفيذ والدفع والهامش من العرض التشغيلي المعتمد.', source: 'order_financial_summary', permission: ['orders.read'],
    searchColumns: ['order_number'], statusColumn: 'status',
    columns: [
      { key: 'order_number', label: 'رقم الأوردر' }, { key: 'status', label: 'التنفيذ', kind: 'status' },
      { key: 'payment_status', label: 'الدفع', kind: 'status' }, { key: 'order_total_minor', label: 'الإجمالي', kind: 'money' },
      { key: 'confirmed_payment_minor', label: 'المؤكد', kind: 'money' }, { key: 'balance_due_minor', label: 'المتبقي', kind: 'money' },
      { key: 'expected_margin_minor', label: 'الهامش المتوقع', kind: 'money' }, { key: 'actual_margin_minor', label: 'الهامش الفعلي', kind: 'money' },
    ],
  },
  payments: {
    key: 'payments', title: 'مدفوعات العملاء', description: 'إيصالات التحصيل وحالة المراجعة دون اعتبار التحصيل إيرادًا.', source: 'customer_payments', permission: ['payments.record', 'payments.review'],
    searchColumns: ['payment_number', 'provider_reference'], statusColumn: 'status',
    columns: [
      { key: 'payment_number', label: 'رقم الدفعة' }, { key: 'status', label: 'الحالة', kind: 'status' },
      { key: 'amount_minor', label: 'المبلغ', kind: 'money' }, { key: 'payment_method', label: 'الوسيلة' },
      { key: 'provider_reference', label: 'مرجع التحويل' }, { key: 'received_at', label: 'وقت الاستلام', kind: 'datetime' },
    ],
  },
  refunds: {
    key: 'refunds', title: 'الاستردادات', description: 'طلبات الاسترداد واعتمادها وتنفيذها وفق فصل الواجبات.', source: 'refunds', permission: ['refunds.request', 'refunds.approve', 'refunds.execute'],
    searchColumns: ['refund_number', 'reason'], statusColumn: 'status',
    columns: [
      { key: 'refund_number', label: 'رقم الاسترداد' }, { key: 'status', label: 'الحالة', kind: 'status' },
      { key: 'amount_minor', label: 'المبلغ', kind: 'money' }, { key: 'reason', label: 'السبب' },
      { key: 'requested_at', label: 'تاريخ الطلب', kind: 'datetime' }, { key: 'executed_at', label: 'تاريخ التنفيذ', kind: 'datetime' },
    ],
  },
  printBatches: {
    key: 'printBatches', title: 'دفعات الطباعة', description: 'الدفعات، الاستلام، فحص الجودة، والتكلفة المثبتة.', source: 'print_batches', permission: ['print_batches.create', 'print_batches.receive', 'print_batches.close'],
    searchColumns: ['batch_number'], statusColumn: 'status',
    columns: [
      { key: 'batch_number', label: 'رقم الدفعة' }, { key: 'status', label: 'الحالة', kind: 'status' },
      { key: 'expected_total_minor', label: 'المتوقع', kind: 'money' }, { key: 'actual_total_minor', label: 'الفعلي', kind: 'money' },
      { key: 'sent_at', label: 'الإرسال', kind: 'datetime' }, { key: 'closed_at', label: 'الإغلاق', kind: 'datetime' },
    ],
  },
  suppliers: {
    key: 'suppliers', title: 'حساب الموردين', description: 'الفواتير والمدفوعات والرصيد المفتوح من العرض المعتمد.', source: 'supplier_payable_summary', permission: ['supplier_invoices.create', 'supplier_invoices.approve', 'orders.read'],
    columns: [
      { key: 'supplier_id', label: 'المورد' }, { key: 'invoiced_minor', label: 'الفواتير', kind: 'money' },
      { key: 'paid_minor', label: 'المدفوع', kind: 'money' }, { key: 'open_payable_minor', label: 'المستحق', kind: 'money' },
    ],
  },
  inventory: {
    key: 'inventory', title: 'أرصدة المخزون', description: 'الرصيد حسب الصنف والموقع من حركات المخزون المعتمدة.', source: 'inventory_balance_by_location', permission: ['orders.read', 'print_batches.create', 'shipments.create'],
    columns: [
      { key: 'product_variant_id', label: 'الصنف' }, { key: 'location_id', label: 'الموقع' },
      { key: 'quantity_on_hand', label: 'الكمية', kind: 'number' }, { key: 'inventory_cost_minor', label: 'تكلفة الرصيد', kind: 'money' },
    ],
  },
  inventoryMovements: {
    key: 'inventoryMovements', title: 'حركات المخزون', description: 'سجل الحركة غير القابل للحذف بين مواقع العهدة.', source: 'inventory_movements', permission: ['orders.read', 'print_batches.create'],
    statusColumn: 'movement_type', columns: [
      { key: 'movement_type', label: 'نوع الحركة', kind: 'status' }, { key: 'quantity', label: 'الكمية', kind: 'number' },
      { key: 'unit_cost_minor', label: 'تكلفة الوحدة', kind: 'money' }, { key: 'occurred_at', label: 'وقت الحركة', kind: 'datetime' },
      { key: 'reason', label: 'السبب' },
    ],
  },
  inventoryLocations: {
    key: 'inventoryLocations', title: 'مواقع المخزون', description: 'مواقع التخزين والعهدة المعتمدة داخل Falcon وخارجها.', source: 'inventory_locations', permission: ['orders.read'],
    searchColumns: ['location_code', 'display_name'], statusColumn: 'is_active', columns: [
      { key: 'location_code', label: 'الكود' }, { key: 'display_name', label: 'الموقع' },
      { key: 'location_type', label: 'النوع' }, { key: 'is_active', label: 'نشط', kind: 'status' },
    ],
  },
  shipments: {
    key: 'shipments', title: 'الشحنات', description: 'حالة الشحن والتتبع وCOD بعقود الأسعار المثبتة.', source: 'shipments', permission: ['shipments.create', 'shipments.update', 'orders.read'],
    searchColumns: ['shipment_number', 'tracking_number'], statusColumn: 'status', columns: [
      { key: 'shipment_number', label: 'رقم الشحنة' }, { key: 'tracking_number', label: 'التتبع' },
      { key: 'status', label: 'الحالة', kind: 'status' }, { key: 'contractual_cod_minor', label: 'COD تعاقدي', kind: 'money' },
      { key: 'courier_delivery_fee_minor', label: 'رسوم التسليم', kind: 'money' }, { key: 'dispatched_at', label: 'الإرسال', kind: 'datetime' },
    ],
  },
  returns: {
    key: 'returns', title: 'المرتجعات', description: 'مرتجعات الشحن مع السبب والتصرف المحاسبي المرجعي.', source: 'returns', permission: ['orders.return', 'shipments.update', 'orders.read'],
    searchColumns: ['return_number', 'reason'], statusColumn: 'status', columns: [
      { key: 'return_number', label: 'رقم المرتجع' }, { key: 'status', label: 'الحالة', kind: 'status' },
      { key: 'reason', label: 'السبب' }, { key: 'confirmed_at', label: 'التأكيد', kind: 'datetime' },
    ],
  },
  settlements: {
    key: 'settlements', title: 'تسويات شركة الشحن', description: 'المتوقع مقابل المحول والفرق دون الثقة في تقرير شركة الشحن كمصدر للحقيقة.', source: 'courier_settlement_summary', permission: ['courier_settlements.prepare', 'courier_settlements.approve', 'orders.read'],
    searchColumns: ['settlement_no'], statusColumn: 'status', columns: [
      { key: 'settlement_no', label: 'رقم التسوية' }, { key: 'status', label: 'الحالة', kind: 'status' },
      { key: 'contractual_cod_minor', label: 'COD تعاقدي', kind: 'money' }, { key: 'expected_net_settlement_minor', label: 'المتوقع', kind: 'money' },
      { key: 'actual_transfer_minor', label: 'المحول', kind: 'money' }, { key: 'difference_minor', label: 'الفرق', kind: 'money' },
      { key: 'period_end', label: 'نهاية الفترة', kind: 'date' },
    ],
  },
  wallets: {
    key: 'wallets', title: 'المحافظ', description: 'تعريف المحافظ وحالة التحصيل التشغيلية. الرصيد المالي المعتمد يظهر في تقرير السيولة.', source: 'wallet_balance_summary', permission: ['wallets.read_summary', 'ledger.read'],
    searchColumns: ['code', 'name', 'provider'], statusColumn: 'is_active', columns: [
      { key: 'code', label: 'الكود' }, { key: 'name', label: 'المحفظة' }, { key: 'provider', label: 'المزود' },
      { key: 'confirmed_customer_receipts_minor', label: 'تحصيلات مؤكدة', kind: 'money' }, { key: 'last_confirmed_receipt_at', label: 'آخر تحصيل', kind: 'datetime' },
      { key: 'is_active', label: 'نشطة', kind: 'status' },
    ],
  },
  reconciliations: {
    key: 'reconciliations', title: 'مطابقة المحافظ', description: 'الرصيد الدفتري مقابل الرصيد الفعلي والفرق المراجع.', source: 'wallet_reconciliation_summary', permission: ['wallets.read_summary', 'wallets.reconcile', 'ledger.read'],
    statusColumn: 'status', columns: [
      { key: 'reconciliation_date', label: 'التاريخ', kind: 'date' }, { key: 'status', label: 'الحالة', kind: 'status' },
      { key: 'opening_book_balance_minor', label: 'رصيد أول', kind: 'money' }, { key: 'expected_closing_balance_minor', label: 'رصيد دفتري', kind: 'money' },
      { key: 'actual_closing_balance_minor', label: 'رصيد فعلي', kind: 'money' }, { key: 'difference_minor', label: 'الفرق', kind: 'money' },
    ],
  },
  expenses: {
    key: 'expenses', title: 'المصروفات', description: 'طلبات المصروفات واعتمادها وسدادها مع مرجع المستند.', source: 'expenses', permission: ['expenses.create', 'expenses.approve', 'expenses.pay'],
    searchColumns: ['expense_number', 'description'], statusColumn: 'status', columns: [
      { key: 'expense_number', label: 'رقم المصروف' }, { key: 'description', label: 'البيان' },
      { key: 'status', label: 'الحالة', kind: 'status' }, { key: 'total_minor', label: 'الإجمالي', kind: 'money' },
      { key: 'expense_date', label: 'التاريخ', kind: 'date' },
    ],
  },
  employees: {
    key: 'employees', title: 'الموظفون', description: 'ملف الموظف التشغيلي ضمن نطاق صلاحيات الرواتب.', source: 'employees', permission: ['payroll.read_all', 'payroll.read_own_scope'],
    searchColumns: ['employee_number', 'full_name'], statusColumn: 'status', columns: [
      { key: 'employee_number', label: 'الكود' }, { key: 'full_name', label: 'الاسم' },
      { key: 'employee_type', label: 'النوع' }, { key: 'status', label: 'الحالة', kind: 'status' }, { key: 'hire_date', label: 'تاريخ التعيين', kind: 'date' },
    ],
  },
  payroll: {
    key: 'payroll', title: 'الرواتب', description: 'حالة دورة الرواتب والمستحق والمدفوع دون حساب الحقيقة المالية في الواجهة.', source: 'payroll_status_summary', permission: ['payroll.read_all', 'payroll.read_own_scope'],
    statusColumn: 'status', columns: [
      { key: 'payroll_period_id', label: 'الفترة' }, { key: 'status', label: 'الحالة', kind: 'status' },
      { key: 'employee_count', label: 'الموظفون', kind: 'number' }, { key: 'net_payroll_minor', label: 'صافي الرواتب', kind: 'money' },
      { key: 'paid_minor', label: 'المدفوع', kind: 'money' }, { key: 'outstanding_minor', label: 'المتبقي', kind: 'money' },
    ],
  },
  performance: {
    key: 'performance', title: 'الأداء والبونص', description: 'ملخص تقييمات الأداء المعتمدة ومصدر البونص.', source: 'employee_bonus_summary', permission: ['payroll.read_all', 'payroll.read_own_scope'],
    columns: [
      { key: 'employee_id', label: 'الموظف' }, { key: 'review_count', label: 'التقييمات', kind: 'number' },
      { key: 'approved_review_count', label: 'المعتمد', kind: 'number' }, { key: 'latest_review_period_end', label: 'آخر فترة', kind: 'date' },
    ],
  },
  partners: {
    key: 'partners', title: 'حسابات الشركاء', description: 'رأس المال والحساب الجاري والتوزيعات والمسحوبات ضمن نطاق الشريك المعتمد.', source: 'partner_account_summary', permission: ['partner_withdrawals.request', 'partner_withdrawals.approve', 'ledger.read'],
    searchColumns: ['partner_code', 'full_name'], columns: [
      { key: 'partner_code', label: 'الكود' }, { key: 'full_name', label: 'الشريك' },
      { key: 'capital_and_current_minor', label: 'رأس المال والجاري', kind: 'money' }, { key: 'allocated_profit_minor', label: 'الأرباح المخصصة', kind: 'money' },
      { key: 'executed_withdrawals_minor', label: 'المسحوبات', kind: 'money' },
    ],
  },
  withdrawals: {
    key: 'withdrawals', title: 'مسحوبات الشركاء', description: 'طلبات المسحوبات وتجميع 24 ساعة وضوابط السيولة والموافقة.', source: 'partner_withdrawals', permission: ['partner_withdrawals.request', 'partner_withdrawals.approve', 'partner_withdrawals.execute'],
    statusColumn: 'status', columns: [
      { key: 'withdrawal_number', label: 'رقم الطلب' }, { key: 'withdrawal_type', label: 'النوع' },
      { key: 'status', label: 'الحالة', kind: 'status' }, { key: 'amount_minor', label: 'المبلغ', kind: 'money' },
      { key: 'rolling_24h_total_minor', label: 'إجمالي 24 ساعة', kind: 'money' }, { key: 'requested_at', label: 'وقت الطلب', kind: 'datetime' },
    ],
  },
  distributions: {
    key: 'distributions', title: 'توزيعات الأرباح', description: 'توزيعات مبنية على إقفال معتمد ولقطة ملكية ثابتة.', source: 'profit_distributions', permission: ['ledger.read', 'profit_distributions.calculate', 'profit_distributions.approve'],
    statusColumn: 'status', columns: [
      { key: 'distribution_number', label: 'رقم التوزيع' }, { key: 'status', label: 'الحالة', kind: 'status' },
      { key: 'distributable_profit_minor', label: 'القابل للتوزيع', kind: 'money' }, { key: 'allocated_total_minor', label: 'المخصص', kind: 'money' },
      { key: 'posted_at', label: 'الترحيل', kind: 'datetime' },
    ],
  },
  approvals: {
    key: 'approvals', title: 'صندوق الموافقات', description: 'ملخص الطلبات حسب النوع والحالة والمبلغ دون تجاوز فصل الواجبات.', source: 'approval_queue_summary', permission: ['orders.read', 'payments.review', 'partner_withdrawals.approve', 'accounting.close_period'],
    statusColumn: 'status', columns: [
      { key: 'request_type', label: 'نوع الطلب' }, { key: 'status', label: 'الحالة', kind: 'status' },
      { key: 'request_count', label: 'العدد', kind: 'number' }, { key: 'requested_amount_minor', label: 'المبلغ', kind: 'money' },
      { key: 'oldest_requested_at', label: 'أقدم طلب', kind: 'datetime' },
    ],
  },
}
