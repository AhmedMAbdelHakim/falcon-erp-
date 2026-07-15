import { useCallback, useEffect, useState } from 'react'
import { RefreshCw } from 'lucide-react'
import { DataTable, type DataRow } from '../components/ui/DataTable'
import { PageHeader } from '../components/ui/PageHeader'
import { PageState } from '../components/ui/PageState'
import { useAuth } from '../context/AuthContext'
import { cairoPeriod, readFinancialReports, type LiquidityRow, type ProfitAndLossRow, type TrialBalanceRow } from '../server/queries/read-models'

export function ReportsPage() {
  const { access } = useAuth()
  const initial = cairoPeriod()
  const [start, setStart] = useState(initial.start)
  const [end, setEnd] = useState(initial.end)
  const [tab, setTab] = useState<'pl' | 'trial' | 'liquidity'>('pl')
  const [data, setData] = useState<{ profitLoss: ProfitAndLossRow[]; trialBalance: TrialBalanceRow[]; liquidity: LiquidityRow[] } | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    if (!access) return
    setLoading(true); setError(null)
    try { setData(await readFinancialReports(access.organization_id, start, end)) }
    catch (caught) { setError(caught instanceof Error ? caught.message : 'تعذر تحميل التقارير') }
    finally { setLoading(false) }
  }, [access, end, start])
  useEffect(() => { void load() }, [load])

  const configs = {
    pl: { rows: data?.profitLoss ?? [], columns: [
      { key: 'month_start', label: 'الشهر', kind: 'date' as const }, { key: 'period_status', label: 'حالة الفترة', kind: 'status' as const },
      { key: 'gross_revenue_minor', label: 'إجمالي الإيراد', kind: 'money' as const }, { key: 'contra_revenue_minor', label: 'مردودات وخصومات', kind: 'money' as const },
      { key: 'net_revenue_minor', label: 'صافي الإيراد', kind: 'money' as const }, { key: 'expense_minor', label: 'المصروفات', kind: 'money' as const }, { key: 'profit_loss_minor', label: 'النتيجة', kind: 'money' as const },
    ] },
    trial: { rows: data?.trialBalance ?? [], columns: [
      { key: 'account_code', label: 'الحساب' }, { key: 'account_name', label: 'اسم الحساب' }, { key: 'account_type', label: 'النوع' },
      { key: 'opening_debit_minor', label: 'افتتاحي مدين', kind: 'money' as const }, { key: 'opening_credit_minor', label: 'افتتاحي دائن', kind: 'money' as const },
      { key: 'period_debit_minor', label: 'حركة مدين', kind: 'money' as const }, { key: 'period_credit_minor', label: 'حركة دائن', kind: 'money' as const },
      { key: 'closing_debit_minor', label: 'ختامي مدين', kind: 'money' as const }, { key: 'closing_credit_minor', label: 'ختامي دائن', kind: 'money' as const },
    ] },
    liquidity: { rows: data?.liquidity ?? [], columns: [
      { key: 'wallet_code', label: 'الكود' }, { key: 'wallet_name', label: 'المحفظة' }, { key: 'provider', label: 'المزود' },
      { key: 'book_balance_minor', label: 'الرصيد الدفتري', kind: 'money' as const }, { key: 'physical_balance_minor', label: 'الرصيد الفعلي', kind: 'money' as const },
      { key: 'difference_minor', label: 'الفرق', kind: 'money' as const }, { key: 'reconciliation_status', label: 'المطابقة', kind: 'status' as const },
    ] },
  }
  const current = configs[tab]
  return <div className="page"><PageHeader title="التقارير المالية" description="تقارير موثوقة مشتقة من دفتر الأستاذ وعقود القراءة المعتمدة." actions={<button className="button secondary" type="button" onClick={() => void load()}><RefreshCw size={16} />تحديث</button>} />
    <div className="toolbar"><div className="toolbar-group"><label>من <input className="field" type="date" value={start} onChange={(event) => setStart(event.target.value)} /></label><label>إلى <input className="field" type="date" value={end} onChange={(event) => setEnd(event.target.value)} /></label></div><div className="segmented" aria-label="نوع التقرير"><button className={tab === 'pl' ? 'active' : ''} onClick={() => setTab('pl')}>الأرباح والخسائر</button><button className={tab === 'trial' ? 'active' : ''} onClick={() => setTab('trial')}>ميزان المراجعة</button><button className={tab === 'liquidity' ? 'active' : ''} onClick={() => setTab('liquidity')}>السيولة</button></div></div>
    {loading ? <PageState kind="loading" /> : error ? <PageState kind="error" message={error} onRetry={() => void load()} /> : current.rows.length === 0 ? <PageState kind="empty" /> : <DataTable columns={current.columns} rows={current.rows as unknown as DataRow[]} page={0} pageSize={current.rows.length} total={current.rows.length} onPageChange={() => undefined} />}
  </div>
}
