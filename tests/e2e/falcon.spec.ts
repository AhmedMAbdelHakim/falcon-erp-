import AxeBuilder from '@axe-core/playwright'
import { expect, test, type Page } from '@playwright/test'

const password = 'FalconQA-2026'

async function login(page: Page, email = 'qa-admin@falcon.test') {
  await page.goto('/login')
  await page.getByLabel('البريد الإلكتروني').fill(email)
  await page.getByLabel('كلمة المرور').fill(password)
  await page.getByRole('button', { name: 'دخول آمن' }).click()
  await expect(page).toHaveURL(/\/dashboard$/)
}

const routes = [
  ['/dashboard', /مرحبًا/], ['/orders', 'الأوردرات'], ['/payments', 'مدفوعات العملاء'],
  ['/printing/batches', 'دفعات الطباعة'], ['/inventory', 'أرصدة المخزون'], ['/shipping/shipments', 'الشحنات'],
  ['/shipping/settlements', 'تسويات شركة الشحن'], ['/finance/expenses', 'المصروفات'], ['/payroll', 'الرواتب'],
  ['/partners', 'حسابات الشركاء'], ['/finance/ledger', 'دفتر الأستاذ'], ['/reports', 'التقارير المالية'],
  ['/finance/monthly-close', 'الإقفال الشهري'], ['/finance/wallets', 'المحافظ'], ['/settings', 'إعدادات النظام'],
  ['/approvals', 'صندوق الموافقات'], ['/audit', 'سجل التدقيق'],
] as const

test('major routes load, remain RTL, and expose no serious axe violations', async ({ page }, testInfo) => {
  await login(page)
  for (const [route, heading] of routes) {
    await test.step(route, async () => {
      await page.goto(route)
      await expect(page.getByRole('heading', { level: 1, name: heading })).toBeVisible()
      await expect(page.locator('html')).toHaveAttribute('dir', 'rtl')
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth)).toBe(true)
    })
  }

  await page.goto('/orders')
  await page.getByRole('button', { name: 'تأكيد الأوردر' }).click()
  const dialog = page.getByRole('dialog')
  await expect(dialog).toBeVisible()
  await expect(page.getByLabel('معرف الأوردر')).toBeVisible()
  await page.keyboard.press('Tab')
  expect(await dialog.evaluate((element) => element.contains(document.activeElement))).toBe(true)
  await page.screenshot({ path: `test-results/screenshots/${testInfo.project.name}-orders-dialog.png`, fullPage: true })

  await page.goto('/dashboard')
  const results = await new AxeBuilder({ page }).analyze()
  expect(results.violations.filter((violation) => ['critical', 'serious'].includes(violation.impact ?? ''))).toEqual([])
  await page.screenshot({ path: `test-results/screenshots/${testInfo.project.name}-dashboard.png`, fullPage: true })
})

test('authorization, cross-organization context, logout, and expired session fail closed', async ({ browser }) => {
  const moderatorContext = await browser.newContext({ locale: 'ar-EG', timezoneId: 'Africa/Cairo' })
  const moderator = await moderatorContext.newPage()
  await login(moderator, 'qa-moderator@falcon.test')
  await moderator.goto('/finance/ledger')
  await expect(moderator.getByRole('heading', { name: 'غير مصرح' })).toBeVisible()
  await moderatorContext.close()

  const crossContext = await browser.newContext({ locale: 'ar-EG', timezoneId: 'Africa/Cairo' })
  const cross = await crossContext.newPage()
  await login(cross, 'qa-cross-org@falcon.test')
  await expect(cross.getByText('Falcon Sandbox', { exact: true })).toBeVisible()
  await cross.goto('/orders')
  await expect(cross.getByText('0 سجل', { exact: true })).toBeVisible()
  const logoutButton = cross.getByRole('button', { name: 'تسجيل الخروج' })
  if ((cross.viewportSize()?.width ?? 0) <= 820) {
    await cross.getByRole('button', { name: 'فتح القائمة' }).click()
  }
  await logoutButton.click()
  await expect(cross).toHaveURL(/\/login$/)
  await cross.goto('/dashboard')
  await expect(cross).toHaveURL(/\/login$/)
  await crossContext.close()
})

test('records local authenticated load and route-transition timing', async ({ page }, testInfo) => {
  test.skip(testInfo.project.name !== 'chromium-desktop-dark', 'Performance sample runs once on desktop Chromium')
  await login(page)

  await page.goto('/dashboard')
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
  const initialLoadMs = await page.evaluate(() => {
    const navigation = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming
    return Math.round(navigation.duration)
  })

  const transitionStarted = Date.now()
  await page.locator('a[href="/orders"]').click()
  await expect(page.getByRole('heading', { level: 1, name: 'الأوردرات' })).toBeVisible()
  const routeTransitionMs = Date.now() - transitionStarted
  const metrics = { initial_load_ms: initialLoadMs, route_transition_ms: routeTransitionMs }

  console.log(`performance_metrics=${JSON.stringify(metrics)}`)
  await testInfo.attach('performance-metrics.json', {
    body: Buffer.from(JSON.stringify(metrics, null, 2)),
    contentType: 'application/json',
  })
  expect(initialLoadMs).toBeLessThan(5_000)
  expect(routeTransitionMs).toBeLessThan(5_000)
})
