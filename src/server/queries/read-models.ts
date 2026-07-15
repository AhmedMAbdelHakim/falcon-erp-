import { supabase } from '../../lib/supabase'
import type { Database } from '../../types/database.generated'

type ApiFunctions = Database['api']['Functions']
export type DashboardSummary = ApiFunctions['read_dashboard_summary']['Returns'][number]
export type ProfitAndLossRow = ApiFunctions['read_profit_and_loss']['Returns'][number]
export type TrialBalanceRow = ApiFunctions['read_trial_balance']['Returns'][number]
export type LiquidityRow = ApiFunctions['read_liquidity_summary']['Returns'][number]
export type JournalEntryRow = ApiFunctions['list_journal_entries']['Returns'][number]
export type MonthlyCloseRow = ApiFunctions['list_monthly_closes']['Returns'][number]
export type AuditEventRow = ApiFunctions['search_audit_events']['Returns'][number]

export async function readDashboard(organizationId: string, start: string, end: string) {
  const { data, error } = await supabase.schema('api').rpc('read_dashboard_summary', {
    p_organization_id: organizationId, p_period_start: start, p_period_end: end,
  })
  if (error) throw error
  return data?.[0] ?? null
}

export async function readFinancialReports(organizationId: string, start: string, end: string) {
  const [profitLoss, trialBalance, liquidity] = await Promise.all([
    supabase.schema('api').rpc('read_profit_and_loss', { p_organization_id: organizationId, p_period_start: start, p_period_end: end }),
    supabase.schema('api').rpc('read_trial_balance', { p_organization_id: organizationId, p_period_start: start, p_period_end: end }),
    supabase.schema('api').rpc('read_liquidity_summary', { p_organization_id: organizationId, p_as_of_date: end }),
  ])
  if (profitLoss.error) throw profitLoss.error
  if (trialBalance.error) throw trialBalance.error
  if (liquidity.error) throw liquidity.error
  return { profitLoss: profitLoss.data ?? [], trialBalance: trialBalance.data ?? [], liquidity: liquidity.data ?? [] }
}

export async function readJournal(organizationId: string, start: string, end: string) {
  const { data, error } = await supabase.schema('api').rpc('list_journal_entries', {
    p_organization_id: organizationId, p_period_start: start, p_period_end: end, p_page_size: 100,
  })
  if (error) throw error
  return data ?? []
}

export async function readMonthlyCloses(organizationId: string) {
  const { data, error } = await supabase.schema('api').rpc('list_monthly_closes', {
    p_organization_id: organizationId, p_page_size: 36,
  })
  if (error) throw error
  return data ?? []
}

export async function readAudit(organizationId: string) {
  const { data, error } = await supabase.schema('api').rpc('search_audit_events', {
    p_organization_id: organizationId, p_page_size: 100,
  })
  if (error) throw error
  return data ?? []
}

export function cairoPeriod() {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date())
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]))
  const end = `${value.year}-${value.month}-${value.day}`
  return { start: `${value.year}-${value.month}-01`, end }
}
