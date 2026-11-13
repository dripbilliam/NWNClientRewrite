[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SmokePlan,[Parameter(Mandatory=$true)][string]$SmokeSha,[Parameter(Mandatory=$true)][string]$CapturePlan,[Parameter(Mandatory=$true)][string]$CaptureSha,[switch]$Run)
$ErrorActionPreference='Stop'
if(-not$Run){throw 'Explicit authorized runtime slot required'}
foreach($tracyPair in @(@($SmokePlan,$SmokeSha),@($CapturePlan,$CaptureSha))){if((Get-FileHash -LiteralPath $tracyPair[0]).Hash.ToLowerInvariant()-ne$tracyPair[1]){throw 'Frozen smoke/capture plan differs'}}
$tracySmoke=Get-Content -LiteralPath $SmokePlan -Raw|ConvertFrom-Json
$tracyCapture=Get-Content -LiteralPath $CapturePlan -Raw|ConvertFrom-Json
foreach($tracyPin in $tracySmoke.pins){if((Get-FileHash -LiteralPath $tracyPin.file).Hash.ToLowerInvariant()-ne$tracyPin.sha256){throw 'Frozen smoke source differs'}}
$tracyEngine=[Diagnostics.Process]::new();$tracyEngine.StartInfo=[Diagnostics.ProcessStartInfo]::new();$tracyEngine.StartInfo.FileName=$tracyCapture.client.file;$tracyEngine.StartInfo.WorkingDirectory=$tracySmoke.out;$tracyEngine.StartInfo.UseShellExecute=$false;$tracyEngine.StartInfo.CreateNoWindow=$true;$tracyEngine.StartInfo.WindowStyle='Hidden';$tracyEngine.StartInfo.RedirectStandardOutput=$true;$tracyEngine.StartInfo.RedirectStandardError=$true
foreach($tracyArgument in $tracySmoke.cli){$tracyEngine.StartInfo.ArgumentList.Add([string]$tracyArgument)}
foreach($tracyEnv in $tracySmoke.environment.psobject.Properties){$tracyEngine.StartInfo.Environment[$tracyEnv.Name]=[string]$tracyEnv.Value}
$tracyEngine.StartInfo.Environment['TRACY_PORT']=[string]$tracyCapture.port
$tracyProof=@{version=1;success=$false;startedUtc=[DateTime]::UtcNow.ToString('o');pid=0;creationFileTimeUtc='';forced=$false;modules=@();scope='Owned bounded headless Tracy integration smoke, not an FPS/gameplay result.'}
$tracyEngineOut=$null;$tracyEngineErr=$null;$tracyCaptureChild=$null;$tracyCaptureOut=$null;$tracyCaptureErr=$null
try{
 if(-not$tracyEngine.Start()){throw 'Private smoke engine failed to start'}
 $tracyProof.pid=$tracyEngine.Id;$tracyProof.creationFileTimeUtc=$tracyEngine.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()
 $tracyEngineOut=$tracyEngine.StandardOutput.ReadToEndAsync();$tracyEngineErr=$tracyEngine.StandardError.ReadToEndAsync()
 $tracyWatch=[Diagnostics.Stopwatch]::StartNew();$tracyReady=$false
 while(-not$tracyReady){
  if($tracyEngine.HasExited){throw 'Private smoke engine exited before ready/listener'}
  if($tracyWatch.Elapsed.TotalSeconds-gt15){throw 'Private smoke startup exceeded15seconds'}
  if(Test-Path -LiteralPath $tracySmoke.outputs.ready){$tracyListeners=@(Get-NetTCPConnection -LocalPort $tracyCapture.port -State Listen -ErrorAction SilentlyContinue);$tracyReady=$tracyListeners.Count-eq1-and$tracyListeners[0].OwningProcess-eq$tracyEngine.Id}
  if(-not$tracyReady){Start-Sleep -Milliseconds 50}
 }
 $tracyProof.modules=@($tracyEngine.Modules|Where-Object ModuleName -EQ 'nwn-particle-kernel.dll'|ForEach-Object{@{name=$_.ModuleName;path=$_.FileName;sha256=(Get-FileHash -LiteralPath $_.FileName).Hash.ToLowerInvariant()}})
 if($tracyProof.modules.Count-ne1-or$tracyProof.modules[0].sha256-ne'd0b89789126189718961712c6b30a7a2007afb7c52a2e8f024ab78158eee893c'){throw 'Actual private particle DLL differs'}
 $tracyCaptureChild=[Diagnostics.Process]::new();$tracyCaptureChild.StartInfo=[Diagnostics.ProcessStartInfo]::new();$tracyCaptureChild.StartInfo.FileName=(Get-Command pwsh).Source;$tracyCaptureChild.StartInfo.WorkingDirectory=$tracySmoke.out;$tracyCaptureChild.StartInfo.UseShellExecute=$false;$tracyCaptureChild.StartInfo.CreateNoWindow=$true;$tracyCaptureChild.StartInfo.WindowStyle='Hidden';$tracyCaptureChild.StartInfo.RedirectStandardOutput=$true;$tracyCaptureChild.StartInfo.RedirectStandardError=$true
 foreach($tracyArgument in @('-NoProfile','-File',(Join-Path $tracyCapture.runtime 'capture-run.ps1'),'-Plan',[IO.Path]::GetFullPath($CapturePlan),'-PlanSha',$CaptureSha,'-ClientPid',[string]$tracyEngine.Id,'-ClientFileTimeUtc',$tracyProof.creationFileTimeUtc,'-Run')){$tracyCaptureChild.StartInfo.ArgumentList.Add([string]$tracyArgument)}
 if(-not$tracyCaptureChild.Start()){throw 'Private capture driver failed to start'}
 $tracyCaptureOut=$tracyCaptureChild.StandardOutput.ReadToEndAsync();$tracyCaptureErr=$tracyCaptureChild.StandardError.ReadToEndAsync();$tracyStopSent=$false
 while(-not$tracyCaptureChild.WaitForExit(50)){
  if(-not$tracyStopSent-and(Test-Path -LiteralPath $tracyCapture.outputs.captureProof)){
   $tracyCaptureProof=Get-Content -LiteralPath $tracyCapture.outputs.captureProof -Raw|ConvertFrom-Json
   if($tracyCaptureProof.cleanExit-and-not$tracyCaptureProof.forced){& node (Join-Path $tracySmoke.out 'execution/write-stop.cjs') ([IO.Path]::GetFullPath($SmokePlan)) $SmokeSha;if($LASTEXITCODE-ne0){throw 'Owned stop marker rejected'};$tracyStopSent=$true}
  }
  if($tracyWatch.Elapsed.TotalSeconds-gt100){throw 'Capture/export smoke driver exceeded100seconds'}
 }
 $tracyProof.captureExit=$tracyCaptureChild.ExitCode
 if(-not$tracyStopSent-and-not$tracyEngine.HasExited){& node (Join-Path $tracySmoke.out 'execution/write-stop.cjs') ([IO.Path]::GetFullPath($SmokePlan)) $SmokeSha;$tracyStopSent=$true}
 if(-not$tracyEngine.WaitForExit(5000)){throw 'Owned smoke did not close after stop marker'}
 $tracyProof.engineExit=$tracyEngine.ExitCode
 $tracyReport=Get-Content -LiteralPath $tracySmoke.outputs.report -Raw|ConvertFrom-Json
 if($tracyProof.engineExit-ne0-or$tracyProof.captureExit-ne0-or-not$tracyReport.success){throw 'Smoke or trace readback rejected; preserve exact output'}
 $tracyProof.report=@{file=$tracySmoke.outputs.report;sha256=(Get-FileHash -LiteralPath $tracySmoke.outputs.report).Hash.ToLowerInvariant()};$tracyProof.success=$true
}catch{$tracyProof.failure=$_.Exception.Message;throw}finally{
 if($tracyProof.pid-and-not$tracyEngine.HasExited-and$tracyEngine.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-eq$tracyProof.creationFileTimeUtc){$tracyEngine.Kill($true);[void]$tracyEngine.WaitForExit(5000);$tracyProof.forced=$true}
 if($tracyCaptureChild-and-not$tracyCaptureChild.HasExited){$tracyCaptureChild.Kill($true);[void]$tracyCaptureChild.WaitForExit(5000)}
 foreach($tracyPair in @(@($tracyEngineOut,$tracySmoke.outputs.stdout),@($tracyEngineErr,$tracySmoke.outputs.stderr),@($tracyCaptureOut,(Join-Path $tracySmoke.out 'capture-driver.stdout.log')),@($tracyCaptureErr,(Join-Path $tracySmoke.out 'capture-driver.stderr.log')))){if($tracyPair[0]-and$tracyPair[0].Wait(5000)){[IO.File]::WriteAllText($tracyPair[1],$tracyPair[0].GetAwaiter().GetResult())}}
 $tracyProof.finishedUtc=[DateTime]::UtcNow.ToString('o');$tracyProof|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $tracySmoke.out 'process-proof.json') -Encoding utf8
 if($tracyCaptureChild){$tracyCaptureChild.Dispose()};$tracyEngine.Dispose()
}
$tracyProof|ConvertTo-Json -Depth 7
