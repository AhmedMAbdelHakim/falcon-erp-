param([string]$Project)

$ErrorActionPreference = 'Stop'

$ErrorActionPreference = 'Continue'
$status = npx supabase status -o env 2>$null
$statusExitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($statusExitCode -ne 0) { throw "Local Supabase status failed with exit code $statusExitCode" }
$apiLine = $status | Where-Object { $_ -like 'API_URL=*' } | Select-Object -First 1
$keyLine = $status | Where-Object { $_ -like 'ANON_KEY=*' } | Select-Object -First 1
if (-not $apiLine -or -not $keyLine) { throw 'Local Supabase public configuration is unavailable.' }

$env:VITE_SUPABASE_URL = ($apiLine -split '=',2)[1].Trim('"')
$env:VITE_SUPABASE_ANON_KEY = ($keyLine -split '=',2)[1].Trim('"')
$env:E2E_BASE_URL = 'http://127.0.0.1:4175'
New-Item -ItemType Directory -Force test-results/screenshots | Out-Null

$fixture = Get-Content -Raw -Encoding UTF8 tests/e2e/fixtures.sql
$fixture | docker exec -i supabase_db_falcon psql -U postgres -d postgres -1 -v ON_ERROR_STOP=1 | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Synthetic E2E fixture failed with exit code $LASTEXITCODE" }

if ($Project) {
  npx playwright test --project=$Project
} else {
  npx playwright test
}
exit $LASTEXITCODE
