[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$stage=Join-Path $project '.cache/nwn71/sync-owner-clock-a'
$clone=Join-Path $project '.cache/nwn71/compositor-callback-a/source'
$plan=Get-Content -LiteralPath (Join-Path $stage 'source-receipt.json') -Raw | ConvertFrom-Json
$python=Join-Path $project '.cache/native-140fps/render-agent/engine-build-tools-v1/python/python.exe'
$tracy=Join-Path $project '.cache/native-tracy/vendor/tracy-0.13.0'
$binary=Join-Path $clone 'bin/godot.windows.template_release.x86_64.exe'
$acceptedBinary=Join-Path $project '.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe'
$sconsign=Join-Path $clone '.sconsign5.dblite'
function Hash([string]$file){(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
if(-not $plan.private -or $plan.changes.Count -ne 4){throw 'Private source receipt differs'}
if((Hash $binary) -ne '633473723181e5b6a5c5190a84f4e2be80b8e15fa81ab46d8318ad3b497ed910'){throw 'Private engine base changed'}
if([long](Get-PSDrive C).Free -lt 9.7GB){throw 'Less than 9.7 GiB free before private build'}
$receipt=[ordered]@{issue='NWN-71';private=$true;diagnosticOnly=$true;startUtc=[DateTime]::UtcNow.ToString('o');success=$false;sourceReceiptSha256=Hash (Join-Path $stage 'source-receipt.json');privateBinaryBefore=Hash $binary;acceptedBinaryBefore=Hash $acceptedBinary;sconsignBefore=Hash $sconsign;freeBeforeBytes=[long](Get-PSDrive C).Free;files=@()}
$backups=@()
foreach($change in $plan.changes){
 $src=Join-Path $clone $change.relative
 $before=Join-Path (Join-Path $stage 'before') $change.relative
 $after=Join-Path (Join-Path $stage 'after') $change.relative
 $objRelative='bin/obj/'+($change.relative -replace '\.cpp$','.windows.template_release.x86_64.obj')
 $obj=Join-Path $clone $objRelative
 $objBackup=Join-Path (Join-Path $stage 'objects-before') $objRelative
 if((Hash $src) -ne $change.beforeSha256 -or (Hash $before) -ne $change.beforeSha256 -or (Hash $after) -ne $change.afterSha256){throw "Source pin differs $($change.relative)"}
 $accepted=Join-Path (Join-Path $project '.cache/native-tracy/engine-msvc-a/source') $change.relative
 if((Hash $accepted) -ne $change.beforeSha256){throw "Accepted source differs $($change.relative)"}
 if(-not(Test-Path -LiteralPath $obj)){throw "Missing private object $objRelative"}
 if(Test-Path -LiteralPath $objBackup){throw 'Preserve prior object backup'}
 [IO.Directory]::CreateDirectory((Split-Path -Parent $objBackup))|Out-Null
 Copy-Item -LiteralPath $obj -Destination $objBackup
 $backups+=@{source=$src;before=$before;object=$obj;objectBackup=$objBackup;sourceHash=$change.beforeSha256;objectHash=Hash $obj;accepted=$accepted}
 $receipt.files+=@{relative=$change.relative;sourceBefore=$change.beforeSha256;overlay=$change.afterSha256;objectBefore=Hash $obj}
}
$binaryBackup=Join-Path $stage 'private-binary-before.exe';$sconsignBackup=Join-Path $stage 'private-sconsign-before.dblite'
if((Test-Path -LiteralPath $binaryBackup) -or (Test-Path -LiteralPath $sconsignBackup)){throw 'Preserve previous build backups'}
Copy-Item -LiteralPath $binary -Destination $binaryBackup;Copy-Item -LiteralPath $sconsign -Destination $sconsignBackup
$baseArgs=@('-m','SCons','platform=windows','target=template_release','arch=x86_64','use_mingw=no','msvc_version=14.5','disable_path_overrides=no','d3d12=no','debug_symbols=yes','optimize=speed','lto=none','profiler=tracy',"profiler_path=$tracy",'profiler_sample_callstack=no','profiler_track_memory=no','profiler_record_on_demand=yes','-j','2','bin/godot.windows.template_release.x86_64.exe')
function Invoke-Scons([string[]]$arguments,[string]$label){
 $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$python;$start.WorkingDirectory=$clone;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.Environment.Remove('NODE_OPTIONS')|Out-Null
 foreach($arg in $arguments){[void]$start.ArgumentList.Add($arg)}
 $proc=[Diagnostics.Process]::new();$proc.StartInfo=$start
 try{
  if(-not$proc.Start()){throw "Could not start $label"}
  $stdout=$proc.StandardOutput.ReadToEndAsync();$stderr=$proc.StandardError.ReadToEndAsync();$watch=[Diagnostics.Stopwatch]::StartNew()
  while(-not$proc.WaitForExit(3000)){
   if($watch.Elapsed.TotalSeconds -gt 900){throw "$label exceeded 15-minute watchdog"}
   if([long](Get-PSDrive C).Free -lt 9GB){throw "$label free disk fell below 9 GiB"}
   $processes=@(Get-Process -Name python,cl,c1xx,c2,link -ErrorAction SilentlyContinue)
   $privateBytes=0L;foreach($p in $processes){$privateBytes += [long]$p.PrivateMemorySize64}
   if($privateBytes -gt 8GB){throw "$label compiler private bytes exceeded 8 GiB"}
  }
  $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult()
  [IO.File]::WriteAllText((Join-Path $stage "$label.stdout.log"),$out);[IO.File]::WriteAllText((Join-Path $stage "$label.stderr.log"),$err)
  if($proc.ExitCode -ne 0){throw "$label exited $($proc.ExitCode)"}
  return $out
 }finally{if($proc.Id -and -not$proc.HasExited){$proc.Kill($true);[void]$proc.WaitForExit(10000)};$proc.Dispose()}
}
try{
 foreach($change in $plan.changes){Copy-Item -LiteralPath (Join-Path (Join-Path $stage 'after') $change.relative) -Destination (Join-Path $clone $change.relative) -Force}
 $dry=Invoke-Scons (@('-m','SCons','-n')+$baseArgs[2..($baseArgs.Count-1)]) 'dryrun'
 $planned=@([regex]::Matches($dry.Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$')|ForEach-Object {$_.Groups[1].Value.Trim()})
 $receipt.plannedCompiles=$planned
 $wanted=@($plan.changes|ForEach-Object {$_.relative}|Sort-Object)
 if((@($planned|Sort-Object) -join '|') -ne ($wanted -join '|')){throw "Unexpected dry-run compile set: $($planned -join ', ')"}
 $built=Invoke-Scons $baseArgs 'build'
 $actual=@([regex]::Matches($built.Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$')|ForEach-Object {$_.Groups[1].Value.Trim()})
 $receipt.actualCompiles=$actual
 if((@($actual|Sort-Object) -join '|') -ne ($wanted -join '|')){throw "Unexpected actual compile set: $($actual -join ', ')"}
 $saved=Join-Path $stage 'Godot_nwn71_sync_owner_clock_a_win64.exe'
 if(Test-Path -LiteralPath $saved){throw 'Preserve previous diagnostic binary'}
 Copy-Item -LiteralPath $binary -Destination $saved
 $receipt.binary=@{file=$saved;sha256=Hash $saved;bytes=(Get-Item -LiteralPath $saved).Length}
 $receipt.success=$true
}catch{$receipt.failure=$_.Exception.Message}
finally{
 foreach($item in $backups){Copy-Item -LiteralPath $item.before -Destination $item.source -Force;Copy-Item -LiteralPath $item.objectBackup -Destination $item.object -Force}
 Copy-Item -LiteralPath $binaryBackup -Destination $binary -Force;Copy-Item -LiteralPath $sconsignBackup -Destination $sconsign -Force
 $receipt.privateSourceRestored=@($backups|Where-Object {(Hash $_.source) -ne $_.sourceHash}).Count -eq 0
 $receipt.privateObjectsRestored=@($backups|Where-Object {(Hash $_.object) -ne $_.objectHash}).Count -eq 0
 $receipt.acceptedSourcesUnchanged=@($backups|Where-Object {(Hash $_.accepted) -ne $_.sourceHash}).Count -eq 0
 $receipt.privateBinaryRestored=(Hash $binary) -eq $receipt.privateBinaryBefore
 $receipt.acceptedBinaryUnchanged=(Hash $acceptedBinary) -eq $receipt.acceptedBinaryBefore
 $receipt.sconsignRestored=(Hash $sconsign) -eq $receipt.sconsignBefore
 $receipt.freeAfterBytes=[long](Get-PSDrive C).Free
 $receipt.success=$receipt.success -and $receipt.privateSourceRestored -and $receipt.privateObjectsRestored -and $receipt.acceptedSourcesUnchanged -and $receipt.privateBinaryRestored -and $receipt.acceptedBinaryUnchanged -and $receipt.sconsignRestored
 $receipt.endUtc=[DateTime]::UtcNow.ToString('o')
 $receipt|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $stage 'build-receipt.json') -Encoding utf8
}
$receipt|ConvertTo-Json -Depth 4
if(-not$receipt.success){exit 1}
