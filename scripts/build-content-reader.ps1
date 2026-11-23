param([string]$OutputDirectory,[switch]$IfNeeded)
$ErrorActionPreference='Stop'
$contentWorkspace=Split-Path $PSScriptRoot -Parent
$contentVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$contentVs=@(& $contentVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')} | Select-Object -First 1
if(-not $contentVs){throw 'MSVC compiler is unavailable'}
$contentToolsVersion=(Get-Content -LiteralPath (Join-Path $contentVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$contentTools=Join-Path $contentVs ('VC/Tools/MSVC/'+$contentToolsVersion)
$contentCompiler=Join-Path $contentTools 'bin/Hostx64/x64/cl.exe'
$contentSdkRoot=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$contentSdk=Get-ChildItem -LiteralPath (Join-Path $contentSdkRoot 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
if(-not $contentSdk){throw 'Windows SDK is unavailable'}
$env:INCLUDE=((Join-Path $contentTools 'include'),(Join-Path $contentSdk.FullName 'ucrt'),(Join-Path $contentSdk.FullName 'shared'),(Join-Path $contentSdk.FullName 'um')) -join ';'
$env:LIB=((Join-Path $contentTools 'lib/x64'),(Join-Path $contentSdkRoot ('Lib/'+$contentSdk.Name+'/ucrt/x64')),(Join-Path $contentSdkRoot ('Lib/'+$contentSdk.Name+'/um/x64'))) -join ';'
$contentOutput=if($OutputDirectory){[IO.Path]::GetFullPath($OutputDirectory)}else{Join-Path $contentWorkspace 'tooling/native/content-reader'}
New-Item -ItemType Directory -Path $contentOutput -Force | Out-Null
$contentSqlite=Join-Path $contentWorkspace 'references/nwnxee-unified/NWNXLib/External/sqlite3'
$contentZstd=Join-Path $contentWorkspace 'references/neverwinter.nim/neverwinter/private/zstd/lib'
$contentSources=@('common/debug.c','common/entropy_common.c','common/error_private.c','common/fse_decompress.c','common/xxhash.c','common/zstd_common.c','decompress/huf_decompress.c','decompress/zstd_ddict.c','decompress/zstd_decompress.c','decompress/zstd_decompress_block.c') | ForEach-Object {Join-Path $contentZstd $_}
$contentInputs=@($PSCommandPath,(Join-Path $PSScriptRoot 'native/nwn_content_reader.c'),(Join-Path $contentSqlite 'sqlite3.c'),(Join-Path $contentSqlite 'include/sqlite3.h'))+@($contentSources)+@(Get-ChildItem -LiteralPath $contentZstd -Recurse -File -Filter '*.h' | ForEach-Object {$_.FullName})
$contentInputHashes=@($contentInputs | Sort-Object -Unique | ForEach-Object {[ordered]@{path=$_.Substring($contentWorkspace.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()}})
$contentExecutable=Join-Path $contentOutput 'nwn-content-reader.exe'
$contentManifest=Join-Path $contentOutput 'build-manifest.json'
if($IfNeeded -and (Test-Path -LiteralPath $contentManifest) -and (Test-Path -LiteralPath $contentExecutable)){
 $built=Get-Content -LiteralPath $contentManifest -Raw | ConvertFrom-Json
 $expected=@($contentInputHashes | ForEach-Object {"$($_.path)=$($_.sha256)"})
 $actual=@($built.inputs | ForEach-Object {"$($_.path)=$($_.sha256)"})
 if($built.compiler -eq $contentToolsVersion -and $expected.Count -eq $actual.Count -and !($expected | Where-Object {$_ -notin $actual}) -and
     (Get-FileHash -LiteralPath $contentExecutable).Hash.ToLowerInvariant() -eq $built.binarySha256){
  Write-Output 'Read-only content reader build current'
  return
 }
}
Push-Location $contentOutput
try{
 & $contentCompiler /nologo /O2 /W3 /std:c11 /TC /D_CRT_SECURE_NO_WARNINGS /DSQLITE_THREADSAFE=0 /DSQLITE_OMIT_LOAD_EXTENSION /DZSTD_DISABLE_ASM /DZSTD_LEGACY_SUPPORT=0 /I (Join-Path $contentSqlite 'include') /I $contentZstd (Join-Path $PSScriptRoot 'native/nwn_content_reader.c') (Join-Path $contentSqlite 'sqlite3.c') @contentSources /Fe:nwn-content-reader.exe /link /INCREMENTAL:NO
 if($LASTEXITCODE -ne 0){throw 'Content reader build failed'}
}finally{Pop-Location}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'native/zstd-LICENSE.txt') -Destination (Join-Path $contentOutput 'zstd-LICENSE.txt')
[ordered]@{compiler=$contentToolsVersion;sqliteSource='references/nwnxee-unified/NWNXLib/External/sqlite3';zstdVersion='1.4.8';inputs=$contentInputHashes;binarySha256=(Get-FileHash -LiteralPath $contentExecutable -Algorithm SHA256).Hash.ToLowerInvariant()} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $contentManifest -Encoding UTF8
Write-Output 'Read-only content reader build PASS'
