$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'windows-profile.c'
$output=Join-Path $PSScriptRoot '../../.cache/nwn79'
$binary=Join-Path $output 'windows-profile.exe'
$manifest=Join-Path $output 'windows-profile-build.json'
$hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
if((Test-Path -LiteralPath $binary)-and(Test-Path -LiteralPath $manifest)){
 try{if((Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json).sourceSha256-eq$hash){Write-Output $binary;return}}catch{}
}
$vswhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs=@(& $vswhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')}|Select-Object -First 1
if(-not$vs){throw 'MSVC is required to build the Windows profile helper'}
$version=(Get-Content -LiteralPath (Join-Path $vs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$tools=Join-Path $vs ('VC/Tools/MSVC/'+$version)
$compiler=Join-Path $tools 'bin/Hostx64/x64/cl.exe'
$sdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$sdkInclude=Get-ChildItem -LiteralPath (Join-Path $sdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$sdkInclude){throw 'Windows SDK is required to build the Windows profile helper'}
$env:INCLUDE=((Join-Path $tools 'include'),(Join-Path $sdkInclude.FullName 'ucrt'),(Join-Path $sdkInclude.FullName 'shared'),(Join-Path $sdkInclude.FullName 'um'))-join';'
$env:LIB=((Join-Path $tools 'lib/x64'),(Join-Path $sdk ('Lib/'+$sdkInclude.Name+'/ucrt/x64')),(Join-Path $sdk ('Lib/'+$sdkInclude.Name+'/um/x64')))-join';'
New-Item -ItemType Directory -Path $output -Force|Out-Null
Push-Location $output
try{
 & $compiler /nologo /O2 /W4 /WX /TC $source /Fe:windows-profile.exe /link /INCREMENTAL:NO crypt32.lib bcrypt.lib shell32.lib ole32.lib
 if($LASTEXITCODE-ne0){throw 'Windows profile helper build failed'}
}finally{Pop-Location}
@{sourceSha256=$hash;binarySha256=(Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash.ToLowerInvariant();compiler=$version}|ConvertTo-Json|Set-Content -LiteralPath $manifest -Encoding utf8
Write-Output $binary
