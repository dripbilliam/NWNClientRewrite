param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label)
$ErrorActionPreference='Stop'
$bspProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$bspFolder=Join-Path $bspProject ('.cache/native-presentation-parity/loading-agent/'+$Label)
if(Test-Path -LiteralPath $bspFolder){throw 'Existing isolated build preserved'}
$bspHeader=Join-Path $bspProject '.tools/extension-api/gdextension_interface.h'
$bspJson=Join-Path $bspProject '.tools/extension-api/extension_api.json'
$bspAbi=Get-Content -LiteralPath $bspJson -Raw | ConvertFrom-Json
if($bspAbi.header.precision-ne'single'){throw 'Single precision Godot ABI required'}
$bspSizes=($bspAbi.builtin_class_sizes | Where-Object build_configuration -eq float_64).sizes
foreach($bspPair in @(@('Variant',24),@('Array',8),@('Dictionary',8),@('StringName',8),@('String',8),@('PackedByteArray',16),@('PackedFloat32Array',16),@('PackedColorArray',16),@('Transform3D',48),@('Vector3',12),@('AABB',24))){if(($bspSizes | Where-Object name -eq $bspPair[0]).size-ne$bspPair[1]){throw 'Godot ABI mismatch'}}
$bspVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$bspVs=@(& $bspVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')} | Select-Object -First 1
if(-not $bspVs){throw 'MSVC unavailable'}
$bspVersion=(Get-Content -LiteralPath (Join-Path $bspVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$bspTools=Join-Path $bspVs ('VC/Tools/MSVC/'+$bspVersion)
$bspCompiler=Join-Path $bspTools 'bin/Hostx64/x64/cl.exe'
$bspSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$bspInclude=Get-ChildItem -LiteralPath (Join-Path $bspSdk 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
if(-not $bspInclude){throw 'Windows SDK unavailable'}
$env:INCLUDE=((Join-Path $bspTools 'include'),(Join-Path $bspInclude.FullName 'ucrt'),(Join-Path $bspInclude.FullName 'shared'),(Join-Path $bspInclude.FullName 'um')) -join ';'
$env:LIB=((Join-Path $bspTools 'lib/x64'),(Join-Path $bspSdk ('Lib/'+$bspInclude.Name+'/ucrt/x64')),(Join-Path $bspSdk ('Lib/'+$bspInclude.Name+'/um/x64'))) -join ';'
New-Item -ItemType Directory -Path $bspFolder | Out-Null
$bspSource=Join-Path $bspFolder 'source'
New-Item -ItemType Directory -Path $bspSource | Out-Null
$bspPins=@()
foreach($bspFile in @((Join-Path $PSScriptRoot 'kernel/bsp_collector.cpp'),(Join-Path $PSScriptRoot 'kernel/bsp_math.hpp'),$bspHeader,$bspJson,$PSCommandPath)){
 $bspTarget=Join-Path $bspSource ([IO.Path]::GetFileName($bspFile))
 Copy-Item -LiteralPath $bspFile -Destination $bspTarget
 $bspPins+=@{source=$bspFile;file=$bspTarget;sha256=(Get-FileHash -LiteralPath $bspFile -Algorithm SHA256).Hash.ToLowerInvariant()}
}
$bspOutput=Join-Path $bspFolder 'nwn-bsp-collector.dll'
$bspFlags=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD','/I',$bspSource,(Join-Path $bspSource 'bsp_collector.cpp'),('/Fe:'+$bspOutput),'/link','/INCREMENTAL:NO')
Push-Location $bspFolder
try{
 & $bspCompiler @bspFlags 2>&1 | Tee-Object -FilePath (Join-Path $bspFolder 'build.log')
 $bspExit=$LASTEXITCODE
}finally{Pop-Location}
$bspChanged=@($bspPins | Where-Object {(Get-FileHash -LiteralPath $_.source -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$bspDescriptor=Join-Path $bspFolder 'bsp_collector.gdextension'
@'
[configuration]
entry_symbol = "nwn_bsp_collector_init"
compatibility_minimum = "4.7"
reloadable = false

[libraries]
windows.release.x86_64 = "res://.cache/bsp-collector-kernel/nwn-bsp-collector.dll"
windows.debug.x86_64 = "res://.cache/bsp-collector-kernel/nwn-bsp-collector.dll"
'@ | Set-Content -LiteralPath $bspDescriptor -Encoding utf8
$bspReceipt=@{version=1;label=$Label;compiler=$bspCompiler;compiler_sha256=(Get-FileHash -LiteralPath $bspCompiler -Algorithm SHA256).Hash.ToLowerInvariant();flags=$bspFlags;exit_code=$bspExit;sources=$bspPins;source_changed=$bspChanged;binary=$bspOutput;binary_sha256=if(Test-Path -LiteralPath $bspOutput){(Get-FileHash -LiteralPath $bspOutput -Algorithm SHA256).Hash.ToLowerInvariant()}else{$null};descriptor=$bspDescriptor;descriptor_sha256=(Get-FileHash -LiteralPath $bspDescriptor -Algorithm SHA256).Hash.ToLowerInvariant();shared_native_builds=0;server_connections=0;scope='Isolated standalone BSP POD collector kernel only; no renderer/scene/lifetime authority'}
$bspReceipt | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $bspFolder 'build.json') -Encoding utf8
if($bspExit-ne0-or$bspChanged.Count-or-not(Test-Path -LiteralPath $bspOutput)){throw 'Isolated BSP build failed, binary missing, or source changed'}
Write-Output ('BSP_PRIVATE_BUILD '+$bspOutput)
