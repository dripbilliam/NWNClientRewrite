$ErrorActionPreference='Stop'
$cryptoWorkspace=Split-Path $PSScriptRoot -Parent
$cryptoSource=Join-Path $cryptoWorkspace 'references/libhydrogen'
$cryptoRevision=& git -C $cryptoSource rev-parse HEAD
if($LASTEXITCODE -ne 0 -or $cryptoRevision -ne '850c6bdbb0ca9a26fd105dbb6b973dc22c2dc6c0'){throw 'Unexpected libhydrogen source revision'}
if(@(& git -C $cryptoSource status --porcelain).Count){throw 'libhydrogen source must remain unmodified'}
$cryptoVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$cryptoVs=@(& $cryptoVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')} | Select-Object -First 1
if(-not $cryptoVs){throw 'MSVC C compiler is unavailable'}
$cryptoToolsVersion=(Get-Content -LiteralPath (Join-Path $cryptoVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$cryptoTools=Join-Path $cryptoVs ('VC/Tools/MSVC/'+$cryptoToolsVersion)
$cryptoCompiler=Join-Path $cryptoTools 'bin/Hostx64/x64/cl.exe'
if(-not (Test-Path -LiteralPath $cryptoCompiler)){throw 'MSVC x64 compiler is unavailable'}
$cryptoSdkRoot=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$cryptoSdk=Get-ChildItem -LiteralPath (Join-Path $cryptoSdkRoot 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
if(-not $cryptoSdk){throw 'Windows SDK is unavailable'}
$env:INCLUDE=((Join-Path $cryptoTools 'include'),(Join-Path $cryptoSdk.FullName 'ucrt'),(Join-Path $cryptoSdk.FullName 'shared'),(Join-Path $cryptoSdk.FullName 'um')) -join ';'
$env:LIB=((Join-Path $cryptoTools 'lib/x64'),(Join-Path $cryptoSdkRoot ('Lib/'+$cryptoSdk.Name+'/ucrt/x64')),(Join-Path $cryptoSdkRoot ('Lib/'+$cryptoSdk.Name+'/um/x64'))) -join ';'
$env:PATH=(Split-Path $cryptoCompiler)+';'+$env:PATH
$cryptoOutput=Join-Path $cryptoWorkspace 'tooling/native'
New-Item -ItemType Directory -Path $cryptoOutput -Force | Out-Null
Push-Location $cryptoOutput
try{
 & $cryptoCompiler /nologo /O2 /W4 /std:c11 /TC /D_CRT_SECURE_NO_WARNINGS /I $cryptoSource (Join-Path $PSScriptRoot 'native/nwn_network_crypto.c') (Join-Path $cryptoSource 'hydrogen.c') /Fe:nwn-network-crypto.exe /link /INCREMENTAL:NO
 if($LASTEXITCODE -ne 0){throw 'Network crypto helper build failed'}
}finally{Pop-Location}
Copy-Item -LiteralPath (Join-Path $cryptoSource 'LICENSE') -Destination (Join-Path $cryptoOutput 'libhydrogen-LICENSE.txt')
Write-Output 'Network crypto helper build PASS'
