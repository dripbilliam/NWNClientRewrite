$ErrorActionPreference='Stop'
$nwnRoot=(Get-Location).Path
$nwnProposalFile=Join-Path $nwnRoot '.cache/nwn71/compositor-callback-capture-a/run-proposal.json'
$nwnExpectedProposal='9e85b86a5335911679eb2d0dc8d2b8843f47fc51cc3c8284b3ec45ea414cb7fd'
function NwnHash([string]$file){(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
if((NwnHash $nwnProposalFile)-ne$nwnExpectedProposal){throw 'Run proposal changed'}
$nwnProposal=Get-Content -LiteralPath $nwnProposalFile -Raw|ConvertFrom-Json
foreach($nwnPin in @($nwnProposal.preparation,$nwnProposal.selection)){if((NwnHash $nwnPin.file)-ne$nwnPin.sha256){throw 'Prepared input changed'}}
if((NwnHash $nwnProposal.replay.arguments[0])-ne$nwnProposal.replay.driverSha256){throw 'Frozen driver changed'}
if((NwnHash $nwnProposal.capture.executable)-ne$nwnProposal.capture.sha256){throw 'Official capture CLI changed'}
$nwnOut=Join-Path $nwnRoot '.cache/nwn71/capture-compositor-callback-a'
if(Test-Path -LiteralPath $nwnOut){throw 'Preserve existing run evidence'}
[IO.Directory]::CreateDirectory($nwnOut)|Out-Null
function NwnStart([string]$exe,$arguments){
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$exe;$info.WorkingDirectory=$nwnRoot;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle='Hidden';$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 foreach($argument in $arguments){$info.ArgumentList.Add([string]$argument)}
 $process=[Diagnostics.Process]::new();$process.StartInfo=$info
 if(-not$process.Start()){throw 'Owned process failed to start'}
 return @{process=$process;stdout=$process.StandardOutput.ReadToEndAsync();stderr=$process.StandardError.ReadToEndAsync()}
}
$nwnCapture=$null;$nwnReplay=$null;$nwnProof=@{success=$false;startedUtc=[DateTime]::UtcNow.ToString('o');proposalSha256=$nwnExpectedProposal;allWorkersPaused=$true;oneRunOnly=$true;capturePeakPrivateBytes=0L;capturePeakWorkingSetBytes=0L;traceMaximumBytes=0L;scope='One compositor callback identity replay; existing strict driver remains acceptance authority. No optimization/FPS gain inferred.'}
try{
 $nwnCapture=NwnStart $nwnProposal.capture.executable $nwnProposal.capture.arguments
 $nwnReplay=NwnStart $nwnProposal.replay.executable $nwnProposal.replay.arguments
 $nwnProof.capturePid=$nwnCapture.process.Id;$nwnProof.replayPid=$nwnReplay.process.Id
 $nwnWatch=[Diagnostics.Stopwatch]::StartNew()
 $nwnTrace=Join-Path $nwnOut 'entry.tracy'
 while(-not($nwnCapture.process.HasExited-and$nwnReplay.process.HasExited)){
  if($nwnWatch.Elapsed.TotalSeconds-gt120){throw 'One-run120second watchdog expired'}
  if(-not$nwnCapture.process.HasExited){
   $nwnCapture.process.Refresh();$nwnPrivate=$nwnCapture.process.PrivateMemorySize64;$nwnWorking=$nwnCapture.process.WorkingSet64
   $nwnProof.capturePeakPrivateBytes=[Math]::Max($nwnProof.capturePeakPrivateBytes,$nwnPrivate);$nwnProof.capturePeakWorkingSetBytes=[Math]::Max($nwnProof.capturePeakWorkingSetBytes,$nwnWorking)
   if($nwnPrivate-gt$nwnProposal.capture.maximumProcessPrivateBytes-or$nwnWorking-gt$nwnProposal.capture.maximumProcessWorkingSetBytes){throw 'Capture exceeded2GiB process cap'}
  }
  if(Test-Path -LiteralPath $nwnTrace){$nwnBytes=(Get-Item -LiteralPath $nwnTrace).Length;$nwnProof.traceMaximumBytes=[Math]::Max($nwnProof.traceMaximumBytes,$nwnBytes);if($nwnBytes-gt$nwnProposal.capture.maximumTraceBytes){throw 'Trace exceeded512MiB cap'}}
  [Threading.Thread]::Sleep(250)
 }
 $nwnProof.captureExit=$nwnCapture.process.ExitCode;$nwnProof.replayExit=$nwnReplay.process.ExitCode
 if($nwnProof.captureExit-ne0-or$nwnProof.replayExit-ne0){throw 'Capture or existing replay driver failed'}
 if(-not(Test-Path -LiteralPath $nwnTrace)){throw 'Trace not produced'}
 $nwnProof.trace=@{file=$nwnTrace;sha256=(NwnHash $nwnTrace);bytes=(Get-Item -LiteralPath $nwnTrace).Length}
 $nwnProof.success=$true
}catch{$nwnProof.failure=$_.Exception.Message;throw}finally{
 foreach($nwnPair in @(@('capture',$nwnCapture),@('replay',$nwnReplay))){
  if($null-eq$nwnPair[1]){continue};$owned=$nwnPair[1]
  if(-not$owned.process.HasExited){$owned.process.Kill($true);[void]$owned.process.WaitForExit(10000);$nwnProof.forced=$true}
  foreach($stream in @('stdout','stderr')){if($owned[$stream].Wait(10000)){[IO.File]::WriteAllText((Join-Path $nwnOut ($nwnPair[0]+'.'+$stream+'.log')),$owned[$stream].GetAwaiter().GetResult())}}
  $owned.process.Dispose()
 }
 $nwnProof.finishedUtc=[DateTime]::UtcNow.ToString('o');$nwnProof|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $nwnOut 'orchestration-receipt.json') -Encoding UTF8
}
$nwnProof|ConvertTo-Json -Depth 6
