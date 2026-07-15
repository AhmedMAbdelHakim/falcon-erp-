const positive = new Set(['active', 'approved', 'posted', 'closed', 'delivered', 'paid', 'reconciled', 'succeeded', 'passed', 'confirmed'])
const negative = new Set(['rejected', 'failed', 'cancelled', 'void', 'overdue', 'difference', 'suspended', 'reversed'])
const warning = new Set(['pending', 'submitted', 'draft', 'open', 'closing', 'partial', 'under_review', 'unreconciled'])

const arabic: Record<string, string> = {
  active: 'نشط', approved: 'معتمد', posted: 'مرحّل', closed: 'مغلق', delivered: 'تم التسليم',
  paid: 'مدفوع', reconciled: 'مطابق', succeeded: 'ناجح', passed: 'مجتاز', confirmed: 'مؤكد',
  rejected: 'مرفوض', failed: 'فشل', cancelled: 'ملغي', overdue: 'متأخر', difference: 'يوجد فرق',
  suspended: 'موقوف', reversed: 'معكوس', pending: 'قيد الانتظار', submitted: 'مقدم', draft: 'مسودة',
  open: 'مفتوح', closing: 'جارٍ الإقفال', partial: 'جزئي', under_review: 'قيد المراجعة',
  unreconciled: 'غير مطابق', ready: 'جاهز', executed: 'منفذ', prepared: 'مجهز', requested: 'مطلوب',
}

export function StatusBadge({ value }: { value: unknown }) {
  const normalized = String(value ?? 'unknown').toLowerCase()
  const tone = positive.has(normalized) ? 'positive' : negative.has(normalized) ? 'negative' : warning.has(normalized) ? 'warning' : 'neutral'
  return <span className={`status-badge ${tone}`}>{arabic[normalized] ?? String(value ?? 'غير محدد')}</span>
}
