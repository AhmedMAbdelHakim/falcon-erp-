import { useCallback, useEffect, useState } from 'react'
import { RefreshCw } from 'lucide-react'
import { DataTable, type DataRow } from '../components/ui/DataTable'
import { PageHeader } from '../components/ui/PageHeader'
import { PageState } from '../components/ui/PageState'
import { useAuth } from '../context/AuthContext'
import { readMonthlyCloses, type MonthlyCloseRow } from '../server/queries/read-models'
import { WorkflowActions } from '../components/WorkflowActions'

const columns = [
  { key: 'period_start', label: 'بداية الفترة', kind: 'date' as const }, { key: 'period_end', label: 'نهاية الفترة', kind: 'date' as const },
  { key: 'closing_status', label: 'دورة الإقفال', kind: 'status' as const }, { key: 'period_status', label: 'الفترة', kind: 'status' as const }, { key: 'approval_status', label: 'الموافقة', kind: 'status' as const },
  { key: 'period_revenue_minor', label: 'الإيراد', kind: 'money' as const }, { key: 'period_expense_minor', label: 'المصروف', kind: 'money' as const }, { key: 'period_profit_loss_minor', label: 'النتيجة', kind: 'money' as const },
  { key: 'trial_balance_debit_minor', label: 'ميزان مدين', kind: 'money' as const }, { key: 'trial_balance_credit_minor', label: 'ميزان دائن', kind: 'money' as const },
]
export function MonthlyClosePage() {
  const { access } = useAuth(); const [rows, setRows] = useState<MonthlyCloseRow[]>([]); const [loading, setLoading] = useState(true); const [error, setError] = useState<string | null>(null)
  const load = useCallback(async () => { if (!access) return; setLoading(true); setError(null); try { setRows(await readMonthlyCloses(access.organization_id)) } catch (caught) { setError(caught instanceof Error ? caught.message : 'تعذر تحميل دورات الإقفال') } finally { setLoading(false) } }, [access])
  useEffect(() => { void load() }, [load])
  return <div className="page"><PageHeader title="الإقفال الشهري" description="حالة التنفيذ، التحقق، الموافقة، وميزان المراجعة لكل فترة. أوامر الإقفال الحساسة لا تظهر إلا لأصحاب الصلاحية." actions={<><WorkflowActions resourceKey="monthlyClose" onComplete={() => void load()} /><button className="button secondary" type="button" onClick={() => void load()}><RefreshCw size={16} />تحديث</button></>} />
    {loading ? <PageState kind="loading" /> : error ? <PageState kind="error" message={error} onRetry={() => void load()} /> : rows.length === 0 ? <PageState kind="empty" title="لم تبدأ دورة إقفال بعد" /> : <DataTable columns={columns} rows={rows as unknown as DataRow[]} page={0} pageSize={36} total={rows.length} onPageChange={() => undefined} />}
  </div>
}
