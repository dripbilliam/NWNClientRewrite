$ErrorActionPreference='Stop'
$kernelProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$kernelEngine=Join-Path $kernelProject '.tools/Godot_v4.7.2-stable_win64_console.exe'
$kernelApi=Join-Path $kernelProject '.tools/extension-api'
$kernelHeader=Join-Path $kernelApi 'gdextension_interface.h'
$kernelJson=Join-Path $kernelApi 'extension_api.json'
if((Get-FileHash -LiteralPath $kernelEngine -Algorithm SHA256).Hash.ToLowerInvariant()-ne'c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643'){throw 'Particle kernel requires the pinned Godot executable'}
if(-not(Test-Path -LiteralPath $kernelHeader)-or-not(Test-Path -LiteralPath $kernelJson)){
 New-Item -ItemType Directory -Path $kernelApi -Force | Out-Null
 Push-Location $kernelApi
 try{
  & $kernelEngine --headless --log-file (Join-Path $kernelApi 'header-dump.log') --dump-gdextension-interface
  if($LASTEXITCODE-ne0){throw 'Godot interface dump failed'}
  & $kernelEngine --headless --log-file (Join-Path $kernelApi 'api-dump.log') --dump-extension-api
  if($LASTEXITCODE-ne0){throw 'Godot API dump failed'}
 }finally{Pop-Location}
}
$kernelAbi=Get-Content -LiteralPath $kernelJson -Raw | ConvertFrom-Json
if($kernelAbi.header.version_full_name-ne'Godot Engine v4.7.2.stable.official'-or$kernelAbi.header.precision-ne'single'){throw 'Unsupported Godot ABI'}
$kernelSizes=($kernelAbi.builtin_class_sizes | Where-Object build_configuration -eq float_64).sizes
foreach($kernelPair in @(@('Variant',24),@('StringName',8),@('String',8),@('PackedByteArray',16),@('PackedFloat32Array',16),@('Basis',36),@('Transform3D',48),@('Quaternion',16),@('Vector3',12),@('AABB',24))){if(($kernelSizes | Where-Object name -eq $kernelPair[0]).size-ne$kernelPair[1]){throw 'GDExtension ABI size mismatch'}}
$kernelVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$kernelVs=@(& $kernelVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')} | Select-Object -First 1
if(-not $kernelVs){throw 'MSVC unavailable'}
$kernelVersion=(Get-Content -LiteralPath (Join-Path $kernelVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$kernelTools=Join-Path $kernelVs ('VC/Tools/MSVC/'+$kernelVersion)
$kernelCompiler=Join-Path $kernelTools 'bin/Hostx64/x64/cl.exe'
$kernelSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$kernelInclude=Get-ChildItem -LiteralPath (Join-Path $kernelSdk 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
if(-not $kernelInclude){throw 'Windows SDK unavailable'}
$env:INCLUDE=((Join-Path $kernelTools 'include'),(Join-Path $kernelInclude.FullName 'ucrt'),(Join-Path $kernelInclude.FullName 'shared'),(Join-Path $kernelInclude.FullName 'um')) -join ';'
$env:LIB=((Join-Path $kernelTools 'lib/x64'),(Join-Path $kernelSdk ('Lib/'+$kernelInclude.Name+'/ucrt/x64')),(Join-Path $kernelSdk ('Lib/'+$kernelInclude.Name+'/um/x64'))) -join ';'
$kernelOutput=Join-Path $kernelProject '.cache/native-kernel'
New-Item -ItemType Directory -Path $kernelOutput -Force | Out-Null
$kernelSource=Join-Path $kernelProject 'native/particle_kernel.cpp'
Push-Location $kernelOutput
try{
 & $kernelCompiler /nologo /O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD /I $kernelApi $kernelSource /Fe:nwn-particle-kernel.dll /link /INCREMENTAL:NO
 if($LASTEXITCODE-ne0){throw 'Native particle kernel build failed'}
}finally{Pop-Location}
$kernelHashes=@{}
foreach($kernelFile in @($kernelSource,$kernelHeader,$kernelJson,$PSCommandPath,(Join-Path $kernelProject 'native/particle_kernel.gdextension'))+@(Get-ChildItem -LiteralPath (Join-Path $kernelProject 'native') -File -Filter '*.hpp' | ForEach-Object FullName)){$kernelHashes[$kernelFile.Substring($kernelProject.Length+1).Replace('\','/')]=(Get-FileHash -LiteralPath $kernelFile -Algorithm SHA256).Hash.ToLowerInvariant()}
@{compiler=$kernelVersion;flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD';sources=$kernelHashes;api=$kernelAbi.header;engineSha256=(Get-FileHash -LiteralPath $kernelEngine -Algorithm SHA256).Hash.ToLowerInvariant();binarySha256=(Get-FileHash -LiteralPath (Join-Path $kernelOutput 'nwn-particle-kernel.dll') -Algorithm SHA256).Hash.ToLowerInvariant();scope='Native vertex kernel, experimental until original-output and guarded runtime checks pass'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $kernelOutput 'build-manifest.json') -Encoding utf8
Write-Output 'Native particle kernel build PASS'
