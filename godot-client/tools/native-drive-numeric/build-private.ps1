param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label,[switch]$Build)
$ErrorActionPreference='Stop'
if(-not$Build){throw 'Source-only package: pass -Build explicitly during an authorized free-PC window.'}
$numericProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$numericOutput=[IO.Path]::GetFullPath((Join-Path $numericProject ('.cache/native-drive-numeric/'+$Label)))
if(-not$numericOutput.StartsWith($numericProject+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Output escapes private cache'}
if(Test-Path -LiteralPath $numericOutput){throw 'Existing build evidence preserved; choose a fresh label'}
$numericApi=Join-Path $numericProject '.tools/extension-api'
$numericHeader=Join-Path $numericApi 'gdextension_interface.h';$numericJson=Join-Path $numericApi 'extension_api.json'
if((Get-FileHash -LiteralPath $numericHeader).Hash.ToLowerInvariant()-ne'640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'-or(Get-FileHash -LiteralPath $numericJson).Hash.ToLowerInvariant()-ne'd0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986'){throw 'Pinned official interface/API hash differs'}
$numericAbi=Get-Content -Raw -LiteralPath $numericJson | ConvertFrom-Json
if($numericAbi.header.version_full_name-ne'Godot Engine v4.7.2.stable.official'-or$numericAbi.header.precision-ne'single'){throw 'Godot 4.7.2 single ABI required'}
$numericSizes=($numericAbi.builtin_class_sizes | Where-Object build_configuration -eq float_64).sizes
foreach($numericPair in @(@('Variant',24),@('StringName',8),@('String',8),@('Vector2',8),@('Vector3',12))){if(($numericSizes | Where-Object name -eq $numericPair[0]).size-ne$numericPair[1]){throw 'ABI size mismatch'}}
$numericPins=@{}
foreach($numericFile in @($numericHeader,$numericJson)+(Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object Extension -in '.cpp','.hpp','.in' | Select-Object -ExpandProperty FullName)){$numericPins[$numericFile]=(Get-FileHash -LiteralPath $numericFile -Algorithm SHA256).Hash.ToLowerInvariant()}
$numericVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$numericVs=@(& $numericVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')} | Select-Object -First 1
if(-not$numericVs){throw 'MSVC unavailable'}
$numericVersion=(Get-Content -Raw -LiteralPath (Join-Path $numericVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')).Trim()
$numericTools=Join-Path $numericVs ('VC/Tools/MSVC/'+$numericVersion);$numericCompiler=Join-Path $numericTools 'bin/Hostx64/x64/cl.exe'
$numericSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$numericInclude=Get-ChildItem -LiteralPath (Join-Path $numericSdk 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
if(-not$numericInclude){throw 'Windows SDK unavailable'}
New-Item -ItemType Directory -Path $numericOutput | Out-Null
Set-Content -LiteralPath (Join-Path $numericOutput '.gdignore') -Value '' -Encoding utf8
$numericOldInclude=$env:INCLUDE;$numericOldLib=$env:LIB
$env:INCLUDE=((Join-Path $numericTools 'include'),(Join-Path $numericInclude.FullName 'ucrt'),(Join-Path $numericInclude.FullName 'shared'),(Join-Path $numericInclude.FullName 'um')) -join ';'
$env:LIB=((Join-Path $numericTools 'lib/x64'),(Join-Path $numericSdk ('Lib/'+$numericInclude.Name+'/ucrt/x64')),(Join-Path $numericSdk ('Lib/'+$numericInclude.Name+'/um/x64'))) -join ';'
Push-Location $numericOutput
try{
 foreach($numericTest in @('drive_clear_kernel_test','drive_height_kernel_test')){
  & $numericCompiler /nologo /O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /I $PSScriptRoot (Join-Path $PSScriptRoot ($numericTest+'.cpp')) ('/Fe:'+ $numericTest+'.exe')
  if($LASTEXITCODE-ne0){throw ('Private kernel build failed: '+$numericTest)}
  & (Join-Path $numericOutput ($numericTest+'.exe'))
  if($LASTEXITCODE-ne0){throw ('Private kernel oracle failed: '+$numericTest)}
 }
 & $numericCompiler /nologo /O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD /I $numericApi (Join-Path $PSScriptRoot 'drive_numeric_extension.cpp') /Fe:nwn-drive-numeric.dll /link /INCREMENTAL:NO
 if($LASTEXITCODE-ne0){throw 'Private sidecar build failed'}
 foreach($numericFile in $numericPins.Keys){if((Get-FileHash -LiteralPath $numericFile -Algorithm SHA256).Hash.ToLowerInvariant()-ne$numericPins[$numericFile]){throw 'Input changed during build'}}
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'private.gdextension.in') -Destination (Join-Path $numericOutput 'private.gdextension')
 @{version=1;schema='nwn-drive-numeric-v1';success=$true;sourcePins=$numericPins;compiler=$numericVersion;flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD';binarySha256=(Get-FileHash -LiteralPath (Join-Path $numericOutput 'nwn-drive-numeric.dll')).Hash.ToLowerInvariant();heightCapability=$false;activeDescriptorWrites=0;sharedDllWrites=0;engineLaunches=0;scope='Private numeric functional proof only; engine frozen oracle still required'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $numericOutput 'build-proof.json') -Encoding utf8
}finally{Pop-Location;$env:INCLUDE=$numericOldInclude;$env:LIB=$numericOldLib}
