param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label)
$ErrorActionPreference='Stop'
$highlightProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$highlightFolder=Join-Path $highlightProject ('.cache/native-presentation-parity/particles-agent/'+$Label)
if(Test-Path -LiteralPath $highlightFolder){throw 'Existing isolated build preserved'}
$highlightHeader=Join-Path $highlightProject '.tools/extension-api/gdextension_interface.h'
$highlightJson=Join-Path $highlightProject '.tools/extension-api/extension_api.json'
$highlightAbi=Get-Content -LiteralPath $highlightJson -Raw | ConvertFrom-Json
if($highlightAbi.header.precision-ne'single'){throw 'Single precision Godot ABI required'}
$highlightSizes=($highlightAbi.builtin_class_sizes | Where-Object build_configuration -eq float_64).sizes
foreach($highlightPair in @(@('Variant',24),@('Array',8),@('Dictionary',8),@('StringName',8),@('String',8),@('PackedByteArray',16),@('PackedFloat32Array',16),@('PackedColorArray',16),@('Transform3D',48),@('Vector3',12),@('AABB',24))){if(($highlightSizes | Where-Object name -eq $highlightPair[0]).size-ne$highlightPair[1]){throw 'Godot ABI mismatch'}}
$highlightVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$highlightVs=@(& $highlightVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')} | Select-Object -First 1
if(-not $highlightVs){throw 'MSVC unavailable'}
$highlightVersion=(Get-Content -LiteralPath (Join-Path $highlightVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$highlightTools=Join-Path $highlightVs ('VC/Tools/MSVC/'+$highlightVersion)
$highlightCompiler=Join-Path $highlightTools 'bin/Hostx64/x64/cl.exe'
$highlightSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$highlightInclude=Get-ChildItem -LiteralPath (Join-Path $highlightSdk 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
if(-not $highlightInclude){throw 'Windows SDK unavailable'}
$env:INCLUDE=((Join-Path $highlightTools 'include'),(Join-Path $highlightInclude.FullName 'ucrt'),(Join-Path $highlightInclude.FullName 'shared'),(Join-Path $highlightInclude.FullName 'um')) -join ';'
$env:LIB=((Join-Path $highlightTools 'lib/x64'),(Join-Path $highlightSdk ('Lib/'+$highlightInclude.Name+'/ucrt/x64')),(Join-Path $highlightSdk ('Lib/'+$highlightInclude.Name+'/um/x64'))) -join ';'
New-Item -ItemType Directory -Path $highlightFolder | Out-Null
$highlightSource=Join-Path $highlightFolder 'source'
New-Item -ItemType Directory -Path $highlightSource | Out-Null
$highlightPins=@()
foreach($highlightFile in @((Join-Path $PSScriptRoot 'kernel/highlight_geometry.cpp'),(Join-Path $PSScriptRoot 'kernel/geometry_math.hpp'),$highlightHeader,$highlightJson,$PSCommandPath)){
 $highlightTarget=Join-Path $highlightSource ([IO.Path]::GetFileName($highlightFile))
 Copy-Item -LiteralPath $highlightFile -Destination $highlightTarget
 $highlightPins+=@{source=$highlightFile;file=$highlightTarget;sha256=(Get-FileHash -LiteralPath $highlightFile -Algorithm SHA256).Hash.ToLowerInvariant()}
}
$highlightOutput=Join-Path $highlightFolder 'nwn-highlight-geometry.dll'
$highlightFlags=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD','/I',$highlightSource,(Join-Path $highlightSource 'highlight_geometry.cpp'),('/Fe:'+$highlightOutput),'/link','/INCREMENTAL:NO')
Push-Location $highlightFolder
try{
 & $highlightCompiler @highlightFlags 2>&1 | Tee-Object -FilePath (Join-Path $highlightFolder 'build.log')
 $highlightExit=$LASTEXITCODE
}finally{Pop-Location}
$highlightChanged=@($highlightPins | Where-Object {(Get-FileHash -LiteralPath $_.source -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$highlightDescriptor=Join-Path $highlightFolder 'highlight_geometry.gdextension'
@'
[configuration]
entry_symbol = "nwn_highlight_geometry_init"
compatibility_minimum = "4.7"
reloadable = false

[libraries]
windows.release.x86_64 = "res://.cache/highlight-kernel/nwn-highlight-geometry.dll"
windows.debug.x86_64 = "res://.cache/highlight-kernel/nwn-highlight-geometry.dll"
'@ | Set-Content -LiteralPath $highlightDescriptor -Encoding utf8
$highlightReceipt=@{version=1;label=$Label;compiler=$highlightCompiler;compiler_sha256=(Get-FileHash -LiteralPath $highlightCompiler -Algorithm SHA256).Hash.ToLowerInvariant();flags=$highlightFlags;exit_code=$highlightExit;sources=$highlightPins;source_changed=$highlightChanged;binary=$highlightOutput;binary_sha256=if(Test-Path -LiteralPath $highlightOutput){(Get-FileHash -LiteralPath $highlightOutput -Algorithm SHA256).Hash.ToLowerInvariant()}else{$null};descriptor=$highlightDescriptor;descriptor_sha256=(Get-FileHash -LiteralPath $highlightDescriptor -Algorithm SHA256).Hash.ToLowerInvariant();shared_native_builds=0;server_connections=0;scope='Isolated standalone highlight POD geometry kernel only; no renderer/scene/lifetime authority'}
$highlightReceipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $highlightFolder 'build.json') -Encoding utf8
if($highlightExit-ne0-or$highlightChanged.Count){throw 'Isolated highlight build failed or source changed'}
Write-Output ('HIGHLIGHT_PRIVATE_BUILD '+$highlightOutput)
