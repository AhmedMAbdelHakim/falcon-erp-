import type { LucideIcon } from 'lucide-react'
import {
  Archive, BadgeDollarSign, BookOpen, Boxes, BriefcaseBusiness, Building2, ClipboardCheck,
  ClipboardList, Contact, FileClock, FileSearch, Gauge, HandCoins, Landmark, PackageCheck,
  PackageOpen, Printer, Receipt, RotateCcw, Settings, ShieldCheck, ShoppingBag, Truck,
  UserRoundCog, Users, WalletCards,
} from 'lucide-react'

export interface NavigationItem {
  label: string
  path: string
  icon: LucideIcon
  permissions: readonly string[]
}

export interface NavigationGroup {
  label: string
  items: readonly NavigationItem[]
}

export const navigation: readonly NavigationGroup[] = [
  {
    label: 'نظرة عامة',
    items: [
      { label: 'لوحة المتابعة', path: '/dashboard', icon: Gauge, permissions: ['ledger.read', 'orders.read', 'wallets.read_summary'] },
      { label: 'الموافقات', path: '/approvals', icon: ClipboardCheck, permissions: ['orders.read', 'payments.review', 'partner_withdrawals.approve', 'accounting.close_period'] },
    ],
  },
  {
    label: 'المبيعات والعملاء',
    items: [
      { label: 'العملاء', path: '/customers', icon: Users, permissions: ['customers.read'] },
      { label: 'الأوردرات', path: '/orders', icon: ShoppingBag, permissions: ['orders.read'] },
      { label: 'المدفوعات', path: '/payments', icon: Receipt, permissions: ['payments.record', 'payments.review'] },
      { label: 'المرتجعات المالية', path: '/refunds', icon: RotateCcw, permissions: ['refunds.request', 'refunds.approve', 'refunds.execute'] },
    ],
  },
  {
    label: 'التنفيذ والتوريد',
    items: [
      { label: 'دفعات الطباعة', path: '/printing/batches', icon: Printer, permissions: ['print_batches.create', 'print_batches.receive', 'print_batches.close'] },
      { label: 'الموردون', path: '/suppliers', icon: Building2, permissions: ['supplier_invoices.create', 'supplier_invoices.approve', 'orders.read'] },
      { label: 'المخزون', path: '/inventory', icon: Boxes, permissions: ['print_batches.create', 'shipments.create', 'orders.read'] },
      { label: 'الشحنات', path: '/shipping/shipments', icon: Truck, permissions: ['shipments.create', 'shipments.update', 'orders.read'] },
      { label: 'تسويات الشحن', path: '/shipping/settlements', icon: PackageCheck, permissions: ['courier_settlements.prepare', 'courier_settlements.approve', 'orders.read'] },
    ],
  },
  {
    label: 'المالية',
    items: [
      { label: 'المحافظ والسيولة', path: '/finance/wallets', icon: WalletCards, permissions: ['wallets.read_summary', 'ledger.read'] },
      { label: 'المصروفات', path: '/finance/expenses', icon: BadgeDollarSign, permissions: ['expenses.create', 'expenses.approve', 'expenses.pay'] },
      { label: 'دفتر الأستاذ', path: '/finance/ledger', icon: BookOpen, permissions: ['ledger.read'] },
      { label: 'الإقفال الشهري', path: '/finance/monthly-close', icon: FileClock, permissions: ['ledger.read'] },
      { label: 'التقارير', path: '/reports', icon: FileSearch, permissions: ['ledger.read', 'wallets.read_summary'] },
    ],
  },
  {
    label: 'الفريق والشركاء',
    items: [
      { label: 'الموظفون', path: '/employees', icon: Contact, permissions: ['payroll.read_all', 'payroll.read_own_scope'] },
      { label: 'الرواتب', path: '/payroll', icon: BriefcaseBusiness, permissions: ['payroll.read_all', 'payroll.read_own_scope'] },
      { label: 'الشركاء', path: '/partners', icon: HandCoins, permissions: ['partner_withdrawals.request', 'partner_withdrawals.approve', 'ledger.read'] },
    ],
  },
  {
    label: 'الرقابة والأدوات',
    items: [
      { label: 'سجل التدقيق', path: '/audit', icon: ShieldCheck, permissions: ['audit.read'] },
      { label: 'بوالص الشحن', path: '/legacy/labels', icon: Archive, permissions: ['shipping_labels.read'] },
      { label: 'إعدادات البوالص', path: '/legacy/settings', icon: PackageOpen, permissions: ['shipping_settings.read'] },
      { label: 'إعدادات النظام', path: '/settings', icon: Settings, permissions: ['audit.read', 'shipping_settings.manage'] },
      { label: 'الحساب والصلاحيات', path: '/access', icon: UserRoundCog, permissions: ['customers.read', 'orders.read', 'ledger.read', 'audit.read'] },
      { label: 'مراكز المخزون', path: '/inventory/locations', icon: Landmark, permissions: ['orders.read'] },
      { label: 'حركات المخزون', path: '/inventory/movements', icon: ClipboardList, permissions: ['orders.read'] },
    ],
  },
]
