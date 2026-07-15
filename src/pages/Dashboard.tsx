import { useCallback, useEffect, useMemo, useState } from 'react'
import { NavLink } from 'react-router-dom'
import {
  AlertTriangle,
  Banknote,
  BarChart3,
  CircleDollarSign,
  ClipboardCheck,
  Gauge,
  PackageSearch,
  RefreshCw,
  ShieldCheck,
  ShoppingBag,
  TrendingDown,
  TrendingUp,
  Truck,
  WalletCards,
  type LucideIcon,
} from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { FinancialAmount } from '../components/ui/FinancialAmount'
import { PageHeader } from '../components/ui/PageHeader'
import { PageState } from '../components/ui/PageState'
import { cairoPeriod, readDashboard, type DashboardSummary } from '../server/queries/read-models'
import { formatDate } from '../lib/format'

export function Dashboard() {
  const { access, hasPermission, hasAnyPermission } = useAuth()
  const [summary, setSummary] = useState<DashboardSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const canReadFinance = hasPermission('ledger.read')

  const load = useCallback(async () => {
    if (!access || !canReadFinance) {
      setLoading(false)
      return
    }
    setLoading(true)
    setError(null)
    try {
      const period = cairoPeriod()
      setSummary(await readDashboard(access.organization_id, period.start, period.end))
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'تعذر تحميل ملخص لوحة التحكم')
    } finally {
      setLoading(false)
    }
  }, [access, canReadFinance])

  useEffect(() => { void load() }, [load])

  const healthItems = useMemo(() => buildHealthItems(summary), [summary])
  const quickLinks = useMemo<QuickLinkItem[]>(() => [
    { label: 'الأوردرات', detail: 'متابعة التنفيذ والتحصيل', path: '/orders', icon: ShoppingBag, permissions: ['orders.read'] },
    { label: 'الشحنات', detail: 'حالات الشحن والتسويات', path: '/shipping/shipments', icon: Truck, permissions: ['shipments.create', 'shipments.update', 'orders.read'] },
    { label: 'المخزون', detail: 'الأرصدة والحركات', path: '/inventory', icon: PackageSearch, permissions: ['print_batches.create', 'shipments.create', 'orders.read'] },
    { label: 'الموافقات', detail: 'طلبات تحتاج قرار', path: '/approvals', icon: ClipboardCheck, permissions: ['orders.read', 'payments.review', 'partner_withdrawals.approve', 'accounting.close_period'] },
    { label: 'التقارير', detail: 'أرباح وسيولة وميزان', path: '/reports', icon: BarChart3, permissions: ['ledger.read', 'wallets.read_summary'] },
    { label: 'المحافظ', detail: 'تحصيلات ومطابقة', path: '/finance/wallets', icon: WalletCards, permissions: ['wallets.read_summary', 'ledger.read'] },
  ].filter((item) => hasAnyPermission(item.permissions)), [hasAnyPermission])

  if (loading) return <div className="page"><PageState kind="loading" /></div>
  if (error) return <div className="page"><PageState kind="error" message={error} onRetry={() => void load()} /></div>

  return (
    <div className="page dashboard-page">
      <PageHeader
        eyebrow={access?.organization_name}
        title={`أهلًا، ${access?.display_name ?? 'مستخدم Falcon'}`}
        description="لوحة متابعة سريعة للإحصائيات المالية والتشغيلية والتنبيهات المهمة، مصممة للعمل بسلاسة على الكمبيوتر والتابلت والموبايل."
        actions={<button className="button secondary" type="button" onClick={() => void load()}><RefreshCw size={16} />تحديث</button>}
      />

      {!canReadFinance ? (
        <OperationalHome quickLinks={quickLinks} />
      ) : !summary ? (
        <PageState kind="empty" title="لا توجد حركة مالية للفترة الحالية" message="ابدأ بإضافة العمليات اليومية، وستظهر الإحصائيات هنا تلقائيًا بعد الترحيل." />
      ) : (
        <>
          <section className="dashboard-hero" aria-label="ملخص الأداء">
            <div>
              <span className="eyebrow">الفترة الحالية</span>
              <h2>{formatDate(summary.period_start)} إلى {formatDate(summary.period_end)}</h2>
              <p>آخر قيد: {formatDate(summary.last_posted_at, true)} · آخر مطابقة: {formatDate(summary.last_reconciled_at, true)}</p>
            </div>
            <div className="hero-balance">
              <span>السيولة الآمنة</span>
              <strong><FinancialAmount value={summary.safe_cash_minor} /></strong>
            </div>
          </section>

          <section className="kpi-grid dashboard-kpis" aria-label="الإحصائيات الرئيسية">
            <Kpi label="إجمالي الإيراد" value={summary.gross_revenue_minor} icon={TrendingUp} tone="positive" />
            <Kpi label="خصومات ومردودات" value={summary.contra_revenue_minor} icon={TrendingDown} tone="warning" />
            <Kpi label="صافي الإيراد" value={summary.net_revenue_minor} icon={Gauge} tone="positive" />
            <Kpi label="المصروفات" value={summary.expense_minor} icon={CircleDollarSign} tone="warning" />
            <Kpi label="الربح / الخسارة" value={summary.profit_loss_minor} icon={Banknote} tone={summary.profit_loss_minor >= 0 ? 'positive' : 'danger'} />
            <Kpi label="رصيد المحافظ" value={summary.wallet_book_balance_minor} icon={WalletCards} />
          </section>

          <section className="dashboard-layout">
            <div className="panel">
              <header className="panel-header"><h2>صحة النظام اليوم</h2><ShieldCheck size={18} /></header>
              <div className="panel-body health-grid">
                {healthItems.map((item) => <HealthCard key={item.label} {...item} />)}
              </div>
            </div>

            <div className="panel">
              <header className="panel-header"><h2>تركيب السيولة</h2><WalletCards size={18} /></header>
              <div className="panel-body">
                <dl className="definition-list">
                  <Metric label="الرصيد الدفتري للمحافظ" value={summary.wallet_book_balance_minor} />
                  <Metric label="الالتزامات المحمية" value={summary.protected_liabilities_minor} />
                  <Metric label="الاحتياطي المحمي" value={summary.protected_reserve_minor} />
                  <Metric label="مسحوبات معلقة" value={summary.pending_withdrawals_minor} />
                </dl>
              </div>
            </div>
          </section>

          <section className="panel quick-panel">
            <header className="panel-header"><h2>اختصارات العمل</h2><BarChart3 size={18} /></header>
            <div className="panel-body quick-grid">
              {quickLinks.map((item) => <QuickLink key={item.path} {...item} />)}
            </div>
          </section>

          <div className="metadata-bar">
            <span>توليد التقرير: {formatDate(summary.generated_at, true)}</span>
            <span>العملة: {summary.currency_code}</span>
          </div>
        </>
      )}
    </div>
  )
}

function OperationalHome({ quickLinks }: { quickLinks: QuickLinkItem[] }) {
  return (
    <>
      <PageState kind="empty" title="مساحة العمل جاهزة" message="حسابك لا يعرض أرقامًا مالية. استخدم الاختصارات المتاحة حسب صلاحياتك." />
      <section className="panel quick-panel">
        <header className="panel-header"><h2>الأجزاء المتاحة لك</h2><BarChart3 size={18} /></header>
        <div className="panel-body quick-grid">
          {quickLinks.map((item) => <QuickLink key={item.path} {...item} />)}
        </div>
      </section>
    </>
  )
}

function Kpi({ label, value, icon: Icon, tone = 'neutral' }: { label: string; value: number; icon: LucideIcon; tone?: 'neutral' | 'positive' | 'warning' | 'danger' }) {
  return (
    <article className={`kpi ${tone}`}>
      <div className="kpi-header"><span>{label}</span><span className="kpi-icon"><Icon size={17} /></span></div>
      <strong><FinancialAmount value={value} /></strong>
      <small>من القيود المرحلة فقط</small>
    </article>
  )
}

function Metric({ label, value }: { label: string; value: number }) {
  return <div><dt>{label}</dt><dd><FinancialAmount value={value} /></dd></div>
}

function HealthCard({ label, count, path, icon: Icon }: HealthItem) {
  const clear = count === 0
  return (
    <NavLink to={path} className={`health-card ${clear ? 'clear' : 'attention'}`}>
      <span className="health-icon"><Icon size={18} /></span>
      <span>{label}</span>
      <strong>{count.toLocaleString('ar-EG')}</strong>
    </NavLink>
  )
}

function QuickLink({ label, detail, path, icon: Icon }: QuickLinkItem) {
  return (
    <NavLink to={path} className="quick-link-card">
      <span className="quick-icon"><Icon size={18} /></span>
      <strong>{label}</strong>
      <small>{detail}</small>
    </NavLink>
  )
}

interface HealthItem {
  label: string
  count: number
  path: string
  icon: LucideIcon
}

interface QuickLinkItem {
  label: string
  detail: string
  path: string
  icon: LucideIcon
  permissions: readonly string[]
}

function buildHealthItems(summary: DashboardSummary | null): HealthItem[] {
  return [
    { label: 'موافقات مفتوحة', count: summary?.open_approval_count ?? 0, path: '/approvals', icon: ClipboardCheck },
    { label: 'محافظ غير مطابقة', count: summary?.unreconciled_wallet_count ?? 0, path: '/finance/wallets', icon: WalletCards },
    { label: 'أحداث غير مرحلة', count: summary?.unposted_event_count ?? 0, path: '/audit', icon: AlertTriangle },
    { label: 'أرصدة مخزون سالبة', count: summary?.negative_inventory_count ?? 0, path: '/inventory', icon: PackageSearch },
  ]
}
