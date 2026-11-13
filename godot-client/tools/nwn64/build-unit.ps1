param([ValidatePattern('^[a-z0-9-]+$')][string]$Label='unit-build-a')
$ErrorActionPreference='Stop'
(Get-Process -Id $PID).PriorityClass='BelowNormal'
$nwn64Project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$nwn64Out=Join-Path $nwn64Project ('.cache/nwn64/'+$Label)
if(Test-Path -LiteralPath $nwn64Out){throw 'Keep previous unit build evidence'}
$nwn64Proposal=Get-Content -LiteralPath (Join-Path $nwn64Project '.cache/nwn64/proposal-a.json') -Raw | ConvertFrom-Json
foreach($nwn64Pin in @($nwn64Proposal.unitSource,$nwn64Proposal.unitSupport)){
 if((Get-FileHash -LiteralPath $nwn64Pin.file).Hash.ToLowerInvariant()-ne$nwn64Pin.sha256){throw 'Changed unit source/support'}
}
foreach($nwn64Stage in $nwn64Proposal.stages){
 $nwn64Inputs=Get-Content -LiteralPath $nwn64Stage.sourcePins.file -Raw | ConvertFrom-Json
 if((Get-FileHash -LiteralPath $nwn64Stage.sourcePins.file).Hash.ToLowerInvariant()-ne$nwn64Stage.sourcePins.sha256){throw 'Changed source pin manifest'}
 foreach($nwn64Pin in $nwn64Inputs.pins){if((Get-FileHash -LiteralPath (Join-Path $nwn64Inputs.project $nwn64Pin.relative)).Hash.ToLowerInvariant()-ne$nwn64Pin.sha256){throw 'Changed compact source closure'}}
}
$nwn64Api=Join-Path $nwn64Project '.tools/extension-api'
if((Get-FileHash -LiteralPath (Join-Path $nwn64Api 'gdextension_interface.h')).Hash.ToLowerInvariant()-ne'640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'){throw 'Changed pinned API header'}
$nwn64VsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$nwn64Vs=@(& $nwn64VsWhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64/cl.exe')}|Select-Object -First 1
if(-not$nwn64Vs){throw 'Pinned MSVC unavailable'}
$nwn64Tools=Join-Path $nwn64Vs 'VC/Tools/MSVC/14.50.35717';$nwn64Compiler=Join-Path $nwn64Tools 'bin/Hostx64/x64/cl.exe'
$nwn64Sdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$nwn64SdkInclude=Get-ChildItem -LiteralPath (Join-Path $nwn64Sdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
New-Item -ItemType Directory -Path $nwn64Out | Out-Null
$nwn64Exe=Join-Path $nwn64Out 'hit-clear-parity.exe'
$nwn64Args=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD',('/I'+$nwn64Api),('/Fo'+(Join-Path $nwn64Out 'hit-clear-parity.obj')),('/Fe'+$nwn64Exe),$nwn64Proposal.unitSource.file,'/link','/INCREMENTAL:NO')
$nwn64PreviousInclude=$env:INCLUDE;$nwn64PreviousLib=$env:LIB
try{
 $env:INCLUDE=((Join-Path $nwn64Tools 'include'),(Join-Path $nwn64SdkInclude.FullName 'ucrt'),(Join-Path $nwn64SdkInclude.FullName 'shared'),(Join-Path $nwn64SdkInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $nwn64Tools 'lib/x64'),(Join-Path $nwn64Sdk ('Lib/'+$nwn64SdkInclude.Name+'/ucrt/x64')),(Join-Path $nwn64Sdk ('Lib/'+$nwn64SdkInclude.Name+'/um/x64')))-join';'
 & $nwn64Compiler @nwn64Args 2>&1 | Tee-Object -FilePath (Join-Path $nwn64Out 'compiler.log')
 if($LASTEXITCODE-ne0){throw ('NWN64 unit compiler failed '+$LASTEXITCODE)}
 & $nwn64Exe 2>&1 | Tee-Object -FilePath (Join-Path $nwn64Out 'test.log')
 $nwn64TestExit=$LASTEXITCODE
 @{version=1;success=$nwn64TestExit-eq0;compiler=$nwn64Compiler;compilerSha256=(Get-FileHash -LiteralPath $nwn64Compiler).Hash.ToLowerInvariant();arguments=$nwn64Args;testExit=$nwn64TestExit;binarySha256=(Get-FileHash -LiteralPath $nwn64Exe).Hash.ToLowerInvariant();proposalSha256=(Get-FileHash -LiteralPath (Join-Path $nwn64Project '.cache/nwn64/proposal-a.json')).Hash.ToLowerInvariant();unitSource=$nwn64Proposal.unitSource;unitSupport=$nwn64Proposal.unitSupport;scope='Pure data compact/resident alias, callback and exception parity; no Godot/renderer/FPS'}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $nwn64Out 'receipt.json') -Encoding utf8
 if($nwn64TestExit-ne0){throw ('NWN64 unit parity failed '+$nwn64TestExit)}
}finally{$env:INCLUDE=$nwn64PreviousInclude;$env:LIB=$nwn64PreviousLib}
