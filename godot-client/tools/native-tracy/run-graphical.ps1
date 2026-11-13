[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Config,[Parameter(Mandatory=$true)][string]$CapturePlan,[Parameter(Mandatory=$true)][string]$CaptureSha,[switch]$Run)
$ErrorActionPreference='Stop'
if(-not $Run){throw 'Explicit authorized private graphical run required'}
if((Get-FileHash -LiteralPath $CapturePlan).Hash.ToLowerInvariant()-ne$CaptureSha){throw 'Capture plan changed'}
$tracyConfig=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
$tracyPlan=Get-Content -LiteralPath $CapturePlan -Raw|ConvertFrom-Json
if($tracyPlan.client.file-ne$tracyConfig.engineLaunch-or$tracyPlan.client.sha256-ne$tracyConfig.engineSha256){throw 'Capture does not select exact private engine'}
& $tracyConfig.node (Join-Path $tracyConfig.source 'verify.cjs') $Config
if($LASTEXITCODE-ne0){throw 'Private stage verification failed'}
$tracyOut=Join-Path $tracyConfig.out 'graphical-check-a'
if(Test-Path -LiteralPath $tracyOut){throw 'Preserve previous graphical run'}
New-Item -ItemType Directory -Path $tracyOut|Out-Null
foreach($tracyName in @('appdata','localappdata')){New-Item -ItemType Directory -Path (Join-Path $tracyOut $tracyName)|Out-Null}
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $tracyOut 'executor.ps1')
$tracyInstall=[IO.Path]::GetFullPath((Join-Path $tracyConfig.project '../../FullDecomp/NwnRootInstall'))
if(-not(Test-Path -LiteralPath (Join-Path $tracyInstall 'data'))){throw 'Original installed resource directory missing'}
$tracyDescriptor=Get-Content -LiteralPath (Join-Path $tracyConfig.view $tracyConfig.descriptorRelative) -Raw|ConvertFrom-Json
$tracyReport=Join-Path $tracyOut 'report.json'
$tracyScript=Join-Path $tracyConfig.view 'tests/native_particle_stream_scene_test.gd'
$tracyProof=@{version=1;success=$false;startedUtc=[DateTime]::UtcNow.ToString('o');pid=0;forced=$false;stageManifestSha256=(Get-FileHash -LiteralPath (Join-Path $tracyConfig.out 'manifest.json')).Hash.ToLowerInvariant();test=@{file=$tracyScript;sha256=(Get-FileHash -LiteralPath $tracyScript).Hash.ToLowerInvariant()};scope='Original-textured64-emitter local compositor/CPU-render-trace check, artificially limited20FPS. No Arelith/gameplay or clean FPS comparison.'}
$tracyEngine=[Diagnostics.Process]::new();$tracyEngine.StartInfo=[Diagnostics.ProcessStartInfo]::new();$tracyEngine.StartInfo.FileName=$tracyConfig.engineLaunch;$tracyEngine.StartInfo.WorkingDirectory=$tracyOut;$tracyEngine.StartInfo.UseShellExecute=$false;$tracyEngine.StartInfo.CreateNoWindow=$true;$tracyEngine.StartInfo.WindowStyle='Hidden';$tracyEngine.StartInfo.RedirectStandardOutput=$true;$tracyEngine.StartInfo.RedirectStandardError=$true
$tracyArgs=@('--path',$tracyConfig.view,'--render-thread','separate','--max-fps','20','--resolution','960x540','--log-file',(Join-Path $tracyOut 'engine.log'),'--script','res://tests/native_particle_stream_scene_test.gd','--',('--report='+$tracyReport),('--install='+$tracyInstall),'--count=64','--profile=false')+@($tracyDescriptor.fullFunctionalFlags)
foreach($tracyArg in $tracyArgs){$tracyEngine.StartInfo.ArgumentList.Add([string]$tracyArg)}
foreach($tracyPair in @(@('APPDATA','appdata'),@('LOCALAPPDATA','localappdata'))){$tracyEngine.StartInfo.Environment[$tracyPair[0]]=Join-Path $tracyOut $tracyPair[1]}
$tracyProof.arguments=$tracyArgs;$tracyEngineOut=$null;$tracyEngineErr=$null
try{
 if(-not$tracyEngine.Start()){throw 'Private graphical engine failed to start'}
 $tracyProof.pid=$tracyEngine.Id;$tracyProof.creationFileTimeUtc=$tracyEngine.StartTime.ToUniversalTime().ToFileTimeUtc().ToString();$tracyEngineOut=$tracyEngine.StandardOutput.ReadToEndAsync();$tracyEngineErr=$tracyEngine.StandardError.ReadToEndAsync()
 $tracyWatch=[Diagnostics.Stopwatch]::StartNew();$tracyReady=$false
 while(-not$tracyReady){
  if($tracyEngine.HasExited){throw 'Graphical fixture exited before owned Tracy listener'}
  if($tracyWatch.Elapsed.TotalSeconds-gt15){throw 'Graphical listener startup exceeded15seconds'}
  $tracyListeners=@(Get-NetTCPConnection -LocalPort $tracyPlan.port -State Listen -ErrorAction SilentlyContinue)
  $tracyReady=$tracyListeners.Count-eq1-and$tracyListeners[0].OwningProcess-eq$tracyEngine.Id
  if(-not$tracyReady){Start-Sleep -Milliseconds 50}
 }
 $tracyProof.modules=@($tracyEngine.Modules|Where-Object ModuleName -EQ 'nwn-particle-kernel.dll'|ForEach-Object{@{name=$_.ModuleName;path=$_.FileName;sha256=(Get-FileHash -LiteralPath $_.FileName).Hash.ToLowerInvariant()}})
 if($tracyProof.modules.Count-ne1-or$tracyProof.modules[0].sha256-ne$tracyConfig.particleSha256){throw 'Actual private particle module differs'}
 & (Join-Path $tracyPlan.runtime 'capture-run.ps1') -Plan $CapturePlan -PlanSha $CaptureSha -ClientPid $tracyEngine.Id -ClientFileTimeUtc $tracyProof.creationFileTimeUtc -Run
 if(-not$tracyEngine.WaitForExit(40000)){throw 'Graphical fixture failed to finish within40seconds after capture'}
 $tracyProof.engineExit=$tracyEngine.ExitCode
 $tracyNative=Get-Content -LiteralPath $tracyReport -Raw|ConvertFrom-Json
 if($tracyProof.engineExit-ne0-or-not$tracyNative.success){throw 'Graphical fixture rejected; preserve output'}
 $tracyProof.report=@{file=$tracyReport;sha256=(Get-FileHash -LiteralPath $tracyReport).Hash.ToLowerInvariant()};$tracyProof.success=$true
}catch{$tracyProof.failure=$_.Exception.Message;throw}finally{
 if($tracyProof.pid-and-not$tracyEngine.HasExited-and$tracyEngine.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-eq$tracyProof.creationFileTimeUtc){$tracyEngine.Kill($true);[void]$tracyEngine.WaitForExit(5000);$tracyProof.forced=$true}
 foreach($tracyPair in @(@($tracyEngineOut,'stdout.log'),@($tracyEngineErr,'stderr.log'))){if($tracyPair[0]-and$tracyPair[0].Wait(5000)){[IO.File]::WriteAllText((Join-Path $tracyOut $tracyPair[1]),$tracyPair[0].GetAwaiter().GetResult())}}
 $tracyProof.finishedUtc=[DateTime]::UtcNow.ToString('o');$tracyProof|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $tracyOut 'process-proof.json') -Encoding utf8;$tracyEngine.Dispose()
}
$tracyProof|ConvertTo-Json -Depth 6
