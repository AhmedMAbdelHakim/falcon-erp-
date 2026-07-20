import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Edit2, Plus, RefreshCw, Save, Search, Wand2, X } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { resourceCatalog, type EditableField } from '../features/resources/catalog'
import { readResource } from '../server/queries/resources'
import { DataTable, type DataColumn, type DataRow } from '../components/ui/DataTable'
import { PageHeader } from '../components/ui/PageHeader'
import { PageState } from '../components/ui/PageState'
import { WorkflowActions } from '../components/WorkflowActions'
import { supabase } from '../lib/supabase'
import { useToast } from '../context/ToastContext'

const PAGE_SIZE = 25
const tablesWithUpdatedBy = new Set(['customers', 'inventory_locations', 'expense_categories', 'employees', 'partners'])

export function ResourcePage({ resourceKey }: { resourceKey: string }) {
  const config = resourceCatalog[resourceKey]
  const { access, hasAnyPermission, hasPermission } = useAuth()
  const { showToast } = useToast()
  const dialog = useRef<HTMLDialogElement>(null)
  const [rows, setRows] = useState<DataRow[]>([])
  const [count, setCount] = useState<number | null>(null)
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const [appliedSearch, setAppliedSearch] = useState('')
  const [editingRow, setEditingRow] = useState<DataRow | null>(null)
  const [saving, setSaving] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const editable = config?.editable
  const canCreate = Boolean(editable && hasPermission(editable.createPermission))
  const canUpdate = Boolean(editable && hasPermission(editable.updatePermission))
  const canEdit = canCreate || canUpdate

  const tableColumns = useMemo<readonly DataColumn[]>(() => {
    if (!config || !canUpdate) return config?.columns ?? []
    return [
      ...config.columns,
      {
        key: '__actions',
        label: 'إجراء',
        render: (_value, row) => (
          <button className="button secondary compact-button" type="button" onClick={() => openEdit(row)}>
            <Edit2 size={14} aria-hidden="true" />
            تعديل
          </button>
        ),
      },
    ]
  }, [canUpdate, config])

  const load = useCallback(async () => {
    if (!access || !config) return
    setLoading(true)
    setError(null)
    try {
      const result = await readResource(config, access.organization_id, page, PAGE_SIZE, appliedSearch)
      setRows(result.rows)
      setCount(result.count)
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'فشل تحميل البيانات')
    } finally {
      setLoading(false)
    }
  }, [access, appliedSearch, config, page])

  useEffect(() => { void load() }, [load])

  if (!config) return <PageState kind="error" title="مسار غير معروف" />
  if (!hasAnyPermission(config.permission)) return <PageState kind="denied" />

  function applySearch(event: React.FormEvent) {
    event.preventDefault()
    setPage(0)
    setAppliedSearch(search)
  }

  function clearSearch() {
    setSearch('')
    setAppliedSearch('')
    setPage(0)
  }

  function openCreate() {
    setEditingRow(null)
    dialog.current?.showModal()
  }

  function openEdit(row: DataRow) {
    setEditingRow(row)
    dialog.current?.showModal()
  }

  function closeDialog() {
    if (!saving) dialog.current?.close()
  }

  async function saveRecord(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!editable || !access) return
    setSaving(true)
    try {
      const values: Record<string, unknown> = { organization_id: access.organization_id }
      if (!editingRow) values.created_by = access.user_id
      if (tablesWithUpdatedBy.has(editable.table)) values.updated_by = access.user_id

      const form = new FormData(event.currentTarget)
      for (const field of editable.fields) {
        values[field.key] = withSmartDefault(readEditableField(form, field), field, editable.table, editingRow)
      }

      const recordId = editingRow?.[editable.idKey ?? 'id']
      const query = recordId
        ? (supabase.from as any)(editable.table).update(values).eq('organization_id', access.organization_id).eq('id', recordId)
        : (supabase.from as any)(editable.table).insert(values)
      const { error: saveError } = await query
      if (saveError) throw saveError
      showToast(editingRow ? 'تم حفظ التعديل.' : 'تمت الإضافة بنجاح.', 'success')
      closeDialog()
      await load()
    } catch (caught) {
      showToast(caught instanceof Error ? caught.message : 'تعذر حفظ البيانات.', 'error')
    } finally {
      setSaving(false)
    }
  }

  const primaryFields = editable?.fields.filter((field) => isPrimaryField(field, editable.table, Boolean(editingRow))) ?? []
  const optionalFields = editable?.fields.filter((field) => !isPrimaryField(field, editable.table, Boolean(editingRow))) ?? []

  return (
    <div className="page">
      <PageHeader title={config.title} description={config.description} eyebrow="بيانات مباشرة من Falcon" actions={<>
        {canCreate ? <button type="button" className="button primary" onClick={openCreate}><Plus size={16} />إضافة سريعة</button> : null}
        <WorkflowActions resourceKey={resourceKey} onComplete={() => void load()} />
        <button type="button" className="button secondary" onClick={() => void load()}><RefreshCw size={16} />تحديث</button>
      </>} />

      <form className="toolbar" onSubmit={applySearch}>
        <div className="toolbar-group">
          <label className="search-field">
            <Search size={16} aria-hidden="true" />
            <input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="بحث داخل النتائج" aria-label={`بحث في ${config.title}`} />
          </label>
          <button type="submit" className="button secondary">بحث</button>
        </div>
        <span className="environment-pill">{count ?? rows.length} سجل</span>
        {search || appliedSearch ? (
          <button type="button" className="button secondary compact-button" onClick={clearSearch}>
            <X size={14} aria-hidden="true" />
            مسح البحث
          </button>
        ) : null}
      </form>

      {loading ? <PageState kind="loading" /> : error ? <PageState kind="error" message={error} onRetry={() => void load()} /> : rows.length === 0 ? <PageState kind="empty" /> : (
        <DataTable columns={tableColumns} rows={rows} page={page} pageSize={PAGE_SIZE} total={count} onPageChange={setPage} />
      )}

      {editable && canEdit ? (
        <dialog ref={dialog} className="command-dialog" onCancel={(event) => { if (saving) event.preventDefault() }}>
          <form onSubmit={saveRecord}>
            <header>
              <div>
                <span className="eyebrow">{editingRow ? 'تعديل البيانات' : 'إضافة سريعة'}</span>
                <h2>{editingRow ? `تعديل ${config.title}` : `إضافة ${config.title}`}</h2>
              </div>
              <button type="button" className="icon-button" onClick={closeDialog} aria-label="إغلاق" title="إغلاق"><X size={18} /></button>
            </header>

            <div className="quick-entry-note">
              <Wand2 size={16} aria-hidden="true" />
              اكتب المهم فقط. السيستم سيكمل الأكواد والتواريخ والحالات تلقائيًا عند الحفظ.
            </div>

            <div className="command-fields">
              {primaryFields.map((field) => <EditableInput key={field.key} field={field} row={editingRow} optional={!editingRow && !isHardRequired(field, editable.table)} />)}
            </div>

            {optionalFields.length > 0 ? (
              <details className="optional-fields">
                <summary>بيانات إضافية اختيارية</summary>
                <div className="command-fields">
                  {optionalFields.map((field) => <EditableInput key={field.key} field={field} row={editingRow} optional />)}
                </div>
              </details>
            ) : null}

            <footer>
              <button className="button secondary" type="button" onClick={closeDialog} disabled={saving}>إلغاء</button>
              <button className="button primary" type="submit" disabled={saving}>
                <Save size={16} aria-hidden="true" />
                {saving ? 'جاري الحفظ...' : 'حفظ'}
              </button>
            </footer>
          </form>
        </dialog>
      ) : null}
    </div>
  )
}

function EditableInput({ field, row, optional = false }: { field: EditableField; row: DataRow | null; optional?: boolean }) {
  const raw = row?.[field.key]
  const value = raw === null || raw === undefined ? '' : String(raw)
  const required = Boolean(field.required && !optional)
  if (field.kind === 'boolean') {
    return (
      <label className="check-field">
        <input name={field.key} type="checkbox" defaultChecked={Boolean(raw ?? true)} />
        {field.label}
      </label>
    )
  }
  if (field.kind === 'select') {
    return (
      <label>
        <span>{field.label}{required ? '' : ' (اختياري)'}</span>
        <select name={field.key} required={required} defaultValue={value}>
          {!required ? <option value="">تلقائي</option> : null}
          {field.options?.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}
        </select>
      </label>
    )
  }
  return (
    <label>
      <span>{field.label}{required ? '' : ' (اختياري)'}</span>
      <input
        name={field.key}
        type={field.kind === 'number' ? 'number' : field.kind === 'date' ? 'date' : 'text'}
        defaultValue={field.kind === 'date' ? value.slice(0, 10) : value}
        required={required}
        placeholder={placeholderFor(field)}
        dir={field.kind === 'number' || field.key.endsWith('_normalized') ? 'ltr' : 'auto'}
        step="1"
      />
    </label>
  )
}

function readEditableField(form: FormData, field: EditableField): unknown {
  if (field.kind === 'boolean') return form.get(field.key) === 'on'
  const raw = String(form.get(field.key) ?? '').trim()
  if (!raw) return null
  if (field.kind === 'number') {
    const value = Number(raw || 0)
    if (!Number.isSafeInteger(value)) throw new Error(`${field.label}: أدخل رقمًا صحيحًا`)
    return value
  }
  return raw
}

function isPrimaryField(field: EditableField, table: string, editing: boolean) {
  if (editing) return true
  const key = field.key
  if (field.kind === 'boolean') return false
  if (key.includes('notes') || key.includes('reference') || key.includes('normalized') || key.includes('alternate') || key.includes('termination')) return false
  if (key.endsWith('_code') || key.endsWith('_number') || key === 'code' || key === 'employee_no') return false
  if (table === 'wallets') return ['name', 'provider', 'wallet_type'].includes(key)
  if (table === 'inventory_locations') return ['name', 'location_kind'].includes(key)
  if (table === 'employees') return ['full_name', 'employee_kind'].includes(key)
  return key.includes('name') || key === 'full_name' || key === 'display_name'
}

function isHardRequired(field: EditableField, table: string) {
  if (table === 'wallets') return field.key === 'name'
  if (table === 'inventory_locations') return field.key === 'name'
  if (table === 'employees') return field.key === 'full_name'
  return field.key === 'full_name' || field.key === 'display_name' || field.key === 'name'
}

function placeholderFor(field: EditableField) {
  if (field.key.endsWith('_code') || field.key.endsWith('_number') || field.key === 'code' || field.key === 'employee_no') return 'سيتم توليده تلقائيًا'
  if (field.kind === 'date') return 'اليوم تلقائيًا'
  if (field.kind === 'number') return '0 تلقائيًا'
  if (field.key.includes('name')) return 'اكتب الاسم فقط'
  return 'اختياري'
}

function withSmartDefault(value: unknown, field: EditableField, table: string, row: DataRow | null) {
  if (value !== null && value !== undefined && value !== '') return value
  if (row) return null
  const stamp = Date.now().toString(36).toUpperCase().slice(-6)
  if (field.kind === 'number') return 0
  if (field.kind === 'date') return new Date().toISOString().slice(0, 10)
  if (field.kind === 'select') return field.options?.[0]?.value ?? null
  if (field.key === 'is_active' || field.key === 'payroll_enabled') return true
  if (field.key === 'status') return table === 'employees' ? 'active' : 'draft'
  if (field.key === 'customer_number') return `C-${stamp}`
  if (field.key === 'supplier_code') return `S-${stamp}`
  if (field.key === 'partner_code') return `P-${stamp}`
  if (field.key === 'employee_no') return `EMP-${stamp}`
  if (field.key === 'code') return `${table.slice(0, 3).toUpperCase()}-${stamp}`
  if (field.key === 'provider') return 'غير محدد'
  if (field.key === 'registered_owner_name' || field.key === 'economic_owner_name') return 'غير محدد'
  if (field.key === 'display_name' || field.key === 'full_name' || field.key === 'name') return 'بدون اسم'
  return null
}
