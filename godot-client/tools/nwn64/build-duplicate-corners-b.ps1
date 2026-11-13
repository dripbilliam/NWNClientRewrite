$ErrorActionPreference='Stop'
(Get-Process -Id $PID).PriorityClass='BelowNormal'
$nwn64Root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$nwn64Capsule=Join-Path $nwn64Root '.cache/nwn64/duplicate-corners-b'
$nwn64SourceManifest=Join-Path $nwn64Capsule 'manifest.json'
$nwn64ExpectedManifest='87fefe888b88d448156d6222cbedc3b70277b99971e67feca8da1d51b802dafc'
if((Get-FileHash -Algorithm SHA256 -LiteralPath $nwn64SourceManifest).Hash.ToLowerInvariant()-ne$nwn64ExpectedManifest){throw 'Private source manifest changed'}
$nwn64Manifest=Get-Content -LiteralPath $nwn64SourceManifest -Raw|ConvertFrom-Json
if($nwn64Manifest.sourceFiles-ne45-or$nwn64Manifest.compileDefine-ne'NWN_PARTICLE_DUPLICATE_CORNERS=1'){throw 'Private source policy changed'}
$nwn64PinsFile=Join-Path $nwn64Root '.cache/nwn64/baseline-source-pins.json'
if((Get-FileHash -Algorithm SHA256 -LiteralPath $nwn64PinsFile).Hash.ToLowerInvariant()-ne$nwn64Manifest.acceptedPinsSha256){throw 'Accepted source manifest changed'}
$nwn64Pins=Get-Content -LiteralPath $nwn64PinsFile -Raw|ConvertFrom-Json
if(@($nwn64Pins.pins).Count-ne45){throw 'Accepted source count changed'}
$nwn64Project=Join-Path $nwn64Root $nwn64Manifest.candidate
foreach($nwn64Pin in $nwn64Pins.pins){
 $nwn64Relative=[string]$nwn64Pin.relative
 if(-not$nwn64Relative.StartsWith('native/')-or$nwn64Relative.Contains('..')){throw 'Unsafe source pin'}
 $nwn64Expected=[string]$nwn64Pin.sha256
 if($nwn64Manifest.changes.PSObject.Properties.Name -contains $nwn64Relative){
  if($nwn64Manifest.changes.PSObject.Properties[$nwn64Relative].Value.before-ne$nwn64Expected){throw 'Overlay baseline mismatch'}
  $nwn64Expected=[string]$nwn64Manifest.changes.PSObject.Properties[$nwn64Relative].Value.after
 }
 $nwn64Source=Join-Path $nwn64Project $nwn64Relative
 if((Get-FileHash -Algorithm SHA256 -LiteralPath $nwn64Source).Hash.ToLowerInvariant()-ne$nwn64Expected){throw ('Private source changed: '+$nwn64Relative)}
}
$nwn64Api=Join-Path $nwn64Root '.tools/extension-api'
$nwn64Header=Join-Path $nwn64Api 'gdextension_interface.h'
$nwn64ApiSha='640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'
if((Get-FileHash -Algorithm SHA256 -LiteralPath $nwn64Header).Hash.ToLowerInvariant()-ne$nwn64ApiSha){throw 'Pinned extension API header changed'}
$nwn64Compiler='C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717\bin\Hostx64\x64\cl.exe'
$nwn64CompilerSha='5b0741ee910ac72235cc0b6cef1b1d0e79aeedf4fe761fa439a7d3b157747cd7'
if((Get-FileHash -Algorithm SHA256 -LiteralPath $nwn64Compiler).Hash.ToLowerInvariant()-ne$nwn64CompilerSha){throw 'Pinned MSVC compiler changed'}
$nwn64Accepted=Join-Path $nwn64Root '.cache/native-kernel/nwn-particle-kernel.dll'
$nwn64AcceptedSha='485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d'
if((Get-FileHash -Algorithm SHA256 -LiteralPath $nwn64Accepted).Hash.ToLowerInvariant()-ne$nwn64AcceptedSha){throw 'Accepted DLL changed before private build'}
$nwn64Output=Join-Path $nwn64Capsule 'kernel-build'
if(Test-Path -LiteralPath $nwn64Output){throw 'Private output already exists; preserve previous build evidence'}
$nwn64Tools='C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717'
$nwn64Sdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$nwn64SdkInclude=Get-ChildItem -LiteralPath (Join-Path $nwn64Sdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$nwn64SdkInclude){throw 'Windows SDK unavailable'}
New-Item -ItemType Directory -Path $nwn64Output|Out-Null
$nwn64Dll=Join-Path $nwn64Output 'nwn-particle-kernel.dll'
$nwn64Arguments=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD','/DNWN_PARTICLE_DUPLICATE_CORNERS=1',('/I'+$nwn64Api),('/Fo'+(Join-Path $nwn64Output 'particle-kernel.obj')),('/Fe'+$nwn64Dll),(Join-Path $nwn64Project 'native/particle_kernel.cpp'),'/link','/INCREMENTAL:NO',('/IMPLIB:'+(Join-Path $nwn64Output 'particle-kernel.lib')))
$nwn64OldInclude=$env:INCLUDE;$nwn64OldLib=$env:LIB
try{
 $env:INCLUDE=((Join-Path $nwn64Tools 'include'),(Join-Path $nwn64SdkInclude.FullName 'ucrt'),(Join-Path $nwn64SdkInclude.FullName 'shared'),(Join-Path $nwn64SdkInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $nwn64Tools 'lib/x64'),(Join-Path $nwn64Sdk ('Lib/'+$nwn64SdkInclude.Name+'/ucrt/x64')),(Join-Path $nwn64Sdk ('Lib/'+$nwn64SdkInclude.Name+'/um/x64')))-join';'
 & $nwn64Compiler @nwn64Arguments 2>&1|Tee-Object -FilePath (Join-Path $nwn64Output 'compiler.log')
 if($LASTEXITCODE-ne0){throw ('Private NWN64 compiler failed '+$LASTEXITCODE)}
 $nwn64BinarySha=(Get-FileHash -Algorithm SHA256 -LiteralPath $nwn64Dll).Hash.ToLowerInvariant()
 $nwn64ProtectedUnchanged=(Get-FileHash -Algorithm SHA256 -LiteralPath $nwn64Accepted).Hash.ToLowerInvariant()-eq$nwn64AcceptedSha
 if(-not$nwn64ProtectedUnchanged){throw 'Accepted DLL changed during private build'}
 @{version=1;issue='NWN-64';private=$true;accepted=$false;production=$false;success=$true;binary=$nwn64Dll;binarySha256=$nwn64BinarySha;sourceManifest=$nwn64SourceManifest;sourceManifestSha256=$nwn64ExpectedManifest;sourceFiles=45;api=$nwn64Header;apiSha256=$nwn64ApiSha;compiler=$nwn64Compiler;compilerSha256=$nwn64CompilerSha;arguments=$nwn64Arguments;acceptedBinarySha256=$nwn64AcceptedSha;acceptedBinaryUnchanged=$nwn64ProtectedUnchanged;scope='Opt-in exact duplicate corner copy; private build only'}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $nwn64Output 'build-receipt.json') -Encoding utf8
}finally{$env:INCLUDE=$nwn64OldInclude;$env:LIB=$nwn64OldLib}
