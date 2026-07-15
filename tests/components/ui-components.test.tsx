import '../setup'
import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { DataTable } from '../../src/components/ui/DataTable'
import { PageState } from '../../src/components/ui/PageState'
import { StatusBadge } from '../../src/components/ui/StatusBadge'
import { ThemeProvider, useTheme } from '../../src/context/ThemeContext'
import { formatDate, formatMinor } from '../../src/lib/format'

describe('shared product states', () => {
  it.each([
    ['loading', 'جارٍ تحميل البيانات'], ['empty', 'لا توجد بيانات'],
    ['error', 'تعذر تحميل البيانات'], ['denied', 'غير مصرح'],
  ] as const)('renders the %s state in Arabic', (kind, title) => {
    render(<PageState kind={kind} />)
    expect(screen.getByRole(kind === 'error' ? 'alert' : 'status')).toHaveTextContent(title)
  })

  it('announces retry and calls the handler', () => {
    const retry = vi.fn()
    render(<PageState kind="error" onRetry={retry} />)
    fireEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    expect(retry).toHaveBeenCalledOnce()
  })
})

describe('data table', () => {
  const columns = [{ key: 'name', label: 'الاسم' }, { key: 'amount_minor', label: 'المبلغ', kind: 'money' as const }, { key: 'status', label: 'الحالة', kind: 'status' as const }]
  const rows = [{ id: '1', name: 'طلب تجريبي', amount_minor: 12345, status: 'approved' }]

  it('renders semantic headers, exact money, and status', () => {
    render(<DataTable columns={columns} rows={rows} page={0} pageSize={25} total={1} onPageChange={() => undefined} />)
    expect(screen.getByRole('columnheader', { name: 'المبلغ' })).toBeVisible()
    expect(screen.getByText('١٢٣٫٤٥ ج.م')).toBeVisible()
    expect(screen.getByText('معتمد')).toBeVisible()
  })

  it('disables impossible pagination and advances when available', () => {
    const change = vi.fn()
    const { rerender } = render(<DataTable columns={columns} rows={rows} page={0} pageSize={1} total={1} onPageChange={change} />)
    expect(screen.getByRole('button', { name: 'الصفحة السابقة' })).toBeDisabled()
    expect(screen.getByRole('button', { name: 'الصفحة التالية' })).toBeDisabled()
    rerender(<DataTable columns={columns} rows={rows} page={0} pageSize={1} total={2} onPageChange={change} />)
    fireEvent.click(screen.getByRole('button', { name: 'الصفحة التالية' }))
    expect(change).toHaveBeenCalledWith(1)
  })
})

describe('formatting and themes', () => {
  it('formats signed bigint money without precision loss', () => {
    expect(formatMinor(12345678901234567n)).toBe('١٢٣٬٤٥٦٬٧٨٩٬٠١٢٬٣٤٥٫٦٧ ج.م')
    expect(formatMinor(-5n)).toBe('-٠٫٠٥ ج.م')
  })

  it('formats valid Cairo dates and preserves invalid values', () => {
    expect(formatDate('not-a-date')).toBe('not-a-date')
    expect(formatDate('2026-07-15T00:00:00Z', true)).toContain('٢٠٢٦')
  })

  it('switches and persists the selected theme', () => {
    function Probe() { const { mode, setMode } = useTheme(); return <button onClick={() => setMode('light')}>{mode}</button> }
    render(<ThemeProvider><Probe /></ThemeProvider>)
    fireEvent.click(screen.getByRole('button'))
    expect(screen.getByRole('button')).toHaveTextContent('light')
    expect(localStorage.getItem('falcon-theme')).toBe('light')
  })

  it('classifies positive, negative, and warning statuses', () => {
    const { rerender } = render(<StatusBadge value="approved" />)
    expect(screen.getByText('معتمد')).toHaveClass('positive')
    rerender(<StatusBadge value="rejected" />)
    expect(screen.getByText('مرفوض')).toHaveClass('negative')
    rerender(<StatusBadge value="pending" />)
    expect(screen.getByText('قيد الانتظار')).toHaveClass('warning')
  })
})
