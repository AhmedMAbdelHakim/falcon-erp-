import type { LucideIcon } from 'lucide-react'
import { AlertTriangle, Ban, Inbox, LoaderCircle, RefreshCw } from 'lucide-react'

interface PageStateProps {
  kind: 'loading' | 'empty' | 'error' | 'denied'
  title?: string
  message?: string
  onRetry?: () => void
  icon?: LucideIcon
}

const defaults = {
  loading: ['جارٍ تحميل البيانات', 'يتم جلب أحدث حالة معتمدة من الخادم.', LoaderCircle],
  empty: ['لا توجد بيانات', 'لا توجد سجلات مطابقة للفلاتر الحالية.', Inbox],
  error: ['تعذر تحميل البيانات', 'لم يتم تغيير أي بيانات. حاول التحديث بعد التحقق من الاتصال.', AlertTriangle],
  denied: ['غير مصرح', 'لا يملك حسابك الصلاحية المطلوبة لعرض هذه الصفحة.', Ban],
} as const

export function PageState({ kind, title, message, onRetry, icon }: PageStateProps) {
  const [defaultTitle, defaultMessage, DefaultIcon] = defaults[kind]
  const Icon = icon ?? DefaultIcon
  return (
    <div className="page-state" role={kind === 'error' ? 'alert' : 'status'}>
      <Icon className={kind === 'loading' ? 'spin' : ''} aria-hidden="true" />
      <h2>{title ?? defaultTitle}</h2>
      <p>{message ?? defaultMessage}</p>
      {onRetry ? (
        <button className="button secondary" type="button" onClick={onRetry}>
          <RefreshCw size={16} aria-hidden="true" />
          إعادة المحاولة
        </button>
      ) : null}
    </div>
  )
}
