[CmdletBinding(DefaultParameterSetName = 'Read')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Read')]
    [string]$Path,
    [Parameter(Mandatory = $true, ParameterSetName = 'List')]
    [string]$List,
    [ValidateSet('notes', 'tests')]
    [string]$Collection = 'notes'
)
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manifestName = if ($Collection -eq 'tests') { 'test-workbenches-manifest.json' } else { 'manifest.json' }
$manifestPath = Join-Path $repositoryRoot ('docs/archive/' + $manifestName)
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$archivePath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $manifest.archive))
if (-not $archivePath.StartsWith($repositoryRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Archive path escapes repository.'
}
if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.archiveSha256) {
    throw 'Archive hash differs from the verified manifest.'
}
if ($PSCmdlet.ParameterSetName -eq 'List') {
    $manifest.entries | Where-Object { $_.path -like $List } |
        Select-Object path, bytes, canonical
    return
}
$normalizedPath = $Path.Replace('\', '/') -replace '^\./', ''
$matches = @($manifest.entries | Where-Object { $_.path -ceq $normalizedPath })
if ($matches.Count -ne 1) {
    throw 'Archived file not found. Use -List with a wildcard to find its original path.'
}
$note = $matches[0]
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $entry = $archive.GetEntry($note.path)
    if ($null -eq $entry -or $entry.Length -ne $note.bytes -or $entry.Length -gt 16MB) {
        throw 'Archived note is missing or has an unexpected length.'
    }
    $entryStream = $entry.Open()
    $buffer = [IO.MemoryStream]::new()
    try {
        $entryStream.CopyTo($buffer)
        $bytes = $buffer.ToArray()
    } finally {
        $entryStream.Dispose()
        $buffer.Dispose()
    }
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $actualHash = ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $hasher.Dispose()
    }
    if ($actualHash -ne $note.sha256) {
        throw 'Archived note hash differs from its original source.'
    }
    [Console]::Out.Write([Text.Encoding]::UTF8.GetString($bytes))
} finally {
    $archive.Dispose()
}
