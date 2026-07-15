import type { ReactNode } from 'react'
import { useAuth } from '../context/AuthContext'
import { PageState } from './ui/PageState'

export function PermissionGuard({ anyOf, children, fallback }: {
  anyOf: readonly string[]
  children: ReactNode
  fallback?: ReactNode
}) {
  const { hasAnyPermission } = useAuth()
  if (!hasAnyPermission(anyOf)) return fallback ?? <PageState kind="denied" />
  return children
}
