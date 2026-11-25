[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Stage,
    [ValidateSet('Prepare', 'Plan', 'Build')][string]$Action = 'Plan',
    [switch]$ReuseCxBuild,
    [ValidateRange(1, 16)][int]$Jobs = 4,
    [string]$SourceArchive,
    [string]$Python,
    [string]$CompilerBin
)
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspace = Split-Path -Parent $project
$relativeStage = "godot-client/.cache/native-font-atlas/$Stage"
$directory = Join-Path $workspace $relativeStage
$source = Join-Path $directory 'source'
$manifestPath = Join-Path $directory 'inputs.json'
$template = 'bin/godot.windows.template_release.x86_64.exe'
$textServer = 'modules/text_server_adv/text_server_adv.cpp'
$renderServer = 'servers/rendering/rendering_server_default.cpp'
$moduleName = 'nwn_particle_shadow_atlas'
$moduleSource = Join-Path $project "native/engine_modules/$moduleName"
$moduleFiles = @('config.py', 'SCsub', 'register_types.cpp', 'register_types.h')
$patch = Join-Path $project 'native/engine_patches/font-atlas-upload-snapshot.patch'
$shutdownPatch = Join-Path $PSScriptRoot 'perf140/render/godot-rd-thread-return.patch'
$sourceCommit = 'ed1daf0bf001b61586d9930840f2f1394092c079'
$archiveHash = 'e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef'
$originalHash = 'f156a5b0100ab39d588a3abc09a013c468b49dbff0ed085b7cb9c2a3e577cfcf'
$patchedHash = 'a8610a38de07f7286b49813065bfdab0bf655a0bf8076e6ffb05a9a93ffa188e'
$renderOriginalHash = '60cdf149a4cb8c8c7b49d562edcce2273e028e4a0a6cb067c7c478054a3dc3c9'
$renderPatchedHash = '27ddf6269efd6817d982d15e0677d7b89ccdec202adfefd79b4fe7bcf8e55297'
$seedEngineHash = 'a3564f1da069cc0dcbfdb7e15249b0369409dd835698234f11b815101db7ef76'

function Get-Sha256([string]$File) {
    (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-Sha256([string]$File, [string]$Expected) {
    if ((Get-Sha256 $File) -ne $Expected) { throw "Unexpected engine input bytes at $File" }
}

function Write-Receipt([string]$File, $Value) {
    [IO.File]::WriteAllText($File, ($Value | ConvertTo-Json -Depth 8) + "`n")
}

if (-not $SourceArchive) { $SourceArchive = Join-Path $project '.cache/native-text-build/godot-source.tar.gz' }
if (-not $Python) { $Python = Join-Path $project '.cache/native-140fps/render-agent/engine-build-tools-v1/python/python.exe' }
if (-not $CompilerBin) { $CompilerBin = Join-Path $project '.cache/native-text-build/compiler/w64devkit/bin' }
$SourceArchive = [IO.Path]::GetFullPath($SourceArchive)
$Python = [IO.Path]::GetFullPath($Python)
$CompilerBin = [IO.Path]::GetFullPath($CompilerBin)
$compiler = Join-Path $CompilerBin 'x86_64-w64-mingw32-g++.exe'

$modulePins = [ordered]@{}
foreach ($file in $moduleFiles) { $modulePins[$file] = Get-Sha256 (Join-Path $moduleSource $file) }

if ($Action -eq 'Prepare') {
    if (Test-Path -LiteralPath $directory) { throw 'Use a fresh private stage for preparation' }
    Assert-Sha256 $SourceArchive $archiveHash
    $seed = Join-Path $project '.cache/cx-shadow-atlas-engine/source'
    if ($ReuseCxBuild) {
        Assert-Sha256 (Join-Path $seed $template) $seedEngineHash
        Assert-Sha256 (Join-Path $seed $textServer) $originalHash
        Assert-Sha256 (Join-Path $seed $renderServer) $renderPatchedHash
        foreach ($file in $moduleFiles) {
            Assert-Sha256 (Join-Path $seed "modules/$moduleName/$file") $modulePins[$file]
        }
    }
    New-Item -ItemType Directory -Path $source | Out-Null
    if ($ReuseCxBuild) {
        $copyLog = Join-Path $directory 'seed-copy.log'
        & robocopy $seed $source /E /COPY:DAT /DCOPY:DAT /XJ /R:1 /W:1 /XD .git /NFL /NDL /NP "/LOG:$copyLog" | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "CX build seed copy failed ($LASTEXITCODE)" }
        Assert-Sha256 (Join-Path $source $template) $seedEngineHash
    } else {
        & tar -xf $SourceArchive -C $source --strip-components 1
        if ($LASTEXITCODE -ne 0) { throw "Godot source extraction failed ($LASTEXITCODE)" }
        $targetModule = Join-Path $source "modules/$moduleName"
        New-Item -ItemType Directory -Path $targetModule | Out-Null
        foreach ($file in $moduleFiles) {
            Copy-Item -LiteralPath (Join-Path $moduleSource $file) -Destination $targetModule
        }
        Assert-Sha256 (Join-Path $source $renderServer) $renderOriginalHash
        & git -C $workspace apply --directory="$relativeStage/source" -- $shutdownPatch
        if ($LASTEXITCODE -ne 0) { throw "Render-device shutdown patch failed ($LASTEXITCODE)" }
    }
    Assert-Sha256 (Join-Path $source $textServer) $originalHash
    & git -C $workspace apply --directory="$relativeStage/source" -- $patch
    if ($LASTEXITCODE -ne 0) { throw "Font-atlas patch failed ($LASTEXITCODE)" }
    Assert-Sha256 (Join-Path $source $textServer) $patchedHash
    Assert-Sha256 (Join-Path $source $renderServer) $renderPatchedHash
    foreach ($file in $moduleFiles) {
        Assert-Sha256 (Join-Path $source "modules/$moduleName/$file") $modulePins[$file]
    }
    Write-Receipt $manifestPath ([ordered]@{
        version = 1
        godotCommit = $sourceCommit
        godotArchiveSha256 = $archiveHash
        textServerBeforeSha256 = $originalHash
        textServerAfterSha256 = $patchedHash
        patchSha256 = Get-Sha256 $patch
        renderServerBeforeSha256 = $renderOriginalHash
        renderServerAfterSha256 = $renderPatchedHash
        shutdownPatchSha256 = Get-Sha256 $shutdownPatch
        cxModuleInputs = $modulePins
        seedExecutableSha256 = $(if ($ReuseCxBuild) { $seedEngineHash })
    })
    Get-Content -LiteralPath $manifestPath -Raw
    return
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.godotCommit -ne $sourceCommit -or $manifest.godotArchiveSha256 -ne $archiveHash -or
    $manifest.textServerBeforeSha256 -ne $originalHash -or $manifest.textServerAfterSha256 -ne $patchedHash) {
    throw 'Unexpected private font-atlas stage inputs'
}
Assert-Sha256 $patch $manifest.patchSha256
if ($manifest.shutdownPatchSha256) { Assert-Sha256 $shutdownPatch $manifest.shutdownPatchSha256 }
Assert-Sha256 (Join-Path $source $textServer) $patchedHash
Assert-Sha256 (Join-Path $source $renderServer) $renderPatchedHash
foreach ($file in $moduleFiles) {
    if ($manifest.cxModuleInputs.$file -ne $modulePins[$file]) { throw "CX module changed after staging at $file" }
    Assert-Sha256 (Join-Path $source "modules/$moduleName/$file") $modulePins[$file]
}
if ($manifest.seedExecutableSha256) { Assert-Sha256 (Join-Path $source $template) $seedEngineHash }

$receiptFile = Join-Path $directory "$($Action.ToLowerInvariant()).json"
$logFile = Join-Path $directory "$($Action.ToLowerInvariant()).log"
if ((Test-Path -LiteralPath $receiptFile) -or (Test-Path -LiteralPath $logFile)) {
    throw 'Preserve existing build evidence. Use a new stage to repeat this action.'
}
$arguments = @('-m', 'SCons', 'platform=windows', 'target=template_release', 'arch=x86_64',
    'use_mingw=yes', 'disable_path_overrides=no', 'd3d12=no', 'debug_symbols=no',
    'optimize=speed', 'lto=none', "-j$Jobs")
if ($Action -eq 'Plan') { $arguments += '-n' }
$receipt = [ordered]@{
    action = $Action
    args = $arguments
    source = $source
    manifestSha256 = Get-Sha256 $manifestPath
    fontAtlasSourceSha256 = $patchedHash
    renderShutdownSourceSha256 = $renderPatchedHash
    renderShutdownPatchSha256 = Get-Sha256 $shutdownPatch
    pythonSha256 = Get-Sha256 $Python
    compilerSha256 = Get-Sha256 $compiler
    startedUtc = [DateTime]::UtcNow.ToString('o')
    success = $false
}
$savedPath = $env:Path
Push-Location -LiteralPath $source
try {
    $env:Path = "$CompilerBin;$savedPath"
    & $Python @arguments *> $logFile
    $receipt.exitCode = $LASTEXITCODE
    if ($receipt.exitCode -ne 0) { throw "Godot $Action failed. See $logFile" }
    Assert-Sha256 (Join-Path $source $textServer) $patchedHash
    Assert-Sha256 (Join-Path $source $renderServer) $renderPatchedHash
    foreach ($file in $moduleFiles) {
        Assert-Sha256 (Join-Path $source "modules/$moduleName/$file") $modulePins[$file]
    }
    if ($Action -eq 'Build') {
        $executable = Join-Path $source $template
        $receipt.executable = $executable
        $receipt.executableSha256 = Get-Sha256 $executable
        if ($receipt.executableSha256 -eq $seedEngineHash) { throw 'Staged executable still matches the unpatched seed' }
    }
    $receipt.success = $true
} catch {
    $receipt.failure = $_.Exception.Message
    throw
} finally {
    Pop-Location
    $env:Path = $savedPath
    $receipt.finishedUtc = [DateTime]::UtcNow.ToString('o')
    Write-Receipt $receiptFile $receipt
}
Get-Content -LiteralPath $receiptFile -Raw
