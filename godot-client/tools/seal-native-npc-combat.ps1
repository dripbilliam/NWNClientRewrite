$ErrorActionPreference='Stop'
$npcProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$npcArchive=Join-Path $npcProject 'backups/native-npc-combat-staged-v1.zip'
if(Test-Path -LiteralPath $npcArchive){throw 'Existing checkpoint preserved'}
$npcSource=Get-Content -LiteralPath (Join-Path $npcProject '.cache/npc-combat-source/native-npc-combat-source-v3/proof.json') -Raw|ConvertFrom-Json
$npcFailed=Get-Content -LiteralPath (Join-Path $npcProject '.cache/npc-combat-evidence/native-npc-combat-local-v1/snapshot.json') -Raw|ConvertFrom-Json
if(-not$npcSource.success-or$npcSource.checks-ne62-or$npcSource.changedInputs.Count-or$npcSource.changedCopiedInputs.Count-or-not$npcFailed.sourceExact-or$npcFailed.runAccepted-or$npcFailed.nativeChecks-ne0){throw 'Unexpected source/failure scope'}
$npcFiles=@()
foreach($npcRoot in @('.cache/npc-combat-source/native-npc-combat-source-v1','.cache/npc-combat-source/native-npc-combat-source-v2','.cache/npc-combat-source/native-npc-combat-source-v3','.cache/npc-combat-evidence/native-npc-combat-local-v1')){
 $npcAbsolute=[IO.Path]::GetFullPath((Join-Path $npcProject $npcRoot));if(-not$npcAbsolute.StartsWith($npcProject+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint root leaves project'}
 foreach($npcFile in [IO.Directory]::EnumerateFiles($npcAbsolute,'*',[IO.SearchOption]::AllDirectories)){if($npcFile.Contains([IO.Path]::DirectorySeparatorChar+'.godot'+[IO.Path]::DirectorySeparatorChar)){continue};$npcRelative=[IO.Path]::GetRelativePath($npcProject,$npcFile).Replace('\','/');if($npcRelative-match '\.dpapi$|(^|/)ticket\.json$'){throw 'Private credential file is not checkpoint source'};$npcFiles+=@{path=$npcRelative;source=$npcFile;sha256=(Get-FileHash -LiteralPath $npcFile).Hash.ToLowerInvariant()}}
}
foreach($npcRelative in @('NATIVE-COMBAT-NPC.md','tools/stage-native-npc-combat-failure.mjs','tools/seal-native-npc-combat.ps1')){$npcFile=Join-Path $npcProject $npcRelative;$npcFiles+=@{path=$npcRelative;source=$npcFile;sha256=(Get-FileHash -LiteralPath $npcFile).Hash.ToLowerInvariant()}}
$npcStream=[IO.File]::Open($npcArchive,[IO.FileMode]::CreateNew)
$npcZip=[IO.Compression.ZipArchive]::new($npcStream,[IO.Compression.ZipArchiveMode]::Create,$false)
try{foreach($npcFile in $npcFiles){[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($npcZip,$npcFile.source,$npcFile.path,[IO.Compression.CompressionLevel]::Fastest)|Out-Null}}finally{$npcZip.Dispose();$npcStream.Dispose()}
$npcRead=[IO.Compression.ZipFile]::OpenRead($npcArchive)
try{if($npcRead.Entries.Count-ne$npcFiles.Count){throw 'Checkpoint entry count differs'};foreach($npcFile in $npcFiles){$npcEntry=$npcRead.GetEntry($npcFile.path);$npcData=$npcEntry.Open();try{$npcDigest=[Security.Cryptography.SHA256]::HashData($npcData);$npcHash=[Convert]::ToHexString($npcDigest).ToLowerInvariant();if($npcHash-ne$npcFile.sha256){throw 'Checkpoint entry differs'}}finally{$npcData.Dispose()}}}finally{$npcRead.Dispose()}
$npcLedger=[ordered]@{version=1;sourceAccepted=$true;sourceChecks=62;sourcePins=$npcSource.inputs.Count;npcServerOutcomeAccepted=$false;rejectedNativeChecks=0;rejectedReason=$npcFailed.reason;exactRejectedSourcePins=$npcFailed.pins.Count;privateConstructorGameplayAccepted=$false;pixelsAccepted=$false;fullCombatAccepted=$false;fullUiAccepted=$false;goalComplete=$false;archive=$npcArchive;archiveEntries=$npcFiles.Count;archiveSha256=(Get-FileHash -LiteralPath $npcArchive).Hash.ToLowerInvariant();archiveReadbackVerified=$true;next='Level-up flow is now primary. NPC early active IPC loss and safe diagnostic capture/offline replay remain recorded backlog; capture expansion was not implemented.'}
$npcLedger|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $npcProject 'reports/native-npc-combat-staged-acceptance-v1.json')
$npcLedger|ConvertTo-Json -Depth 3
