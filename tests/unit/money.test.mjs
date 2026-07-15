import test from 'node:test'
import assert from 'node:assert/strict'
import { egpToMinor, formatEgp, minorUnits, sumMinor, allocateLargestRemainder } from '../../src/lib/money/index.ts'

test('money parsing remains exact in bigint minor units', () => {
  assert.equal(egpToMinor('123456789012345.67'), 12345678901234567n)
  assert.equal(egpToMinor('-0.05'), -5n)
  assert.equal(formatEgp(12345678901234567n, 'en-EG'), '123,456,789,012,345.67 EGP')
})

test('unsafe numeric minor units and fractional money are rejected', () => {
  assert.throws(() => minorUnits(Number.MAX_SAFE_INTEGER + 1), /safe integer/)
  assert.throws(() => egpToMinor('1.001'), /two decimal/)
})

test('sums and largest-remainder allocations conserve value', () => {
  const shares = allocateLargestRemainder(1001n, [1n, 1n, 1n])
  assert.deepEqual(shares, [334n, 334n, 333n])
  assert.equal(sumMinor(shares), 1001n)
})
