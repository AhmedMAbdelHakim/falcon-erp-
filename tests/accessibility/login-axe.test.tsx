import '../setup'
import axe from 'axe-core'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { expect, it, vi } from 'vitest'
import { Login } from '../../src/pages/Login'

vi.mock('../../src/context/AuthContext', () => ({ useAuth: () => ({ configured: true, signIn: vi.fn(), user: null, loading: false }) }))

it('has no automatically detectable accessibility violations on login', async () => {
  const { container } = render(<MemoryRouter><Login /></MemoryRouter>)
  const result = await axe.run(container, { rules: { 'color-contrast': { enabled: false } } })
  expect(result.violations.map((violation) => violation.id)).toEqual([])
  expect(screen.getByRole('main')).toHaveAttribute('dir', 'rtl')
  expect(screen.getByLabelText('البريد الإلكتروني')).toHaveAttribute('autocomplete', 'username')
  expect(screen.getByLabelText('كلمة المرور')).toHaveAttribute('autocomplete', 'current-password')
})
