param([Parameter(Mandatory=$true)][string]$Label)
$ErrorActionPreference='Stop'
if($Label -notmatch '^combined-loading-accounting-[a-z0-9-]+$'){throw 'Owned accounting candidate label required'}
$ownedProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$ownedStage=[IO.Path]::GetFullPath((Join-Path $ownedProject ('.cache/native-140fps/loading-agent/'+$Label)))
$ownedDraft=Get-Content -Raw -LiteralPath (Join-Path $ownedStage 'draft.json') | ConvertFrom-Json
$ownedCandidate=[IO.Path]::GetFullPath((Join-Path $ownedStage 'project'))
if($ownedDraft.project-ne$ownedCandidate-or-not$ownedStage.StartsWith($ownedProject+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Draft/output ownership differs'}
$ownedOutput=Join-Path $ownedStage 'build-output'
if(Test-Path -LiteralPath $ownedOutput){throw 'Existing build evidence preserved'}
New-Item -ItemType Directory -Path $ownedOutput | Out-Null
$ownedSource=Join-Path $ownedCandidate 'native/resource_index.cpp'
$ownedSourceSha=(Get-FileHash -LiteralPath $ownedSource -Algorithm SHA256).Hash.ToLowerInvariant()
if($ownedSourceSha-ne($ownedDraft.pins | Where-Object relative -eq 'native/resource_index.cpp').sha256){throw 'Draft native source differs'}
$ownedDependencies=@{}
foreach($ownedRelative in @('native/resource_index.cpp','native/two_da_parser.hpp','native/resource_index.gdextension')){
 $ownedSha=(Get-FileHash -LiteralPath (Join-Path $ownedCandidate $ownedRelative) -Algorithm SHA256).Hash.ToLowerInvariant()
 if($ownedSha-ne($ownedDraft.pins | Where-Object relative -eq $ownedRelative).sha256){throw 'Pinned native dependency differs'}
 $ownedDependencies[$ownedRelative]=$ownedSha
}
$ownedApi=Join-Path $ownedProject '.tools/extension-api'
$ownedHeader=Join-Path $ownedApi 'gdextension_interface.h'; $ownedApiFile=Join-Path $ownedApi 'extension_api.json'
$ownedHeaderSha=(Get-FileHash -LiteralPath $ownedHeader -Algorithm SHA256).Hash.ToLowerInvariant(); $ownedApiSha=(Get-FileHash -LiteralPath $ownedApiFile -Algorithm SHA256).Hash.ToLowerInvariant()
$ownedAbi=Get-Content -Raw -LiteralPath $ownedApiFile | ConvertFrom-Json
if($ownedAbi.header.version_full_name-ne'Godot Engine v4.7.2.stable.official'-or$ownedAbi.header.precision-ne'single'){throw 'Pinned Godot 4.7.2 single-precision ABI required'}
$ownedSizes=($ownedAbi.builtin_class_sizes | Where-Object build_configuration -eq float_64).sizes
foreach($ownedPair in @(@('Variant',24),@('StringName',8),@('String',8),@('PackedByteArray',16),@('PackedFloat32Array',16),@('Basis',36),@('Transform3D',48),@('Quaternion',16),@('Vector3',12),@('AABB',24))){if(($ownedSizes | Where-Object name -eq $ownedPair[0]).size-ne$ownedPair[1]){throw 'GDExtension ABI size differs'}}
$ownedVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$ownedVs=@(& $ownedVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')} | Select-Object -First 1
if(-not$ownedVs){throw 'MSVC unavailable'}
$ownedVersion=(Get-Content -Raw -LiteralPath (Join-Path $ownedVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')).Trim()
$ownedTools=Join-Path $ownedVs ('VC/Tools/MSVC/'+$ownedVersion); $ownedCompiler=Join-Path $ownedTools 'bin/Hostx64/x64/cl.exe'
$ownedSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$ownedInclude=Get-ChildItem -LiteralPath (Join-Path $ownedSdk 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
if(-not$ownedInclude){throw 'Windows SDK unavailable'}
$env:INCLUDE=((Join-Path $ownedTools 'include'),(Join-Path $ownedInclude.FullName 'ucrt'),(Join-Path $ownedInclude.FullName 'shared'),(Join-Path $ownedInclude.FullName 'um')) -join ';'
$env:LIB=((Join-Path $ownedTools 'lib/x64'),(Join-Path $ownedSdk ('Lib/'+$ownedInclude.Name+'/ucrt/x64')),(Join-Path $ownedSdk ('Lib/'+$ownedInclude.Name+'/um/x64'))) -join ';'
$ownedBegan=[DateTime]::UtcNow.ToString('o')
Push-Location $ownedOutput
try{ & $ownedCompiler /nologo /O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD /I $ownedApi $ownedSource /Fe:nwn-resource-index.dll /link /INCREMENTAL:NO; if($LASTEXITCODE-ne0){throw 'Private native accountant build failed'} }finally{Pop-Location}
if((Get-FileHash -LiteralPath $ownedSource -Algorithm SHA256).Hash.ToLowerInvariant()-ne$ownedSourceSha-or(Get-FileHash -LiteralPath $ownedHeader -Algorithm SHA256).Hash.ToLowerInvariant()-ne$ownedHeaderSha-or(Get-FileHash -LiteralPath $ownedApiFile -Algorithm SHA256).Hash.ToLowerInvariant()-ne$ownedApiSha){throw 'Native build input drift'}
foreach($ownedRelative in $ownedDependencies.Keys){if((Get-FileHash -LiteralPath (Join-Path $ownedCandidate $ownedRelative) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$ownedDependencies[$ownedRelative]){throw 'Native dependency changed during build'}}
@{success=$true;project=$ownedCandidate;sourceSha256=$ownedSourceSha;dependencies=$ownedDependencies;headerSha256=$ownedHeaderSha;apiSha256=$ownedApiSha;compiler=$ownedVersion;flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD';binarySha256=(Get-FileHash -LiteralPath (Join-Path $ownedOutput 'nwn-resource-index.dll') -Algorithm SHA256).Hash.ToLowerInvariant();startedAt=$ownedBegan;endedAt=[DateTime]::UtcNow.ToString('o');sharedOutputWrites=0;scope='Private accounting access prototype; functional proof required, no timing claim'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $ownedOutput 'build-proof.json') -Encoding utf8
