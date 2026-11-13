param()
$ErrorActionPreference='Stop'
$sealProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sealLocal=Join-Path $sealProject '.cache/combat-local-evidence/native-combat-presentation-local-v2'
$sealCpu=Join-Path $sealProject '.cache/combat-presentation-tests/native-combat-presentation-gait-v2'
$sealSnapshot=Get-Content -LiteralPath (Join-Path $sealLocal 'snapshot.json') -Raw|ConvertFrom-Json
$sealProof=Get-Content -LiteralPath (Join-Path $sealCpu 'proof.json') -Raw|ConvertFrom-Json
$sealReport=Get-Content -LiteralPath (Join-Path $sealLocal 'native-combat-presentation-local-v2.json') -Raw|ConvertFrom-Json
if(-not$sealSnapshot.success-or-not$sealProof.success-or$sealProof.changedInputs.Count-ne0-or-not$sealReport.success-or$sealReport.failure-or-not$sealReport.combatPresentationLifecycle.success){throw 'Final scoped acceptance is not clean'}
$sealNativeChecks=($sealProof.results|Measure-Object -Property checks -Sum).Sum
if($sealNativeChecks-ne5157-or$sealProof.protocolTests-ne5){throw 'Unexpected copied suite coverage'}
$sealOriginal=@(@{file='native-combat-base-handoff-original-v1.json';cases=120},@{file='native-combat-gait-base-original-v1.json';cases=36},@{file='native-combat-locomotion-handoff-original-v1.json';cases=18})
$sealOriginalDigests=[ordered]@{}
foreach($entry in $sealOriginal){$source=Join-Path $sealProject ('reports/'+$entry.file);$data=Get-Content -LiteralPath $source -Raw|ConvertFrom-Json;if($data.binarySha256-ne'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'-or$data.cases.Count-ne$entry.cases){throw 'Original corpus changed'};$sealOriginalDigests[$entry.file]=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()}
foreach($relative in @('systems/combat_animation.gd','systems/native_render/combat_presentation.gd','systems/native_render/live_world.gd','systems/native_data/combat_motion.gd')){
 $cpu=@($sealProof.inputs|Where-Object {$_.path-eq$relative});$local=@($sealSnapshot.pins|Where-Object {$_.path-eq('godot-client/'+$relative)})
 if($cpu.Count-ne1-or$local.Count-ne1-or$cpu[0].sha256-ne$local[0].sha256){throw ('CPU/local production mismatch '+$relative)}
}
$sealFiles=[ordered]@{}
foreach($pin in $sealSnapshot.pins){$sealFiles[$pin.path]=@{source=(Join-Path (Join-Path $sealLocal 'source') $pin.path);sha256=$pin.sha256}}
foreach($pin in $sealProof.inputs){$name=if($pin.path.StartsWith('../')){$pin.path.Substring(3)}else{'godot-client/'+$pin.path};$sealFiles['evidence/accepted-cpu/source/'+$name]=@{source=(Join-Path (Join-Path $sealCpu 'godot-client') $pin.path);sha256=$pin.sha256}}
foreach($root in @(@{path=$sealLocal;prefix='evidence/accepted-local/'},@{path=$sealCpu;prefix='evidence/accepted-cpu/'})){
 foreach($file in Get-ChildItem -LiteralPath $root.path -File){$sealFiles[$root.prefix+$file.Name]=@{source=$file.FullName;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}}
}
$sealExtras=@('NATIVE-COMBAT-LOCOMOTION.md','NATIVE-COMBAT-HANDOFF.md','reports/native-combat-receiver-research-v1.json','reports/native-combat-handoff-owners-research-v1.json','reports/native-combat-gait-base-original-v1.json','reports/native-combat-locomotion-handoff-original-v1.json','reports/native-combat-base-handoff-original-v1.json','reports/native-combat-check-lifecycle-v1.tap','tools/test-native-combat-locomotion.ps1','tools/test-native-combat-handoff.ps1','tools/stage-native-combat-locomotion.mjs','tools/seal-native-combat-locomotion.ps1','../scripts/inspect-native-combat-gait-base.py','../scripts/inspect-native-combat-locomotion-handoff.py','../scripts/inspect-native-combat-base-handoff.py','reports/native-combat-presentation-local-v1.json','reports/native-combat-presentation-local-v1.native.json','reports/native-combat-presentation-local-v1.isolation.json')
foreach($directory in @('backups/native-combat-locomotion-before-v1','backups/native-combat-live-harness-before-v1','backups/native-combat-check-lifecycle-before-v1')){foreach($file in Get-ChildItem -LiteralPath (Join-Path $sealProject $directory) -File){$sealExtras+=$directory+'/'+$file.Name}}
foreach($relative in $sealExtras){$source=Join-Path $sealProject $relative;$name=if($relative.StartsWith('../')){$relative.Substring(3)}else{'godot-client/'+$relative};if($sealFiles.Contains($name)){continue};$sealFiles[$name]=@{source=$source;sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()}}
$sealArchive=Join-Path $sealProject 'backups/native-combat-locomotion-bound-v1.zip'
if(Test-Path -LiteralPath $sealArchive){throw 'Existing final archive preserved'}
$stream=[IO.File]::Open($sealArchive,[IO.FileMode]::CreateNew)
try{$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true);try{foreach($name in $sealFiles.Keys){$item=$sealFiles[$name];if((Get-FileHash -LiteralPath $item.source -Algorithm SHA256).Hash.ToLowerInvariant()-ne$item.sha256){throw ('Immutable snapshot changed '+$name)};[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$item.source,$name,[IO.Compression.CompressionLevel]::Optimal)|Out-Null}}finally{$zip.Dispose()}}finally{$stream.Dispose()}
$zip=[IO.Compression.ZipFile]::OpenRead($sealArchive)
try{if($zip.Entries.Count-ne$sealFiles.Count){throw 'ZIP count differs'};foreach($entry in $zip.Entries){$stream=$entry.Open();try{$hasher=[Security.Cryptography.SHA256]::Create();$actual=[Convert]::ToHexString($hasher.ComputeHash($stream)).ToLowerInvariant();$hasher.Dispose()}finally{$stream.Dispose()};if($actual-ne$sealFiles[$entry.FullName].sha256){throw ('ZIP readback differs '+$entry.FullName)}}}finally{$zip.Dispose()}
$sealReceipt=[ordered]@{success=$true;archive=$sealArchive;sha256=(Get-FileHash -LiteralPath $sealArchive -Algorithm SHA256).Hash.ToLowerInvariant();files=$sealFiles.Count;bytes=(Get-Item -LiteralPath $sealArchive).Length;readbackVerified=$true;sourceSnapshotExact=$true;currentWholeTreeClaim=$false;originalCorpora=$sealOriginalDigests;originalCases=@{castBase=120;gaitBase=36;emptyPath=18};copiedNativeChecks=5157;copiedProtocolChecks=5;lifecycleTests=12;authoritativeLocalChecks=38;serverOutcomeAccepted=$true;localRun='native-combat-presentation-local-v2';rawFinishAck=$true;cleanExit=$true;workersRemaining=0;nativeOutputsUnchanged=$true;nativeBuilds=0;publicConnections=0;gpuTests=0;pixelsAccepted=$false;fullCombatAccepted=$false;fullUiAccepted=$false;goalComplete=$false;scope='Original resting-base/path handoff, actual LiveWorld boundary and owned original-server moving cast/private clips/received facing/attack cancellation. Completed source snapshots are exact; NPC/shape/repeated mixed combat/pixels/full parity remain open.'}
[IO.File]::WriteAllText(($sealArchive+'.verified.json'),($sealReceipt|ConvertTo-Json -Depth 6)+[Environment]::NewLine)
[IO.File]::WriteAllText((Join-Path $sealProject 'reports/native-combat-locomotion-acceptance-v1.json'),($sealReceipt|ConvertTo-Json -Depth 6)+[Environment]::NewLine)
$sealReceipt|ConvertTo-Json -Compress -Depth 6
