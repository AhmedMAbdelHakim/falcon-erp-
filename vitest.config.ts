import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  root,
  plugins: [react()],
  test: {
    environment: 'jsdom',
    include: ['tests/components/**/*.test.tsx', 'tests/accessibility/**/*.test.tsx'],
    coverage: { reporter: ['text', 'json-summary'] },
  },
})
