param(
 [string[]]$Cases=@(),
 [string]$OutputRoot='',
 [string]$Install='',
 [ValidateRange(5,180)][int]$CaseTimeoutSeconds=60,
 [switch]$List,
 [switch]$AllowFailureProbe
)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Split-Path $project -Parent
$godot=Join-Path $project '.tools/Godot_v4.7.2-stable_win64_console.exe'
$pwsh=(Get-Command pwsh -ErrorAction Stop).Source
$catalog=[ordered]@{}
foreach($name in @('nwn79_native_server_status_test.gd','nwn79_native_character_needed_test.gd','nwn79_native_runtime_52_54_test.gd','nwn79_native_login_packets_test.gd','nwn79_native_world_state_test.gd','nwn79_native_nwsync_wait_visibility_test.gd','nwn79_native_creature_voice_session_test.gd','nwn79_native_levelup_transaction_test.gd','nwn79_native_object_updates_test.gd','nwn79_native_player_requests_test.gd')){
 $id=$name.Substring(0,$name.Length-8)
 $catalog[$id]=[ordered]@{kind='godot';path=('tests/'+$name);marker='(?m)\bPASS\b'}
}
$resourceCases=@('nwn79_workshop_admission_test.gd','nwn79_workshop_audio_mount_test.gd','nwn79_workshop_audio_preference_test.gd','nwn79_erf_bytes_index_test.gd','nwn79_nwsync_nested_archive_test.gd','nwn79_installed_key_selection_test.gd','nwn79_custom_tlk_admission_test.gd','nwn79_tlk_unknown_language_test.gd','nwn79_erf_file_stamp_test.gd','nwn79_nwsync_nested_archive_borrow_test.gd','nwn79_nwsync_archive_tlk_repair_test.gd','nwn79_native_install_selection_test.gd')
foreach($name in $resourceCases){
 $id=$name.Substring(0,$name.Length-8)
 $resultKind=if($name -eq 'nwn79_native_install_selection_test.gd'){'marker'}elseif($name -in @('nwn79_nwsync_nested_archive_borrow_test.gd','nwn79_nwsync_archive_tlk_repair_test.gd')){'stdout-json'}else{'report-json'}
 $catalog[$id]=[ordered]@{kind='godot';path=('tests/'+$name);marker='(?m)\bPASS\b';resultKind=$resultKind}
}
$resourceIds=@($resourceCases|ForEach-Object {$_.Substring(0,$_.Length-8)})
$catalog['ps-local-smoke-receipt']=[ordered]@{kind='powershell';path='tools/nwn79/test-local-smoke-receipt.ps1';marker='nwn79-local-smoke-validator-test-v1'}
$catalog['ps-handoff-roundtrip-receipt']=[ordered]@{kind='powershell';path='tools/nwn79/test-direct-handoff-roundtrip-receipt.ps1';marker='nwn79-direct-handoff'}
$catalog['ps-native-loading-capture']=[ordered]@{kind='powershell';path='tools/nwn79/test-native-loading-capture-verifier.ps1';marker='nwn79-native-loading-capture-verifier-test-v1'}
$catalog['godot-only-guard']=[ordered]@{kind='powershell';path='tools/nwn79/check-godot-only.ps1';marker='Godot-only runtime guard PASS'}
if($List){$catalog.GetEnumerator()|ForEach-Object {[ordered]@{id=$_.Key;kind=$_.Value.kind;path=$_.Value.path}}|ConvertTo-Json -Depth 4;return}
if($Cases.Count -eq 0){$Cases=@($catalog.Keys|Where-Object {$_ -notin $resourceIds})}
if(@($Cases|Select-Object -Unique).Count -ne $Cases.Count){throw 'Duplicate focused test case'}
foreach($id in $Cases){if(-not$catalog.Contains($id) -and $id -ne '_intentional_failure'){throw ('Unknown focused test case: '+$id)}}
if($Cases -contains '_intentional_failure' -and -not$AllowFailureProbe){throw 'Intentional failure probe requires -AllowFailureProbe'}
if($Cases -contains 'nwn79_workshop_audio_mount' -and (-not$Install -or -not(Test-Path -LiteralPath $Install -PathType Container))){throw 'Workshop audio mount test requires -Install with an existing NWN installation directory'}
if(-not(Test-Path -LiteralPath $godot -PathType Leaf)){throw 'Pinned Godot console is unavailable; run tools/setup.ps1'}
if((Get-FileHash -LiteralPath $godot -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643'){throw 'Focused suite requires the pinned Godot console'}
$output=if($OutputRoot){[IO.Path]::GetFullPath($OutputRoot)}else{Join-Path $workspace ('.cache/nwn79-focused-tests-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))}
if(-not$output.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)){throw 'Focused test output must be a fresh workspace directory'}
New-Item -ItemType Directory -Path $output -Force|Out-Null
$results=[ordered]@{}
foreach($id in $Cases){
 $spec=if($id -eq '_intentional_failure'){@{kind='failure-probe';path='';marker='never'}}else{$catalog[$id]}
 $path=if($spec.path){Join-Path $project $spec.path}else{''}
 $row=[ordered]@{status='fail';kind=$spec.kind;path=$spec.path;exitCode=-1;timedOut=$false;markerMatched=$false;stdout=($id+'.stdout.txt');stderr=($id+'.stderr.txt')}
 try{
  if($path -and -not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Focused test source is missing: '+$spec.path)}
  $start=[Diagnostics.ProcessStartInfo]::new()
  $start.FileName=if($spec.kind -eq 'godot'){$godot}else{$pwsh}
  $start.WorkingDirectory=$project;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
  $arguments=if($spec.kind -eq 'godot'){@('--headless','--path',$project,'--script',('res://'+$spec.path.Replace('\','/')))}elseif($spec.kind -eq 'failure-probe'){@('-NoProfile','-Command','exit 23')}else{@('-NoProfile','-File',$path)}
  if($spec.kind -eq 'godot' -and $spec.resultKind -in @('report-json','stdout-json')){
   if($spec.resultKind -eq 'report-json'){$arguments+=@('--',('--report='+(Join-Path $output ($id+'.result.json'))))}
   elseif($id -eq 'nwn79_nwsync_nested_archive_borrow'){$arguments+=@('--',('--scratch='+(Join-Path $output ($id+'.scratch'))))}
  }
  if($id -eq 'nwn79_workshop_audio_mount'){$arguments+=('--install='+[IO.Path]::GetFullPath($Install))}
  foreach($argument in $arguments){[void]$start.ArgumentList.Add([string]$argument)}
  $process=[Diagnostics.Process]::Start($start)
  if($process -eq $null){throw 'Focused test process did not start'}
  try{
   $stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync()
   if(-not$process.WaitForExit($CaseTimeoutSeconds*1000)){$row.timedOut=$true;$process.Kill($true);[void]$process.WaitForExit(10000)}
   $stdout=$stdoutTask.GetAwaiter().GetResult();$stderr=$stderrTask.GetAwaiter().GetResult()
   [IO.File]::WriteAllText((Join-Path $output $row.stdout),$stdout)
   [IO.File]::WriteAllText((Join-Path $output $row.stderr),$stderr)
   $row.exitCode=$process.ExitCode
   if($spec.resultKind -eq 'report-json'){
    $resultFile=Join-Path $output ($id+'.result.json')
    $row.result=($id+'.result.json')
    if(Test-Path -LiteralPath $resultFile){$result=Get-Content -LiteralPath $resultFile -Raw|ConvertFrom-Json;$row.markerMatched=($result.success -eq $true -and @($result.failures).Count -eq 0)}
   }elseif($spec.resultKind -eq 'stdout-json'){
    $resultLine=@($stdout -split "`r?`n"|Where-Object {$_.Trim().StartsWith('{')})|Select-Object -Last 1
    if($resultLine){$result=$resultLine|ConvertFrom-Json;$row.markerMatched=($result.success -eq $true -and @($result.failures).Count -eq 0)}
   }else{$row.markerMatched=[regex]::IsMatch($stdout,[string]$spec.marker)}
   if(-not$row.timedOut -and $row.exitCode -eq 0 -and $row.markerMatched){$row.status='pass'}
   else{$row.reason='exit='+$row.exitCode+' timeout='+$row.timedOut+' marker='+$row.markerMatched}
  }finally{$process.Dispose()}
 }catch{$row.reason=$_.Exception.Message}
 $results[$id]=$row
 Write-Output ($id+': '+$row.status)
}
$failed=@($results.Keys|Where-Object {$results[$_].status -ne 'pass'})
$summary=[ordered]@{format='nwn79-focused-godot-powershell-suite-v1';scope='Curated offline NWN-79 Godot/PowerShell regression suite; private-server, graphical, process-tree and live-settings audits are separate';project=$project;engineSha256=(Get-FileHash -LiteralPath $godot -Algorithm SHA256).Hash.ToLowerInvariant();cases=$results;passed=($failed.Count -eq 0);failed=$failed}
$receipt=Join-Path $output 'summary.json'
[IO.File]::WriteAllText($receipt,($summary|ConvertTo-Json -Depth 8))
Write-Output ('Focused test receipt: '+$receipt)
if($failed.Count){throw ('Focused test failures: '+($failed -join ', '))}
