param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+\.json$')][string]$Report,[ValidateSet('roundtrip','cancel','failure','nui','vault','sync')][string]$Scenario='roundtrip',[Alias('Fixture')][ValidatePattern('^vault-handoff-fixtures-v[0-9]+\.json$')][string]$FixtureReport='',[string]$SyncFixture='',[ValidateSet('none','cancel','failure')][string]$SyncRecovery='none',[switch]$OriginGc)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'tools/local-test-guard.ps1')
Assert-NativeLocalTestAvailable $PSScriptRoot
if(($Scenario -eq 'vault') -ne [bool]$FixtureReport){throw 'Vault scenario requires its explicit external fixture report'}
if(($Scenario -eq 'sync') -ne [bool]$SyncFixture -or $SyncFixture -and -not [IO.Path]::IsPathRooted($SyncFixture)){throw 'Sync scenario requires its explicit external fixture descriptor'}
if($SyncRecovery -ne 'none' -and $Scenario -ne 'sync'){throw 'Content recovery requires the sync scenario'}
$fixtureName=if($Scenario -eq 'vault'){$FixtureReport}elseif($Scenario -eq 'sync'){'nui-handoff-server-fixtures-v4.json'}elseif($Scenario -eq 'nui'){'nui-handoff-server-fixtures-v3.json'}else{'handoff-server-fixtures-v1.json'}
$fixture=Get-Content (Join-Path $PSScriptRoot ('reports/'+$fixtureName)) -Raw|ConvertFrom-Json
$binary=[IO.Path]::GetFullPath((Join-Path $root '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
$secondaryPid=0
foreach($server in $fixture.servers){
 $endpoint=Get-NetUDPEndpoint -LocalPort $server.port -ErrorAction Stop
 $owned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'"|Where-Object {$_.ExecutablePath -eq $binary -and $_.CommandLine.Contains('"'+$server.profile+'"') -and $_.CommandLine.Contains($server.module)})
 if(-not @($owned|Where-Object {$_.ProcessId -in $endpoint.OwningProcess}).Count){throw 'Handoff endpoint is not the requested owned fixture; preserved'}
 if($Scenario -eq 'vault' -and -not @($owned|Where-Object {$_.ProcessId -in $endpoint.OwningProcess -and $_.CommandLine -match '(?:^|\s)-servervault\s+1(?:\s|$)'}).Count){throw 'Vault scenario requires server-vault-only profiles'}
 if($server.port -eq 5122){$secondaryPid=@($owned|Where-Object {$_.ProcessId -in $endpoint.OwningProcess})[0].ProcessId}
}
$request=Join-Path $PSScriptRoot ('reports/'+[IO.Path]::GetFileNameWithoutExtension($Report)+'.stop-destination.json')
$ack=Join-Path $PSScriptRoot ('reports/'+[IO.Path]::GetFileNameWithoutExtension($Report)+'.destination-stopped.json')
foreach($file in @((Join-Path $PSScriptRoot ('reports/'+$Report)),$request,$ack)){if(Test-Path -LiteralPath $file){throw 'Use a new handoff report name'}}
$start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=Join-Path $root 'node_modules/electron/dist/electron.exe';$start.WorkingDirectory=$root;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
if($OriginGc){$start.ArgumentList.Add('--js-flags=--expose-gc')}
foreach($arg in @((Join-Path $PSScriptRoot 'tools/local-host.cjs'),'--portal-handoff-smoke','--allow-server=127.0.0.1:5122','--native-verbose',('--report='+$Report))){$start.ArgumentList.Add($arg)}
if($Scenario -in @('cancel','failure')){$start.ArgumentList.Add('--portal-recovery='+$Scenario)}
if($Scenario -eq 'nui'){$start.ArgumentList.Add('--portal-nui-smoke')}
if($Scenario -eq 'vault'){$start.ArgumentList.Add('--portal-vault-fixture='+$FixtureReport)}
if($Scenario -eq 'sync'){$start.ArgumentList.Add('--portal-sync-fixture='+$SyncFixture)}
if($SyncRecovery -ne 'none'){$start.ArgumentList.Add('--portal-sync-recovery='+$SyncRecovery)}
if($OriginGc){$start.ArgumentList.Add('--native-origin-gc')}
$stopped=$false;$process=[Diagnostics.Process]::Start($start)
try{
 if($Scenario -eq 'failure'){
  while(-not $process.HasExited){
   if(-not $stopped -and (Test-Path -LiteralPath $request)){
    $message=Get-Content -LiteralPath $request -Raw|ConvertFrom-Json
    if($message.kind -ne 'owned-handoff-stop' -or $message.connection -ne 2 -or $message.host -ne '127.0.0.1' -or $message.port -ne 5122){throw 'Unrecognized destination stop request'}
    $secondary=$fixture.servers|Where-Object port -eq 5122
    $current=Get-CimInstance Win32_Process -Filter "ProcessId = $secondaryPid"
    if(-not $current -or $current.ExecutablePath -ne $binary -or -not $current.CommandLine.Contains('"'+$secondary.profile+'"') -or -not $current.CommandLine.Contains($secondary.module)){throw 'Destination PID changed; preserved'}
    & (Join-Path $PSScriptRoot 'tools/handoff-server.ps1') -Action Stop
    $stopped=$true;Wait-Process -Id $secondaryPid -Timeout 5 -ErrorAction SilentlyContinue
    $releaseDeadline=[DateTime]::UtcNow.AddSeconds(8)
    do{
     $remaining=@(Get-NetUDPEndpoint -LocalPort 5122 -ErrorAction SilentlyContinue)
     if(-not $remaining.Count){break}
     if(@($remaining|Where-Object {$_.OwningProcess -ne $secondaryPid}).Count){throw 'Destination port changed owner; preserved'}
     Start-Sleep -Milliseconds 100
    }while([DateTime]::UtcNow -lt $releaseDeadline)
    if($remaining.Count){throw 'Owned destination socket has not been released; preserved'}
    $ackStream=[IO.File]::Open($ack,[IO.FileMode]::CreateNew);try{$bytes=[Text.Encoding]::UTF8.GetBytes('{"port":5122,"stopped":true}');$ackStream.Write($bytes)}finally{$ackStream.Dispose()}
   }
   Start-Sleep -Milliseconds 100
  }
 }
 $process.WaitForExit();$exitCode=$process.ExitCode
}finally{if($stopped -and -not (Get-NetUDPEndpoint -LocalPort 5122 -ErrorAction SilentlyContinue)){& (Join-Path $PSScriptRoot 'tools/handoff-server.ps1') -Action Start}}
exit $exitCode
