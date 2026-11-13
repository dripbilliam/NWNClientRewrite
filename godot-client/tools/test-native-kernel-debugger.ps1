param([ValidatePattern('^[a-z0-9-]{3,80}$')][string]$Run='native-kernel-vertices-v1',[string]$Script='res://tests/native_particle_vertices_test.gd',[string[]]$TestArguments=@('--kernel=compiled'),[switch]$Graphical,[ValidateSet('default','safe','separate')][string]$RenderThread='default',[ValidateSet('editor','release')][string]$Runtime='editor')
$ErrorActionPreference='Stop'
$kernelProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
& (Join-Path $PSScriptRoot 'ensure-particle-kernel.ps1')
& (Join-Path $PSScriptRoot 'ensure-resource-index.ps1')
$kernelExecutable=Join-Path $kernelProject '.tools/Godot_v4.7.2-stable_win64.exe'
if($Runtime-eq'release'){$kernelPackage=& (Join-Path $PSScriptRoot 'prepare-release-test.ps1');if($kernelPackage.kind-ne'native-release-package'){throw 'Release test package is unavailable'};$kernelExecutable=$kernelPackage.executable}
$kernelReport=Join-Path $kernelProject ('reports/'+$Run+'.json')
$kernelProof=$kernelReport.Replace('.json','.debugger.json')
$kernelLog=$kernelReport.Replace('.json','.cdb.log')
$kernelEngineLog=$kernelReport.Replace('.json','.engine.log')
$kernelCommands=$kernelReport.Replace('.json','.cdb.txt')
$kernelConsole=$kernelReport.Replace('.json','.console.log')
foreach($kernelOutput in @($kernelReport,$kernelProof,$kernelLog,$kernelEngineLog,$kernelCommands,$kernelConsole)){if(Test-Path -LiteralPath $kernelOutput){throw 'Kernel evidence output already exists'}}
$kernelHashes=[ordered]@{}
$kernelInputs=@(& rg --files (Join-Path $kernelProject 'systems') (Join-Path $kernelProject 'native') (Join-Path $kernelProject 'tests') -g '*.gd' -g '*.cpp' -g '*.hpp' -g '*.gdextension')+@((Join-Path $kernelProject '.cache/native-kernel/nwn-particle-kernel.dll'),(Join-Path $kernelProject '.cache/native-kernel/build-manifest.json'),(Join-Path $kernelProject '.cache/native-resource-index/nwn-resource-index.dll'),(Join-Path $kernelProject '.cache/native-resource-index/build-manifest.json'),$PSCommandPath,(Join-Path $PSScriptRoot 'build-particle-kernel.ps1'),(Join-Path $PSScriptRoot 'ensure-particle-kernel.ps1'),(Join-Path $PSScriptRoot 'build-resource-index.ps1'),(Join-Path $PSScriptRoot 'ensure-resource-index.ps1'))
$kernelInputs+=$kernelExecutable
if($Runtime-eq'release'){$kernelInputs+=@($kernelPackage.pack,$kernelPackage.receipt,(Join-Path $kernelProject '.tools/release-runtime-4.7.2.verified.json'),(Join-Path $PSScriptRoot 'ensure-release-runtime.ps1'),(Join-Path $PSScriptRoot 'prepare-release-test.ps1'),(Join-Path $PSScriptRoot 'prepare-release-pack.gd'))}
foreach($kernelInput in $kernelInputs){$kernelHashes[[IO.Path]::GetFullPath($kernelInput).Substring($kernelProject.Length+1).Replace('\','/')]=(Get-FileHash -LiteralPath $kernelInput -Algorithm SHA256).Hash.ToLowerInvariant()}
$kernelTrap='.echo NATIVE_KERNEL_EXCEPTION;.exr -1;.ecxr;kv;~* k;q'
$kernelSetup=@('av','0xc0000374','0xc0000409','0xc000001d') | ForEach-Object {'sxe -c "'+$kernelTrap+'" '+$_}
$kernelSetup+=@('.echo NATIVE_KERNEL_ARMED','g')
[IO.File]::WriteAllLines($kernelCommands,$kernelSetup)
$kernelCdb='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe'
$kernelArgs=@('-hd','-G','-sins','-y',(Join-Path $kernelProject '.tools'),'-logo',$kernelLog,'-cf',$kernelCommands,$kernelExecutable)
if($Runtime-ne'release'){$kernelArgs+=@('--path',$kernelProject)}
$kernelArgs+=@('--log-file',$kernelEngineLog)
if($RenderThread-ne'default'){$kernelArgs+=@('--render-thread',$RenderThread)}
if(-not$Graphical){$kernelArgs+='--headless'}
else{
 . (Join-Path $PSScriptRoot 'native-window-screen.ps1')
 $kernelScreen=Get-NativeSecondaryScreen
 if($kernelScreen-ge0){$kernelArgs+=@('--screen',[string]$kernelScreen)}
}
if($Runtime-eq'release'){$kernelArgs+=@('--',('--release-entry='+$Script),('--report='+$kernelReport))+$TestArguments}else{$kernelArgs+=@('--script',$Script,'--',('--report='+$kernelReport))+$TestArguments}
Push-Location -LiteralPath $(if($Runtime-eq'release'){$kernelPackage.directory}else{$kernelProject})
try{& $kernelCdb @kernelArgs 2>&1 | Out-File -LiteralPath $kernelConsole -Encoding utf8;$kernelExit=$LASTEXITCODE}finally{Pop-Location}
$kernelText=Get-Content -LiteralPath $kernelLog -Raw
$kernelResult=if(Test-Path -LiteralPath $kernelReport){Get-Content -LiteralPath $kernelReport -Raw | ConvertFrom-Json}else{$null}
$kernelUnchanged=$true
foreach($kernelInput in $kernelHashes.Keys){if((Get-FileHash -LiteralPath (Join-Path $kernelProject $kernelInput) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$kernelHashes[$kernelInput]){$kernelUnchanged=$false}}
$kernelArmed=$kernelText-match '(?m)^NATIVE_KERNEL_ARMED\r?$'
$kernelException=$kernelText-match '(?m)^NATIVE_KERNEL_EXCEPTION\r?$'
$kernelEngineText=if(Test-Path -LiteralPath $kernelEngineLog){Get-Content -LiteralPath $kernelEngineLog -Raw}else{'ERROR: Engine log missing'}
$kernelConsoleText=Get-Content -LiteralPath $kernelConsole -Raw
$kernelEngineError=($kernelText+[Environment]::NewLine+$kernelEngineText+[Environment]::NewLine+$kernelConsoleText)-match '(?m)SCRIPT ERROR|^ERROR:|ObjectDB.*leak|resources still in use|Unicode parsing error'
$kernelPassed=$kernelExit-eq 0-and$kernelResult.success-and$kernelArmed-and-not$kernelException-and-not$kernelEngineError-and$kernelUnchanged
$kernelEvidence=[ordered]@{success=$kernelPassed;report=$kernelReport;script=$Script;testArguments=$TestArguments;compiledKernelEnvironment=$env:NWN_PARTICLE_KERNEL;graphical=[bool]$Graphical;renderThreadRequested=$RenderThread;debuggerExit=$kernelExit;normalHeap=$true;exceptionTraps=4;armed=$kernelArmed;exception=$kernelException;engineOrLifetimeError=$kernelEngineError;sourceUnchanged=$kernelUnchanged;sourceSha256=$kernelHashes;publicConnections=0;fullMigrationAccepted=$false;performanceAccepted=$false;scope='Compiled native kernel diagnostic; check report for original corpus/fixture coverage'}
$kernelEvidence.runtime=$Runtime;$kernelEvidence.runtimeExecutable=$kernelExecutable
if($Runtime-eq'release'){$kernelEvidence.package=$kernelPackage}
[IO.File]::WriteAllText($kernelProof,($kernelEvidence | ConvertTo-Json -Depth 6)+[Environment]::NewLine)
Write-Output (@{success=$kernelPassed;checks=$kernelResult.checks;proof=$kernelProof;sourceUnchanged=$kernelUnchanged;engineOrLifetimeError=$kernelEngineError}|ConvertTo-Json -Compress)
if(-not$kernelPassed){throw 'Native kernel debugger check failed; inspect retained evidence'}
