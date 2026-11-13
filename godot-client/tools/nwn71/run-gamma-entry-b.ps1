$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$planFile=Join-Path $root '.cache/nwn71/gamma-entry-b/plan.json'
$expected='b52c6d79a9856cce1b2e8297d85e4ad8b074e165437dbca6bdfd6eb223354961'
function Hash([string]$file){(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
if((Hash $planFile)-ne$expected){throw 'Entry plan changed'}
$plan=Get-Content -LiteralPath $planFile -Raw|ConvertFrom-Json
if((Hash $plan.gamma.file)-ne$plan.gamma.sha256-or(Hash $plan.engine.file)-ne$plan.engine.sha256-or(Hash $plan.driver.file)-ne$plan.driver.sha256){throw 'Pinned source/runtime changed'}
function StartOwned([string]$exe,$arguments,[string]$mode,[string]$nwnUserDataPath){
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$exe;$info.WorkingDirectory=$root;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle='Hidden';$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 if($mode-ne''){$info.Environment['NWN71_GAMMA_PREWARM']=if($mode-eq'on'){'1'}else{'0'};$info.Environment['APPDATA']=$nwnUserDataPath;$info.Environment['LOCALAPPDATA']=$nwnUserDataPath}
 foreach($a in $arguments){$info.ArgumentList.Add([string]$a)}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$info
 if(-not$p.Start()){throw 'Owned diagnostic process failed to start'}
 return @{process=$p;stdout=$p.StandardOutput.ReadToEndAsync();stderr=$p.StandardError.ReadToEndAsync()}
}
$receipts=@()
foreach($run in $plan.runs){
 if((Hash $run.selection.file)-ne$run.selection.sha256){throw 'Selection changed'}
 if((Hash $run.capture.executable)-ne$plan.captureCliSha256){throw 'Capture CLI changed'}
 if(Test-Path -LiteralPath $run.output){throw 'Preserve prior entry result'}
 if((Get-PSDrive C).Free-lt8GB){throw 'Disk free under 8 GiB'}
 [IO.Directory]::CreateDirectory($run.output)|Out-Null
 $nwnUserDataPath=Join-Path $run.output 'userdata';[IO.Directory]::CreateDirectory($nwnUserDataPath)|Out-Null
 $capture=$null;$replay=$null
 $proof=@{schema=$plan.schema;mode=$run.mode;planSha256=$expected;startedUtc=[DateTime]::UtcNow.ToString('o');scope=$plan.scope;capturePeakPrivateBytes=0L;capturePeakWorkingSetBytes=0L;success=$false}
 try{
  $capture=StartOwned $run.capture.executable $run.capture.arguments '' ''
  $replay=StartOwned $run.replay.executable $run.replay.arguments $run.mode $nwnUserDataPath
  $proof.capturePid=$capture.process.Id;$proof.replayPid=$replay.process.Id
  $trace=Join-Path $run.output 'entry.tracy';$watch=[Diagnostics.Stopwatch]::StartNew()
  while(-not($capture.process.HasExited-and$replay.process.HasExited)){
   if($watch.Elapsed.TotalSeconds-gt120){throw 'Entry watchdog exceeded 120 seconds'}
   if($replay.process.HasExited-and-not(Test-Path -LiteralPath $trace)-and$watch.Elapsed.TotalSeconds-gt25){throw 'Replay ended without Tracy connection'}
   if(-not$capture.process.HasExited){$capture.process.Refresh();$proof.capturePeakPrivateBytes=[Math]::Max([long]$proof.capturePeakPrivateBytes,[long]$capture.process.PrivateMemorySize64);$proof.capturePeakWorkingSetBytes=[Math]::Max([long]$proof.capturePeakWorkingSetBytes,[long]$capture.process.WorkingSet64);if($proof.capturePeakPrivateBytes-gt2GB-or$proof.capturePeakWorkingSetBytes-gt2GB){throw 'Capture process exceeded 2 GiB'}}
   if(Test-Path -LiteralPath $trace){if((Get-Item -LiteralPath $trace).Length-gt512MB){throw 'Trace exceeded 512 MiB'}}
   if((Get-PSDrive C).Free-lt8GB){throw 'Disk free under 8 GiB'}
   [Threading.Thread]::Sleep(250)
  }
  $proof.captureExit=$capture.process.ExitCode;$proof.replayExit=$replay.process.ExitCode
  if(Test-Path -LiteralPath $trace){$proof.trace=@{file=$trace;sha256=(Hash $trace);bytes=(Get-Item -LiteralPath $trace).Length}}
  $report=Join-Path $root ("reports/"+$run.label+".json")
  if(Test-Path -LiteralPath $report){$proof.replayReport=@{file=$report;sha256=(Hash $report)}}
  $proof.success=$proof.captureExit-eq0-and$proof.replayExit-eq0-and$null-ne$proof.trace-and$null-ne$proof.replayReport
  if(-not$proof.success){throw 'Capture or strict replay failed'}
 }catch{$proof.failure=$_.Exception.Message}finally{
  foreach($pair in @(@('capture',$capture),@('replay',$replay))){
   if($null-eq$pair[1]){continue};$owned=$pair[1]
   if(-not$owned.process.HasExited){$owned.process.Kill($true);[void]$owned.process.WaitForExit(10000);$proof.forcedStop=$true}
   foreach($stream in @('stdout','stderr')){if($owned[$stream].Wait(10000)){[IO.File]::WriteAllText((Join-Path $run.output ($pair[0]+'.'+$stream+'.log')),$owned[$stream].GetAwaiter().GetResult())}}
   $owned.process.Dispose()
  }
  $proof.finishedUtc=[DateTime]::UtcNow.ToString('o')
  $proof|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $run.output 'receipt.json') -Encoding UTF8
  $receipts+=$proof
 }
 if(-not$proof.success){break}
}
$receipts|ConvertTo-Json -Depth 4
if($receipts.Count-ne2-or@($receipts|Where-Object{-not$_.success}).Count-ne0){throw 'Original-entry check incomplete'}
