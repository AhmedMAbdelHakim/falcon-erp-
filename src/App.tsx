import { lazy, Suspense, type ReactNode } from 'react'
import { BrowserRouter, Navigate, Outlet, Route, Routes, useLocation } from 'react-router-dom'
import { AppShell } from './components/AppShell'
import { PageState } from './components/ui/PageState'
import { AuthProvider, useAuth } from './context/AuthContext'
import { ThemeProvider } from './context/ThemeContext'
import { ToastProvider } from './context/ToastContext'

const AccessPage = lazy(() => import('./pages/AccessPage').then((module) => ({ default: module.AccessPage })))
const AuditPage = lazy(() => import('./pages/AuditPage').then((module) => ({ default: module.AuditPage })))
const BatchPrint = lazy(() => import('./pages/BatchPrint').then((module) => ({ default: module.BatchPrint })))
const CancelledLabels = lazy(() => import('./pages/CancelledLabels').then((module) => ({ default: module.CancelledLabels })))
const CreateLabel = lazy(() => import('./pages/CreateLabel').then((module) => ({ default: module.CreateLabel })))
const Dashboard = lazy(() => import('./pages/Dashboard').then((module) => ({ default: module.Dashboard })))
const LabelsList = lazy(() => import('./pages/LabelsList').then((module) => ({ default: module.LabelsList })))
const LedgerPage = lazy(() => import('./pages/LedgerPage').then((module) => ({ default: module.LedgerPage })))
const Login = lazy(() => import('./pages/Login').then((module) => ({ default: module.Login })))
const MonthlyClosePage = lazy(() => import('./pages/MonthlyClosePage').then((module) => ({ default: module.MonthlyClosePage })))
const ReportsPage = lazy(() => import('./pages/ReportsPage').then((module) => ({ default: module.ReportsPage })))
const ResourcePage = lazy(() => import('./pages/ResourcePage').then((module) => ({ default: module.ResourcePage })))
const Settings = lazy(() => import('./pages/Settings').then((module) => ({ default: module.Settings })))
const SettingsHub = lazy(() => import('./pages/SettingsHub').then((module) => ({ default: module.SettingsHub })))

function ProtectedRoute({ children }: { children?: ReactNode }) {
  const { user, access, loading, accessError } = useAuth()
  const location = useLocation()
  if (loading) return <div className="standalone-state"><PageState kind="loading" title="جارٍ التحقق من جلسة العمل" /></div>
  if (!user) return <Navigate to="/login" replace state={{ from: location.pathname }} />
  if (accessError || !access) return <div className="standalone-state"><PageState kind="denied" title="تعذر فتح مساحة العمل" message={accessError ?? 'لا يوجد دور نشط لهذا الحساب.'} /></div>
  return children ?? <Outlet />
}

function PermissionRoute({ anyOf, children }: { anyOf: readonly string[]; children: ReactNode }) {
  const { hasAnyPermission } = useAuth()
  return hasAnyPermission(anyOf) ? children : <PageState kind="denied" />
}

function Resource({ resourceKey, permissions }: { resourceKey: string; permissions: readonly string[] }) {
  return <PermissionRoute anyOf={permissions}><ResourcePage resourceKey={resourceKey} /></PermissionRoute>
}

const resources = {
  customers: ['customers.read'], orders: ['orders.read'], payments: ['payments.record', 'payments.review'], refunds: ['refunds.request', 'refunds.approve', 'refunds.execute'],
  printBatches: ['print_batches.create', 'print_batches.receive', 'print_batches.close'], suppliers: ['supplier_invoices.create', 'supplier_invoices.approve', 'orders.read'],
  inventory: ['orders.read', 'print_batches.create', 'shipments.create'], inventoryMovements: ['orders.read'], inventoryLocations: ['orders.read'],
  shipments: ['shipments.create', 'shipments.update', 'orders.read'], returns: ['orders.return', 'shipments.update', 'orders.read'], settlements: ['courier_settlements.prepare', 'courier_settlements.approve', 'orders.read'],
  wallets: ['wallets.read_summary', 'ledger.read'], reconciliations: ['wallets.read_summary', 'wallets.reconcile', 'ledger.read'], expenses: ['expenses.create', 'expenses.approve', 'expenses.pay'],
  employees: ['payroll.read_all', 'payroll.read_own_scope'], payroll: ['payroll.read_all', 'payroll.read_own_scope'], performance: ['payroll.read_all', 'payroll.read_own_scope'],
  partners: ['partner_withdrawals.request', 'partner_withdrawals.approve', 'ledger.read'], withdrawals: ['partner_withdrawals.request', 'partner_withdrawals.approve', 'partner_withdrawals.execute'],
  distributions: ['ledger.read', 'profit_distributions.calculate', 'profit_distributions.approve'], approvals: ['orders.read', 'payments.review', 'partner_withdrawals.approve', 'accounting.close_period'],
} as const

export default function App() {
  return <BrowserRouter><ThemeProvider><ToastProvider><AuthProvider><Suspense fallback={<div className="standalone-state"><PageState kind="loading" /></div>}><Routes>
    <Route path="/login" element={<Login />} />
    <Route element={<ProtectedRoute />}>
      <Route element={<AppShell />}>
        <Route index element={<Navigate to="/dashboard" replace />} />
        <Route path="dashboard" element={<Dashboard />} />
        <Route path="customers" element={<Resource resourceKey="customers" permissions={resources.customers} />} />
        <Route path="customers/:id" element={<Resource resourceKey="customers" permissions={resources.customers} />} />
        <Route path="orders" element={<Resource resourceKey="orders" permissions={resources.orders} />} />
        <Route path="orders/new" element={<Resource resourceKey="orders" permissions={resources.orders} />} />
        <Route path="orders/:id" element={<Resource resourceKey="orders" permissions={resources.orders} />} />
        <Route path="orders/:id/edit" element={<Resource resourceKey="orders" permissions={resources.orders} />} />
        <Route path="payments" element={<Resource resourceKey="payments" permissions={resources.payments} />} />
        <Route path="refunds" element={<Resource resourceKey="refunds" permissions={resources.refunds} />} />
        <Route path="printing/batches" element={<Resource resourceKey="printBatches" permissions={resources.printBatches} />} />
        <Route path="printing/batches/new" element={<Resource resourceKey="printBatches" permissions={resources.printBatches} />} />
        <Route path="printing/batches/:id" element={<Resource resourceKey="printBatches" permissions={resources.printBatches} />} />
        <Route path="suppliers" element={<Resource resourceKey="suppliers" permissions={resources.suppliers} />} />
        <Route path="suppliers/:id" element={<Resource resourceKey="suppliers" permissions={resources.suppliers} />} />
        <Route path="inventory" element={<Resource resourceKey="inventory" permissions={resources.inventory} />} />
        <Route path="inventory/movements" element={<Resource resourceKey="inventoryMovements" permissions={resources.inventoryMovements} />} />
        <Route path="inventory/locations" element={<Resource resourceKey="inventoryLocations" permissions={resources.inventoryLocations} />} />
        <Route path="shipping/shipments" element={<Resource resourceKey="shipments" permissions={resources.shipments} />} />
        <Route path="shipping/shipments/:id" element={<Resource resourceKey="shipments" permissions={resources.shipments} />} />
        <Route path="shipping/returns" element={<Resource resourceKey="returns" permissions={resources.returns} />} />
        <Route path="shipping/settlements" element={<Resource resourceKey="settlements" permissions={resources.settlements} />} />
        <Route path="shipping/settlements/:id" element={<Resource resourceKey="settlements" permissions={resources.settlements} />} />
        <Route path="finance/wallets" element={<Resource resourceKey="wallets" permissions={resources.wallets} />} />
        <Route path="finance/wallets/:id" element={<Resource resourceKey="wallets" permissions={resources.wallets} />} />
        <Route path="finance/reconciliations" element={<Resource resourceKey="reconciliations" permissions={resources.reconciliations} />} />
        <Route path="finance/expenses" element={<Resource resourceKey="expenses" permissions={resources.expenses} />} />
        <Route path="finance/ledger" element={<PermissionRoute anyOf={['ledger.read']}><LedgerPage /></PermissionRoute>} />
        <Route path="finance/periods" element={<MonthlyClosePage />} />
        <Route path="finance/monthly-close" element={<PermissionRoute anyOf={['ledger.read']}><MonthlyClosePage /></PermissionRoute>} />
        <Route path="employees" element={<Resource resourceKey="employees" permissions={resources.employees} />} />
        <Route path="employees/:id" element={<Resource resourceKey="employees" permissions={resources.employees} />} />
        <Route path="payroll" element={<Resource resourceKey="payroll" permissions={resources.payroll} />} />
        <Route path="payroll/:id" element={<Resource resourceKey="payroll" permissions={resources.payroll} />} />
        <Route path="performance" element={<Resource resourceKey="performance" permissions={resources.performance} />} />
        <Route path="partners" element={<Resource resourceKey="partners" permissions={resources.partners} />} />
        <Route path="partners/withdrawals" element={<Resource resourceKey="withdrawals" permissions={resources.withdrawals} />} />
        <Route path="partners/profit-distributions" element={<Resource resourceKey="distributions" permissions={resources.distributions} />} />
        <Route path="approvals" element={<Resource resourceKey="approvals" permissions={resources.approvals} />} />
        <Route path="audit" element={<PermissionRoute anyOf={['audit.read']}><AuditPage /></PermissionRoute>} />
        <Route path="reports" element={<PermissionRoute anyOf={['ledger.read', 'wallets.read_summary']}><ReportsPage /></PermissionRoute>} />
        <Route path="access" element={<AccessPage />} />
        <Route path="settings" element={<SettingsHub />} />
        <Route path="legacy/labels" element={<PermissionRoute anyOf={['shipping_labels.read']}><LabelsList /></PermissionRoute>} />
        <Route path="legacy/labels/new" element={<PermissionRoute anyOf={['shipping_labels.create']}><CreateLabel /></PermissionRoute>} />
        <Route path="legacy/labels/edit/:id" element={<PermissionRoute anyOf={['shipping_labels.update']}><CreateLabel /></PermissionRoute>} />
        <Route path="legacy/cancelled" element={<PermissionRoute anyOf={['shipping_labels.read']}><CancelledLabels /></PermissionRoute>} />
        <Route path="legacy/settings" element={<PermissionRoute anyOf={['shipping_settings.read']}><Settings /></PermissionRoute>} />
      </Route>
      <Route path="legacy/labels/batch" element={<PermissionRoute anyOf={['shipping_labels.update']}><BatchPrint /></PermissionRoute>} />
    </Route>
    <Route path="labels/*" element={<Navigate to="/legacy/labels" replace />} />
    <Route path="*" element={<Navigate to="/dashboard" replace />} />
  </Routes></Suspense></AuthProvider></ToastProvider></ThemeProvider></BrowserRouter>
}
