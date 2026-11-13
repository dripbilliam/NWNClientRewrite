[CmdletBinding()]
param([ValidateRange(1,16)][int]$Jobs=8)
$ErrorActionPreference='Stop'
$gapProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$gapStage=Join-Path $gapProject '.cache/native-render-gap/engine'
$gapManifestPath=Join-Path $gapStage 'manifest.json'
$gapManifest=Get-Content -LiteralPath $gapManifestPath -Raw | ConvertFrom-Json
$gapSource=[IO.Path]::GetFullPath($gapManifest.source)
if(-not $gapSource.StartsWith($gapStage+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Engine source outside private stage'}
function Assert-GapSource {
 foreach($patch in $gapManifest.patches){if((Get-FileHash -LiteralPath (Join-Path $gapSource $patch.relative)).Hash.ToLowerInvariant()-ne$patch.afterSha256){throw ('Engine patch drift '+$patch.relative)}}
 foreach($module in $gapManifest.modules){if((Get-FileHash -LiteralPath (Join-Path $gapSource $module.relative)).Hash.ToLowerInvariant()-ne$module.sha256){throw ('Engine module drift '+$module.relative)}}
}
Assert-GapSource
$gapPrevious=Get-Content -LiteralPath (Join-Path $gapProject '.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/build-1793998835313/invocation.json') -Raw | ConvertFrom-Json
if((Get-FileHash -LiteralPath $gapPrevious.compilerExecutable).Hash.ToLowerInvariant()-ne$gapPrevious.compilerSha256){throw 'Compiler drift'}
$gapArguments=@('-m','SCons','platform=windows','target=template_release','arch=x86_64','use_mingw=yes','disable_path_overrides=no','d3d12=no','debug_symbols=no','optimize=speed','lto=none','-j',[string]$Jobs)
$gapRun=Join-Path $gapStage ('build-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
New-Item -ItemType Directory -Path $gapRun | Out-Null
Copy-Item -LiteralPath $gapManifestPath -Destination (Join-Path $gapRun 'source-manifest.json')
foreach($gapEntry in @($gapManifest.patches.relative)+@($gapManifest.modules.relative)){
 $gapEvidence=Join-Path (Join-Path $gapRun 'source-evidence') $gapEntry
 New-Item -ItemType Directory -Force -Path (Split-Path -Parent $gapEvidence) | Out-Null
 Copy-Item -LiteralPath (Join-Path $gapSource $gapEntry) -Destination $gapEvidence
}
$gapPins=@{python=$gapPrevious.python;pythonSha256=(Get-FileHash -LiteralPath $gapPrevious.python).Hash.ToLowerInvariant();compiler=$gapPrevious.compilerExecutable;compilerSha256=$gapPrevious.compilerSha256;source=$gapSource;manifestSha256=(Get-FileHash -LiteralPath $gapManifestPath).Hash.ToLowerInvariant();arguments=$gapArguments;startedAt=[DateTimeOffset]::UtcNow.ToString('o')}
[IO.File]::WriteAllText((Join-Path $gapRun 'invocation.json'),($gapPins | ConvertTo-Json -Depth 5))
$gapSavedPath=$env:Path
try {
 $env:Path=$gapPrevious.compilerPath+';'+$gapSavedPath
 $gapProcess=Start-Process -FilePath $gapPrevious.python -ArgumentList $gapArguments -WorkingDirectory $gapSource -WindowStyle Hidden -RedirectStandardOutput (Join-Path $gapRun 'stdout.log') -RedirectStandardError (Join-Path $gapRun 'stderr.log') -PassThru
 [IO.File]::WriteAllText((Join-Path $gapRun 'process.json'),(@{pid=$gapProcess.Id;run=$gapRun;private=$true} | ConvertTo-Json))
 Write-Output ('Build started '+$gapProcess.Id+' '+$gapRun)
 $gapProcess.WaitForExit(); $gapProcess.Refresh()
 Assert-GapSource
 $gapOutput=Join-Path $gapSource 'bin/godot.windows.template_release.x86_64.exe'
 $gapReceipt=@{exitCode=$gapProcess.ExitCode;run=$gapRun;finishedAt=[DateTimeOffset]::UtcNow.ToString('o');sourceUnchanged=$true;sharedOutputsChanged=$false}
 if($gapProcess.ExitCode-eq0){
  $gapArchive=Join-Path $gapRun 'godot.windows.template_release.x86_64.exe'
  Copy-Item -LiteralPath $gapOutput -Destination $gapArchive
  $gapReceipt.output=$gapArchive; $gapReceipt.outputSha256=(Get-FileHash -LiteralPath $gapArchive).Hash.ToLowerInvariant()
 }
 [IO.File]::WriteAllText((Join-Path $gapRun 'receipt.json'),($gapReceipt | ConvertTo-Json -Depth 5))
 $gapReceipt | ConvertTo-Json -Depth 5
 if($gapProcess.ExitCode-ne0){exit $gapProcess.ExitCode}
} finally {$env:Path=$gapSavedPath}
