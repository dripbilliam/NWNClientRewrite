param(
 [Parameter(Mandatory=$true)][string]$PackageRoot,
 [Parameter(Mandatory=$true)][string]$Report
)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$package=[IO.Path]::GetFullPath($PackageRoot)
$reportPath=[IO.Path]::GetFullPath($Report)
if(-not$package.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not$reportPath.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Package and report must stay inside this workspace'}
if(Test-Path -LiteralPath $reportPath){throw 'Use a fresh headless launch report path'}
$project=Join-Path $package 'godot-client'
$manifestPath=Join-Path $project 'godot-delivery-manifest.json'
$enginePath=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
$consolePath=Join-Path $project '.tools/Godot_v4.7.2-stable_win64_console.exe'
& (Join-Path $PSScriptRoot 'verify-godot-delivery.ps1') -PackageRoot $package -Strict | Out-Null
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if(@($manifest.files|Where-Object {$_.path -eq 'godot-client/.tools/Godot_v4.7.2-stable_win64_console.exe'}).Count -ne 0 -or (Test-Path -LiteralPath $consolePath)){throw 'Unused Windows console wrapper entered the ordinary package'}
$engineEntry=@($manifest.files|Where-Object {$_.path -eq 'godot-client/.tools/Godot_v4.7.2-stable_win64.exe'})
if($engineEntry.Count -ne 1){throw 'Pinned desktop engine missing from delivery manifest'}
$engineHash=(Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash.ToLowerInvariant()
if($engineHash -ne [string]$engineEntry[0].sha256){throw 'Pinned desktop engine hash differs from manifest'}
$output=@(& (Join-Path $project 'join-godot.ps1') -Headless -CheckOnly 2>&1 | ForEach-Object {$_.ToString()})
if($output -notcontains 'Godot-only pinned headless engine launch PASS' -or $output -notcontains 'Godot-only native client prerequisites PASS'){throw ('Packaged headless launcher failed: '+($output -join ' | '))}
$receipt=[ordered]@{
 success=$true
 package=$package
 manifestSha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
 engineSha256=$engineHash
 engine='Godot_v4.7.2-stable_win64.exe'
 headlessFlag=$true
 consoleWrapperPackaged=$false
 launcherCheck='Godot-only pinned headless engine launch PASS'
}
New-Item -ItemType Directory -Path (Split-Path -Path $reportPath -Parent) -Force|Out-Null
$receipt|ConvertTo-Json|Set-Content -LiteralPath $reportPath -Encoding utf8
Write-Output ('Packaged Godot headless launcher PASS: '+$reportPath)
