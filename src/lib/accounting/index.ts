import { sumMinor, type MinorUnits } from '../money'

export interface JournalLineDraft {
  accountId: string
  debitMinor: MinorUnits
  creditMinor: MinorUnits
  memo?: string
}

export function assertBalanced(lines: readonly JournalLineDraft[]): void {
  if (lines.length < 2) throw new RangeError('A journal entry requires at least two lines')
  for (const line of lines) {
    if (line.debitMinor < 0n || line.creditMinor < 0n || (line.debitMinor === 0n) === (line.creditMinor === 0n)) {
      throw new RangeError('Each line must contain exactly one positive debit or credit')
    }
  }
  const debits = sumMinor(lines.map((line) => line.debitMinor))
  const credits = sumMinor(lines.map((line) => line.creditMinor))
  if (debits !== credits) throw new RangeError(`Unbalanced journal: debits=${debits}, credits=${credits}`)
}
