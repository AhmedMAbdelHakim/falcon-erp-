import { defineConfig, devices } from '@playwright/test'

const baseURL = process.env.E2E_BASE_URL ?? 'http://127.0.0.1:4175'

export default defineConfig({
  testDir: './tests/e2e',
  outputDir: './test-results/playwright-artifacts',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 30_000,
  expect: { timeout: 7_000 },
  reporter: [['line'], ['html', { outputFolder: 'test-results/playwright-report', open: 'never' }]],
  use: {
    baseURL,
    locale: 'ar-EG',
    timezoneId: 'Africa/Cairo',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  webServer: {
    command: 'npm run dev -- --host 127.0.0.1 --port 4175',
    url: baseURL,
    reuseExistingServer: false,
    timeout: 120_000,
  },
  projects: [
    { name: 'chromium-desktop-dark', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 }, colorScheme: 'dark' } },
    { name: 'firefox-desktop-light', use: { ...devices['Desktop Firefox'], viewport: { width: 1440, height: 900 }, colorScheme: 'light' } },
    { name: 'webkit-desktop-dark', use: { ...devices['Desktop Safari'], viewport: { width: 1440, height: 900 }, colorScheme: 'dark' } },
    { name: 'chromium-tablet-light', use: { ...devices['Desktop Chrome'], viewport: { width: 1024, height: 768 }, colorScheme: 'light' } },
    { name: 'chromium-mobile-portrait', use: { ...devices['Pixel 5'], viewport: { width: 390, height: 844 }, colorScheme: 'dark' } },
    { name: 'chromium-mobile-landscape', use: { ...devices['Pixel 5 landscape'], viewport: { width: 844, height: 390 }, colorScheme: 'light' } },
    { name: 'chromium-high-contrast', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 }, colorScheme: 'light', forcedColors: 'active', reducedMotion: 'reduce' } },
  ],
})
