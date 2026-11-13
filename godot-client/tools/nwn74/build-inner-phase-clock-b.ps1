[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$stage=Join-Path $project '.cache/nwn74/inner-phase-clock-b'
$private=Join-Path $project '.cache/nwn74/engine-source-f-control'
$relative='servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp'
$target=Join-Path $private $relative
$overlay=Join-Path $stage 'render_forward_clustered.cpp'
$object=Join-Path $private 'bin/obj/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.windows.template_release.x86_64.obj'
$binary=Join-Path $private 'bin/godot.windows.template_release.x86_64.exe'
$sconsign=Join-Path $private '.sconsign5.dblite'
$acceptedSource=Join-Path $project ".cache/native-tracy/engine-msvc-a/source/$relative"
$acceptedBinary=Join-Path $project '.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe'
$python=Join-Path $project '.cache/native-140fps/render-agent/engine-build-tools-v1/python/python.exe'
$tracy=Join-Path $project '.cache/native-tracy/vendor/tracy-0.13.0'
function Hash([string]$file){(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
$receipt=[ordered]@{issue='NWN-74';private=$true;diagnosticOnly=$true;startUtc=[DateTime]::UtcNow.ToString('o');success=$false;acceptedSourceBefore=Hash $acceptedSource;acceptedBinaryBefore=Hash $acceptedBinary;privateSourceBefore=Hash $target;privateObjectBefore=Hash $object;privateBinaryBefore=Hash $binary;sconsignBefore=Hash $sconsign;overlay=Hash $overlay;freeBeforeBytes=[long](Get-PSDrive C).Free}
if($receipt.privateSourceBefore -ne '05b7e8379000b331fbb26dedc9577b594eca7d09d7ea7872cbc54078b3837e74' -or $receipt.overlay -ne '0d3c0d5c1f9b1aa3ebf9167615ba68b4783b655098557af5f22e638eadd67e64'){throw 'Private source or diagnostic overlay differs'}
if($receipt.acceptedSourceBefore -ne 'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd'){throw 'Accepted source changed'}
if($receipt.freeBeforeBytes -lt 10.5GB){throw 'Less than 10.5 GiB free before one-TU build'}
$backups=@(@($target,(Join-Path $stage 'before-private-forward.cpp')),@($object,(Join-Path $stage 'before-private-forward.obj')),@($binary,(Join-Path $stage 'before-private-engine.exe')),@($sconsign,(Join-Path $stage 'before-private-sconsign.dblite')))
foreach($pair in $backups){if(Test-Path -LiteralPath $pair[1]){throw "Preserve prior backup $($pair[1])"};Copy-Item -LiteralPath $pair[0] -Destination $pair[1]}
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
   $free=[long](Get-PSDrive C).Free;if($free -lt 10GB){throw "$label disk headroom fell below 10 GiB"}
   $compilers=@(Get-Process -Name python,cl,c1xx,c2,link -ErrorAction SilentlyContinue)
   $privateBytes=0L;foreach($p in $compilers){$privateBytes += [long]$p.PrivateMemorySize64}
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
 $saved=Join-Path $stage 'Godot_nwn74_inner_phase_clock_b_win64.exe'
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
