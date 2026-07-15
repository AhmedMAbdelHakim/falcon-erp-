$ErrorActionPreference = 'Stop'

$container = 'supabase_db_falcon'
$restoreDatabase = 'falcon_phase35_restore'
$containerDump = '/tmp/falcon-phase35.dump'
$outputDirectory = Join-Path $PSScriptRoot '..\test-results\backup'
$localDump = Join-Path $outputDirectory 'falcon-phase35.dump'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

function Invoke-Docker {
  param([string[]]$Arguments)
  & docker @Arguments
  if ($LASTEXITCODE -ne 0) { throw "docker command failed with exit code $LASTEXITCODE" }
}

function Query-Database {
  param([string]$Database, [string]$Sql)
  $value = & docker exec $container psql -U postgres -d $Database -Atqc $Sql
  if ($LASTEXITCODE -ne 0) { throw "database query failed for $Database" }
  return ($value | Out-String).Trim()
}

if (-not (& docker ps --format '{{.Names}}' | Where-Object { $_ -eq $container })) {
  throw "Expected local Supabase container $container is not running"
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$baseline = Query-Database 'postgres' @'
select json_build_object(
  'organizations', (select count(*) from public.organizations),
  'accounts', (select count(*) from accounting.accounts),
  'journal_entries', (select count(*) from accounting.journal_entries),
  'journal_lines', (select count(*) from accounting.journal_lines),
  'storage_objects', (select count(*) from storage.objects),
  'unbalanced_entries', (
    select count(*) from (
      select journal_entry_id
      from accounting.journal_lines
      group by journal_entry_id
      having sum(debit_minor) <> sum(credit_minor)
    ) as unbalanced
  )
)::text;
'@

try {
  Invoke-Docker -Arguments @('exec', $container, 'pg_dump', '-U', 'postgres', '-d', 'postgres', '-Fc', '--no-owner', '--no-acl', '-f', $containerDump)
  Invoke-Docker -Arguments @('cp', "${container}:${containerDump}", $localDump)
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $localDump).Hash.ToLowerInvariant()
  $sizeBytes = (Get-Item -LiteralPath $localDump).Length
  if ($sizeBytes -le 0) { throw 'Backup artifact is empty' }

  Invoke-Docker -Arguments @('exec', $container, 'psql', '-U', 'supabase_admin', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-c', "drop database if exists $restoreDatabase with (force);")
  Invoke-Docker -Arguments @('exec', $container, 'psql', '-U', 'supabase_admin', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1', '-c', "create database $restoreDatabase template template0;")
  Invoke-Docker -Arguments @('exec', $container, 'pg_restore', '-U', 'supabase_admin', '-d', $restoreDatabase, '--no-owner', '--no-acl', '--exit-on-error', $containerDump)

  $restored = Query-Database $restoreDatabase @'
select json_build_object(
  'organizations', (select count(*) from public.organizations),
  'accounts', (select count(*) from accounting.accounts),
  'journal_entries', (select count(*) from accounting.journal_entries),
  'journal_lines', (select count(*) from accounting.journal_lines),
  'storage_objects', (select count(*) from storage.objects),
  'unbalanced_entries', (
    select count(*) from (
      select journal_entry_id
      from accounting.journal_lines
      group by journal_entry_id
      having sum(debit_minor) <> sum(credit_minor)
    ) as unbalanced
  )
)::text;
'@
  if ($baseline -ne $restored) {
    throw "Restored verification differs from source. source=$baseline restored=$restored"
  }
  if (($restored | ConvertFrom-Json).unbalanced_entries -ne 0) {
    throw 'Restored database contains an unbalanced journal entry'
  }

  $stopwatch.Stop()
  [ordered]@{
    backup_path = $localDump
    backup_sha256 = $hash
    backup_size_bytes = $sizeBytes
    elapsed_seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
    source = ($baseline | ConvertFrom-Json)
    restored = ($restored | ConvertFrom-Json)
    result = 'PASS'
  } | ConvertTo-Json -Depth 4
}
finally {
  & docker exec $container psql -U supabase_admin -d postgres -c "drop database if exists $restoreDatabase with (force);" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Failed to remove temporary restore database $restoreDatabase" }
  & docker exec $container rm -f $containerDump | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Failed to remove temporary container backup artifact' }
}
