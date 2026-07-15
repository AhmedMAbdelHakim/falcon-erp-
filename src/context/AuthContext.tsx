import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { isSupabaseConfigured, supabase } from '../lib/supabase'
import type { Database } from '../types/database.generated'

export type AccessContext = Database['api']['Functions']['read_current_access_context']['Returns'][number]

interface AuthContextValue {
  user: User | null
  session: Session | null
  access: AccessContext | null
  loading: boolean
  accessError: string | null
  configured: boolean
  hasPermission: (permission: string) => boolean
  hasAnyPermission: (permissions: readonly string[]) => boolean
  hasRole: (role: string) => boolean
  refreshAccess: () => Promise<void>
  signIn: (email: string, password: string) => Promise<{ error: Error | null }>
  signOut: () => Promise<{ error: Error | null }>
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined)

function messageFromUnknown(error: unknown): string {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error) {
    return String(error.message)
  }
  return 'تعذر التحقق من صلاحيات الحساب.'
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [session, setSession] = useState<Session | null>(null)
  const [access, setAccess] = useState<AccessContext | null>(null)
  const [accessError, setAccessError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  const refreshAccess = useCallback(async () => {
    if (!isSupabaseConfigured) {
      setAccess(null)
      setAccessError('إعداد الاتصال بقاعدة البيانات غير مكتمل.')
      return
    }

    try {
      const { data, error } = await supabase.schema('api').rpc('read_current_access_context')
      if (error) throw error
      setAccess(data?.[0] ?? null)
      setAccessError(data?.[0] ? null : 'لا توجد صلاحيات نشطة لهذا الحساب.')
    } catch (error) {
      setAccess(null)
      setAccessError(messageFromUnknown(error))
    }
  }, [])

  useEffect(() => {
    let active = true

    async function initialize() {
      if (!isSupabaseConfigured) {
        if (active) setLoading(false)
        return
      }
      const { data } = await supabase.auth.getSession()
      if (!active) return
      setSession(data.session)
      setUser(data.session?.user ?? null)
      if (data.session) await refreshAccess()
      if (active) setLoading(false)
    }

    void initialize()
    const { data } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession)
      setUser(nextSession?.user ?? null)
      setAccess(null)
      setAccessError(null)
      if (nextSession) {
        queueMicrotask(() => void refreshAccess())
      }
    })

    return () => {
      active = false
      data.subscription.unsubscribe()
    }
  }, [refreshAccess])

  const permissionSet = useMemo(() => new Set(access?.permission_keys ?? []), [access])
  const roleSet = useMemo(() => new Set(access?.role_keys ?? []), [access])

  const value = useMemo<AuthContextValue>(() => ({
    user,
    session,
    access,
    loading,
    accessError,
    configured: isSupabaseConfigured,
    hasPermission: (permission) => permissionSet.has(permission),
    hasAnyPermission: (permissions) => permissions.some((permission) => permissionSet.has(permission)),
    hasRole: (role) => roleSet.has(role),
    refreshAccess,
    signIn: async (email, password) => {
      if (!isSupabaseConfigured) return { error: new Error('إعداد الاتصال بقاعدة البيانات غير مكتمل.') }
      setLoading(true)
      const { error } = await supabase.auth.signInWithPassword({ email, password })
      setLoading(false)
      return { error: error ? new Error(error.message) : null }
    },
    signOut: async () => {
      const { error } = await supabase.auth.signOut()
      setAccess(null)
      return { error: error ? new Error(error.message) : null }
    },
  }), [access, accessError, loading, permissionSet, refreshAccess, roleSet, session, user])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext)
  if (!context) throw new Error('useAuth must be used within AuthProvider')
  return context
}
