param([switch]$Baseline,[string]$Install='')
$ErrorActionPreference='Stop'
$portraitProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$portraitWorkspace=[IO.Path]::GetFullPath((Join-Path $portraitProject '..'))
$portraitGodot=Join-Path $portraitProject '.tools/Godot_v4.7.2-stable_win64.exe'
if((Get-FileHash -LiteralPath $portraitGodot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing runtime'}
if(-not $Install){$Install=[IO.Path]::GetFullPath((Join-Path $portraitWorkspace '../FullDecomp/NwnRootInstall'))}
$portraitRun=Join-Path $portraitProject ('.cache/portrait-asset-queue-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$portraitCopy=Join-Path $portraitRun 'project';[IO.Directory]::CreateDirectory($portraitCopy)|Out-Null
$portraitScripts=@('tests/native_portrait_asset_queue_test.gd','tests/native_ui_art_binding_test.gd','tests/native_ui_art_queue_policy_test.gd')
$portraitClosure=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$portraitPending=[Collections.Generic.Queue[string]]::new()
foreach($relative in $portraitScripts){$portraitPending.Enqueue($relative)}
while($portraitPending.Count){
 $relative=$portraitPending.Dequeue();if(-not $portraitClosure.Add($relative)){continue}
 $source=Join-Path $portraitProject $relative
 if(-not(Test-Path -LiteralPath $source)){throw ('Missing static dependency: '+$relative)}
 if($relative.EndsWith('.gd')){foreach($match in [regex]::Matches([IO.File]::ReadAllText($source),'res://([^"\r\n]+\.(?:gdshader|json|gd))"')){$portraitPending.Enqueue($match.Groups[1].Value)}}
}
foreach($relative in @('native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','tools/test-native-portrait-asset-queue.ps1')){[void]$portraitClosure.Add($relative)}
$portraitInputs=@()
foreach($relative in ($portraitClosure|Sort-Object)){
 $source=Join-Path $portraitProject $relative;$destination=Join-Path $portraitCopy $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
 $hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant();Copy-Item -LiteralPath $source -Destination $destination
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hash){throw ('Changed during copy: '+$relative)}
 $portraitInputs+=@{path=$relative;sha256=$hash}
}
[IO.File]::WriteAllText((Join-Path $portraitCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Actual Portrait Bitmap Queue""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
$portraitResults=@()
foreach($script in $portraitScripts){
 $name=[IO.Path]::GetFileNameWithoutExtension($script);$log=Join-Path $portraitRun ($name+'.engine.log');$output=Join-Path $portraitRun ($name+'.json')
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$portraitGodot;$info.WorkingDirectory=$portraitWorkspace;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 foreach($argument in @('--headless','--max-fps','60','--path',$portraitCopy,'--log-file',$log,'--script',('res://'+$script),'--',('--report='+$output),('--install='+$Install),'--entity-api-rest=false')){$info.ArgumentList.Add($argument)}
 $ownedProcess=$null;$outFile=$null;$errFile=$null;$timedOut=$false;$logStopped=$false
 try{
  $ownedProcess=[Diagnostics.Process]::Start($info)
  $outFile=[IO.File]::Create((Join-Path $portraitRun ($name+'.stdout.log')));$errFile=[IO.File]::Create((Join-Path $portraitRun ($name+'.stderr.log')))
  $outTask=$ownedProcess.StandardOutput.BaseStream.CopyToAsync($outFile);$errTask=$ownedProcess.StandardError.BaseStream.CopyToAsync($errFile)
  $deadline=[DateTime]::UtcNow.AddSeconds(35)
  while(-not $ownedProcess.WaitForExit(250)){
   if([DateTime]::UtcNow-ge$deadline){$timedOut=$true;break}
   if((Test-Path -LiteralPath $log)-and(Get-Item -LiteralPath $log).Length-gt 8388608){$logStopped=$true;break}
  }
  if(-not $ownedProcess.HasExited){$ownedProcess.Kill($true);$ownedProcess.WaitForExit()}
  $null=$outTask.GetAwaiter().GetResult();$null=$errTask.GetAwaiter().GetResult();$ownedProcess.Refresh()
  $result=if(Test-Path -LiteralPath $output){Get-Content -LiteralPath $output -Raw|ConvertFrom-Json}else{$null}
  $clean=(Test-Path -LiteralPath $log)-and([IO.File]::ReadAllText($log)-notmatch '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit')
  $portraitResults+=@{script=$script;success=[bool]($result-and$result.success-and$ownedProcess.ExitCode-eq0-and$clean-and-not$timedOut-and-not$logStopped);checks=if($result){$result.checks}else{0};exitCode=$ownedProcess.ExitCode;timedOut=$timedOut;logGuard=$logStopped;cleanEngine=$clean;result=$output;engineLog=$log}
 }finally{if($ownedProcess-and-not$ownedProcess.HasExited){$ownedProcess.Kill($true);$ownedProcess.WaitForExit()};if($outFile){$outFile.Dispose()};if($errFile){$errFile.Dispose()}}
}
$portraitChanged=@($portraitInputs|Where-Object{(Get-FileHash -LiteralPath (Join-Path $portraitProject $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$portraitCopyChanged=@($portraitInputs|Where-Object{(Get-FileHash -LiteralPath (Join-Path $portraitCopy $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$portraitSuccess=-not($portraitResults|Where-Object{-not$_.success})-and$portraitChanged.Count-eq0-and$portraitCopyChanged.Count-eq0
$portraitReceipt=@{success=[bool]$portraitSuccess;baseline=[bool]$Baseline;testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$portraitRun;inputs=$portraitInputs;changedInputs=$portraitChanged;changedCopiedInputs=$portraitCopyChanged;results=$portraitResults;publicConnections=0;nativeBuilds=0;gpu=$false;scope='Actual installed bitmap asset decode/publication, Portrait pooled jump/revisit and lifecycle under bounded real AssetService admission; existing async binding identity. Controlled frame art/fonts. No screenshot or full creator claim.'}
[IO.File]::WriteAllText((Join-Path $portraitRun 'runner.json'),($portraitReceipt|ConvertTo-Json -Depth 9))
if($portraitSuccess-and-not$Baseline){[IO.File]::WriteAllText((Join-Path $portraitProject 'reports/native-portrait-asset-queue-v1-receipt.json'),($portraitReceipt|ConvertTo-Json -Depth 9))}
@{success=[bool]$portraitSuccess;baseline=[bool]$Baseline;directory=$portraitRun;inputCount=$portraitInputs.Count;results=$portraitResults;changedInputs=$portraitChanged.Count;changedCopiedInputs=$portraitCopyChanged.Count}|ConvertTo-Json -Depth 6
if(-not$portraitSuccess-and-not$Baseline){throw ('Owned Portrait bitmap test rejected: '+$portraitRun)}
