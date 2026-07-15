import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { parse } from 'csv-parse/sync'

const fixtureDirectory = resolve('tests/fixtures/import')

function load(name, requiredColumns) {
  const records = parse(readFileSync(resolve(fixtureDirectory, `${name}.csv`), 'utf8'), {
    bom: true,
    columns: true,
    skip_empty_lines: true,
    trim: true,
  })
  const columns = Object.keys(records[0] ?? {})
  for (const column of requiredColumns) {
    if (!columns.includes(column)) throw new Error(`${name}: missing required column ${column}`)
  }
  return records
}

function integer(value, label, { nonnegative = false } = {}) {
  if (!/^-?\d+$/.test(value)) throw new Error(`${label}: expected integer minor units`)
  const parsed = BigInt(value)
  if (nonnegative && parsed < 0n) throw new Error(`${label}: expected a nonnegative value`)
  return parsed
}

function unique(records, key, name) {
  const seen = new Set()
  for (const record of records) {
    if (!record[key]) throw new Error(`${name}: empty ${key}`)
    if (seen.has(record[key])) throw new Error(`${name}: duplicate ${key} ${record[key]}`)
    seen.add(record[key])
  }
}

function validate() {
  const balances = load('opening_balances', ['account_code', 'debit_minor', 'credit_minor'])
  const customers = load('customers', ['external_id', 'full_name', 'phone'])
  const suppliers = load('suppliers', ['external_id', 'name'])
  const inventory = load('inventory', ['sku', 'quantity_on_hand', 'unit_cost_minor'])
  const wallets = load('wallets', ['external_id', 'name', 'opening_balance_minor'])

  unique(balances, 'account_code', 'opening_balances')
  unique(customers, 'external_id', 'customers')
  unique(suppliers, 'external_id', 'suppliers')
  unique(inventory, 'sku', 'inventory')
  unique(wallets, 'external_id', 'wallets')

  let debit = 0n
  let credit = 0n
  for (const row of balances) {
    debit += integer(row.debit_minor, `opening_balances ${row.account_code} debit`, { nonnegative: true })
    credit += integer(row.credit_minor, `opening_balances ${row.account_code} credit`, { nonnegative: true })
  }
  if (debit !== credit) throw new Error(`opening_balances: debits ${debit} do not equal credits ${credit}`)

  for (const row of inventory) {
    integer(row.quantity_on_hand, `inventory ${row.sku} quantity`, { nonnegative: true })
    integer(row.unit_cost_minor, `inventory ${row.sku} cost`, { nonnegative: true })
  }
  for (const row of wallets) integer(row.opening_balance_minor, `wallet ${row.external_id} balance`)

  return {
    balanced_opening_minor: debit.toString(),
    customers: customers.length,
    inventory: inventory.length,
    opening_balances: balances.length,
    suppliers: suppliers.length,
    wallets: wallets.length,
  }
}

function digest(summary) {
  return createHash('sha256').update(JSON.stringify(summary)).digest('hex')
}

const first = validate()
const second = validate()
const firstDigest = digest(first)
if (firstDigest !== digest(second)) throw new Error('dry run is not deterministic')

let negativeFixtureRejected = false
try {
  unique([{ external_id: 'DUP' }, { external_id: 'DUP' }], 'external_id', 'negative_fixture')
} catch {
  negativeFixtureRejected = true
}
if (!negativeFixtureRejected) throw new Error('negative duplicate fixture was not rejected')

console.log(JSON.stringify({
  database_mutations: 0,
  deterministic_sha256: firstDigest,
  negative_fixture_rejected: true,
  rollback_required: false,
  summary: first,
}, null, 2))
