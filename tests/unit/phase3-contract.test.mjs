import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { workflowActions } from '../../src/features/workflows/actions.ts'

test('transactional UI covers every required Falcon workflow family', () => {
  const required = ['orders', 'payments', 'refunds', 'printBatches', 'suppliers', 'shipments', 'returns', 'settlements', 'wallets', 'expenses', 'payroll', 'partners', 'withdrawals', 'distributions', 'ledger', 'monthlyClose']
  for (const family of required) assert.ok(workflowActions[family]?.length, `missing ${family}`)
  const commands = Object.values(workflowActions).flat()
  assert.equal(new Set(commands.map((item) => item.rpc)).size, commands.length)
  assert.ok(commands.every((item) => item.permission && item.commandType && item.fields.length > 0))
})

test('new financial UI never performs direct table mutation', async () => {
  const files = ['src/components/WorkflowActions.tsx', 'src/server/queries/read-models.ts', 'src/server/queries/resources.ts']
  for (const file of files) {
    const source = await readFile(new URL(`../../${file}`, import.meta.url), 'utf8')
    assert.doesNotMatch(source, /\.(insert|update|upsert|delete)\s*\(/, file)
  }
})

test('Arabic product files contain no UTF-8 mojibake markers', async () => {
  const files = ['src/pages/Login.tsx', 'src/pages/Dashboard.tsx', 'src/pages/ResourcePage.tsx', 'src/components/AppShell.tsx', 'src/features/resources/catalog.ts']
  for (const file of files) {
    const source = await readFile(new URL(`../../${file}`, import.meta.url), 'utf8')
    assert.doesNotMatch(source, /[ØÙ]/, file)
  }
})

test('generated database contract includes authenticated access and reporting RPCs', async () => {
  const generated = await readFile(new URL('../../src/types/database.generated.ts', import.meta.url), 'utf8')
  for (const name of ['read_current_access_context', 'read_dashboard_summary', 'read_profit_and_loss', 'read_trial_balance', 'read_liquidity_summary', 'list_journal_entries', 'list_monthly_closes', 'search_audit_events']) assert.match(generated, new RegExp(`${name}:`))
})
