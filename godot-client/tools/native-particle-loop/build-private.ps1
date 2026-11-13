param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label,[Parameter(Mandatory=$true)][ValidateSet('control','candidate')][string]$Variant)
$ErrorActionPreference='Stop'
$particleProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$particleRoot=Join-Path $particleProject ('.cache/native-presentation-parity/root/fps-max-v1/particle-loop-'+$Label)
$particleSource=Join-Path $particleRoot $Variant
$particleOutput=Join-Path $particleSource 'build'
if(Test-Path -LiteralPath $particleOutput){throw 'Prior build preserved'}
$particlePins=Get-Content -Raw -LiteralPath (Join-Path $particleSource 'source-pins.json') | ConvertFrom-Json
foreach($particlePin in $particlePins){if((Get-FileHash -LiteralPath (Join-Path $particleSource $particlePin.relative)).Hash.ToLowerInvariant()-ne$particlePin.sha256){throw 'Frozen native source changed'}}
$particleApi=Join-Path $particleProject '.tools/extension-api'
foreach($particlePin in @(@('gdextension_interface.h','640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'),@('extension_api.json','d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986'))){if((Get-FileHash -LiteralPath (Join-Path $particleApi $particlePin[0])).Hash.ToLowerInvariant()-ne$particlePin[1]){throw 'Pinned API differs'}}
$particleVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$particleVs=@(& $particleVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64/cl.exe')} | Select-Object -First 1
if(-not$particleVs){throw 'Pinned MSVC unavailable'}
$particleTools=Join-Path $particleVs 'VC/Tools/MSVC/14.50.35717'
$particleCompiler=Join-Path $particleTools 'bin/Hostx64/x64/cl.exe'
$particleSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$particleInclude=Get-ChildItem -LiteralPath (Join-Path $particleSdk 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
if(-not$particleInclude){throw 'Windows SDK unavailable'}
New-Item -ItemType Directory -Path $particleOutput | Out-Null
$particleOldInclude=$env:INCLUDE;$particleOldLib=$env:LIB
$env:INCLUDE=((Join-Path $particleTools 'include'),(Join-Path $particleInclude.FullName 'ucrt'),(Join-Path $particleInclude.FullName 'shared'),(Join-Path $particleInclude.FullName 'um')) -join ';'
$env:LIB=((Join-Path $particleTools 'lib/x64'),(Join-Path $particleSdk ('Lib/'+$particleInclude.Name+'/ucrt/x64')),(Join-Path $particleSdk ('Lib/'+$particleInclude.Name+'/um/x64'))) -join ';'
Push-Location $particleOutput
try{
 & $particleCompiler /nologo /O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD /I $particleApi (Join-Path $particleSource 'native/particle_kernel.cpp') /Fe:nwn-particle-kernel.dll /link /INCREMENTAL:NO
 if($LASTEXITCODE-ne0){throw 'Private particle build failed'}
 foreach($particlePin in $particlePins){if((Get-FileHash -LiteralPath (Join-Path $particleSource $particlePin.relative)).Hash.ToLowerInvariant()-ne$particlePin.sha256){throw 'Input changed during build'}}
 @{version=1;success=$true;variant=$Variant;compiler='14.50.35717';flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD';sourcePins=$particlePins;binarySha256=(Get-FileHash -LiteralPath (Join-Path $particleOutput 'nwn-particle-kernel.dll')).Hash.ToLowerInvariant();builderSha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();sharedSourceWrites=0;sharedDllWrites=0;engineLaunches=0} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $particleOutput 'build-proof.json') -Encoding utf8
}finally{Pop-Location;$env:INCLUDE=$particleOldInclude;$env:LIB=$particleOldLib}
