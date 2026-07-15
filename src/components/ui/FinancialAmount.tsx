import { formatMinor } from '../../lib/format'

export function FinancialAmount({ value, muted = false }: {
  value: string | number | bigint | null | undefined
  muted?: boolean
}) {
  return <span className={`financial-amount${muted ? ' muted' : ''}`} dir="ltr">{formatMinor(value)}</span>
}
