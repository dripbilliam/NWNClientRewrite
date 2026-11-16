param(
 [Parameter(Mandatory=$true)][string]$Destination,
 [string]$Install='',
 [string]$GodotArchive=''
)
$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Split-Path -Path $client -Parent
$destination=[IO.Path]::GetFullPath($Destination)
$installed=if($Install){[IO.Path]::GetFullPath($Install)}else{[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall'))}
$archive=if($GodotArchive){[IO.Path]::GetFullPath($GodotArchive)}else{Join-Path $client '.tools/Godot_v4.7.2-stable_win64.exe.zip'}
if(-not$destination.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $destination.StartsWith($client+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $destination)){throw 'Restage destination must be a fresh workspace directory outside godot-client'}
if(-not(Test-Path -LiteralPath $installed -PathType Container)){throw 'NWN installation is unavailable'}
$lock=Get-Content -LiteralPath (Join-Path $client 'runtime-lock.json') -Raw|ConvertFrom-Json
if(-not(Test-Path -LiteralPath $archive -PathType Leaf)){throw 'Offline pinned Godot archive is unavailable'}
$archiveHash=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if($archiveHash -ne $lock.sha256){throw 'Offline Godot archive does not match the runtime lock'}
& (Join-Path $PSScriptRoot 'check-godot-only.ps1')|Out-Null

# This matches the source inputs selected by stage-clean-source.ps1. Recompute
# immediately after staging; a changed seal means the copy straddled an edit.
$inputs=[Collections.Generic.List[string]]::new()
foreach($name in @('project.godot','runtime-lock.json','main.tscn','join-godot.ps1')){$inputs.Add((Join-Path $client $name))}
foreach($file in Get-ChildItem -LiteralPath $client -File){if($file.Name -match '\.gd(?:\.uid)?$'){$inputs.Add($file.FullName)}}
foreach($folder in @('systems','data','native','tools')){
 foreach($file in Get-ChildItem -LiteralPath (Join-Path $client $folder) -Recurse -File){
  $include=switch($folder){
   'systems' {$file.Name -match '\.(?:gd|json|tscn|tres|gdshader)(?:\.uid)?$'}
   'data' {$file.Extension -eq '.json'}
   'native' {$file.Extension -in @('.c','.cpp','.h','.hpp','.inc','.gdextension')}
   'tools' {$file.Extension -in @('.ps1','.gd','.uid','.json','.c','.h','.hpp','.inc')}
  }
  if($include){$inputs.Add($file.FullName)}
 }
}
foreach($name in @('build-content-reader.ps1','build-network-crypto.ps1','native/nwn_content_reader.c','native/nwn_network_crypto.c','native/zstd-LICENSE.txt')){$inputs.Add((Join-Path $workspace ('scripts/'+$name)))}
foreach($relative in @('references/libhydrogen','references/nwnxee-unified/NWNXLib/External/sqlite3','references/neverwinter.nim/neverwinter/private/zstd/lib')){
 $reference=Join-Path $workspace $relative
 if(-not(Test-Path -LiteralPath $reference -PathType Container)){throw ('Clean source reference is missing: '+$relative)}
 foreach($file in Get-ChildItem -LiteralPath $reference -Recurse -File){$inputs.Add($file.FullName)}
}
$lines=[Collections.Generic.List[string]]::new()
foreach($path in ($inputs|Sort-Object -Unique)){
 if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('Clean source input is missing: '+$path)}
 $relative=$path.Substring($workspace.Length+1).Replace('\','/')
 $lines.Add($relative+'|'+(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant())
}
$bytes=[Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
$seal=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
$stage=Join-Path $destination 'source'
$package=Join-Path $stage 'package'
[ordered]@{
 format='nwn79-clean-restage-plan-v1'
 sourceSeal=$seal
 sourceFileCount=$lines.Count
 sourceGuard='pass'
 godotArchive=$archive
 godotArchiveSha256=$archiveHash
 install=$installed
 destination=$destination
 stageCommand=@((Join-Path $PSScriptRoot 'stage-clean-source.ps1'),'-Destination',$stage)
 setupCommand=@((Join-Path $stage 'godot-client/tools/nwn79/setup-godot-client.ps1'),'-Install',$installed,'-GodotArchive',$archive,'-UserDataDirectory',(Join-Path $destination 'setup-user-data'))
 packageCommand=@((Join-Path $stage 'godot-client/tools/nwn79/build-godot-delivery.ps1'),'-Install',$installed,'-Destination',$package)
 verifyCommand=@((Join-Path $stage 'godot-client/tools/nwn79/verify-godot-delivery.ps1'),'-PackageRoot',$package,'-Strict')
 acceptance=@('Recompute this source seal immediately after stage copy and reject a changed snapshot','Verify package manifest hashes and zero Node/Electron files','Run isolated packaged menu/chooser check','Run private Prelude acceptance only in an exclusive server window')
 executed=$false
}|ConvertTo-Json -Depth 5
