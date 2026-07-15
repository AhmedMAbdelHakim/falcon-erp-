import { useMemo, useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { Bell, ChevronLeft, LogOut, Menu, Moon, Search, Sun, X } from 'lucide-react'
import { navigation } from '../config/navigation'
import { useAuth } from '../context/AuthContext'
import { useTheme } from '../context/ThemeContext'
import { useToast } from '../context/ToastContext'

const roleLabels: Record<string, string> = {
  super_admin: 'مدير النظام',
  partner: 'شريك',
  finance_manager: 'مدير مالي',
  operations: 'تشغيل',
  moderator: 'مودريتور',
  auditor: 'مراجع',
  read_only: 'قراءة فقط',
}

export function AppShell() {
  const { access, hasAnyPermission, signOut } = useAuth()
  const { resolved, setMode } = useTheme()
  const { showToast } = useToast()
  const navigate = useNavigate()
  const [open, setOpen] = useState(false)

  const groups = useMemo(() => navigation.map((group) => ({
    ...group,
    items: group.items.filter((item) => hasAnyPermission(item.permissions)),
  })).filter((group) => group.items.length > 0), [hasAnyPermission])

  async function logout() {
    await signOut()
    showToast('تم تسجيل الخروج بأمان.', 'success')
    navigate('/login', { replace: true })
  }

  return (
    <div className="app-shell">
      <a className="skip-link" href="#main-content">تخطي إلى المحتوى</a>
      <header className="mobile-bar">
        <button type="button" className="icon-button" onClick={() => setOpen(true)} aria-label="فتح القائمة"><Menu /></button>
        <strong>Falcon</strong>
        <button type="button" className="icon-button" onClick={() => setMode(resolved === 'dark' ? 'light' : 'dark')} aria-label="تبديل المظهر">{resolved === 'dark' ? <Sun /> : <Moon />}</button>
      </header>

      <aside className={`sidebar${open ? ' open' : ''}`} aria-label="التنقل الرئيسي">
        <div className="sidebar-brand">
          <div className="brand-mark" aria-hidden="true">F</div>
          <div><strong>Falcon</strong><span>المحاسبة والتشغيل</span></div>
          <button type="button" className="icon-button mobile-only" onClick={() => setOpen(false)} aria-label="إغلاق القائمة"><X /></button>
        </div>
        <nav aria-label="التنقل الرئيسي">
          {groups.map((group) => (
            <section key={group.label} className="nav-group">
              <h2>{group.label}</h2>
              {group.items.map((item) => {
                const Icon = item.icon
                return (
                  <NavLink key={item.path} to={item.path} onClick={() => setOpen(false)} className={({ isActive }) => isActive ? 'active' : undefined}>
                    <Icon size={18} aria-hidden="true" />
                    <span>{item.label}</span>
                    <ChevronLeft size={14} className="nav-chevron" aria-hidden="true" />
                  </NavLink>
                )
              })}
            </section>
          ))}
        </nav>
        <div className="sidebar-account">
          <div className="account-avatar" aria-hidden="true">{access?.display_name?.charAt(0) ?? 'F'}</div>
          <div className="account-copy">
            <strong>{access?.display_name ?? 'مستخدم Falcon'}</strong>
            <span>{(access?.role_keys ?? []).map((role) => roleLabels[role] ?? role).join('، ') || 'بدون دور نشط'}</span>
          </div>
          <button type="button" className="icon-button" onClick={logout} aria-label="تسجيل الخروج" title="تسجيل الخروج"><LogOut size={18} /></button>
        </div>
      </aside>

      {open ? <button className="sidebar-overlay" type="button" onClick={() => setOpen(false)} aria-label="إغلاق القائمة" /> : null}

      <div className="workspace">
        <header className="topbar">
          <div className="global-search" role="search">
            <Search size={17} aria-hidden="true" />
            <input aria-label="بحث سريع" placeholder="بحث في Falcon" disabled title="البحث الشامل غير مفعل في العقد الحالي" />
          </div>
          <div className="topbar-actions">
            <span className="environment-pill">بيئة محلية</span>
            <button type="button" className="icon-button" aria-label="التنبيهات" title="التنبيهات"><Bell size={18} /></button>
            <button type="button" className="icon-button" onClick={() => setMode(resolved === 'dark' ? 'light' : 'dark')} aria-label="تبديل المظهر" title="تبديل المظهر">{resolved === 'dark' ? <Sun size={18} /> : <Moon size={18} />}</button>
          </div>
        </header>
        <main id="main-content" tabIndex={-1}><Outlet /></main>
      </div>
    </div>
  )
}
