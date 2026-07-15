import type { ReactNode } from 'react'
import { ChevronLeft, ChevronRight } from 'lucide-react'
import { formatValue } from '../../lib/format'
import { FinancialAmount } from './FinancialAmount'
import { StatusBadge } from './StatusBadge'

export type DataRow = Record<string, unknown>

export interface DataColumn {
  key: string
  label: string
  kind?: 'text' | 'money' | 'status' | 'date' | 'datetime' | 'number'
  render?: (value: unknown, row: DataRow) => ReactNode
}

interface DataTableProps {
  columns: readonly DataColumn[]
  rows: readonly DataRow[]
  page: number
  pageSize: number
  total: number | null
  onPageChange: (page: number) => void
  rowLabel?: (row: DataRow) => string
}

function Cell({ column, row }: { column: DataColumn; row: DataRow }) {
  const value = row[column.key]
  if (column.render) return column.render(value, row)
  if (column.kind === 'money') return <FinancialAmount value={value as string | number | bigint | null} />
  if (column.kind === 'status') return <StatusBadge value={value} />
  return formatValue(value, column.kind === 'datetime' ? `${column.key}_at` : column.key)
}

export function DataTable({ columns, rows, page, pageSize, total, onPageChange, rowLabel }: DataTableProps) {
  const hasNext = total === null ? rows.length === pageSize : (page + 1) * pageSize < total
  return (
    <div className="table-shell">
      <div className="table-scroll" tabIndex={0} aria-label="جدول بيانات قابل للتمرير">
        <table>
          <thead>
            <tr>{columns.map((column) => <th key={column.key} scope="col">{column.label}</th>)}</tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr key={String(row.id ?? row.order_id ?? row.settlement_id ?? `${page}-${index}`)} aria-label={rowLabel?.(row)}>
                {columns.map((column) => <td key={column.key}><Cell column={column} row={row} /></td>)}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <footer className="table-pagination" aria-label="التنقل بين صفحات الجدول">
        <span>{total === null ? `صفحة ${page + 1}` : `${Math.min(page * pageSize + 1, total)}-${Math.min((page + 1) * pageSize, total)} من ${total}`}</span>
        <div>
          <button type="button" className="icon-button" onClick={() => onPageChange(page - 1)} disabled={page === 0} aria-label="الصفحة السابقة" title="الصفحة السابقة"><ChevronRight size={18} /></button>
          <button type="button" className="icon-button" onClick={() => onPageChange(page + 1)} disabled={!hasNext} aria-label="الصفحة التالية" title="الصفحة التالية"><ChevronLeft size={18} /></button>
        </div>
      </footer>
    </div>
  )
}
