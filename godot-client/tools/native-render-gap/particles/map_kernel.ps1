param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label,[switch]$TimestampFromOriginal)
$ErrorActionPreference='Stop'
(Get-Process -Id $PID).PriorityClass='BelowNormal'
$mapProjectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$mapStage=Join-Path $mapProjectRoot ('.cache/native-render-gap/particles/'+$Label)
$mapBuild=Join-Path $mapStage 'kernel-build'
$mapReceipt=Get-Content -LiteralPath (Join-Path $mapBuild 'build-receipt.json') -Raw|ConvertFrom-Json
if(-not $mapReceipt.success){throw 'Original kernel build did not pass'}
$mapOriginal=[IO.Path]::GetFullPath($mapReceipt.binary)
if($mapOriginal -ne [IO.Path]::GetFullPath((Join-Path $mapBuild 'nwn-particle-kernel.dll'))){throw 'Original DLL is outside expected private build'}
if((Get-FileHash -LiteralPath $mapOriginal).Hash.ToLowerInvariant() -ne $mapReceipt.binarySha256){throw 'Original binary pin changed'}
$mapObject=Join-Path $mapBuild 'particle-kernel.obj'
$mapObjectSha=(Get-FileHash -LiteralPath $mapObject).Hash.ToLowerInvariant()
$mapOutput=Join-Path $mapStage $(if($TimestampFromOriginal){'kernel-map-b'}else{'kernel-map-a'})
if(Test-Path -LiteralPath $mapOutput){throw 'Prior map evidence retained'}
New-Item -ItemType Directory -Path $mapOutput|Out-Null
$mapBinary=Join-Path $mapOutput 'nwn-particle-kernel.dll'
$mapFile=Join-Path $mapOutput 'nwn-particle-kernel.map'
$mapCompiler=[IO.Path]::GetFullPath($mapReceipt.compiler)
if((Get-FileHash -LiteralPath $mapCompiler).Hash.ToLowerInvariant() -ne $mapReceipt.compilerSha256){throw 'Original compiler pin changed'}
$mapToolRoot=[IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $mapCompiler) '../../..'))
$mapSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$mapSdkInclude=Get-ChildItem -LiteralPath (Join-Path $mapSdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not $mapSdkInclude){throw 'Original Windows SDK unavailable'}
$mapArguments=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD',('/Fe'+$mapBinary),$mapObject,'/link','/INCREMENTAL:NO',('/IMPLIB:'+(Join-Path $mapOutput 'particle-kernel.lib')),('/MAP:'+$mapFile))
$mapRequestedTimestamp=$null
if($TimestampFromOriginal){$mapOriginalBytes=[IO.File]::ReadAllBytes($mapOriginal);$mapPeOffset=[BitConverter]::ToUInt32($mapOriginalBytes,60);$mapRequestedTimestamp=[BitConverter]::ToUInt32($mapOriginalBytes,$mapPeOffset+8);$mapArguments+=('/TIMESTAMP:'+$mapRequestedTimestamp)}
$mapPreviousInclude=$env:INCLUDE;$mapPreviousLib=$env:LIB
$mapStarted=[DateTime]::UtcNow.ToString('o');$mapExit=-1;$mapCompareExit=-1
try{
 $env:INCLUDE=((Join-Path $mapToolRoot 'include'),(Join-Path $mapSdkInclude.FullName 'ucrt'),(Join-Path $mapSdkInclude.FullName 'shared'),(Join-Path $mapSdkInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $mapToolRoot 'lib/x64'),(Join-Path $mapSdk ('Lib/'+$mapSdkInclude.Name+'/ucrt/x64')),(Join-Path $mapSdk ('Lib/'+$mapSdkInclude.Name+'/um/x64')))-join';'
 & $mapCompiler @mapArguments 2>&1|Tee-Object -FilePath (Join-Path $mapOutput 'linker.log')
 $mapExit=$LASTEXITCODE
 if($mapExit -ne 0){throw ('Same-object MAP link failed '+$mapExit)}
 & node (Join-Path $mapProjectRoot 'tools/native-render-gap/original/frame-pacing/compare-map-layout.cjs') $mapOriginal $mapBinary $mapFile > (Join-Path $mapOutput 'layout-proof.json')
 $mapCompareExit=$LASTEXITCODE
 $mapProof=Get-Content -LiteralPath (Join-Path $mapOutput 'layout-proof.json') -Raw|ConvertFrom-Json
 if((Get-FileHash -LiteralPath $mapOriginal).Hash.ToLowerInvariant() -ne $mapReceipt.binarySha256){throw 'Original binary mutated'}
 if((Get-FileHash -LiteralPath $mapObject).Hash.ToLowerInvariant() -ne $mapObjectSha){throw 'Original object mutated'}
 @{version=1;success=$mapExit -eq 0;olderBinaryMappingAllowed=$mapProof.olderBinaryMappingAllowed;fullFileIdentical=$mapProof.before.sha256 -eq $mapProof.after.sha256;startedUtc=$mapStarted;finishedUtc=[DateTime]::UtcNow.ToString('o');compiler=$mapCompiler;arguments=$mapArguments;requestedLinkTimestamp=$mapRequestedTimestamp;originalBinary=$mapOriginal;originalBinarySha256=$mapReceipt.binarySha256;object=$mapObject;objectSha256=$mapObjectSha;binary=$mapBinary;binarySha256=(Get-FileHash -LiteralPath $mapBinary).Hash.ToLowerInvariant();map=$mapFile;mapSha256=(Get-FileHash -LiteralPath $mapFile).Hash.ToLowerInvariant();linkExit=$mapExit;compareExit=$mapCompareExit;sourceCompilation=0;originalInputsUnchanged=$true;normalizationApplied=$false;scope='Private same-OBJ MAP relink; older RIP mapping allowed only if every loadable section, RVA, size, flags and byte matches. No timestamps or debug data normalized.'}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $mapOutput 'receipt.json') -Encoding utf8
 [PSCustomObject]@{linkExit=$mapExit;compareExit=$mapCompareExit;olderBinaryMappingAllowed=$mapProof.olderBinaryMappingAllowed;receipt=(Join-Path $mapOutput 'receipt.json')}
}catch{
 @{success=$false;startedUtc=$mapStarted;finishedUtc=[DateTime]::UtcNow.ToString('o');linkExit=$mapExit;compareExit=$mapCompareExit;error=$_.Exception.Message;normalizationApplied=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $mapOutput 'failure.json') -Encoding utf8
 throw
}finally{$env:INCLUDE=$mapPreviousInclude;$env:LIB=$mapPreviousLib}
