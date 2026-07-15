import { formatEgp, minorUnits } from './money'

export function formatMinor(value: string | number | bigint | null | undefined): string {
  if (value === null || value === undefined) return '-'
  try {
    return formatEgp(minorUnits(value), 'ar-EG').replace(' EGP', ' ج.م')
  } catch {
    return 'قيمة غير صالحة'
  }
}

export function formatDate(value: string | null | undefined, withTime = false): string {
  if (!value) return '-'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value
  return new Intl.DateTimeFormat('ar-EG', {
    timeZone: 'Africa/Cairo',
    dateStyle: 'medium',
    ...(withTime ? { timeStyle: 'short' as const } : {}),
  }).format(date)
}

export function formatValue(value: unknown, key = ''): string {
  if (value === null || value === undefined || value === '') return '-'
  if (key.endsWith('_minor')) return formatMinor(value as string | number | bigint)
  if (key.endsWith('_at') || key.endsWith('_date')) return formatDate(String(value), key.endsWith('_at'))
  if (typeof value === 'boolean') return value ? 'نعم' : 'لا'
  if (Array.isArray(value)) return value.join('، ')
  if (typeof value === 'object') return 'بيانات مرفقة'
  return String(value)
}
