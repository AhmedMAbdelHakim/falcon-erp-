export type MinorUnits = bigint

const DECIMAL_MONEY = /^(-?)(\d+)(?:\.(\d{1,2}))?$/

export function minorUnits(value: bigint | number | string): MinorUnits {
  if (typeof value === 'bigint') return value
  if (typeof value === 'number') {
    if (!Number.isSafeInteger(value)) throw new RangeError('Minor units must be a safe integer')
    return BigInt(value)
  }
  if (!/^-?\d+$/.test(value)) throw new TypeError('Minor units must be an integer string')
  return BigInt(value)
}

export function egpToMinor(value: string): MinorUnits {
  const match = DECIMAL_MONEY.exec(value.trim())
  if (!match) throw new TypeError('EGP amount must have at most two decimal places')
  const [, sign, whole, fraction = ''] = match
  const absolute = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'))
  return sign === '-' ? -absolute : absolute
}

export function formatEgp(value: MinorUnits, locale = 'en-EG'): string {
  const sign = value < 0n ? '-' : ''
  const absolute = value < 0n ? -value : value
  const whole = absolute / 100n
  const fraction = absolute % 100n
  const fractionDigits = fraction.toString().padStart(2, '0')
  const localizedFraction = [...fractionDigits]
    .map((digit) => new Intl.NumberFormat(locale, { useGrouping: false }).format(BigInt(digit)))
    .join('')
  const separator = locale.toLowerCase().startsWith('ar') ? '٫' : '.'
  return `${sign}${new Intl.NumberFormat(locale).format(whole)}${separator}${localizedFraction} EGP`
}

export function sumMinor(values: readonly MinorUnits[]): MinorUnits {
  return values.reduce((total, value) => total + value, 0n)
}

export function allocateLargestRemainder(total: MinorUnits, weights: readonly bigint[]): MinorUnits[] {
  if (total < 0n) throw new RangeError('Allocation total cannot be negative')
  if (weights.length === 0 || weights.some((weight) => weight < 0n)) throw new RangeError('Weights must be non-negative')
  const denominator = weights.reduce((sum, weight) => sum + weight, 0n)
  if (denominator === 0n) throw new RangeError('At least one weight must be positive')

  const shares = weights.map((weight, index) => ({
    index,
    value: (total * weight) / denominator,
    remainder: (total * weight) % denominator,
  }))
  let undistributed = total - shares.reduce((sum, share) => sum + share.value, 0n)
  shares.sort((a, b) => a.remainder === b.remainder ? a.index - b.index : a.remainder > b.remainder ? -1 : 1)
  for (let index = 0; undistributed > 0n; index += 1, undistributed -= 1n) shares[index].value += 1n
  return shares.sort((a, b) => a.index - b.index).map((share) => share.value)
}
