import { readFile } from 'node:fs/promises'
import { preview } from 'vite'

const expectedConfiguration = {
  framework: 'vite',
  installCommand: 'npm ci',
  buildCommand: 'npm run build',
  outputDirectory: 'dist',
}

const configuration = JSON.parse(await readFile('vercel.json', 'utf8'))
for (const [key, value] of Object.entries(expectedConfiguration)) {
  if (configuration[key] !== value) {
    throw new Error(`vercel.json ${key} must be ${value}`)
  }
}

const rewrite = configuration.rewrites?.find((entry) => entry.source === '/(.*)')
if (rewrite?.destination !== '/index.html') {
  throw new Error('vercel.json must rewrite SPA routes to /index.html')
}

const server = await preview({
  preview: { host: '127.0.0.1', port: 4176, strictPort: true },
})

try {
  const baseUrl = 'http://127.0.0.1:4176'
  const nestedRoutes = [
    '/dashboard',
    '/orders/00000000-0000-4000-8000-000000000000',
    '/finance/monthly-close',
    '/legacy/labels/edit/00000000-0000-4000-8000-000000000000',
  ]

  for (const route of nestedRoutes) {
    const response = await fetch(`${baseUrl}${route}`)
    const body = await response.text()
    if (!response.ok || !body.includes('<div id="root"></div>')) {
      throw new Error(`SPA direct navigation failed for ${route}: HTTP ${response.status}`)
    }
  }

  const index = await (await fetch(baseUrl)).text()
  const assetPath = index.match(/<script[^>]+src="([^"]+)"/)?.[1]
  if (!assetPath) throw new Error('Production index does not reference a JavaScript asset')

  const assetResponse = await fetch(`${baseUrl}${assetPath}`)
  const assetBody = await assetResponse.text()
  if (!assetResponse.ok || assetBody.includes('<div id="root"></div>')) {
    throw new Error(`Static asset routing failed for ${assetPath}`)
  }

  console.log(JSON.stringify({
    asset: assetPath,
    nested_routes: nestedRoutes,
    result: 'PASS',
    vercel_configuration: expectedConfiguration,
  }, null, 2))
} finally {
  await server.close()
}
