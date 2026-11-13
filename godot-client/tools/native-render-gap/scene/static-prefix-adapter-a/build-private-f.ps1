param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label,[switch]$Build)
$ErrorActionPreference='Stop'
if(-not$Build){throw 'Source-only adapter: -Build is permitted only after a new free-PC authorization.'}
$cursorProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$cursorOutput=[IO.Path]::GetFullPath((Join-Path $cursorProject ('.cache/native-render-gap/scene/static-prefix-adapter-'+$Label)))
if(-not$cursorOutput.StartsWith($cursorProject+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Private output escapes project'}
if(Test-Path -LiteralPath $cursorOutput){throw 'Preserve existing adapter evidence; choose a fresh label'}
$cursorCompiler=Join-Path $cursorProject '.cache/native-text-build/compiler/w64devkit/bin/x86_64-w64-mingw32-g++.exe'
$cursorApi=Join-Path $cursorProject '.tools/extension-api'
$cursorHeader=Join-Path $cursorApi 'gdextension_interface.h'
if((Get-FileHash -LiteralPath $cursorCompiler).Hash.ToLowerInvariant()-ne'03e15580dda29518716dc6f6840d5ea055f526ddc8f59f14192b8d3e3eeea622'){throw 'Private compiler differs'}
if((Get-FileHash -LiteralPath $cursorHeader).Hash.ToLowerInvariant()-ne'640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'){throw 'Official Godot interface differs'}
$cursorContract=Join-Path $PSScriptRoot 'source-contract-f.json'
$cursorSource=Get-Content -LiteralPath $cursorContract -Raw|ConvertFrom-Json
foreach($cursorPin in $cursorSource.sourcePins){if((Get-FileHash -LiteralPath $cursorPin.file).Hash.ToLowerInvariant()-ne$cursorPin.sha256){throw 'Uncompiled proposal source pin differs'}}
New-Item -ItemType Directory -Path $cursorOutput|Out-Null
$cursorArguments=@('-std=c++17','-O2','-ffp-contract=off','-fno-fast-math','-shared','-static-libgcc','-static-libstdc++','-I',$cursorApi,(Join-Path $PSScriptRoot 'cursor_extension_f.cpp'),'-o',(Join-Path $cursorOutput 'nwn-static-prefix-cursor.dll'))
$cursorStart=[DateTime]::UtcNow
$cursorStdio=@(& $cursorCompiler @cursorArguments 2>&1)
$cursorExit=$LASTEXITCODE
$cursorStdio|Set-Content -LiteralPath (Join-Path $cursorOutput 'compiler.log') -Encoding utf8
$cursorReceipt=@{version=1;kind='private-isolated-static-prefix-cursor-build';success=$cursorExit-eq0;exit=$cursorExit;startedUtc=$cursorStart.ToString('o');finishedUtc=[DateTime]::UtcNow.ToString('o');compiler=@{file=$cursorCompiler;sha256=(Get-FileHash -LiteralPath $cursorCompiler).Hash.ToLowerInvariant()};arguments=$cursorArguments;sourceContract=@{file=$cursorContract;sha256=(Get-FileHash -LiteralPath $cursorContract).Hash.ToLowerInvariant()};sourcePins=$cursorSource.sourcePins;activationAccepted=$false;functionalAcceptance=$false;scope='Separate private GDExtension library only; no installed/shared binary or descriptor writes, no native launch or FPS claim.'}
if($cursorExit-eq0){$cursorReceipt.binary=@{file=(Join-Path $cursorOutput 'nwn-static-prefix-cursor.dll');sha256=(Get-FileHash -LiteralPath (Join-Path $cursorOutput 'nwn-static-prefix-cursor.dll')).Hash.ToLowerInvariant()}}
$cursorReceipt|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $cursorOutput 'build-receipt.json') -Encoding utf8
if($cursorExit-ne0){throw 'Private adapter compilation rejected; output retained'}
Write-Output ('Private adapter built at '+$cursorOutput+'; actual engine/owner oracles still required.')
