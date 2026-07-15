import { useCallback, useEffect, useState } from 'react'
import { RefreshCw } from 'lucide-react'
import { DataTable, type DataRow } from '../components/ui/DataTable'
import { PageHeader } from '../components/ui/PageHeader'
import { PageState } from '../components/ui/PageState'
import { useAuth } from '../context/AuthContext'
import { cairoPeriod, readJournal, type JournalEntryRow } from '../server/queries/read-models'
import { WorkflowActions } from '../components/WorkflowActions'

const columns = [
  { key: 'entry_number', label: 'رقم القيد', kind: 'number' as const }, { key: 'accounting_date', label: 'التاريخ', kind: 'date' as const },
  { key: 'description', label: 'البيان' }, { key: 'source_type', label: 'المصدر' }, { key: 'status', label: 'الحالة', kind: 'status' as const },
  { key: 'total_debit_minor', label: 'مدين', kind: 'money' as const }, { key: 'total_credit_minor', label: 'دائن', kind: 'money' as const },
  { key: 'posted_at', label: 'وقت الترحيل', kind: 'datetime' as const },
]
export function LedgerPage() {
  const { access } = useAuth(); const initial = cairoPeriod()
  const [start, setStart] = useState(initial.start); const [end, setEnd] = useState(initial.end)
  const [rows, setRows] = useState<JournalEntryRow[]>([]); const [loading, setLoading] = useState(true); const [error, setError] = useState<string | null>(null)
  const load = useCallback(async () => { if (!access) return; setLoading(true); setError(null); try { setRows(await readJournal(access.organization_id, start, end)) } catch (caught) { setError(caught instanceof Error ? caught.message : 'تعذر تحميل القيود') } finally { setLoading(false) } }, [access, end, start])
  useEffect(() => { void load() }, [load])
  return <div className="page"><PageHeader title="دفتر الأستاذ" description="القيود المرحلة والقابلة للتتبع. التصحيح يتم بعكس معتمد وليس بتعديل القيد." actions={<><WorkflowActions resourceKey="ledger" onComplete={() => void load()} /><button className="button secondary" type="button" onClick={() => void load()}><RefreshCw size={16} />تحديث</button></>} />
    <div className="toolbar"><div className="toolbar-group"><label>من <input className="field" type="date" value={start} onChange={(event) => setStart(event.target.value)} /></label><label>إلى <input className="field" type="date" value={end} onChange={(event) => setEnd(event.target.value)} /></label></div><span className="environment-pill">{rows.length} قيد</span></div>
    {loading ? <PageState kind="loading" /> : error ? <PageState kind="error" message={error} onRetry={() => void load()} /> : rows.length === 0 ? <PageState kind="empty" /> : <DataTable columns={columns} rows={rows as unknown as DataRow[]} page={0} pageSize={100} total={rows.length} onPageChange={() => undefined} />}
  </div>
}
