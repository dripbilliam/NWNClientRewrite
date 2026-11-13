param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label,[switch]$EmitMap)
$ErrorActionPreference='Stop'
(Get-Process -Id $PID).PriorityClass='BelowNormal'
$kernelProjectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$kernelStage=Join-Path $kernelProjectRoot ('.cache/native-render-gap/particles/'+$Label)
$kernelInputs=Get-Content -LiteralPath (Join-Path $kernelStage 'kernel-source-pins.json') -Raw|ConvertFrom-Json
$kernelSource=[IO.Path]::GetFullPath($kernelInputs.project)
$kernelExpected=[IO.Path]::GetFullPath((Join-Path $kernelStage 'kernel-project'))
if($kernelSource-ne$kernelExpected){throw 'Unexpected private compiler project'}
$kernelOutput=Join-Path $kernelStage 'kernel-build'
if(Test-Path -LiteralPath $kernelOutput){throw 'Previous build evidence retained'}
foreach($kernelPin in $kernelInputs.pins){if((Get-FileHash -LiteralPath (Join-Path $kernelSource $kernelPin.relative)).Hash.ToLowerInvariant()-ne$kernelPin.sha256){throw ('Changed compiler input '+$kernelPin.relative)}}
$kernelApi=Join-Path $kernelProjectRoot '.tools/extension-api'
foreach($kernelApiPin in @(@('gdextension_interface.h','640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'),@('extension_api.json','d0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986'))){if((Get-FileHash -LiteralPath (Join-Path $kernelApi $kernelApiPin[0])).Hash.ToLowerInvariant()-ne$kernelApiPin[1]){throw 'Pinned API mismatch'}}
$kernelVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$kernelVs=@(& $kernelVsWhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64/cl.exe')}|Select-Object -First 1
if(-not$kernelVs){throw 'Pinned MSVC unavailable'}
$kernelTools=Join-Path $kernelVs 'VC/Tools/MSVC/14.50.35717';$kernelCompiler=Join-Path $kernelTools 'bin/Hostx64/x64/cl.exe'
$kernelSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$kernelSdkInclude=Get-ChildItem -LiteralPath (Join-Path $kernelSdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$kernelSdkInclude){throw 'Windows SDK unavailable'}
New-Item -ItemType Directory -Path $kernelOutput|Out-Null
$kernelBinary=Join-Path $kernelOutput 'nwn-particle-kernel.dll'
$kernelArguments=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD',('/I'+$kernelApi),('/Fo'+(Join-Path $kernelOutput 'particle-kernel.obj')),('/Fe'+$kernelBinary),(Join-Path $kernelSource 'native/particle_kernel.cpp'),'/link','/INCREMENTAL:NO',('/IMPLIB:'+(Join-Path $kernelOutput 'particle-kernel.lib')))
$kernelMap=$null
if($EmitMap){$kernelMap=Join-Path $kernelOutput 'nwn-particle-kernel.map';$kernelArguments+=('/MAP:'+$kernelMap)}
$kernelPreviousInclude=$env:INCLUDE;$kernelPreviousLib=$env:LIB
$kernelStarted=[DateTime]::UtcNow.ToString('o');$kernelExit=-1
try{
 $env:INCLUDE=((Join-Path $kernelTools 'include'),(Join-Path $kernelSdkInclude.FullName 'ucrt'),(Join-Path $kernelSdkInclude.FullName 'shared'),(Join-Path $kernelSdkInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $kernelTools 'lib/x64'),(Join-Path $kernelSdk ('Lib/'+$kernelSdkInclude.Name+'/ucrt/x64')),(Join-Path $kernelSdk ('Lib/'+$kernelSdkInclude.Name+'/um/x64')))-join';'
 & $kernelCompiler @kernelArguments 2>&1|Tee-Object -FilePath (Join-Path $kernelOutput 'compiler.log')
 $kernelExit=$LASTEXITCODE
 if($kernelExit-ne0){throw ('Private compiler failed '+$kernelExit)}
 foreach($kernelPin in $kernelInputs.pins){if((Get-FileHash -LiteralPath (Join-Path $kernelSource $kernelPin.relative)).Hash.ToLowerInvariant()-ne$kernelPin.sha256){throw 'Compiler input changed during build'}}
 @{version=1;success=$true;startedUtc=$kernelStarted;finishedUtc=[DateTime]::UtcNow.ToString('o');compiler=$kernelCompiler;compilerSha256=(Get-FileHash -LiteralPath $kernelCompiler).Hash.ToLowerInvariant();flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD';arguments=$kernelArguments;exit=$kernelExit;binary=$kernelBinary;binarySha256=(Get-FileHash -LiteralPath $kernelBinary).Hash.ToLowerInvariant();map=$kernelMap;mapSha256=$(if($kernelMap){(Get-FileHash -LiteralPath $kernelMap).Hash.ToLowerInvariant()}else{$null});sourcePins=$kernelInputs.pins;sharedSourceWrites=0;sharedBinaryWrites=0;engineStarts=0;scope='Private build proof only; no graphical/FPS or authority acceptance'}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $kernelOutput 'build-receipt.json') -Encoding utf8
}catch{
 @{version=1;success=$false;startedUtc=$kernelStarted;finishedUtc=[DateTime]::UtcNow.ToString('o');exit=$kernelExit;error=$_.Exception.Message;sharedSourceWrites=0;sharedBinaryWrites=0}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $kernelOutput 'build-failure.json') -Encoding utf8
 throw
}finally{$env:INCLUDE=$kernelPreviousInclude;$env:LIB=$kernelPreviousLib}
