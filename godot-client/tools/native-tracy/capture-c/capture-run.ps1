param([Parameter(Mandatory=$true)][string]$Plan,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$PlanSha,[Parameter(Mandatory=$true)][int]$ClientPid,[Parameter(Mandatory=$true)][ValidatePattern('^[0-9]+$')][string]$ClientFileTimeUtc,[switch]$Run)
$ErrorActionPreference='Stop'
if(-not$Run){throw 'Capture/export tools require the root-authorized native slot'}
$capturePlanFile=[IO.Path]::GetFullPath($Plan)
if((Get-FileHash -LiteralPath $capturePlanFile).Hash.ToLowerInvariant()-ne$PlanSha){throw 'Exact capture plan differs'}
$capturePlan=Get-Content -LiteralPath $capturePlanFile -Raw|ConvertFrom-Json
if($capturePlan.kind-ne'private-tracy-capture-plan'-or$capturePlan.tools.version-ne'0.13.0'-or$capturePlan.tools.protocol-ne76-or$capturePlan.address-ne'127.0.0.1'){throw 'Capture source/protocol/address policy differs'}
foreach($capturePin in $capturePlan.runtimePins){if((Get-FileHash -LiteralPath $capturePin.file).Hash.ToLowerInvariant()-ne$capturePin.sha256){throw 'Frozen capture workflow differs'}}
$captureRunner=@($capturePlan.runtimePins|Where-Object file -EQ $PSCommandPath)
if($captureRunner.Count-ne1){throw 'Use frozen execution copy of capture runner'}
foreach($capturePin in @($capturePlan.tools.capture,$capturePlan.tools.exporter,$capturePlan.tools.sourceReceipt,$capturePlan.tools.toolsReceipt,$capturePlan.client,$capturePlan.client.buildProof)) {if((Get-FileHash -LiteralPath $capturePin.file).Hash.ToLowerInvariant()-ne$capturePin.sha256){throw 'Pinned client/tool/build receipt differs'}}
foreach($captureOutput in @($capturePlan.outputs.psobject.Properties.Value)+@($capturePlan.exportJobs|ForEach-Object{$_.stdout;$_.stderr;$_.proof})){if(Test-Path -LiteralPath $captureOutput){throw 'Preserve prior capture/export output; create a fresh plan'}}
$captureClient=Get-Process -Id $ClientPid -ErrorAction Stop
if($captureClient.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-ne$ClientFileTimeUtc-or-not$captureClient.MainModule.FileName.Equals($capturePlan.client.file,[StringComparison]::OrdinalIgnoreCase)){throw 'Exact root-owned client PID/lifetime/path differs'}
$captureListeners=@(Get-NetTCPConnection -LocalPort $capturePlan.port -State Listen -ErrorAction Stop)
if($captureListeners.Count-eq0-or@($captureListeners|Where-Object OwningProcess -NE $ClientPid).Count-gt0){throw 'Private Tracy port is not owned exclusively by the pinned client'}
$captureRun=@{version=1;kind='private-tracy-capture-run';plan=@{file=$capturePlanFile;sha256=$PlanSha};client=@{pid=$ClientPid;creationFileTimeUtc=$ClientFileTimeUtc;path=$captureClient.MainModule.FileName;sha256=$capturePlan.client.sha256;listenerAddresses=@($captureListeners|ForEach-Object LocalAddress)};startedUtc=[DateTime]::UtcNow.ToString('o');success=$false;gameTerminationAttempted=$false;children=@();failure=$null}
$captureRun.client.connectionObserved=$false;$captureRun.client.lifetimeSamples=0;$captureRun.client.exitObservedUtc=$null;$captureRun.client.exitCode=$null;$captureRun.client.attributionEndUtc=$null;$captureRun.client.aliveThroughCapture=$false;$captureRun.client.naturalExitDuringCapture=$false
function Assert-CaptureClientScope([Diagnostics.Process]$OwnedCapture){
 $captureClient.Refresh()
 $scopeNow=[DateTime]::UtcNow.ToString('o')
 if($captureClient.HasExited){
  if(-not$captureRun.client.exitObservedUtc){$captureRun.client.exitObservedUtc=$scopeNow;$captureRun.client.exitCode=$captureClient.ExitCode;$captureRun.client.attributionEndUtc=$scopeNow}
  if(-not$captureRun.client.connectionObserved){throw 'Client retired before any exact owned TCP capture connection was observed'}
  if($captureClient.ExitCode-ne0){throw 'Pinned client exited with failure during capture'}
  $captureRun.client.naturalExitDuringCapture=$true
 }else{
  if($captureClient.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-ne$ClientFileTimeUtc-or-not$captureClient.MainModule.FileName.Equals($capturePlan.client.file,[StringComparison]::OrdinalIgnoreCase)){throw 'Pinned client PID/lifetime/path changed during capture'}
  $captureRun.client.lifetimeSamples+=1
  $captureRun.client.lastAliveObservedUtc=$scopeNow
 }
 # This only observes localhost TCP ownership; never connects a second server.
 $scopeConnections=@(Get-NetTCPConnection -LocalPort $capturePlan.port -ErrorAction SilentlyContinue)
 $scopeListeners=@($scopeConnections|Where-Object State -EQ Listen)
 if(@($scopeListeners|Where-Object OwningProcess -NE $ClientPid).Count-gt0){throw 'Private Tracy listener was replaced by another process during connect/save'}
 if(-not$OwnedCapture.HasExited-and-not$captureClient.HasExited){
  $scopeClientConnections=@($scopeConnections|Where-Object{$_.State-eq'Established'-and$_.OwningProcess-eq$ClientPid-and$_.RemoteAddress-in@('127.0.0.1','::1','::ffff:127.0.0.1')})
  $scopeCaptureConnections=@(Get-NetTCPConnection -OwningProcess $OwnedCapture.Id -State Established -ErrorAction SilentlyContinue|Where-Object{$_.RemotePort-eq$capturePlan.port-and$_.RemoteAddress-in@('127.0.0.1','::1','::ffff:127.0.0.1')})
  foreach($scopeServer in $scopeClientConnections){foreach($scopePeer in $scopeCaptureConnections){if($scopeServer.RemotePort-eq$scopePeer.LocalPort-and$scopeServer.LocalPort-eq$scopePeer.RemotePort){$captureRun.client.connectionObserved=$true;$captureRun.client.lastConnectionObservedUtc=$scopeNow}}}
 }
}
function Invoke-OwnedTracyProcess([string]$Executable,[string]$ExpectedSha,[string[]]$Arguments,[string]$Stdout,[string]$Stderr,[string]$Proof,[int]$TimeoutSeconds,[long]$MaximumOutputBytes,[bool]$WatchClient=$false){
 if((Get-FileHash -LiteralPath $Executable).Hash.ToLowerInvariant()-ne$ExpectedSha){throw 'Tool executable changed before start'}
 $tracyStart=[Diagnostics.ProcessStartInfo]::new();$tracyStart.FileName=$Executable;$tracyStart.WorkingDirectory=$capturePlan.out;$tracyStart.UseShellExecute=$false;$tracyStart.CreateNoWindow=$true;$tracyStart.WindowStyle='Hidden';$tracyStart.RedirectStandardOutput=$true;$tracyStart.RedirectStandardError=$true
 foreach($tracyArg in $Arguments){$tracyStart.ArgumentList.Add([string]$tracyArg)}
 $tracyProcess=[Diagnostics.Process]::new();$tracyProcess.StartInfo=$tracyStart
 $tracyProof=@{version=1;pid=0;creationFileTimeUtc='';executable=$Executable;sha256=$ExpectedSha;arguments=$Arguments;startedUtc=[DateTime]::UtcNow.ToString('o');exit=$null;cleanExit=$false;forced=$false;peakPrivateMemoryBytes=0;peakWorkingSetBytes=0;failure=$null;drainCompleted=$false;drainTimedOut=$false;drainFailure=$null;killWaitCompleted=$null;imageIdentity=@{mode='pending';moduleObserved=$false;observedPath=$null;queryFailures=@();useShellExecute=$false;launchAbsolutePath=[IO.Path]::GetFullPath($Executable);launchSha256=$ExpectedSha}}
 $tracyOutputStream=$null;$tracyErrorStream=$null;$tracyOutputCopy=$null;$tracyErrorCopy=$null
 try{
  $tracyOutputStream=[IO.File]::Open($Stdout,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read);$tracyErrorStream=[IO.File]::Open($Stderr,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
  if(-not$tracyProcess.Start()){throw 'Owned Tracy child did not start'}
  $tracyProof.pid=$tracyProcess.Id;$tracyProof.creationFileTimeUtc=$tracyProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()
  $tracyOutputCopy=$tracyProcess.StandardOutput.BaseStream.CopyToAsync($tracyOutputStream);$tracyErrorCopy=$tracyProcess.StandardError.BaseStream.CopyToAsync($tracyErrorStream)
  # MainModule can briefly be null immediately after Start(). Observe it with
  # a finite startup window; a fast natural exit retains honest direct-launch
  # provenance instead of inventing an actual loaded-module observation.
  $tracyImageWatch=[Diagnostics.Stopwatch]::StartNew()
  while(-not$tracyProof.imageIdentity.moduleObserved){
   $tracyActualImage=$null
   if($tracyProcess.HasExited){$tracyProof.imageIdentity.mode='direct-absolute-launch-fast-natural-exit';break}
   try{$tracyActualImage=$tracyProcess.MainModule.FileName}catch{if($tracyProof.imageIdentity.queryFailures.Count-lt8){$tracyProof.imageIdentity.queryFailures+=@{atMs=$tracyImageWatch.ElapsedMilliseconds;message=$_.Exception.Message}}}
   if(-not[string]::IsNullOrEmpty($tracyActualImage)){
    if(-not[IO.Path]::GetFullPath($tracyActualImage).Equals([IO.Path]::GetFullPath($Executable),[StringComparison]::OrdinalIgnoreCase)){throw 'Actual observed loaded tool differs'}
    $tracyProof.imageIdentity.moduleObserved=$true;$tracyProof.imageIdentity.observedPath=[IO.Path]::GetFullPath($tracyActualImage);$tracyProof.imageIdentity.mode='observed-main-module';break
   }
   if($tracyImageWatch.ElapsedMilliseconds-ge2000){$tracyProof.imageIdentity.mode='alive-image-query-timeout';throw 'Owned tool remained alive without queryable image path for2s'}
   Start-Sleep -Milliseconds 10
   $tracyProcess.Refresh()
  }
  $tracyWatch=[Diagnostics.Stopwatch]::StartNew()
  $tracyScopeLastMs=-1000
  while(-not$tracyProcess.WaitForExit(200)){
   $tracyProcess.Refresh();$tracyProof.peakPrivateMemoryBytes=[Math]::Max([long]$tracyProof.peakPrivateMemoryBytes,$tracyProcess.PrivateMemorySize64);$tracyProof.peakWorkingSetBytes=[Math]::Max([long]$tracyProof.peakWorkingSetBytes,$tracyProcess.WorkingSet64)
   if($tracyWatch.Elapsed.TotalSeconds-gt$TimeoutSeconds){throw 'Bounded Tracy child deadline exceeded'}
   if($tracyProcess.PrivateMemorySize64-gt$capturePlan.maximumProcessMemoryMB*1MB-or$tracyProcess.WorkingSet64-gt$capturePlan.maximumProcessMemoryMB*1MB){throw 'Bounded Tracy child memory exceeded'}
   if((Get-Item -LiteralPath $Stdout).Length-gt$MaximumOutputBytes-or(Get-Item -LiteralPath $Stderr).Length-gt8MB){throw 'Bounded Tracy child output exceeded'}
   if((Test-Path -LiteralPath $capturePlan.outputs.trace)-and(Get-Item -LiteralPath $capturePlan.outputs.trace).Length-gt$capturePlan.maximumTraceBytes){throw 'Bounded .tracy artifact exceeded'}
   if($tracyProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-ne$tracyProof.creationFileTimeUtc){throw 'Owned Tracy child lifetime changed'}
   if($WatchClient-and$tracyWatch.ElapsedMilliseconds-$tracyScopeLastMs-ge500){Assert-CaptureClientScope $tracyProcess;$tracyScopeLastMs=$tracyWatch.ElapsedMilliseconds}
  }
  if($WatchClient){Assert-CaptureClientScope $tracyProcess;if(-not$captureRun.client.connectionObserved){throw 'No exact client/capture TCP connection was observed'};if(-not$captureRun.client.exitObservedUtc){$captureRun.client.aliveThroughCapture=$true;$captureRun.client.attributionEndUtc=[DateTime]::UtcNow.ToString('o')}}
  $tracyProof.exit=$tracyProcess.ExitCode;$tracyProof.cleanExit=$tracyProcess.ExitCode-eq0
 }catch{$tracyProof.failure=$_.Exception.Message;throw}finally{
  if($tracyProof.pid-gt0-and-not$tracyProcess.HasExited){if($tracyProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-eq$tracyProof.creationFileTimeUtc){$tracyProcess.Kill();$tracyProof.killWaitCompleted=$tracyProcess.WaitForExit(5000);$tracyProof.forced=$true}}
  # No unbounded GetResult: failed/held pipes must still produce a rejection receipt.
  try{
   $tracyDrainTasks=@($tracyOutputCopy,$tracyErrorCopy)|Where-Object{$null-ne$_}
   if($tracyDrainTasks.Count-gt0){$tracyDrain=[Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]$tracyDrainTasks);if(-not$tracyDrain.Wait(5000)){$tracyProof.drainTimedOut=$true;$tracyProof.drainFailure='Pipe drain deadline exceeded'}else{$tracyDrain.GetAwaiter().GetResult();$tracyProof.drainCompleted=$true}}
  }catch{$tracyProof.drainFailure=$_.Exception.Message}
  finally{
   if($tracyProof.drainTimedOut){try{$tracyProcess.StandardOutput.Close();$tracyProcess.StandardError.Close()}catch{}}
   if($tracyOutputStream){try{$tracyOutputStream.Dispose()}catch{$tracyProof.drainFailure='Output disposal: '+$_.Exception.Message}}
   if($tracyErrorStream){try{$tracyErrorStream.Dispose()}catch{$tracyProof.drainFailure='Error disposal: '+$_.Exception.Message}}
  }
  $tracyProof.finishedUtc=[DateTime]::UtcNow.ToString('o');$tracyProof|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $Proof -Encoding utf8
  $captureRun.children+=@{file=$Proof;sha256=(Get-FileHash -LiteralPath $Proof).Hash.ToLowerInvariant()};$tracyProcess.Dispose()
 }
 if(-not$tracyProof.cleanExit-or$tracyProof.forced-or-not$tracyProof.drainCompleted-or$tracyProof.drainFailure){throw 'Tracy child did not exit and drain naturally within bounds'}
 if((Get-Item -LiteralPath $Stdout).Length-gt$MaximumOutputBytes){throw 'Final export/log exceeds bound'}
}
try{
 $captureArgs=@('-a','127.0.0.1','-p',[string]$capturePlan.port,'-o',[string]$capturePlan.outputs.trace,'-s',[string]$capturePlan.seconds,'-m',[string]$capturePlan.memoryPercent)
 Invoke-OwnedTracyProcess $capturePlan.tools.capture.file $capturePlan.tools.capture.sha256 $captureArgs $capturePlan.outputs.captureStdout $capturePlan.outputs.captureStderr $capturePlan.outputs.captureProof $capturePlan.captureTimeoutSeconds 8MB $true
 if(-not(Test-Path -LiteralPath $capturePlan.outputs.trace)-or(Get-Item -LiteralPath $capturePlan.outputs.trace).Length-lt64-or(Get-Item -LiteralPath $capturePlan.outputs.trace).Length-gt$capturePlan.maximumTraceBytes){throw 'No bounded .tracy artifact was saved'}
 foreach($captureExport in $capturePlan.exportJobs){Invoke-OwnedTracyProcess $capturePlan.tools.exporter.file $capturePlan.tools.exporter.sha256 $captureExport.arguments $captureExport.stdout $captureExport.stderr $captureExport.proof $capturePlan.exportTimeoutSeconds $capturePlan.maximumExportBytes}
 foreach($capturePin in $capturePlan.runtimePins){if((Get-FileHash -LiteralPath $capturePin.file).Hash.ToLowerInvariant()-ne$capturePin.sha256){throw 'Frozen workflow changed during capture'}}
 if((Get-FileHash -LiteralPath $capturePlan.client.file).Hash.ToLowerInvariant()-ne$capturePlan.client.sha256){throw 'Pinned client binary changed during capture'}
 $captureRun.success=$true
}catch{$captureRun.failure=$_.Exception.Message;throw}finally{$captureRun.finishedUtc=[DateTime]::UtcNow.ToString('o');$captureRun|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $capturePlan.outputs.runProof -Encoding utf8;$captureClient.Dispose()}
& node (Join-Path $PSScriptRoot 'trace-verify.cjs') ('--plan='+$capturePlanFile) ('--plan-sha='+$PlanSha)
if($LASTEXITCODE-ne0){throw 'Trace semantic/version/source/zone acceptance rejected; outputs retained'}
