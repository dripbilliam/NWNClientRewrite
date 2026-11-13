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
function Invoke-OwnedTracyProcess([string]$Executable,[string]$ExpectedSha,[string[]]$Arguments,[string]$Stdout,[string]$Stderr,[string]$Proof,[int]$TimeoutSeconds,[long]$MaximumOutputBytes){
 if((Get-FileHash -LiteralPath $Executable).Hash.ToLowerInvariant()-ne$ExpectedSha){throw 'Tool executable changed before start'}
 $tracyStart=[Diagnostics.ProcessStartInfo]::new();$tracyStart.FileName=$Executable;$tracyStart.WorkingDirectory=$capturePlan.out;$tracyStart.UseShellExecute=$false;$tracyStart.CreateNoWindow=$true;$tracyStart.WindowStyle='Hidden';$tracyStart.RedirectStandardOutput=$true;$tracyStart.RedirectStandardError=$true
 foreach($tracyArg in $Arguments){$tracyStart.ArgumentList.Add([string]$tracyArg)}
 $tracyProcess=[Diagnostics.Process]::new();$tracyProcess.StartInfo=$tracyStart
 $tracyProof=@{version=1;pid=0;creationFileTimeUtc='';executable=$Executable;sha256=$ExpectedSha;arguments=$Arguments;startedUtc=[DateTime]::UtcNow.ToString('o');exit=$null;cleanExit=$false;forced=$false;peakPrivateMemoryBytes=0;peakWorkingSetBytes=0;failure=$null}
 $tracyOutputStream=$null;$tracyErrorStream=$null;$tracyOutputCopy=$null;$tracyErrorCopy=$null
 try{
  $tracyOutputStream=[IO.File]::Open($Stdout,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read);$tracyErrorStream=[IO.File]::Open($Stderr,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
  if(-not$tracyProcess.Start()){throw 'Owned Tracy child did not start'}
  $tracyProof.pid=$tracyProcess.Id;$tracyProof.creationFileTimeUtc=$tracyProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()
  if(-not$tracyProcess.MainModule.FileName.Equals($Executable,[StringComparison]::OrdinalIgnoreCase)){throw 'Actual loaded tool differs'}
  $tracyOutputCopy=$tracyProcess.StandardOutput.BaseStream.CopyToAsync($tracyOutputStream);$tracyErrorCopy=$tracyProcess.StandardError.BaseStream.CopyToAsync($tracyErrorStream)
  $tracyWatch=[Diagnostics.Stopwatch]::StartNew()
  while(-not$tracyProcess.WaitForExit(200)){
   $tracyProcess.Refresh();$tracyProof.peakPrivateMemoryBytes=[Math]::Max([long]$tracyProof.peakPrivateMemoryBytes,$tracyProcess.PrivateMemorySize64);$tracyProof.peakWorkingSetBytes=[Math]::Max([long]$tracyProof.peakWorkingSetBytes,$tracyProcess.WorkingSet64)
   if($tracyWatch.Elapsed.TotalSeconds-gt$TimeoutSeconds){throw 'Bounded Tracy child deadline exceeded'}
   if($tracyProcess.PrivateMemorySize64-gt$capturePlan.maximumProcessMemoryMB*1MB-or$tracyProcess.WorkingSet64-gt$capturePlan.maximumProcessMemoryMB*1MB){throw 'Bounded Tracy child memory exceeded'}
   if((Get-Item -LiteralPath $Stdout).Length-gt$MaximumOutputBytes-or(Get-Item -LiteralPath $Stderr).Length-gt8MB){throw 'Bounded Tracy child output exceeded'}
   if((Test-Path -LiteralPath $capturePlan.outputs.trace)-and(Get-Item -LiteralPath $capturePlan.outputs.trace).Length-gt$capturePlan.maximumTraceBytes){throw 'Bounded .tracy artifact exceeded'}
   if($tracyProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-ne$tracyProof.creationFileTimeUtc){throw 'Owned Tracy child lifetime changed'}
  }
  $tracyProof.exit=$tracyProcess.ExitCode;$tracyProof.cleanExit=$tracyProcess.ExitCode-eq0
 }catch{$tracyProof.failure=$_.Exception.Message;throw}finally{
  if($tracyProof.pid-gt0-and-not$tracyProcess.HasExited){if($tracyProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-eq$tracyProof.creationFileTimeUtc){$tracyProcess.Kill();[void]$tracyProcess.WaitForExit(5000);$tracyProof.forced=$true}}
  if($tracyOutputCopy){$tracyOutputCopy.GetAwaiter().GetResult()};if($tracyErrorCopy){$tracyErrorCopy.GetAwaiter().GetResult()};if($tracyOutputStream){$tracyOutputStream.Dispose()};if($tracyErrorStream){$tracyErrorStream.Dispose()}
  $tracyProof.finishedUtc=[DateTime]::UtcNow.ToString('o');$tracyProof|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $Proof -Encoding utf8
  $captureRun.children+=@{file=$Proof;sha256=(Get-FileHash -LiteralPath $Proof).Hash.ToLowerInvariant()};$tracyProcess.Dispose()
 }
 if(-not$tracyProof.cleanExit-or$tracyProof.forced){throw 'Tracy child did not exit naturally with success'}
 if((Get-Item -LiteralPath $Stdout).Length-gt$MaximumOutputBytes){throw 'Final export/log exceeds bound'}
}
try{
 $captureArgs=@('-a','127.0.0.1','-p',[string]$capturePlan.port,'-o',[string]$capturePlan.outputs.trace,'-s',[string]$capturePlan.seconds,'-m',[string]$capturePlan.memoryPercent)
 Invoke-OwnedTracyProcess $capturePlan.tools.capture.file $capturePlan.tools.capture.sha256 $captureArgs $capturePlan.outputs.captureStdout $capturePlan.outputs.captureStderr $capturePlan.outputs.captureProof $capturePlan.captureTimeoutSeconds 8MB
 if(-not(Test-Path -LiteralPath $capturePlan.outputs.trace)-or(Get-Item -LiteralPath $capturePlan.outputs.trace).Length-lt64-or(Get-Item -LiteralPath $capturePlan.outputs.trace).Length-gt$capturePlan.maximumTraceBytes){throw 'No bounded .tracy artifact was saved'}
 foreach($captureExport in $capturePlan.exportJobs){Invoke-OwnedTracyProcess $capturePlan.tools.exporter.file $capturePlan.tools.exporter.sha256 $captureExport.arguments $captureExport.stdout $captureExport.stderr $captureExport.proof $capturePlan.exportTimeoutSeconds $capturePlan.maximumExportBytes}
 foreach($capturePin in $capturePlan.runtimePins){if((Get-FileHash -LiteralPath $capturePin.file).Hash.ToLowerInvariant()-ne$capturePin.sha256){throw 'Frozen workflow changed during capture'}}
 if((Get-FileHash -LiteralPath $capturePlan.client.file).Hash.ToLowerInvariant()-ne$capturePlan.client.sha256){throw 'Pinned client binary changed during capture'}
 $captureRun.success=$true
}catch{$captureRun.failure=$_.Exception.Message;throw}finally{$captureRun.finishedUtc=[DateTime]::UtcNow.ToString('o');$captureRun|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $capturePlan.outputs.runProof -Encoding utf8;$captureClient.Dispose()}
& node (Join-Path $PSScriptRoot 'trace-verify.cjs') ('--plan='+$capturePlanFile) ('--plan-sha='+$PlanSha)
if($LASTEXITCODE-ne0){throw 'Trace semantic/version/source/zone acceptance rejected; outputs retained'}
