[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Plan,
  [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$PlanSha
)
$ErrorActionPreference='Stop'
function NwnHash([string]$File){(Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()}
$planFile=[IO.Path]::GetFullPath($Plan)
if((NwnHash $planFile)-ne$PlanSha){throw 'Private plan pin differs'}
$p=Get-Content -LiteralPath $planFile -Raw|ConvertFrom-Json
if($p.schema-ne'nwn71-isolated-compositor-callback-v1'){throw 'Wrong private plan'}
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$expected=[IO.Path]::GetFullPath((Join-Path $workspace '.cache/nwn71/compositor-callback-a/source'))
if($p.source-ne$expected){throw 'Build source is not the isolated clone'}
if((NwnHash $p.target.file)-ne$p.target.sha256-or(NwnHash $p.after.file)-ne$p.after.sha256-or(NwnHash $p.before.file)-ne$p.before.sha256){throw 'Private source patch pin differs'}
if((NwnHash $p.python.file)-ne$p.python.sha256-or(NwnHash $p.parentDiagnostic.file)-ne$p.parentDiagnostic.sha256){throw 'Tool or parent diagnostic pin differs'}
if(-not(@($p.args)-contains'-j')-or[string]::Join(' ',@($p.args))-notmatch ' -j 2 '){throw 'Only two compiler jobs are permitted'}
$stage=Split-Path $p.source -Parent
$dry=Join-Path $stage 'dryrun-patched.log'
if(-not(Test-Path -LiteralPath $dry)){throw 'Dry-run evidence missing'}
$planned=@(Get-Content -LiteralPath $dry|Where-Object{$_ -match '^Compiling '}|ForEach-Object{$_.Trim()})
if($planned.Count-lt1-or$planned.Count-gt[int]$p.maximumCompiles){throw 'Dry-run exceeds the narrow compile cap'}
if(-not($planned -match 'renderer_scene_render_rd.cpp')){throw 'Callback translation unit absent from dry-run'}
$free=(Get-PSDrive C).Free
if($free-lt[long]$p.minimumFreeBytes){throw 'Private build leaves too little disk space'}
$receipt=Join-Path $stage 'build-receipt.json'
if(Test-Path -LiteralPath $receipt){throw 'Preserve prior build receipt'}
$started=[DateTime]::UtcNow.ToString('o')
$info=[Diagnostics.ProcessStartInfo]::new()
$info.FileName=$p.python.file
$info.WorkingDirectory=$p.source
$info.UseShellExecute=$false
$info.CreateNoWindow=$true
$info.WindowStyle='Hidden'
$info.RedirectStandardOutput=$true
$info.RedirectStandardError=$true
$info.Environment.Remove('NODE_OPTIONS')|Out-Null
foreach($arg in $p.args){$info.ArgumentList.Add([string]$arg)}
$process=[Diagnostics.Process]::new();$process.StartInfo=$info
$proof=@{schema=$p.schema;planSha256=$PlanSha;startedUtc=$started;source=$p.source;sourceSha256=$p.target.sha256;dryrunSha256=(NwnHash $dry);plannedCompiles=$planned;success=$false;exit=$null;peakPrivateBytes=0L;peakWorkingSetBytes=0L;minimumFreeBytes=[long]$free;scope='Private clone only, -j2, 6 GiB aggregate compiler-process guard. No FPS measurement.'}
$outTask=$null;$errTask=$null
try{
 if(-not$process.Start()){throw 'SCons process failed to start'}
 $proof.pid=$process.Id
 $outTask=$process.StandardOutput.ReadToEndAsync()
 $errTask=$process.StandardError.ReadToEndAsync()
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not$process.WaitForExit(1500)){
  if($watch.Elapsed.TotalSeconds-gt[int]$p.maximumSeconds){throw 'Private build exceeded time cap'}
  $procs=@(Get-Process -Name cl,c1xx,link,python,pythonw -ErrorAction SilentlyContinue)
  $private=0L;$working=0L
  foreach($item in $procs){$private+=[long]$item.PrivateMemorySize64;$working+=[long]$item.WorkingSet64}
  $proof.peakPrivateBytes=[Math]::Max([long]$proof.peakPrivateBytes,$private)
  $proof.peakWorkingSetBytes=[Math]::Max([long]$proof.peakWorkingSetBytes,$working)
  if($private-gt[long]$p.memoryCapBytes-or$working-gt[long]$p.memoryCapBytes){throw 'Compiler process memory exceeded 6 GiB cap'}
  $remaining=(Get-PSDrive C).Free
  $proof.minimumFreeBytes=[Math]::Min([long]$proof.minimumFreeBytes,[long]$remaining)
  if($remaining-lt[long]$p.minimumFreeBytes){throw 'Private build crossed 8 GiB free-space floor'}
 }
 $proof.exit=$process.ExitCode
 if($proof.exit-ne0){throw "SCons exited $($proof.exit)"}
 $stdout=$outTask.GetAwaiter().GetResult();$stderr=$errTask.GetAwaiter().GetResult()
 $actual=@($stdout -split "`r?`n"|Where-Object{$_ -match '^Compiling '}|ForEach-Object{$_.Trim()})
 $proof.actualCompiles=$actual
 if($actual.Count-ne$planned.Count-or@(Compare-Object $planned $actual).Count-ne0){throw 'Actual compile set differs from dry-run'}
 $binary=Join-Path $p.source 'bin/godot.windows.template_release.x86_64.exe'
 $saved=Join-Path $stage 'Godot_nwn71_compositor_callback_win64.exe'
 if(-not(Test-Path -LiteralPath $binary)-or(Test-Path -LiteralPath $saved)){throw 'Private binary missing or prior output exists'}
 Copy-Item -LiteralPath $binary -Destination $saved
 $proof.binary=@{file=$saved;sha256=(NwnHash $saved);bytes=(Get-Item -LiteralPath $saved).Length}
 $proof.success=$true
}catch{$proof.failure=$_.Exception.Message}finally{
 if($process.Id-and-not$process.HasExited){$process.Kill($true);[void]$process.WaitForExit(10000);$proof.forcedStop=$true}
 if($outTask-and$outTask.Wait(10000)){[IO.File]::WriteAllText((Join-Path $stage 'build.stdout.log'),$outTask.GetAwaiter().GetResult())}
 if($errTask-and$errTask.Wait(10000)){[IO.File]::WriteAllText((Join-Path $stage 'build.stderr.log'),$errTask.GetAwaiter().GetResult())}
 $proof.finishedUtc=[DateTime]::UtcNow.ToString('o')
 $proof.sourceUnchanged=(NwnHash $p.target.file)-eq$p.target.sha256
 $proof.parentUnchanged=(NwnHash $p.parentDiagnostic.file)-eq$p.parentDiagnostic.sha256
 $proof.success=$proof.success-and$proof.sourceUnchanged-and$proof.parentUnchanged
 $proof|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $receipt -Encoding utf8
 $process.Dispose()
}
$proof|ConvertTo-Json -Depth 3
if(-not$proof.success){throw $proof.failure}
