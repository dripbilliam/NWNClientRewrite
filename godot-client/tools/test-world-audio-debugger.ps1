param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='world-audio-debugger-v1',[ValidateRange(1,5)][int]$Count=3)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$workspace=Split-Path $project -Parent
$output=Join-Path $project ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $output){throw 'Audio debugger report exists'}
. (Join-Path $PSScriptRoot 'local-test-guard.ps1');Assert-NativeLocalTestAvailable $project
$cdbExecutable='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe'
$engine=[IO.Path]::GetFullPath((Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'))
if(-not(Test-Path -LiteralPath $cdbExecutable)){throw 'Installed local debugger unavailable'}
$sourceNames=@('systems/world_audio.gd','systems/creation_audio.gd','systems/world_sound_state.gd','systems/audio_stream_transfer.gd','systems/local_connection.gd','systems/visual_runtime.gd','systems/area_visual_runtime.gd','systems/visual_probe.gd','tools/world-audio.mjs','tools/world-audio-evidence.cjs','tools/shutdown-evidence.cjs','tools/local-host.cjs')
$hashes=@{};foreach($name in $sourceNames){$hashes[$name]=(Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()}
$rows=[Collections.Generic.List[object]]::new();$failure=$null;$restored=$false
try{
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Stop
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module GodotSounds2
 for($i=1;$i-le$Count;$i++){
  $name=$Run+'-'+$i;$reportFile=Join-Path $project ('reports/'+$name+'.json');$debugLog=Join-Path $project ('reports/'+$name+'.cdb.log');$commands=Join-Path $project ('reports/'+$name+'.cdb.txt')
  if(Test-Path -LiteralPath $reportFile){throw 'Per-run debugger target exists'}
  $break='.echo OWNED_AUDIO_EXCEPTION;.exr -1;.ecxr;kv;~* k;q'
  @('.echo OWNED_AUDIO_START',('sxe -c "'+$break+'" av'),('sxe -c "'+$break+'" 0xc0000374'),('sxe -c "'+$break+'" 0xc0000409'),('sxe -c "'+$break+'" 0xc000001d'),'.echo OWNED_AUDIO_ARMED','g')|Set-Content -LiteralPath $commands -Encoding ascii
  $launch=[Diagnostics.ProcessStartInfo]::new();$launch.FileName=(Get-Command pwsh).Source;$launch.WorkingDirectory=$workspace;$launch.UseShellExecute=$false;$launch.CreateNoWindow=$true;$launch.RedirectStandardOutput=$true;$launch.RedirectStandardError=$true
  foreach($arg in @('-NoProfile','-File',(Join-Path $project 'join-local.ps1'),'-WorldAudioSmoke','-AutoPlay','-NativeVerbose','-Report',($name+'.json'))){$launch.ArgumentList.Add($arg)}
  $child=[Diagnostics.Process]::Start($launch);$stdout=$child.StandardOutput.ReadToEndAsync();$stderr=$child.StandardError.ReadToEndAsync();$deadline=[DateTime]::UtcNow.AddSeconds(30);$target=$null
  while(-not$child.HasExited-and[DateTime]::UtcNow-lt$deadline){
   $targets=@(Get-CimInstance Win32_Process -Filter "Name = 'Godot_v4.7.2-stable_win64.exe'" | Where-Object {$_.ExecutablePath-eq$engine-and$_.CommandLine.Contains('--local-ticket=')})
   if($targets.Count-eq1){$target=$targets[0];break}
   if($targets.Count-gt1){throw 'Ambiguous native target; preserved all processes'}
   Start-Sleep -Milliseconds 100
  }
  if($null-eq$target){throw 'Owned native target did not appear for debugger attachment'}
  $debug=[Diagnostics.ProcessStartInfo]::new();$debug.FileName=$cdbExecutable;$debug.WorkingDirectory=$workspace;$debug.UseShellExecute=$false;$debug.CreateNoWindow=$true;$debug.RedirectStandardOutput=$true;$debug.RedirectStandardError=$true
  foreach($arg in @('-G','-sins','-y',(Join-Path $project '.tools'),'-logo',$debugLog,'-cf',$commands,'-p',[string]$target.ProcessId)){$debug.ArgumentList.Add($arg)}
  $debugger=[Diagnostics.Process]::Start($debug);$debugOut=$debugger.StandardOutput.ReadToEndAsync();$debugErr=$debugger.StandardError.ReadToEndAsync();$timer=[Diagnostics.Stopwatch]::StartNew();$forced=$false
  while(-not$child.WaitForExit(1000)){
   if($timer.Elapsed.TotalSeconds-gt210){$forced=$true;$child.Kill($true);$child.WaitForExit();break}
  }
  if(-not$debugger.WaitForExit(5000)){$forced=$true;$debugger.Kill();$debugger.WaitForExit()}
  ($stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult())|Set-Content -LiteralPath (Join-Path $project ('reports/'+$name+'.launcher.log')) -Encoding utf8
  ($debugOut.GetAwaiter().GetResult()+$debugErr.GetAwaiter().GetResult())|Set-Content -LiteralPath (Join-Path $project ('reports/'+$name+'.debugger-stdout.log')) -Encoding utf8
  $text=Get-Content -LiteralPath $debugLog -Raw;$armed=$text-match'(?m)^OWNED_AUDIO_START\r?$'-and$text-match'(?m)^OWNED_AUDIO_ARMED\r?$';$exception=$text-match'(?m)^OWNED_AUDIO_EXCEPTION\r?$'
  $report=Get-Content -LiteralPath $reportFile -Raw|ConvertFrom-Json
  $unchanged=$true;foreach($source in $sourceNames){if((Get-FileHash -LiteralPath (Join-Path $project $source) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hashes[$source]){$unchanged=$false}}
  $row=@{report=$name+'.json';targetPid=$target.ProcessId;debuggerArmed=$armed;debuggerException=$exception;debuggerLog=$name+'.cdb.log';launcherExit=$child.ExitCode;debuggerExit=$debugger.ExitCode;nativeExit=$report.nativeExit;checks=@($report.visualTest.checks).Count;forced=$forced;sourceUnchanged=$unchanged;workloadPassed=($armed-and-not$exception-and-not$forced-and$unchanged-and$child.ExitCode-eq0-and$report.success)}
  $rows.Add($row);Write-Output ($row|ConvertTo-Json -Compress)
  if(-not$row.workloadPassed){throw ('Audio debugger run did not complete cleanly: '+$name)}
 }
}catch{$failure=$_.Exception.Message}
finally{
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Stop
 & (Join-Path $workspace 'scripts/local-multiplayer-server.ps1') -Action Start -Module Prelude
 $restored=$true
 @{scope='Debugger attaches only to the newly launched pinned replacement process; original binaries/editor untouched, no public server and no remote symbol downloads';success=($null-eq$failure-and$rows.Count-eq$Count);runs=@($rows.ToArray());expected=$Count;failure=$failure;sourceSha256=$hashes;ordinaryServerRestored=$restored}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $output -Encoding utf8
}
if($failure){throw $failure}
