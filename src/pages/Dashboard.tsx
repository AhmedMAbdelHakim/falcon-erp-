import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, Banknote, CircleDollarSign, RefreshCw, ShieldCheck, TrendingUp, WalletCards } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { FinancialAmount } from '../components/ui/FinancialAmount'
import { PageHeader } from '../components/ui/PageHeader'
import { PageState } from '../components/ui/PageState'
import { cairoPeriod, readDashboard, type DashboardSummary } from '../server/queries/read-models'
import { formatDate } from '../lib/format'

export function Dashboard() {
  const { access, hasPermission } = useAuth()
  const [summary, setSummary] = useState<DashboardSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const canReadFinance = hasPermission('ledger.read')

  const load = useCallback(async () => {
    if (!access || !canReadFinance) { setLoading(false); return }
    setLoading(true); setError(null)
    try { const period = cairoPeriod(); setSummary(await readDashboard(access.organization_id, period.start, period.end)) }
    catch (caught) { setError(caught instanceof Error ? caught.message : 'تعذر تحميل الملخص') }
    finally { setLoading(false) }
  }, [access, canReadFinance])

  useEffect(() => { void load() }, [load])

  if (loading) return <div className="page"><PageState kind="loading" /></div>
  if (error) return <div className="page"><PageState kind="error" message={error} onRetry={() => void load()} /></div>

  return <div className="page">
    <PageHeader eyebrow={access?.organization_name} title={`مرحبًا، ${access?.display_name ?? 'مستخدم Falcon'}`} description="ملخص تشغيلي ومالي مباشر حسب صلاحياتك الحالية." actions={<button className="button secondary" type="button" onClick={() => void load()}><RefreshCw size={16} />تحديث</button>} />
    {!canReadFinance ? <PageState kind="empty" title="مساحة العمل التشغيلية جاهزة" message="لا يعرض حسابك قيمًا مالية. استخدم الوحدات المتاحة من قائمة التنقل لتنفيذ مهامك." /> : !summary ? <PageState kind="empty" title="لا توجد حركة مالية للفترة" /> : <>
      <div className="metadata-bar"><span>الفترة: {formatDate(summary.period_start)} إلى {formatDate(summary.period_end)}</span><span>آخر قيد: {formatDate(summary.last_posted_at, true)}</span><span>توليد: {formatDate(summary.generated_at, true)}</span></div>
      <section className="kpi-grid" aria-label="المؤشرات المالية">
        <Kpi label="صافي الإيراد" value={summary.net_revenue_minor} icon={TrendingUp} />
        <Kpi label="المصروفات" value={summary.expense_minor} icon={CircleDollarSign} />
        <Kpi label="الربح أو الخسارة" value={summary.profit_loss_minor} icon={Banknote} />
        <Kpi label="السيولة الآمنة" value={summary.safe_cash_minor} icon={WalletCards} />
      </section>
      <section className="content-grid">
        <div className="panel"><header className="panel-header"><h2>تركيب السيولة</h2><ShieldCheck size={18} /></header><div className="panel-body"><dl className="definition-list">
          <Metric label="الرصيد الدفتري للمحافظ" value={summary.wallet_book_balance_minor} />
          <Metric label="الالتزامات المحمية" value={summary.protected_liabilities_minor} />
          <Metric label="الاحتياطي المحمي" value={summary.protected_reserve_minor} />
          <Metric label="مسحوبات معلقة" value={summary.pending_withdrawals_minor} />
        </dl></div></div>
        <div className="panel"><header className="panel-header"><h2>تنبيهات تتطلب متابعة</h2><AlertTriangle size={18} /></header><div className="panel-body alert-list">
          <Alert label="موافقات مفتوحة" count={summary.open_approval_count} />
          <Alert label="محافظ غير مطابقة" count={summary.unreconciled_wallet_count} />
          <Alert label="أحداث غير مرحلة" count={summary.unposted_event_count} />
          <Alert label="أرصدة مخزون سالبة" count={summary.negative_inventory_count} />
        </div></div>
      </section>
    </>}
  </div>
}

function Kpi({ label, value, icon: Icon }: { label: string; value: number; icon: typeof TrendingUp }) { return <article className="kpi"><div className="kpi-header"><span>{label}</span><span className="kpi-icon"><Icon size={17} /></span></div><strong><FinancialAmount value={value} /></strong><small>من القيود المرحلة فقط</small></article> }
function Metric({ label, value }: { label: string; value: number }) { return <div><dt>{label}</dt><dd><FinancialAmount value={value} /></dd></div> }
function Alert({ label, count }: { label: string; count: number }) { return <div className="alert-row"><span>{label}</span><strong>{count.toLocaleString('ar-EG')}</strong></div> }
