const positive = new Set(['active', 'approved', 'posted', 'closed', 'delivered', 'paid', 'reconciled', 'succeeded', 'passed', 'confirmed', 'ready', 'executed', 'prepared'])
const negative = new Set(['rejected', 'failed', 'cancelled', 'void', 'overdue', 'difference', 'suspended', 'reversed', 'inactive', 'terminated'])
const warning = new Set(['pending', 'submitted', 'draft', 'open', 'closing', 'partial', 'under_review', 'unreconciled', 'requested'])

const arabic: Record<string, string> = {
  active: 'نشط',
  approved: 'معتمد',
  posted: 'مرحل',
  closed: 'مغلق',
  delivered: 'تم التسليم',
  paid: 'مدفوع',
  reconciled: 'مطابق',
  succeeded: 'ناجح',
  passed: 'مجتاز',
  confirmed: 'مؤكد',
  ready: 'جاهز',
  executed: 'منفذ',
  prepared: 'مجهز',
  rejected: 'مرفوض',
  failed: 'فشل',
  cancelled: 'ملغي',
  void: 'باطل',
  overdue: 'متأخر',
  difference: 'يوجد فرق',
  suspended: 'موقوف',
  reversed: 'معكوس',
  inactive: 'غير نشط',
  terminated: 'منتهي',
  pending: 'قيد الانتظار',
  submitted: 'مقدم',
  draft: 'مسودة',
  open: 'مفتوح',
  closing: 'جاري الإقفال',
  partial: 'جزئي',
  under_review: 'قيد المراجعة',
  unreconciled: 'غير مطابق',
  requested: 'مطلوب',
}

export function StatusBadge({ value }: { value: unknown }) {
  const normalized = String(value ?? 'unknown').toLowerCase()
  const tone = positive.has(normalized) ? 'positive' : negative.has(normalized) ? 'negative' : warning.has(normalized) ? 'warning' : 'neutral'
  return <span className={`status-badge ${tone}`}>{arabic[normalized] ?? String(value ?? 'غير محدد')}</span>
}
