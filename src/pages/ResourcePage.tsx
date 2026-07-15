import { useCallback, useEffect, useState } from 'react'
import { RefreshCw, Search } from 'lucide-react'
import { useAuth } from '../context/AuthContext'
import { resourceCatalog } from '../features/resources/catalog'
import { readResource } from '../server/queries/resources'
import { DataTable, type DataRow } from '../components/ui/DataTable'
import { PageHeader } from '../components/ui/PageHeader'
import { PageState } from '../components/ui/PageState'
import { WorkflowActions } from '../components/WorkflowActions'

const PAGE_SIZE = 25

export function ResourcePage({ resourceKey }: { resourceKey: string }) {
  const config = resourceCatalog[resourceKey]
  const { access, hasAnyPermission } = useAuth()
  const [rows, setRows] = useState<DataRow[]>([])
  const [count, setCount] = useState<number | null>(null)
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const [appliedSearch, setAppliedSearch] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

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

  return (
    <div className="page">
      <PageHeader title={config.title} description={config.description} eyebrow="بيانات مباشرة من Falcon" actions={<>
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
      </form>
      {loading ? <PageState kind="loading" /> : error ? <PageState kind="error" message={error} onRetry={() => void load()} /> : rows.length === 0 ? <PageState kind="empty" /> : (
        <DataTable columns={config.columns} rows={rows} page={page} pageSize={PAGE_SIZE} total={count} onPageChange={setPage} />
      )}
    </div>
  )
}
