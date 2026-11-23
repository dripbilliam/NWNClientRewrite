param([ValidateRange(1, 16)][int]$Jobs = 8)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$workspace = Split-Path -Parent $project
$tools = Join-Path $project '.tools'
$lockPath = Join-Path $project 'client-runtime-lock.json'
$lockText = [IO.File]::ReadAllText($lockPath).Replace("`r`n", "`n")
$lock = $lockText | ConvertFrom-Json

function Get-TextDigest([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()
}

function Get-FileDigest([string]$File) {
    (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
}

$recipeSha256 = Get-TextDigest $lockText
$runtimeRoot = Join-Path $tools 'client-runtime'
$install = Join-Path $runtimeRoot $recipeSha256
$executable = Join-Path $install 'Godot_client_win64.exe'
if (Test-Path -LiteralPath $install) {
    $receipt = Get-Content -LiteralPath (Join-Path $install 'runtime.json') -Raw | ConvertFrom-Json
    if ($receipt.kind -ne 'native-client-runtime' -or $receipt.recipeSha256 -ne $recipeSha256 -or
        $receipt.executableSha256 -ne (Get-FileDigest $executable)) {
        throw 'Installed client engine does not match its build receipt.'
    }
    return $executable
}

$inputs = Join-Path $tools 'client-build-inputs'
New-Item -ItemType Directory -Path $inputs, $runtimeRoot -Force | Out-Null
function Get-BuildInput($InputSpec) {
    $file = Join-Path $inputs $InputSpec.file
    if (!(Test-Path -LiteralPath $file)) {
        $download = "$file.$([guid]::NewGuid().ToString('N')).download"
        try {
            Invoke-WebRequest -Uri $InputSpec.url -OutFile $download
            if ((Get-FileDigest $download) -ne $InputSpec.sha256) { throw "Checksum mismatch for $($InputSpec.file)" }
            [IO.File]::Move($download, $file)
        } finally {
            if (Test-Path -LiteralPath $download) { Remove-Item -LiteralPath $download }
        }
    }
    if ((Get-FileDigest $file) -ne $InputSpec.sha256) { throw "Checksum mismatch for $file" }
    $file
}

$sourceArchive = Get-BuildInput $lock.source
$compilerArchive = Get-BuildInput $lock.compiler
$pythonArchive = Get-BuildInput $lock.python
$sconsArchive = Get-BuildInput $lock.scons
$relativeStage = ".cache/client-engine-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$stage = Join-Path $workspace $relativeStage
$source = Join-Path $stage 'src'
$compiler = Join-Path $stage 'w64devkit/bin'
New-Item -ItemType Directory -Path $source | Out-Null
& tar.exe -xf $sourceArchive --strip-components=1 -C $source
if ($LASTEXITCODE -ne 0) { throw 'Client engine source extraction failed.' }
& tar.exe -xf $compilerArchive -C $stage
if ($LASTEXITCODE -ne 0) { throw 'Client engine compiler extraction failed.' }
[IO.Compression.ZipFile]::ExtractToDirectory($pythonArchive, (Join-Path $stage 'python'))
[IO.Compression.ZipFile]::ExtractToDirectory($sconsArchive, (Join-Path $stage 'scons'))
[IO.File]::WriteAllText((Join-Path $stage 'python/python312._pth'), "python312.zip`n.`n../scons`n")

foreach ($patch in $lock.patches) {
    $patchText = [IO.File]::ReadAllText((Join-Path $project $patch.file)).Replace("`r`n", "`n")
    if ((Get-TextDigest $patchText) -ne $patch.sha256) { throw "Client engine patch changed at $($patch.file)" }
    $patchFile = Join-Path $stage (Split-Path -Leaf $patch.file)
    [IO.File]::WriteAllText($patchFile, $patchText)
    & git -C $workspace apply --directory="$relativeStage/src" -- $patchFile
    if ($LASTEXITCODE -ne 0) { throw "Could not apply engine patch $($patch.file)" }
}

$sconsArguments = @('-m', 'SCons') + @($lock.buildArguments) + @('-j', [string]$Jobs)
$log = Join-Path $stage 'build.log'
Write-Host "Building the client engine. Log at $log"
$previousPath = $env:PATH
Push-Location -LiteralPath $source
try {
    $env:PATH = "$compiler;$previousPath"
    & (Join-Path $stage 'python/python.exe') @sconsArguments *> $log
    if ($LASTEXITCODE -ne 0) { throw "Client engine build failed. See $log" }
} finally {
    Pop-Location
    $env:PATH = $previousPath
}

$stagedInstall = Join-Path $runtimeRoot ([guid]::NewGuid().ToString('N') + '.incoming')
New-Item -ItemType Directory -Path $stagedInstall | Out-Null
$stagedExecutable = Join-Path $stagedInstall 'Godot_client_win64.exe'
Copy-Item -LiteralPath (Join-Path $source 'bin/godot.windows.template_release.x86_64.exe') -Destination $stagedExecutable
$receipt = @{
    kind = 'native-client-runtime'
    recipeSha256 = $recipeSha256
    executableSha256 = Get-FileDigest $stagedExecutable
}
[IO.File]::WriteAllText((Join-Path $stagedInstall 'runtime.json'), ($receipt | ConvertTo-Json) + "`n")
[IO.Directory]::Move($stagedInstall, $install)
$executable
