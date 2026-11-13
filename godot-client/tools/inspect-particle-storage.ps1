param([string]$Run='native-particle-storage-v1')
$ErrorActionPreference='Stop'
if($Run-notmatch'^[a-zA-Z0-9-]+$'){throw 'Invalid storage inspection run name'}
$probeProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$probeOutput=Join-Path $probeProject '.cache/particle-storage'
$probeReport=Join-Path $probeProject ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $probeReport){throw 'Storage receipt already exists; use a new run name'}
$probeVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$probeVs=@(& $probeVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')} | Select-Object -First 1
if(-not $probeVs){throw 'MSVC unavailable'}
$probeVersion=(Get-Content -LiteralPath (Join-Path $probeVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$probeTools=Join-Path $probeVs ('VC/Tools/MSVC/'+$probeVersion)
$probeCompiler=Join-Path $probeTools 'bin/Hostx64/x64/cl.exe'
$probeSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$probeInclude=Get-ChildItem -LiteralPath (Join-Path $probeSdk 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
if(-not $probeInclude){throw 'Windows SDK unavailable'}
$env:INCLUDE=((Join-Path $probeTools 'include'),(Join-Path $probeInclude.FullName 'ucrt'),(Join-Path $probeInclude.FullName 'shared'),(Join-Path $probeInclude.FullName 'um')) -join ';'
$env:LIB=((Join-Path $probeTools 'lib/x64'),(Join-Path $probeSdk ('Lib/'+$probeInclude.Name+'/ucrt/x64')),(Join-Path $probeSdk ('Lib/'+$probeInclude.Name+'/um/x64'))) -join ';'
$probeFiles=@((Join-Path $probeProject 'native/particle_kernel.cpp'),(Join-Path $probeProject 'tools/inspect-particle-storage.cpp'),$PSCommandPath,(Join-Path $probeProject '.tools/extension-api/gdextension_interface.h'))+@(Get-ChildItem -LiteralPath (Join-Path $probeProject 'native') -File -Filter '*.hpp' | ForEach-Object FullName)
$probeHashes=@{}
foreach($probeFile in $probeFiles){$probeHashes[$probeFile]=(Get-FileHash -LiteralPath $probeFile -Algorithm SHA256).Hash.ToLowerInvariant()}
New-Item -ItemType Directory -Path $probeOutput -Force | Out-Null
Push-Location $probeOutput
try{
 & $probeCompiler /nologo /O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /I (Join-Path $probeProject '.tools/extension-api') (Join-Path $probeProject 'tools/inspect-particle-storage.cpp') /Fe:inspect-particle-storage.exe /link /INCREMENTAL:NO
 if($LASTEXITCODE-ne0){throw 'Storage inspection compilation failed'}
 $probeJson=& (Join-Path $probeOutput 'inspect-particle-storage.exe')
 if($LASTEXITCODE-ne0){throw 'Storage inspection execution failed'}
 $probeResult=$probeJson | ConvertFrom-Json
}finally{Pop-Location}
foreach($probeFile in $probeFiles){if((Get-FileHash -LiteralPath $probeFile -Algorithm SHA256).Hash.ToLowerInvariant()-ne$probeHashes[$probeFile]){throw 'Storage source changed during inspection'}}
@{success=$probeResult.success;scope='CPU-only actual current C++ particle storage; no Godot initialization or public/local server connection';compiler=$probeVersion;flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD';sources=$probeHashes;sourceUnchanged=$true;measurements=$probeResult} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $probeReport -Encoding utf8
$probeResult | ConvertTo-Json -Depth 6
