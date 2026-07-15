import '../setup'
import { fireEvent, render, screen, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { AppShell } from '../../src/components/AppShell'
import { WorkflowActions } from '../../src/components/WorkflowActions'

const auth = {
  access: { display_name: 'مستخدم اختبار', role_keys: ['operations'], permission_keys: ['orders.read', 'orders.confirm'], organization_id: '00000000-0000-4000-8000-00000000f001' },
  hasAnyPermission: (permissions: readonly string[]) => permissions.includes('orders.read'),
  hasPermission: (permission: string) => permission === 'orders.confirm',
  signOut: vi.fn(),
}
const toast = { showToast: vi.fn() }

vi.mock('../../src/context/AuthContext', () => ({ useAuth: () => auth }))
vi.mock('../../src/context/ThemeContext', () => ({ useTheme: () => ({ resolved: 'dark', setMode: vi.fn() }) }))
vi.mock('../../src/context/ToastContext', () => ({ useToast: () => toast }))

describe('permission-aware navigation', () => {
  beforeEach(() => { auth.signOut.mockClear(); toast.showToast.mockClear() })

  it('shows permitted navigation and hides financial navigation', () => {
    render(<MemoryRouter initialEntries={['/orders']}><AppShell /></MemoryRouter>)
    expect(screen.getByRole('link', { name: 'الأوردرات' })).toBeVisible()
    expect(screen.queryByRole('link', { name: 'دفتر الأستاذ' })).not.toBeInTheDocument()
    expect(screen.getByRole('navigation', { name: 'التنقل الرئيسي' })).toBeVisible()
  })

  it('opens and closes the mobile navigation controls', () => {
    render(<MemoryRouter><AppShell /></MemoryRouter>)
    fireEvent.click(screen.getByRole('button', { name: 'فتح القائمة' }))
    expect(document.querySelector('.sidebar')).toHaveClass('open')
    const sidebar = screen.getByRole('complementary', { name: 'التنقل الرئيسي' })
    fireEvent.click(within(sidebar).getByRole('button', { name: 'إغلاق القائمة' }))
    expect(document.querySelector('.sidebar')).not.toHaveClass('open')
  })

  it('renders only workflow actions granted by the current permission set', () => {
    render(<WorkflowActions resourceKey="orders" />)
    expect(screen.getByRole('button', { name: 'تأكيد الأوردر' })).toBeVisible()
    expect(screen.queryByRole('button', { name: 'منح خصم' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إلغاء الأوردر' })).not.toBeInTheDocument()
  })

  it('opens an accessible transactional dialog with labelled fields', () => {
    render(<WorkflowActions resourceKey="orders" />)
    fireEvent.click(screen.getByRole('button', { name: 'تأكيد الأوردر' }))
    expect(screen.getByRole('dialog')).toHaveAttribute('open')
    expect(screen.getByRole('heading', { name: 'تأكيد الأوردر' })).toBeVisible()
    expect(screen.getByRole('textbox', { name: 'معرف الأوردر' })).toBeRequired()
    expect(screen.getByRole('spinbutton', { name: 'الإصدار المتوقع' })).toBeRequired()
  })
})
