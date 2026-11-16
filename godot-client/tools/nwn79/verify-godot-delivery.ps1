param(
 [Parameter(Mandatory=$true)][string]$PackageRoot,
 [switch]$Strict
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($PackageRoot)
$manifestPath=Join-Path $root 'godot-client/godot-delivery-manifest.json'
if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'Godot-only delivery manifest is missing'}
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if($manifest.format -ne 'nwn79-godot-delivery-v1' -or -not($manifest.files -is [array]) -or $manifest.files.Count -lt 100){throw 'Godot-only delivery manifest is invalid'}
$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($entry in $manifest.files){
 $relative=[string]$entry.path
 if(-not$relative -or $relative.StartsWith('/') -or $relative.Contains('..') -or $relative.Contains(':') -or $relative.Contains('\')){throw ('Invalid delivery path: '+$relative)}
 if(-not$seen.Add($relative)){throw ('Duplicate delivery path: '+$relative)}
 $absolute=[IO.Path]::GetFullPath((Join-Path $root $relative))
 if(-not$absolute.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not(Test-Path -LiteralPath $absolute -PathType Leaf)){throw ('Missing delivery file: '+$relative)}
 $file=Get-Item -LiteralPath $absolute
 if($file.Length -ne [long]$entry.size -or (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$entry.sha256){throw ('Delivery checksum mismatch: '+$relative)}
}
$actual=@(Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {$_.FullName.Substring($root.Length+1).Replace('\','/')})
foreach($relative in $actual){
 if($relative -match '(?i)(^|/)(electron|node_modules)(/|$)|\.(?:cjs|mjs|js)$|(^|/)(?:node|electron)\.exe$'){throw ('Legacy runtime entered Godot-only delivery: '+$relative)}
 if($Strict -and $relative -ne 'godot-client/godot-delivery-manifest.json' -and -not$seen.Contains($relative)){throw ('Unexpected delivery file: '+$relative)}
}
foreach($required in @('godot-client/project.godot','godot-client/join-godot.ps1','godot-client/native_direct_session_world.gd','godot-client/.tools/Godot_v4.7.2-stable_win64.exe','godot-client/.cache/native-kernel/nwn-particle-kernel.dll','godot-client/.cache/native-resource-index/nwn-resource-index.dll','godot-client/.cache/nwn79/windows-profile.exe','tooling/native/content-reader/nwn-content-reader.exe','tooling/native/nwn-network-crypto.exe')){
 if(-not$seen.Contains($required)){throw ('Required delivery component missing from manifest: '+$required)}
}
Write-Output ('Godot-only delivery verification PASS ('+$seen.Count+' files)')
