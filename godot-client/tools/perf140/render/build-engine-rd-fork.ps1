[CmdletBinding()]
param(
 [ValidatePattern('^[a-z0-9-]+$')][string]$Stage='engine-rd-thread-return-v1',
 [ValidatePattern('^[a-z0-9-]+$')][string]$ToolsStage='engine-build-tools-v1',
 [ValidateSet('pristine','patched')][string]$SourceState='patched',
 [ValidateRange(1,16)][int]$Jobs=4,
 [switch]$DryRun
)
$ErrorActionPreference='Stop'
$renderProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$renderDirectory=Join-Path $renderProject ('.cache/native-140fps/render-agent/'+$Stage)
$renderManifest=Get-Content -LiteralPath (Join-Path $renderDirectory 'manifest.json') -Raw|ConvertFrom-Json
$renderTools=Get-Content -LiteralPath (Join-Path $renderProject ('.cache/native-140fps/render-agent/'+$ToolsStage+'/manifest.json')) -Raw|ConvertFrom-Json
$renderTarget=Join-Path $renderManifest.source 'servers/rendering/rendering_server_default.cpp'
$renderExpectedHash=if($SourceState-eq'pristine'){$renderManifest.originalTargetSha256}else{$renderManifest.changedTargetSha256}
if((Get-FileHash -LiteralPath $renderTarget).Hash.ToLowerInvariant()-ne$renderExpectedHash){throw 'Private engine source state drifted'}
if((Get-FileHash -LiteralPath $renderTools.python).Hash.ToLowerInvariant()-ne$renderTools.pythonExeSha256){throw 'Private Python runtime drifted'}
$renderCompiler=Join-Path $renderProject '.cache/native-text-build/compiler/w64devkit/bin'
$renderCompilerArchive=Join-Path $renderProject '.cache/native-text-build/w64devkit-x64-2.10.1.7z.exe'
if((Get-FileHash -LiteralPath $renderCompilerArchive).Hash.ToLowerInvariant()-ne'add1edf984ce4d473cfeb7c52e0ab38db73a855bba6c7f564d5e16648eb2896a'){throw 'Retained official compiler archive drifted'}
$renderCompilerExecutable=Join-Path $renderCompiler 'x86_64-w64-mingw32-g++.exe'
if(-not(Test-Path -LiteralPath $renderCompilerExecutable)){$renderCompilerExecutable=Join-Path $renderCompiler 'g++.exe'}
$renderCompilerHash=(Get-FileHash -LiteralPath $renderCompilerExecutable).Hash.ToLowerInvariant()
$renderArguments=@('-m','SCons','platform=windows','target=template_release','arch=x86_64','use_mingw=yes','disable_path_overrides=no','d3d12=no','debug_symbols=no','optimize=speed','lto=none','-j',[string]$Jobs)
$renderRun=Join-Path $renderDirectory ('build-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
New-Item -ItemType Directory -Path $renderRun|Out-Null
$renderInvocation=@{python=$renderTools.python;arguments=$renderArguments;source=$renderManifest.source;sourceState=$SourceState;sourceTargetSha256=$renderExpectedHash;compilerPath=$renderCompiler;compilerExecutable=$renderCompilerExecutable;compilerSha256=$renderCompilerHash;jobs=$Jobs;dryRun=[bool]$DryRun;sourceManifestSha256=(Get-FileHash -LiteralPath (Join-Path $renderDirectory 'manifest.json')).Hash.ToLowerInvariant();sharedOutputChanged=$false;requestedAt=[DateTimeOffset]::UtcNow.ToString('o')}
[IO.File]::WriteAllText((Join-Path $renderRun 'invocation.json'),($renderInvocation|ConvertTo-Json -Depth 5))
if($DryRun){$renderInvocation|ConvertTo-Json -Depth 5;return}
$renderSavedPath=$env:Path
try {
 $env:Path=$renderCompiler+';'+$renderSavedPath
 $renderProcess=Start-Process -FilePath $renderTools.python -ArgumentList $renderArguments -WorkingDirectory $renderManifest.source -WindowStyle Hidden -RedirectStandardOutput (Join-Path $renderRun 'stdout.log') -RedirectStandardError (Join-Path $renderRun 'stderr.log') -PassThru
 [IO.File]::WriteAllText((Join-Path $renderRun 'process.json'),(@{pid=$renderProcess.Id;run=$renderRun;private=$true}|ConvertTo-Json))
 $renderProcess.WaitForExit()
 $renderProcess.Refresh()
 $renderArchiveDirectory=Join-Path $renderRun 'binaries'
 New-Item -ItemType Directory -Path $renderArchiveDirectory|Out-Null
 $renderOutput=@(Get-ChildItem -LiteralPath (Join-Path $renderManifest.source 'bin') -File|ForEach-Object { $renderDestination=Join-Path $renderArchiveDirectory $_.Name; Copy-Item -LiteralPath $_.FullName -Destination $renderDestination; @{path=$renderDestination;originalBuildOutput=$_.FullName;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $renderDestination).Hash.ToLowerInvariant()} })
 $renderReceipt=@{exitCode=$renderProcess.ExitCode;run=$renderRun;sourceState=$SourceState;sourceUnchanged=((Get-FileHash -LiteralPath $renderTarget).Hash.ToLowerInvariant()-eq$renderExpectedHash);outputs=$renderOutput;finishedAt=[DateTimeOffset]::UtcNow.ToString('o');sharedSourceChanged=$false;sharedEngineChanged=$false}
 [IO.File]::WriteAllText((Join-Path $renderRun 'receipt.json'),($renderReceipt|ConvertTo-Json -Depth 5))
 $renderReceipt|ConvertTo-Json -Depth 5
 if($renderProcess.ExitCode-ne0){exit $renderProcess.ExitCode}
} finally {$env:Path=$renderSavedPath}
