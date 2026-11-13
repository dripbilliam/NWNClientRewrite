param(
 [Parameter(Mandatory=$true)][ValidateRange(1,2147483647)][int]$ClientPid,
 [Parameter(Mandatory=$true)][string]$Engine,
 [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$EngineSha,
 [Parameter(Mandatory=$true)][string]$OutputDirectory,
 [ValidateRange(1,30)][int]$Seconds=30
)
$ErrorActionPreference='Stop'
$sampleAncestor=[IO.DirectoryInfo]::new($PSScriptRoot)
while($sampleAncestor-and-not((Test-Path -LiteralPath (Join-Path $sampleAncestor.FullName 'project.godot'))-and(Test-Path -LiteralPath (Join-Path $sampleAncestor.FullName 'systems/model_rigs.gd')))){$sampleAncestor=$sampleAncestor.Parent}
if(-not$sampleAncestor){throw 'Owned Godot project ancestor not found'}
$sampleProject=$sampleAncestor.FullName
$sampleOut=[IO.Path]::GetFullPath($OutputDirectory)
$sampleAllowed=[IO.Path]::GetFullPath((Join-Path $sampleProject '.cache/native-render-gap/original/frame-pacing/')).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
if(-not$sampleOut.StartsWith($sampleAllowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Output must be a fresh child of the owned pacing cache'}
if(Test-Path -LiteralPath $sampleOut){throw 'Preserve prior capture'}
$sampleEngine=[IO.Path]::GetFullPath($Engine)
if((Get-FileHash -LiteralPath $sampleEngine).Hash.ToLowerInvariant()-ne$EngineSha){throw 'Target engine pin mismatch'}
$sampleClient=Get-Process -Id $ClientPid
if(-not[string]::Equals($sampleClient.Path,$sampleEngine,[StringComparison]::OrdinalIgnoreCase)){throw 'PID is not the pinned client'}
$sampleIdentity=$sampleClient.StartTime.ToUniversalTime().ToString('o')
New-Item -ItemType Directory -Path $sampleOut | Out-Null
$sampleTemp=Join-Path $sampleOut 'temporary';New-Item -ItemType Directory -Path $sampleTemp|Out-Null
$sampleProfile=Join-Path $sampleOut 'cpu-sampled.wprp';Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'cpu-sampled.wprp') -Destination $sampleProfile
$sampleInstance='NwnRenderGapCPU-'+[Guid]::NewGuid().ToString('N')
$sampleWpr=Join-Path $env:WINDIR 'System32/wpr.exe'
$sampleState=@{version=1;scope='Private named bounded sampled CPU diagnostic; system-provider collection with target PID analysis filter. No settings, focus, process policy, registry, profile interval or unrelated logger changes.';instance=$sampleInstance;targetPid=$ClientPid;targetStartUtc=$sampleIdentity;engine=$sampleEngine;engineSha256=$EngineSha;profile=$sampleProfile;profileSha256=(Get-FileHash -LiteralPath $sampleProfile).Hash.ToLowerInvariant();captureSeconds=$Seconds;maximumRawTraceMiB=128;systemProviderCapture=$true;collectionPidFilter=$false;stackEvent='SampledProfile';started=$false;stopped=$false}
function Save-SampleState {$sampleState|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $sampleOut 'capture.json') -Encoding utf8}
function Invoke-PrivateWpr([string]$Name,[string[]]$Arguments){
 $sampleInfo=[Diagnostics.ProcessStartInfo]::new();$sampleInfo.FileName=$sampleWpr;$sampleInfo.UseShellExecute=$false;$sampleInfo.CreateNoWindow=$true;$sampleInfo.RedirectStandardOutput=$true;$sampleInfo.RedirectStandardError=$true
 foreach($sampleArg in $Arguments){$sampleInfo.ArgumentList.Add($sampleArg)}
 $sampleCommand=[Diagnostics.Process]::new();$sampleCommand.StartInfo=$sampleInfo;[void]$sampleCommand.Start()
 $sampleStdout=$sampleCommand.StandardOutput.ReadToEndAsync();$sampleStderr=$sampleCommand.StandardError.ReadToEndAsync()
 $sampleCommandPid=$sampleCommand.Id
 if(-not$sampleCommand.WaitForExit(45000)){
  # Terminate only this owned WPR command process, never the target client or
  # any logger. The caller's finally still attempts an explicit-instance stop.
  $sampleCommand.Kill();[void]$sampleCommand.WaitForExit(5000);$sampleTimedOut=$true
 }else{$sampleTimedOut=$false}
 $sampleExit=if($sampleCommand.HasExited){$sampleCommand.ExitCode}else{-408}
 # A spawned helper could inherit a redirected pipe. Bound pipe draining too,
 # so a finished WPR command cannot leave this controller waiting indefinitely.
 $samplePipesDone=[Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($sampleStdout,$sampleStderr),5000)
 $sampleOutput=if($sampleStdout.IsCompletedSuccessfully){$sampleStdout.GetAwaiter().GetResult()}else{'Owned command stdout did not complete before the bounded drain deadline.'}
 $sampleError=if($sampleStderr.IsCompletedSuccessfully){$sampleStderr.GetAwaiter().GetResult()}else{'Owned command stderr did not complete before the bounded drain deadline.'}
 $sampleCommand.StandardOutput.Dispose();$sampleCommand.StandardError.Dispose();$sampleCommand.Dispose()
 [IO.File]::WriteAllText((Join-Path $sampleOut ($Name+'.stdout.log')),$sampleOutput);[IO.File]::WriteAllText((Join-Path $sampleOut ($Name+'.stderr.log')),$sampleError)
 @{name=$Name;arguments=$Arguments;exit=$sampleExit;timedOut=$sampleTimedOut;pipesCompleted=$samplePipesDone;ownedCommandPid=$sampleCommandPid;utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $sampleOut ($Name+'.json')) -Encoding utf8
 if($sampleTimedOut-or-not$samplePipesDone){return -408}
 return $sampleExit
}
Save-SampleState
# Never use bare -stop or -cancel: those can affect somebody else's WPR trace.
try {
 $sampleState.startAttempted=$true;Save-SampleState
 $sampleStartExit=Invoke-PrivateWpr 'start' @('-start',($sampleProfile+'!NwnCpuSampled.Verbose'),'-filemode','-recordtempto',$sampleTemp,'-instancename',$sampleInstance)
 $sampleState.startExit=$sampleStartExit;Save-SampleState
 if($sampleStartExit-ne0){throw 'Private WPR start failed; no retry, policy change, or global cancellation performed. Inspect retained diagnostics.'}
 $sampleState.started=$true;$sampleState.startedUtc=[DateTime]::UtcNow.ToString('o');Save-SampleState
 Write-Output ('Started private sampled CPU trace '+$sampleInstance+' for target '+$ClientPid)
 Start-Sleep -Seconds $Seconds
 $sampleAfter=Get-Process -Id $ClientPid
 $sampleState.targetIdentityMatched=([string]::Equals($sampleAfter.Path,$sampleEngine,[StringComparison]::OrdinalIgnoreCase)-and($sampleAfter.StartTime.ToUniversalTime().ToString('o')-eq$sampleIdentity))
} finally {
 $sampleStopExit=Invoke-PrivateWpr 'stop' @('-stop',(Join-Path $sampleOut 'cpu.etl'),'-instancename',$sampleInstance)
 $sampleState.stopExit=$sampleStopExit;$sampleState.stopped=$sampleStopExit-eq0;$sampleState.stoppedUtc=[DateTime]::UtcNow.ToString('o');Save-SampleState
 if(-not$sampleState.stopped){Write-Warning ('OWNED PRIVATE SESSION MAY REMAIN: '+$sampleInstance+'. Only an explicit matching -instancename stop is allowed.')}
}
if(-not$sampleState.stopped){throw ('OWNED PRIVATE SESSION MAY REMAIN: '+$sampleInstance+'. Use only its explicit -instancename when stopping; never stop unrelated loggers.')}
if(-not$sampleState.targetIdentityMatched){throw 'Target identity changed during capture; do not attribute samples to the requested client'}
$sampleTrace=Get-Item -LiteralPath (Join-Path $sampleOut 'cpu.etl');$sampleState.etlBytes=$sampleTrace.Length;$sampleState.etlSha256=(Get-FileHash -LiteralPath $sampleTrace.FullName).Hash.ToLowerInvariant();$sampleState.success=$true;Save-SampleState
Write-Output ('Stopped private trace; '+$sampleTrace.Length+' bytes. Analysis must check lost events and restrict exact PID/TID before attributing samples.')
