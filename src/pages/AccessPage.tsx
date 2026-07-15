import { useEffect, useMemo, useState } from 'react'
import { KeyRound, RefreshCw, Save, ShieldCheck, UserRound, UsersRound } from 'lucide-react'
import { PageHeader } from '../components/ui/PageHeader'
import { PageState } from '../components/ui/PageState'
import { useAuth } from '../context/AuthContext'
import { useToast } from '../context/ToastContext'
import { formatDate } from '../lib/format'
import { supabase } from '../lib/supabase'

type AccessRole = {
  role_id: string
  role_key: string
  display_name: string
  description: string | null
  permission_count: number
}

type AccessUser = {
  user_id: string
  email: string
  display_name: string
  profile_status: string
  role_keys: string[]
  permission_count: number
  updated_at: string
}

const roleLabels: Record<string, string> = {
  super_admin: 'مدير النظام',
  finance_manager: 'مدير مالي',
  operations: 'تشغيل ومخزون',
  moderator: 'مودريتور',
  auditor: 'مراجع',
  partner: 'شريك',
  read_only: 'مشاهدة فقط',
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error && 'message' in error) return String(error.message)
  return 'تعذر تنفيذ العملية.'
}

export function AccessPage() {
  const { access, hasRole, refreshAccess } = useAuth()
  const { showToast } = useToast()
  const [roles, setRoles] = useState<AccessRole[]>([])
  const [users, setUsers] = useState<AccessUser[]>([])
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null)
  const [draftRoles, setDraftRoles] = useState<string[]>([])
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [loadError, setLoadError] = useState<string | null>(null)

  const isSuperAdmin = hasRole('super_admin')
  const selectedUser = users.find((user) => user.user_id === selectedUserId) ?? users[0] ?? null

  const roleOptions = useMemo(
    () => roles.filter((role) => role.role_key !== 'partner').sort((a, b) => a.role_key.localeCompare(b.role_key)),
    [roles],
  )

  async function loadManagement() {
    if (!access?.organization_id || !isSuperAdmin) return
    setLoading(true)
    setLoadError(null)
    try {
      const client = supabase.schema('api') as any
      const [roleResult, userResult] = await Promise.all([
        client.rpc('list_access_roles', { p_organization_id: access.organization_id }),
        client.rpc('list_access_users', { p_organization_id: access.organization_id }),
      ])
      if (roleResult.error) throw roleResult.error
      if (userResult.error) throw userResult.error
      const nextRoles = roleResult.data as AccessRole[]
      const nextUsers = userResult.data as AccessUser[]
      setRoles(nextRoles)
      setUsers(nextUsers)
      const nextSelected = selectedUserId && nextUsers.some((user) => user.user_id === selectedUserId)
        ? selectedUserId
        : nextUsers[0]?.user_id ?? null
      setSelectedUserId(nextSelected)
      setDraftRoles(nextUsers.find((user) => user.user_id === nextSelected)?.role_keys ?? [])
    } catch (error) {
      setLoadError(errorMessage(error))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    void loadManagement()
  }, [access?.organization_id, isSuperAdmin])

  useEffect(() => {
    if (selectedUser) setDraftRoles(selectedUser.role_keys)
  }, [selectedUser?.user_id])

  function toggleRole(roleKey: string) {
    setDraftRoles((current) => (
      current.includes(roleKey)
        ? current.filter((key) => key !== roleKey)
        : [...current, roleKey].sort()
    ))
  }

  async function saveRoles() {
    if (!access?.organization_id || !selectedUser) return
    setSaving(true)
    try {
      const client = supabase.schema('api') as any
      const { error } = await client.rpc('update_user_roles', {
        p_organization_id: access.organization_id,
        p_user_id: selectedUser.user_id,
        p_role_keys: draftRoles,
      })
      if (error) throw error
      showToast('تم تحديث صلاحيات المستخدم.', 'success')
      await loadManagement()
      if (selectedUser.user_id === access.user_id) await refreshAccess()
    } catch (error) {
      showToast(errorMessage(error), 'error')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="page">
      <PageHeader
        title="الحساب والصلاحيات"
        description="الأدوار والصلاحيات هنا صادرة من قاعدة البيانات مباشرة. السوبر أدمن فقط يقدر يعدل أدوار الفريق."
        actions={isSuperAdmin ? (
          <button className="button secondary" type="button" onClick={loadManagement} disabled={loading}>
            <RefreshCw size={16} aria-hidden="true" />
            تحديث
          </button>
        ) : null}
      />

      <div className="content-grid">
        <section className="panel">
          <header className="panel-header">
            <h2>هوية العمل</h2>
            <UserRound size={18} aria-hidden="true" />
          </header>
          <div className="panel-body">
            <dl className="definition-list">
              <div><dt>الاسم</dt><dd>{access?.display_name}</dd></div>
              <div><dt>المؤسسة</dt><dd>{access?.organization_name}</dd></div>
              <div><dt>الكود</dt><dd>{access?.organization_code}</dd></div>
              <div><dt>العملة</dt><dd>{access?.currency_code}</dd></div>
              <div><dt>المنطقة الزمنية</dt><dd>{access?.timezone_name}</dd></div>
              <div><dt>آخر تحقق</dt><dd>{formatDate(access?.generated_at, true)}</dd></div>
            </dl>
          </div>
        </section>

        <section className="panel">
          <header className="panel-header">
            <h2>أدواري الحالية</h2>
            <ShieldCheck size={18} aria-hidden="true" />
          </header>
          <div className="panel-body">
            <h3 className="compact-title"><KeyRound size={16} aria-hidden="true" />الأدوار</h3>
            <div className="chip-list">{access?.role_keys.map((role) => <span key={role}>{roleLabels[role] ?? role}</span>)}</div>
            <h3 className="compact-title">الصلاحيات</h3>
            <div className="chip-list">{access?.permission_keys.map((permission) => <span key={permission}>{permission}</span>)}</div>
          </div>
        </section>
      </div>

      {isSuperAdmin ? (
        <section className="panel access-manager-panel">
          <header className="panel-header">
            <h2>إدارة أعضاء الفريق</h2>
            <UsersRound size={18} aria-hidden="true" />
          </header>
          <div className="panel-body">
            {loading ? <PageState kind="loading" /> : null}
            {loadError ? <PageState kind="error" message={loadError} onRetry={loadManagement} /> : null}
            {!loading && !loadError ? (
              <div className="access-manager">
                <div className="access-user-list" aria-label="أعضاء الفريق">
                  {users.map((user) => (
                    <button
                      key={user.user_id}
                      className={user.user_id === selectedUser?.user_id ? 'active' : ''}
                      type="button"
                      onClick={() => setSelectedUserId(user.user_id)}
                    >
                      <strong>{user.display_name}</strong>
                      <span>{user.email}</span>
                      <small>{user.role_keys.map((role) => roleLabels[role] ?? role).join('، ') || 'بدون دور'}</small>
                    </button>
                  ))}
                </div>

                {selectedUser ? (
                  <div className="access-editor">
                    <div className="access-editor-heading">
                      <div>
                        <h3>{selectedUser.display_name}</h3>
                        <p>{selectedUser.email}</p>
                      </div>
                      <span className="status-badge positive">{selectedUser.profile_status}</span>
                    </div>

                    <div className="role-grid">
                      {roleOptions.map((role) => (
                        <label key={role.role_id} className="role-option">
                          <input
                            type="checkbox"
                            checked={draftRoles.includes(role.role_key)}
                            onChange={() => toggleRole(role.role_key)}
                          />
                          <span>
                            <strong>{roleLabels[role.role_key] ?? role.display_name}</strong>
                            <small>{role.permission_count} صلاحية</small>
                          </span>
                        </label>
                      ))}
                    </div>

                    <div className="access-editor-actions">
                      <button className="button primary" type="button" onClick={saveRoles} disabled={saving || draftRoles.length === 0}>
                        <Save size={16} aria-hidden="true" />
                        حفظ الصلاحيات
                      </button>
                      <button className="button secondary" type="button" onClick={() => setDraftRoles(selectedUser.role_keys)} disabled={saving}>
                        إلغاء التعديل
                      </button>
                    </div>
                  </div>
                ) : (
                  <PageState kind="empty" title="لا يوجد أعضاء" message="لا يوجد مستخدمون قابلون للإدارة في هذه المؤسسة." />
                )}
              </div>
            ) : null}
          </div>
        </section>
      ) : null}
    </div>
  )
}
