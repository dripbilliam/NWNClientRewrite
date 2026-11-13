param([string]$Godot='')
$ErrorActionPreference='Stop'
$fittingProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if(-not $Godot){$Godot=Join-Path $fittingProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not(Test-Path -LiteralPath $Godot)){throw 'Existing Godot executable is required; this runner never builds or downloads'}
$fittingRun=Join-Path $fittingProject ('.cache/nameplate-text-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($fittingRun)|Out-Null
$fittingInputs=@('systems/native_data/nameplate_text.gd','systems/native_data/radial_text.gd','systems/native_render/particle_math.gd','systems/native_render/particle_trig.gd','systems/native_nameplate.gd','systems/native_nameplate_mesh.gd','systems/server_text.gd','tests/native_nameplate_text_test.gd')
$fittingHashes=@()
foreach($fittingRelative in $fittingInputs){
 $fittingOriginal=Join-Path $fittingProject $fittingRelative
 $fittingCopy=Join-Path $fittingRun $fittingRelative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($fittingCopy))|Out-Null
 $fittingHash=(Get-FileHash -LiteralPath $fittingOriginal -Algorithm SHA256).Hash.ToLowerInvariant()
 Copy-Item -LiteralPath $fittingOriginal -Destination $fittingCopy
 if((Get-FileHash -LiteralPath $fittingCopy -Algorithm SHA256).Hash.ToLowerInvariant()-ne$fittingHash){throw 'Nameplate source changed while copying'}
 $fittingHashes+=@{path=$fittingRelative;sha256=$fittingHash}
}
$fittingOracle=[IO.Path]::GetFullPath((Join-Path $fittingProject '../backups/animations/native-nameplate-text-v3.json'))
$fittingOracleHash=(Get-FileHash -LiteralPath $fittingOracle -Algorithm SHA256).Hash.ToLowerInvariant()
$fittingRunnerHash=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $fittingRun 'project.godot'),@'
config_version=5
[application]
config/name="Isolated Original Nameplate Text"
[rendering]
renderer/rendering_method="gl_compatibility"
'@)
$fittingReport=Join-Path $fittingRun 'result.json'
$fittingLog=Join-Path $fittingRun 'engine.log'
$fittingOut=Join-Path $fittingRun 'stdout.log'
$fittingErr=Join-Path $fittingRun 'stderr.log'
$fittingArguments=@('--headless','--path',('"'+$fittingRun+'"'),'--log-file',('"'+$fittingLog+'"'),'--script','res://tests/native_nameplate_text_test.gd','--',('"--report='+$fittingReport+'"'),('"--oracle='+$fittingOracle+'"'))
$fittingOwned=Start-Process -FilePath $Godot -ArgumentList $fittingArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $fittingOut -RedirectStandardError $fittingErr
if(-not $fittingOwned.WaitForExit(30000)){
 $fittingOwned.Kill();$fittingOwned.WaitForExit()
 Get-Content -LiteralPath $fittingLog -Tail 40 -ErrorAction SilentlyContinue|Out-Host
 throw 'Stopped only the runner-owned timed-out headless nameplate test'
}
$fittingOwned.Refresh()
Get-Content -LiteralPath $fittingOut|Out-Host
Get-Content -LiteralPath $fittingErr|Out-Host
if(-not(Test-Path -LiteralPath $fittingReport)){throw 'Nameplate test produced no receipt'}
$fittingResult=Get-Content -LiteralPath $fittingReport -Raw|ConvertFrom-Json
$fittingEngine=[IO.File]::ReadAllText($fittingLog)
$fittingEngineClean=$fittingEngine-notmatch '(?m)SCRIPT ERROR|^ERROR:|ObjectDB.*leak|resources still in use|Unicode parsing error'
if($fittingOwned.ExitCode-ne0-or-not$fittingResult.success-or-not$fittingEngineClean){throw 'Nameplate test failed; inspect the isolated logs'}
foreach($fittingEntry in $fittingHashes){
 if((Get-FileHash -LiteralPath (Join-Path $fittingProject $fittingEntry.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$fittingEntry.sha256){throw ('Nameplate input changed during test: '+$fittingEntry.path)}
}
if((Get-FileHash -LiteralPath $fittingOracle -Algorithm SHA256).Hash.ToLowerInvariant()-ne$fittingOracleHash-or(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()-ne$fittingRunnerHash){throw 'Nameplate oracle/runner changed during test'}
$fittingReceipt=[ordered]@{success=$true;testedAtUtc=[DateTime]::UtcNow.ToString('o');checks=$fittingResult.checks;headless=$true;gpu=$false;gameServerConnections=0;nativeBuilds=0;exitCode=$fittingOwned.ExitCode;engineOrLifetimeError=$false;engine=$Godot;engineSha256=(Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash.ToLowerInvariant();sourceUnchanged=$true;inputs=$fittingHashes;oracle=@{path=$fittingOracle;sha256=$fittingOracleHash;cases=459;policies=272};runnerSha256=$fittingRunnerHash;isolatedProject=$fittingRun;report=$fittingReport;engineLog=$fittingLog;scope=$fittingResult.scope;originalPixelsAccepted=$false;fullUiAccepted=$false}
[IO.File]::WriteAllText((Join-Path $fittingProject 'reports/native-nameplate-text-v1-receipt.json'),($fittingReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
$fittingReceipt|ConvertTo-Json -Depth 8
