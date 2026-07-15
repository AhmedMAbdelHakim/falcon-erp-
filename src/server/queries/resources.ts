import { supabase } from '../../lib/supabase'
import type { DataRow } from '../../components/ui/DataTable'
import type { ResourceConfig } from '../../features/resources/catalog'

export interface ResourceResult {
  rows: DataRow[]
  count: number | null
}

export async function readResource(
  config: ResourceConfig,
  organizationId: string,
  page: number,
  pageSize: number,
  search: string,
): Promise<ResourceResult> {
  const start = page * pageSize
  const end = start + pageSize - 1

  // The catalog source union is generated from Database tables/views. The result is
  // normalized to unknown-key rows only at this shared rendering boundary.
  // Supabase overloads tables and views separately; the catalog intentionally spans
  // both generated unions, so this cast is contained at the rendering-only boundary.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let query = (supabase.from as any)(config.source)
    .select('*', { count: 'exact' })
    .eq('organization_id', organizationId)
    .range(start, end)

  const normalizedSearch = search.trim().replace(/[,%()]/g, ' ')
  if (normalizedSearch && config.searchColumns?.length) {
    query = query.or(config.searchColumns.map((column) => `${column}.ilike.%${normalizedSearch}%`).join(','))
  }

  const { data, error, count } = await query
  if (error) throw error
  return { rows: (data ?? []) as unknown as DataRow[], count }
}
