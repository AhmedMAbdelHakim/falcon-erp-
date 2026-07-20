import { useCallback, useEffect, useMemo, useState } from 'react'
import { ArrowDownLeft, ArrowUpRight, BookOpen, CalendarDays, RefreshCw } from 'lucide-react'
import { DataTable, type DataRow } from '../components/ui/DataTable'
import { FinancialAmount } from '../components/ui/FinancialAmount'
import { PageHeader } from '../components/ui/PageHeader'
import { PageState } from '../components/ui/PageState'
import { useAuth } from '../context/AuthContext'
import { cairoPeriod, readJournal, type JournalEntryRow } from '../server/queries/read-models'
import { WorkflowActions } from '../components/WorkflowActions'
import { formatDate } from '../lib/format'

const technicalColumns = [
  { key: 'entry_number', label: 'رقم القيد', kind: 'number' as const },
  { key: 'accounting_date', label: 'التاريخ', kind: 'date' as const },
  { key: 'description', label: 'البيان' },
  { key: 'source_type', label: 'المصدر' },
  { key: 'status', label: 'الحالة', kind: 'status' as const },
  { key: 'total_debit_minor', label: 'مدين', kind: 'money' as const },
  { key: 'total_credit_minor', label: 'دائن', kind: 'money' as const },
  { key: 'posted_at', label: 'وقت الترحيل', kind: 'datetime' as const },
]

export function LedgerPage() {
  const { access } = useAuth()
  const initial = cairoPeriod()
  const [start, setStart] = useState(initial.start)
  const [end, setEnd] = useState(initial.end)
  const [rows, setRows] = useState<JournalEntryRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    if (!access) return
    setLoading(true)
    setError(null)
    try {
      setRows(await readJournal(access.organization_id, start, end))
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'تعذر تحميل الكناش')
    } finally {
      setLoading(false)
    }
  }, [access, end, start])

  useEffect(() => { void load() }, [load])

  const summary = useMemo(() => summarizeNotebook(rows), [rows])

  return (
    <div className="page ledger-notebook-page">
      <PageHeader
        title="كناش الحسابات"
        description="عرض مبسط للحسابات اليومية: الداخل، الخارج، قيمة العملية، والبيان. التفاصيل المحاسبية المتقدمة موجودة أسفل الصفحة عند الحاجة."
        eyebrow="حسابات مبسطة"
        actions={<>
          <WorkflowActions resourceKey="ledger" onComplete={() => void load()} />
          <button className="button secondary" type="button" onClick={() => void load()}><RefreshCw size={16} />تحديث</button>
        </>}
      />

      <div className="toolbar notebook-toolbar">
        <div className="toolbar-group">
          <label>من <input className="field" type="date" value={start} onChange={(event) => setStart(event.target.value)} /></label>
          <label>إلى <input className="field" type="date" value={end} onChange={(event) => setEnd(event.target.value)} /></label>
        </div>
        <span className="environment-pill">{rows.length} عملية</span>
      </div>

      {loading ? <PageState kind="loading" /> : error ? <PageState kind="error" message={error} onRetry={() => void load()} /> : rows.length === 0 ? <PageState kind="empty" title="الكناش فاضي في الفترة دي" message="اختار فترة تانية أو ابدأ تسجيل العمليات من الصفحات اليومية." /> : (
        <>
          <section className="notebook-summary" aria-label="ملخص الكناش">
            <NotebookTotal label="داخل" value={summary.incomingMinor} icon={ArrowDownLeft} tone="in" />
            <NotebookTotal label="خارج" value={summary.outgoingMinor} icon={ArrowUpRight} tone="out" />
            <NotebookTotal label="صافي الحركة" value={summary.netMinor} icon={BookOpen} tone={summary.netMinor >= 0 ? 'in' : 'out'} />
            <article className="notebook-total neutral">
              <span className="notebook-total-icon"><CalendarDays size={18} /></span>
              <div><span>الفترة</span><strong>{formatDate(start)} - {formatDate(end)}</strong></div>
            </article>
          </section>

          <section className="notebook-list" aria-label="كناش الحسابات المبسط">
            {rows.map((row) => <NotebookRow key={row.journal_entry_id} row={row} />)}
          </section>

          <details className="advanced-ledger">
            <summary>عرض محاسبي متقدم</summary>
            <DataTable columns={technicalColumns} rows={rows as unknown as DataRow[]} page={0} pageSize={100} total={rows.length} onPageChange={() => undefined} />
          </details>
        </>
      )}
    </div>
  )
}

function NotebookTotal({ label, value, icon: Icon, tone }: { label: string; value: number; icon: typeof BookOpen; tone: 'in' | 'out' | 'neutral' }) {
  return (
    <article className={`notebook-total ${tone}`}>
      <span className="notebook-total-icon"><Icon size={18} /></span>
      <div><span>{label}</span><strong><FinancialAmount value={Math.abs(value)} /></strong></div>
    </article>
  )
}

function NotebookRow({ row }: { row: JournalEntryRow }) {
  const direction = classifyEntry(row)
  const amount = Math.max(Number(row.total_debit_minor ?? 0), Number(row.total_credit_minor ?? 0))
  return (
    <article className={`notebook-row ${direction}`}>
      <div className="notebook-date">
        <span>{formatDate(row.accounting_date)}</span>
        <small>قيد #{row.entry_number}</small>
      </div>
      <div className="notebook-copy">
        <strong>{row.description || labelSource(row.source_type)}</strong>
        <span>{labelSource(row.source_type)} · {labelPurpose(row.posting_purpose)} · {row.status === 'posted' ? 'مرحل' : row.status}</span>
      </div>
      <div className="notebook-money">
        <span>{direction === 'out' ? 'خارج' : direction === 'in' ? 'داخل' : 'حركة'}</span>
        <strong><FinancialAmount value={amount} /></strong>
      </div>
    </article>
  )
}

function summarizeNotebook(rows: JournalEntryRow[]) {
  return rows.reduce((totals, row) => {
    const amount = Math.max(Number(row.total_debit_minor ?? 0), Number(row.total_credit_minor ?? 0))
    const direction = classifyEntry(row)
    if (direction === 'in') totals.incomingMinor += amount
    else if (direction === 'out') totals.outgoingMinor += amount
    return { ...totals, netMinor: totals.incomingMinor - totals.outgoingMinor }
  }, { incomingMinor: 0, outgoingMinor: 0, netMinor: 0 })
}

function classifyEntry(row: JournalEntryRow) {
  const text = `${row.source_type ?? ''} ${row.posting_purpose ?? ''} ${row.description ?? ''}`.toLowerCase()
  if (/(payment|receipt|collection|revenue|delivery|settlement|capital|loan)/.test(text)) return 'in'
  if (/(expense|payroll|refund|withdrawal|supplier|fee|return)/.test(text)) return 'out'
  return 'neutral'
}

function labelSource(value: string | null | undefined) {
  const labels: Record<string, string> = {
    customer_payment: 'تحصيل عميل',
    expense: 'مصروف',
    payroll: 'راتب',
    supplier_invoice: 'مورد',
    supplier_payment: 'سداد مورد',
    refund: 'استرداد',
    partner_withdrawal: 'مسحوب شريك',
    wallet_transfer: 'تحويل محفظة',
    courier_settlement: 'تسوية شحن',
    manual_journal: 'قيد يدوي',
  }
  return labels[String(value ?? '')] ?? String(value ?? 'عملية')
}

function labelPurpose(value: string | null | undefined) {
  const labels: Record<string, string> = {
    original: 'عملية أصلية',
    reversal: 'عكس',
    correction: 'تصحيح',
    adjustment: 'تسوية',
  }
  return labels[String(value ?? '')] ?? String(value ?? 'حركة')
}
