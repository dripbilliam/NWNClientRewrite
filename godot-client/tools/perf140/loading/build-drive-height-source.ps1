# SOURCE-ONLY/unexecuted. Root must grant a CPU lane before invoking this.
param([Parameter(Mandatory=$true)][string]$Label,[string]$Corpus='')
$ErrorActionPreference='Stop'
if($Label -notmatch '^drive-height-(pure|golden)-[a-z0-9-]+$'){throw 'Fresh owned height-pure or height-golden label required'}
$ownedProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$ownedOutput=[IO.Path]::GetFullPath((Join-Path $ownedProject ('.cache/native-140fps/loading-agent/'+$Label)))
if(-not$ownedOutput.StartsWith($ownedProject+'\',[StringComparison]::OrdinalIgnoreCase)-or(Test-Path -LiteralPath $ownedOutput)){throw 'Fresh owned output required; existing evidence preserved'}
$ownedInputs=@{}
foreach($ownedName in @('drive_height_kernel.hpp','drive_height_kernel_test.cpp')){$ownedInputs[$ownedName]=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $ownedName) -Algorithm SHA256).Hash.ToLowerInvariant()}
$ownedCorpus='';$ownedCorpusSha='';$ownedReferenceReceipt='';$ownedReferenceSha=''
if($Corpus){
 $ownedCorpus=[IO.Path]::GetFullPath($Corpus)
 if(-not$ownedCorpus.StartsWith((Join-Path $ownedProject '.cache/native-140fps/loading-agent')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Corpus must be a private loading-agent output'}
 $ownedCorpusSha=(Get-FileHash -LiteralPath $ownedCorpus -Algorithm SHA256).Hash.ToLowerInvariant()
 $ownedReferenceReceipt=Join-Path ([IO.Path]::GetDirectoryName($ownedCorpus)) 'receipt.json'
 $ownedReferenceSha=(Get-FileHash -LiteralPath $ownedReferenceReceipt -Algorithm SHA256).Hash.ToLowerInvariant()
 $ownedReference=Get-Content -Raw -LiteralPath $ownedReferenceReceipt | ConvertFrom-Json
 $ownedReferenceCorpus=''
 if($ownedReference.corpus.file -is [string] -and -not [string]::IsNullOrWhiteSpace($ownedReference.corpus.file)){$ownedReferenceCorpus=[IO.Path]::GetFullPath($ownedReference.corpus.file)}
 if($ownedReference.success -isnot [bool] -or $ownedReference.success -ne $true -or
    $ownedReference.activationAccepted -isnot [bool] -or $ownedReference.activationAccepted -ne $true -or
    $ownedReference.corpusAccepted -isnot [bool] -or $ownedReference.corpusAccepted -ne $true -or
    $ownedReference.nativeHeightIntegration -isnot [bool] -or $ownedReference.nativeHeightIntegration -ne $false -or
    $ownedReference.engineSha256 -ne 'ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a' -or
    $ownedReferenceCorpus -ne $ownedCorpus -or $ownedReference.corpus.sha256 -ne $ownedCorpusSha){throw 'Verified exact-engine golden exporter receipt required; a bare corpus is not engine provenance'}
}
$ownedVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$ownedVs=@(& $ownedVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')} | Select-Object -First 1
if(-not$ownedVs){throw 'MSVC unavailable'}
$ownedVersion=(Get-Content -Raw -LiteralPath (Join-Path $ownedVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')).Trim()
$ownedTools=Join-Path $ownedVs ('VC/Tools/MSVC/'+$ownedVersion);$ownedCompiler=Join-Path $ownedTools 'bin/Hostx64/x64/cl.exe'
$ownedSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$ownedInclude=Get-ChildItem -LiteralPath (Join-Path $ownedSdk 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
if(-not$ownedInclude){throw 'Windows SDK unavailable'}
$env:INCLUDE=((Join-Path $ownedTools 'include'),(Join-Path $ownedInclude.FullName 'ucrt'),(Join-Path $ownedInclude.FullName 'shared'),(Join-Path $ownedInclude.FullName 'um')) -join ';'
$env:LIB=((Join-Path $ownedTools 'lib/x64'),(Join-Path $ownedSdk ('Lib/'+$ownedInclude.Name+'/ucrt/x64')),(Join-Path $ownedSdk ('Lib/'+$ownedInclude.Name+'/um/x64'))) -join ';'
New-Item -ItemType Directory -Path $ownedOutput | Out-Null
$ownedStarted=[DateTime]::UtcNow.ToString('o')
Push-Location $ownedOutput
try{
 & $ownedCompiler /nologo /O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /I $PSScriptRoot (Join-Path $PSScriptRoot 'drive_height_kernel_test.cpp') /Fe:drive-height-pure.exe 2>&1 | Tee-Object -FilePath (Join-Path $ownedOutput 'compiler.log')
 if($LASTEXITCODE-ne0){throw 'Standalone height build failed'}
 if($ownedCorpus){& (Join-Path $ownedOutput 'drive-height-pure.exe') $ownedCorpus 2>&1 | Tee-Object -FilePath (Join-Path $ownedOutput 'oracle.log')}else{& (Join-Path $ownedOutput 'drive-height-pure.exe') 2>&1 | Tee-Object -FilePath (Join-Path $ownedOutput 'oracle.log')}
 if($LASTEXITCODE-ne0){throw 'Standalone height oracle failed'}
}finally{Pop-Location}
$ownedOracle=Get-Content -LiteralPath (Join-Path $ownedOutput 'oracle.log') | Select-Object -Last 1 | ConvertFrom-Json
$ownedCorpusExpected=[bool]$ownedCorpus
if($ownedOracle.success -isnot [bool] -or $ownedOracle.success -ne $true -or
   $ownedOracle.checks -le 0 -or $ownedOracle.goldenCorpusProvided -isnot [bool] -or
   $ownedOracle.goldenCorpusProvided -ne $ownedCorpusExpected){throw 'Standalone oracle result/activation proof invalid'}
foreach($ownedName in $ownedInputs.Keys){if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $ownedName) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$ownedInputs[$ownedName]){throw 'Height source changed during build'}}
if($ownedCorpus-and(Get-FileHash -LiteralPath $ownedCorpus -Algorithm SHA256).Hash.ToLowerInvariant()-ne$ownedCorpusSha){throw 'Corpus changed during oracle'}
if($ownedReferenceReceipt-and(Get-FileHash -LiteralPath $ownedReferenceReceipt -Algorithm SHA256).Hash.ToLowerInvariant()-ne$ownedReferenceSha){throw 'Golden exporter receipt changed during oracle'}
@{success=$true;label=$Label;compiler=$ownedVersion;flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD';sourceRoot=$PSScriptRoot;sourcePins=$ownedInputs;outputRoot=$ownedOutput;binarySha256=(Get-FileHash -LiteralPath (Join-Path $ownedOutput 'drive-height-pure.exe') -Algorithm SHA256).Hash.ToLowerInvariant();corpus=$ownedCorpus;corpusSha256=$ownedCorpusSha;goldenReferenceReceipt=$ownedReferenceReceipt;goldenReferenceSha256=$ownedReferenceSha;oracle=$ownedOracle;startedAt=$ownedStarted;endedAt=[DateTime]::UtcNow.ToString('o');nativeDllBuilds=0;sharedOutputWrites=0;serverConnections=0;graphics=0;runtimeIntegration=$false;scope='Standalone pure/verified actual-Godot golden-corpus correctness only; no FPS or live gameplay claim'} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $ownedOutput 'receipt.json') -Encoding utf8
