$ErrorActionPreference = 'Stop'
$container = 'supabase_db_falcon'
$org = '00000000-0000-4000-8000-00000000f001'
$actor = '1b000000-0000-4000-8000-000000000001'

function Psql([string]$Sql) {
  $out = & docker exec $container psql -U postgres -d postgres -X -qAt -v ON_ERROR_STOP=1 -c $Sql 2>&1
  if ($LASTEXITCODE -ne 0) { throw ($out -join [Environment]::NewLine) }
  ($out -join [Environment]::NewLine).Trim()
}
function PsqlJob([string]$Sql) {
  Start-Job -ScriptBlock {
    param($Container,$Query)
    $out = & docker exec $Container psql -U postgres -d postgres -X -qAt -v ON_ERROR_STOP=1 -c $Query 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($out -join [Environment]::NewLine) }
    ($out -join [Environment]::NewLine).Trim()
  } -ArgumentList $container,$Sql
}
function JsonResult($Output) {
  $text = $Output -join [Environment]::NewLine
  $line = $text -split '[\r\n]+' | Where-Object { $_.Trim().StartsWith('{') } | Select-Object -Last 1
  if (-not $line) { throw "No JSON command response: $text" }
  $line | ConvertFrom-Json
}
function SqlJson($Value) {
  (($Value | ConvertTo-Json -Depth 12 -Compress).Replace("'","''"))
}

Psql @"
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change,is_sso_user,is_anonymous)
values('00000000-0000-0000-0000-000000000000','$actor','authenticated','authenticated','concurrency@phase2.test',crypt('phase2',gen_salt('bf')),statement_timestamp(),jsonb_build_object('provider','email','providers',jsonb_build_array('email')),jsonb_build_object(),statement_timestamp(),statement_timestamp(),'','','','',false,false)
on conflict(id) do nothing;
update public.profiles set status='active',activated_at=statement_timestamp(),activated_by=id where id='$actor';
insert into private.user_roles(organization_id,user_id,role_id,effective_from,assigned_by,assignment_reason)
select '$org','$actor',r.id,statement_timestamp()-interval '1 minute','$actor','Concurrency fixture'
from private.roles r where r.organization_id='$org' and r.role_key='super_admin'
and not exists(select 1 from private.user_roles ur where ur.organization_id='$org' and ur.user_id='$actor' and ur.role_id=r.id and ur.revoked_at is null);
"@ | Out-Null

$accountRows = Psql "select code||'='||id from accounting.accounts where organization_id='$org' and code in('5200','6200') order by code;"
$accounts = @{}
foreach($row in ($accountRows -split '[\r\n]+')) {
  $pair = $row.Split('=')
  $accounts[$pair[0]] = $pair[1]
}
$source = [guid]::NewGuid().ToString()
$key = "concurrent-$([guid]::NewGuid())"
$lines = @(
  [ordered]@{account_id=$accounts['5200'];debit_minor='250';credit_minor='0'},
  [ordered]@{account_id=$accounts['6200'];debit_minor='0';credit_minor='250'}
)
$payload = [ordered]@{
  organization_id=$org;source_type='manual_journal';source_id=$source
  posting_purpose='manual_adjustment';description='Concurrent idempotency probe'
  lines=$lines;accounting_date=$null;approval_request_id=$null
  corrects_entry_id=$null;affected_closed_period_id=$null
}
$linesJson = SqlJson $lines
$payloadJson = SqlJson $payload
$linesBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($linesJson))
$payloadBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payloadJson))
$fp = Psql "select private.canonical_request_fingerprint('ledger.post',convert_from(decode('$payloadBase64','base64'),'UTF8')::jsonb,1::smallint);"
$call = @"
select set_config('request.jwt.claim.sub','$actor',true);
set local role authenticated;
select api.post_journal_entry('$org','manual_journal','$source','manual_adjustment','Concurrent idempotency probe',convert_from(decode('$linesBase64','base64'),'UTF8')::jsonb,'$key','$fp',gen_random_uuid(),null,null,null,null);
"@

$periodLock = PsqlJob "begin;select id from accounting.accounting_periods where organization_id='$org' and private.cairo_accounting_date() between period_start and period_end for update;select pg_sleep(3);commit;"
Start-Sleep -Milliseconds 300
$watch = [Diagnostics.Stopwatch]::StartNew()
$job1 = PsqlJob $call
$job2 = PsqlJob $call
Wait-Job $job1,$job2,$periodLock | Out-Null
$watch.Stop()
$result1 = JsonResult (Receive-Job $job1)
$result2 = JsonResult (Receive-Job $job2)
Receive-Job $periodLock | Out-Null
Remove-Job $job1,$job2,$periodLock
$counts = (Psql "select (select count(*) from accounting.journal_entries where source_id='$source')||'|'||(select count(*) from private.command_executions where command_type='ledger.post' and idempotency_key='$key');").Split('|')
if (-not $result1.success -or -not $result2.success -or
    $result1.journal_entry_ids[0] -ne $result2.journal_entry_ids[0] -or
    [int]$counts[0] -ne 1 -or [int]$counts[1] -ne 1 -or
    $watch.ElapsedMilliseconds -lt 2000) {
  throw "Concurrent idempotency failed: journals=$($counts[0]) commands=$($counts[1]) elapsed=$($watch.ElapsedMilliseconds)"
}

$blockedSource = [guid]::NewGuid().ToString()
$blockedKey = "close-race-$([guid]::NewGuid())"
$blockedPayload = [ordered]@{}
foreach($entry in $payload.GetEnumerator()) { $blockedPayload[$entry.Key] = $entry.Value }
$blockedPayload.source_id = $blockedSource
$blockedPayload.description = 'Close versus post race probe'
$blockedJson = SqlJson $blockedPayload
$blockedBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($blockedJson))
$blockedFp = Psql "select private.canonical_request_fingerprint('ledger.post',convert_from(decode('$blockedBase64','base64'),'UTF8')::jsonb,1::smallint);"
$blockedCall = @"
select set_config('request.jwt.claim.sub','$actor',true);
set local role authenticated;
select api.post_journal_entry('$org','manual_journal','$blockedSource','manual_adjustment','Close versus post race probe',convert_from(decode('$linesBase64','base64'),'UTF8')::jsonb,'$blockedKey','$blockedFp',gen_random_uuid(),null,null,null,null);
"@
Psql "update accounting.accounting_periods set status='open',close_requested_by=null,close_requested_at=null where organization_id='$org' and private.cairo_accounting_date() between period_start and period_end;" | Out-Null
$closeJob = PsqlJob "begin;select id from accounting.accounting_periods where organization_id='$org' and private.cairo_accounting_date() between period_start and period_end for update;update accounting.accounting_periods set status='closing',close_requested_by='$actor',close_requested_at=statement_timestamp() where organization_id='$org' and private.cairo_accounting_date() between period_start and period_end;select pg_sleep(2);commit;"
Start-Sleep -Milliseconds 300
$raceWatch = [Diagnostics.Stopwatch]::StartNew()
$blocked = JsonResult (Psql $blockedCall)
$raceWatch.Stop()
Wait-Job $closeJob | Out-Null
Receive-Job $closeJob | Out-Null
Remove-Job $closeJob
$blockedCount = [int](Psql "select count(*) from accounting.journal_entries where source_id='$blockedSource';")
Psql "update accounting.accounting_periods set status='open',close_requested_by=null,close_requested_at=null where organization_id='$org' and private.cairo_accounting_date() between period_start and period_end;" | Out-Null
if ($blocked.success -or $blocked.error_code -ne 'POSTING_PERIOD_CLOSED' -or
    $blockedCount -ne 0 -or $raceWatch.ElapsedMilliseconds -lt 1200) {
  throw "Close/post serialization failed: error=$($blocked.error_code) journals=$blockedCount elapsed=$($raceWatch.ElapsedMilliseconds)"
}

[ordered]@{
  concurrent_idempotency=[ordered]@{
    status='passed';elapsed_ms=$watch.ElapsedMilliseconds
    command_rows=[int]$counts[1];journal_rows=[int]$counts[0]
    replayed_journal_entry_id=$result1.journal_entry_ids[0]
  }
  close_vs_post=[ordered]@{
    status='passed';elapsed_ms=$raceWatch.ElapsedMilliseconds
    error_code=$blocked.error_code;journal_rows=$blockedCount
  }
} | ConvertTo-Json -Depth 4 -Compress
