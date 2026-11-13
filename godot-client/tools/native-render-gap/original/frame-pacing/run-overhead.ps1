param([Parameter(Mandatory=$true)][string]$Engine,[Parameter(Mandatory=$true)][string]$EngineSha,[ValidatePattern('^[a-z0-9-]+$')][string]$Label='a',[ValidateRange(240,1000000)][int]$Iterations=2400,[switch]$ResumeSafeCompleted)
$ErrorActionPreference='Stop'
$paceProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$paceRoot=Join-Path $paceProject ('.cache/native-render-gap/original/frame-pacing/overhead-'+$Label)
$paceManifest=Get-Content -LiteralPath (Join-Path $paceRoot 'manifest.json') -Raw|ConvertFrom-Json
$paceEngine=[IO.Path]::GetFullPath($Engine)
function Assert-PacingInputs {
 if((Get-FileHash -LiteralPath $paceEngine).Hash.ToLowerInvariant()-ne$EngineSha){throw 'Common engine drift'}
 foreach($pacePin in $paceManifest.pins){if((Get-FileHash -LiteralPath (Join-Path $paceManifest.renderer $pacePin.relative)).Hash.ToLowerInvariant()-ne$pacePin.sha256){throw 'Fixture input drift'}}
}
$paceCases=@(@('safe-off-a','safe',$false),@('safe-on-a','safe',$true),@('safe-on-b','safe',$true),@('safe-off-b','safe',$false),@('separate-off','separate',$false),@('separate-on','separate',$true))
$paceResults=@()
if($ResumeSafeCompleted){
 foreach($paceName in @('safe-off-a','safe-on-a','safe-on-b','safe-off-b')){
  $pacePrevious=Get-Content -LiteralPath (Join-Path $paceRoot ($paceName+'/receipt.json')) -Raw|ConvertFrom-Json
  if(-not$pacePrevious.success-or$pacePrevious.iterations-ne$Iterations-or$pacePrevious.mode-ne'safe'){throw 'Wrong completed safe child'}
  $paceResults+=$pacePrevious
 }
 $paceCases=@(@('separate-off-resumed','separate',$false),@('separate-on','separate',$true))
}
foreach($paceCase in $paceCases){
 Assert-PacingInputs
 $paceName=$paceCase[0];$paceMode=$paceCase[1];$paceEnabled=[bool]$paceCase[2]
 $paceRun=Join-Path $paceRoot $paceName
 if(Test-Path -LiteralPath $paceRun){throw ('Preserve prior '+$paceName)}
 New-Item -ItemType Directory -Path $paceRun | Out-Null
 $paceReport=Join-Path $paceRun 'native.json'
 $paceArguments=@('--headless','--rendering-method','dummy','--audio-driver','Dummy','--fixed-fps','1000','--render-thread',$paceMode,'--disable-render-loop','--path',$paceManifest.renderer,'--script','res://fixture.gd','--',('--report='+$paceReport),('--iterations='+$Iterations),'--warmup=2000')
 if($paceEnabled){$paceArguments+='--frame-pacing-metrics=on'}
 $paceStart=[Diagnostics.ProcessStartInfo]::new();$paceStart.FileName=$paceEngine;$paceStart.UseShellExecute=$false;$paceStart.CreateNoWindow=$true;$paceStart.RedirectStandardOutput=$true;$paceStart.RedirectStandardError=$true
 foreach($paceArgument in $paceArguments){$paceStart.ArgumentList.Add($paceArgument)}
 $paceStart.Environment['APPDATA']=Join-Path $paceRun 'appdata';$paceStart.Environment['LOCALAPPDATA']=Join-Path $paceRun 'localappdata'
 $paceChild=[Diagnostics.Process]::new();$paceChild.StartInfo=$paceStart;$paceWatch=[Diagnostics.Stopwatch]::StartNew();[void]$paceChild.Start()
 @{pid=$paceChild.Id;engine=$paceEngine;engineSha256=$EngineSha;arguments=$paceArguments;startedUtc=[DateTime]::UtcNow.ToString('o');gpu=$false;scope='Owned dummy headless CPU overhead child'}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $paceRun 'process.json') -Encoding utf8
 Write-Output ('Started pacing overhead '+$paceName+' PID '+$paceChild.Id)
 $paceStdout=$paceChild.StandardOutput.ReadToEndAsync();$paceStderr=$paceChild.StandardError.ReadToEndAsync()
 if(-not$paceChild.WaitForExit(30000)){$paceChild.Kill();$paceChild.WaitForExit();throw 'Owned pacing headless child timed out'}
 $paceWatch.Stop();$paceChild.Refresh();$paceCpu=$paceChild.TotalProcessorTime.TotalMilliseconds;$paceCode=$paceChild.ExitCode
 $paceOut=$paceStdout.GetAwaiter().GetResult();$paceErr=$paceStderr.GetAwaiter().GetResult();[IO.File]::WriteAllText((Join-Path $paceRun 'stdout.log'),$paceOut);[IO.File]::WriteAllText((Join-Path $paceRun 'stderr.log'),$paceErr)
 $paceChild.Dispose();Assert-PacingInputs
 # The standard experimental separate-thread WARNING contains "crashes".
 # Reject fatal diagnostics rather than that expected capability warning.
 if($paceCode-ne0-or($paceOut+$paceErr)-match'SCRIPT ERROR|ERROR:|Parse Error|Compile Error|leaked|still in use|CrashHandler|crash (?:dump|backtrace)|signal 11'){Get-Content -LiteralPath (Join-Path $paceRun 'stderr.log') -Tail 18;throw ('Pacing overhead child rejected '+$paceName)}
 $paceNative=Get-Content -LiteralPath $paceReport -Raw|ConvertFrom-Json
 if(-not$paceNative.success-or$paceNative.display-ne'headless'-or$paceNative.rendering_method-ne'dummy'-or$paceNative.iterations-ne$Iterations){throw 'Wrong headless CPU workload'}
 $paceCounts=@($paceNative.pacing.main_completed,$paceNative.pacing.render_completed)
 if($paceEnabled){if(-not$paceNative.pacing.enabled-or$paceCounts[0]-lt$Iterations-or$paceCounts[1]-lt$Iterations-or$paceNative.pacing.cpu_windows.Count-lt1){throw 'Enabled ring/window path not executed'}}else{if($paceNative.pacing.enabled-or$paceCounts[0]-ne0-or$paceCounts[1]-ne0-or$paceNative.pacing.cpu_windows.Count-ne0){throw 'Absent flag unexpectedly recorded'}}
 $paceResult=@{name=$paceName;mode=$paceMode;enabled=$paceEnabled;exit=$paceCode;outerWallMs=$paceWatch.Elapsed.TotalMilliseconds;outerProcessCpuMs=$paceCpu;workloadWallUs=$paceNative.workload_wall_us;checksum=$paceNative.checksum;iterations=$Iterations;mainCompleted=$paceCounts[0];renderCompleted=$paceCounts[1];sameThread=$paceNative.pacing.same_thread;cpuWindows=$paceNative.pacing.cpu_windows.Count;success=$true}
 $paceResult|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $paceRun 'receipt.json') -Encoding utf8
 $paceResults+=$paceResult;Write-Output ($paceResult|ConvertTo-Json -Compress)
}
if(@($paceResults.checksum|Select-Object -Unique).Count-ne1){throw 'Deterministic workload diverged'}
@{version=1;success=$true;engine=$paceEngine;engineSha256=$EngineSha;results=$paceResults;gpu=$false;fpsClaim=$false;scope='Dummy renderer/fixed simulation headless component overhead only. Outer process CPU includes startup/warmup/cold snapshot/teardown; workload wall excludes startup and warmup. Timing comparisons are distinct from target gameplay and FPS; static disabled-path checks plus zero records prove metrics are inactive when flag is absent.'}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $paceRoot 'acceptance.json') -Encoding utf8
Write-Output 'All pacing CPU overhead children exited cleanly.'
