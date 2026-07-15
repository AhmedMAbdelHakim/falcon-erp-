import { spawnSync } from 'node:child_process'
import { writeFileSync } from 'node:fs'

const executable = process.execPath
const cliLauncher = 'node_modules/supabase/dist/supabase.js'
const result = spawnSync(executable, [cliLauncher, 'gen', 'types', 'typescript', '--local', '--schema', 'public,api'], {
  encoding: 'utf8',
  shell: false,
})

if (result.status !== 0) {
  process.stderr.write(result.stderr || 'Supabase type generation failed\n')
  process.exit(result.status ?? 1)
}

if (!result.stdout.includes('export type Json') || !result.stdout.includes('export type Database')) {
  throw new Error('Supabase returned an invalid TypeScript payload; existing types were preserved')
}

writeFileSync('src/types/database.generated.ts', result.stdout, 'utf8')
