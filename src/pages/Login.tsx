import { useEffect, useState } from 'react'
import { KeyRound, LogIn, Mail, ShieldCheck } from 'lucide-react'
import { useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

export function Login() {
  const { configured, signIn, user, loading: authLoading } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (user && !authLoading) navigate('/dashboard', { replace: true })
  }, [authLoading, navigate, user])

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    setSubmitting(true)
    setError(null)
    const result = await signIn(email.trim(), password)
    setSubmitting(false)
    if (result.error) {
      setError(result.error.message)
      return
    }
    const requested = (location.state as { from?: string } | null)?.from
    navigate(requested ?? '/dashboard', { replace: true })
  }

  return (
    <main className="login-page" dir="rtl">
      <section className="login-form-wrap" aria-labelledby="login-title">
        <div className="login-form">
          <div className="login-brand">
            <div className="brand-mark" aria-hidden="true">F</div>
            <div><strong>Falcon</strong><span>المحاسبة والعمليات</span></div>
          </div>
          <h1 id="login-title">تسجيل الدخول</h1>
          <p>استخدم حساب العمل المصرح له. تظهر الوحدات والبيانات حسب أدوارك الفعلية داخل المؤسسة.</p>
          {!configured ? <div className="form-error" role="alert">إعداد الاتصال غير مكتمل. أضف عنوان Supabase والمفتاح العام إلى بيئة التشغيل.</div> : null}
          {error ? <div className="form-error" role="alert">تعذر تسجيل الدخول: {error}</div> : null}
          <form onSubmit={submit}>
            <div className="form-group">
              <label htmlFor="email">البريد الإلكتروني</label>
              <div className="input-with-icon"><Mail size={17} aria-hidden="true" /><input id="email" type="email" dir="ltr" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} /></div>
            </div>
            <div className="form-group">
              <label htmlFor="password">كلمة المرور</label>
              <div className="input-with-icon"><KeyRound size={17} aria-hidden="true" /><input id="password" type="password" dir="ltr" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} /></div>
            </div>
            <button className="button primary login-submit" type="submit" disabled={!configured || submitting || authLoading}>
              <LogIn size={17} aria-hidden="true" />{submitting ? 'جارٍ التحقق...' : 'دخول آمن'}
            </button>
          </form>
        </div>
      </section>
      <aside className="login-scene" aria-label="تعريف النظام">
        <div><ShieldCheck size={34} aria-hidden="true" /><h2>حقيقة مالية واحدة.<br />تشغيل يمكن تتبعه.</h2><p>القيود، السيولة، المخزون، الموافقات، والإقفال الشهري من عقود Falcon المعتمدة.</p></div>
      </aside>
    </main>
  )
}
