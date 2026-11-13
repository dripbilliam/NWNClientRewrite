[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$stage=Join-Path $project '.cache/nwn74/trait-hoist-a'
$private=Join-Path $project '.cache/nwn74/engine-source-f-control'
$relative='servers/rendering/rendering_device.cpp'
$target=Join-Path $private $relative
$overlay=Join-Path $stage 'overlay.cpp'
$object=Join-Path $private 'bin/obj/servers/rendering/rendering_device.windows.template_release.x86_64.obj'
$binary=Join-Path $private 'bin/godot.windows.template_release.x86_64.exe'
$sconsign=Join-Path $private '.sconsign5.dblite'
$acceptedSource=Join-Path $project ".cache/native-tracy/engine-msvc-a/source/$relative"
$acceptedBinary=Join-Path $project '.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe'
$python=Join-Path $project '.cache/native-140fps/render-agent/engine-build-tools-v1/python/python.exe'
$tracy=Join-Path $project '.cache/native-tracy/vendor/tracy-0.13.0'
function Hash([string]$file){(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
$receipt=[ordered]@{issue='NWN-74';private=$true;startUtc=[DateTime]::UtcNow.ToString('o');success=$false;acceptedSourceBefore=Hash $acceptedSource;acceptedBinaryBefore=Hash $acceptedBinary;privateSourceBefore=Hash $target;privateObjectBefore=Hash $object;privateBinaryBefore=Hash $binary;sconsignBefore=Hash $sconsign;overlay=Hash $overlay;freeBeforeBytes=[long](Get-PSDrive C).Free}
if($receipt.acceptedSourceBefore -ne 'cb319128c2650189dc3ebff5aad7e70ac73b0bd4c4d0c58993f06d4d002ddc62'){throw 'Accepted source changed'}
if($receipt.overlay -ne '9de657dbbe6a2d020b0775a9401806b051004f92c48123a1a382267e2d712e45'){throw 'Overlay changed'}
if($receipt.freeBeforeBytes -lt 10GB){throw 'Less than 10 GiB free'}
$backups=@(@($target,(Join-Path $stage 'before-private-rendering-device.cpp')),@($object,(Join-Path $stage 'before-private-rendering-device.obj')),@($binary,(Join-Path $stage 'before-private-engine.exe')),@($sconsign,(Join-Path $stage 'before-private-sconsign.dblite')))
foreach($pair in $backups){if(Test-Path -LiteralPath $pair[1]){throw "Prior backup exists: $($pair[1])"};Copy-Item -LiteralPath $pair[0] -Destination $pair[1]}
$baseArgs=@('-m','SCons','platform=windows','target=template_release','arch=x86_64','use_mingw=no','msvc_version=14.5','disable_path_overrides=no','d3d12=no','debug_symbols=yes','optimize=speed','lto=none','profiler=tracy',"profiler_path=$tracy",'profiler_sample_callstack=no','profiler_track_memory=no','profiler_record_on_demand=yes','-j','2','bin/godot.windows.template_release.x86_64.exe')
function Invoke-Scons([string[]]$arguments,[string]$label){
 $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$python;$start.WorkingDirectory=$private;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.Environment.Remove('NODE_OPTIONS') | Out-Null
 foreach($arg in $arguments){[void]$start.ArgumentList.Add($arg)}
 $proc=[Diagnostics.Process]::new();$proc.StartInfo=$start
 try{
  if(-not $proc.Start()){throw "Could not start $label"}
  $out=$proc.StandardOutput.ReadToEndAsync();$err=$proc.StandardError.ReadToEndAsync();$watch=[Diagnostics.Stopwatch]::StartNew()
  while(-not $proc.WaitForExit(3000)){
   if($watch.Elapsed.TotalSeconds -gt 900){throw "$label exceeded 15-minute watchdog"}
   if([long](Get-PSDrive C).Free -lt 10GB){throw "$label disk headroom below 10 GiB"}
   $privateBytes=0L;foreach($p in @(Get-Process -Name python,cl,c1xx,c2,link -ErrorAction SilentlyContinue)){$privateBytes += [long]$p.PrivateMemorySize64}
   if($privateBytes -gt 8GB){throw "$label compiler private bytes exceeded 8 GiB"}
  }
  $stdout=$out.GetAwaiter().GetResult();$stderr=$err.GetAwaiter().GetResult()
  [IO.File]::WriteAllText((Join-Path $stage "$label.stdout.log"),$stdout)
  [IO.File]::WriteAllText((Join-Path $stage "$label.stderr.log"),$stderr)
  if($proc.ExitCode -ne 0){throw "$label exited $($proc.ExitCode)"}
  return $stdout
 }finally{if($proc.Id -and -not $proc.HasExited){$proc.Kill($true);[void]$proc.WaitForExit(10000)};$proc.Dispose()}
}
try{
 Copy-Item -LiteralPath $overlay -Destination $target -Force
 if((Hash $target) -ne $receipt.overlay){throw 'Overlay copy differs'}
 $dry=Invoke-Scons (@('-m','SCons','-n')+$baseArgs[2..($baseArgs.Count-1)]) 'dryrun'
 $planned=@([regex]::Matches($dry.Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$') | ForEach-Object {$_.Groups[1].Value.Trim()})
 $receipt.plannedCompiles=$planned
 if($planned.Count -ne 1 -or $planned[0] -ne $relative){throw "Dry-run compile set differs: $($planned -join ', ')"}
 $built=Invoke-Scons $baseArgs 'build'
 $actual=@([regex]::Matches($built.Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$') | ForEach-Object {$_.Groups[1].Value.Trim()})
 $receipt.actualCompiles=$actual
 if($actual.Count -ne 1 -or $actual[0] -ne $relative){throw "Actual compile set differs: $($actual -join ', ')"}
 $saved=Join-Path $stage 'Godot_nwn74_trait_hoist_win64.exe'
 if(Test-Path -LiteralPath $saved){throw 'Preserve prior diagnostic binary'}
 Copy-Item -LiteralPath $binary -Destination $saved
 $receipt.binary=[ordered]@{file=$saved;sha256=Hash $saved;bytes=(Get-Item -LiteralPath $saved).Length}
 $receipt.success=$true
}catch{$receipt.failure=$_.Exception.Message}
finally{
 foreach($pair in $backups){Copy-Item -LiteralPath $pair[1] -Destination $pair[0] -Force}
 $receipt.privateSourceRestored=(Hash $target) -eq $receipt.privateSourceBefore
 $receipt.privateObjectRestored=(Hash $object) -eq $receipt.privateObjectBefore
 $receipt.privateBinaryRestored=(Hash $binary) -eq $receipt.privateBinaryBefore
 $receipt.sconsignRestored=(Hash $sconsign) -eq $receipt.sconsignBefore
 $receipt.acceptedSourceUnchanged=(Hash $acceptedSource) -eq $receipt.acceptedSourceBefore
 $receipt.acceptedBinaryUnchanged=(Hash $acceptedBinary) -eq $receipt.acceptedBinaryBefore
 $receipt.freeAfterBytes=[long](Get-PSDrive C).Free
 $receipt.success=$receipt.success -and $receipt.privateSourceRestored -and $receipt.privateObjectRestored -and $receipt.privateBinaryRestored -and $receipt.sconsignRestored -and $receipt.acceptedSourceUnchanged -and $receipt.acceptedBinaryUnchanged
 $receipt.endUtc=[DateTime]::UtcNow.ToString('o')
 $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $stage 'build-receipt.json') -Encoding utf8
}
$receipt | ConvertTo-Json -Depth 4
if(-not $receipt.success){exit 1}
