param()
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$broad=Join-Path $project '.cache/combat-presentation-tests/native-combat-presentation-class-v1'
$focused=Join-Path $project '.cache/combat-class-default/native-combat-class-after-v2'
$proof=Get-Content -LiteralPath (Join-Path $broad 'proof.json') -Raw|ConvertFrom-Json
$focus=Get-Content -LiteralPath (Join-Path $focused 'proof.json') -Raw|ConvertFrom-Json
if(-not$proof.success-or-not$focus.success-or$proof.changedInputs.Count-or$focus.changedInputs.Count-or$focus.checks-ne130-or($proof.results|Measure-Object checks -Sum).Sum-ne5287-or$proof.protocolTests-ne5){throw 'Scoped combat receipts are not accepted'}
foreach($name in @('systems/native_data/combat_actor.gd','systems/native_data/combat_class_state.gd','systems/native_render/combat_presentation.gd')){
 $a=@($proof.inputs|Where-Object {$_.path-eq$name});$b=@($focus.inputs|Where-Object {$_.path-eq('godot-client/'+$name)})
 if($a.Count-ne1-or$b.Count-ne1-or$a[0].sha256-ne$b[0].sha256){throw ('Focused/broad production differs '+$name)}
}
$original=Get-Content -LiteralPath (Join-Path $project 'reports/native-combat-class-default-original-v1.json') -Raw|ConvertFrom-Json
if(-not$original.success-or$original.binarySha256-ne'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a'-or$original.constructorCases.Count-ne3-or$original.selectorCases.Count-ne84){throw 'Original class proof differs'}
$files=[ordered]@{}
foreach($pin in $proof.inputs){$name=if($pin.path.StartsWith('../')){$pin.path.Substring(3)}else{'godot-client/'+$pin.path};$files[$name]=@{source=(Join-Path (Join-Path $broad 'godot-client') $pin.path);sha256=$pin.sha256}}
foreach($pin in $focus.inputs){$files['evidence/focused/source/'+$pin.path]=@{source=(Join-Path (Join-Path $focused 'inputs') $pin.path);sha256=$pin.sha256}}
foreach($item in @(@{directory=$broad;prefix='evidence/broad/'},@{directory=$focused;prefix='evidence/focused/'},@{directory=(Join-Path $project '.cache/combat-class-default/native-combat-class-before-v1');prefix='evidence/rejected-fixture/'},@{directory=(Join-Path $project '.cache/combat-class-default/native-combat-class-before-v2');prefix='evidence/before-failure/'})){
 foreach($file in Get-ChildItem -LiteralPath $item.directory -File){$files[$item.prefix+$file.Name]=@{source=$file.FullName;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}}
}
$event=Get-Content -LiteralPath (Join-Path $project 'reports/native-combat-installed-events-v1-receipt.json') -Raw|ConvertFrom-Json
if(-not$event.success-or$event.checks-ne19){throw 'Event provenance diagnostic differs'}
foreach($pin in $event.inputs){$files['evidence/events/source/'+$pin.path]=@{source=(Join-Path (Join-Path $event.directory 'inputs') $pin.path);sha256=$pin.sha256}}
foreach($file in Get-ChildItem -LiteralPath $event.directory -File){$files['evidence/events/'+$file.Name]=@{source=$file.FullName;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}}
$extras=@('NATIVE-COMBAT-CLASS-STATE.md','NATIVE-COMBAT-EVENT-PROVENANCE.md','reports/native-combat-installed-events-v1-receipt.json','reports/native-combat-installed-events-original-v1.json','tools/seal-native-combat-class.ps1','../scripts/inspect-native-installed-combat-events.py','../scripts/inspect-native-model-events.py','../scripts/inspect-native-intratile-coordinator.py')
foreach($file in Get-ChildItem -LiteralPath (Join-Path $project 'backups/native-combat-class-before-v1') -File){$extras+='backups/native-combat-class-before-v1/'+$file.Name}
foreach($relative in $extras){$name=if($relative.StartsWith('../')){$relative.Substring(3)}else{'godot-client/'+$relative};if($files.Contains($name)){continue};$file=Join-Path $project $relative;$files[$name]=@{source=$file;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}}
$archive=Join-Path $project 'backups/native-combat-class-bound-v1.zip';if(Test-Path -LiteralPath $archive){throw 'Existing checkpoint preserved'}
$stream=[IO.File]::Open($archive,[IO.FileMode]::CreateNew)
try{$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true);try{foreach($name in $files.Keys){$row=$files[$name];if((Get-FileHash -LiteralPath $row.source -Algorithm SHA256).Hash.ToLowerInvariant()-ne$row.sha256){throw ('Snapshot changed '+$name)};[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$row.source,$name,[IO.Compression.CompressionLevel]::Optimal)|Out-Null}}finally{$zip.Dispose()}}finally{$stream.Dispose()}
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try{if($zip.Entries.Count-ne$files.Count){throw 'Archive count differs'};foreach($entry in $zip.Entries){$stream=$entry.Open();try{$sha=[Security.Cryptography.SHA256]::Create();$actual=[Convert]::ToHexString($sha.ComputeHash($stream)).ToLowerInvariant();$sha.Dispose()}finally{$stream.Dispose()};if($actual-ne$files[$entry.FullName].sha256){throw ('Readback differs '+$entry.FullName)}}}finally{$zip.Dispose()}
$receipt=[ordered]@{success=$true;archive=$archive;sha256=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant();files=$files.Count;bytes=(Get-Item -LiteralPath $archive).Length;readbackVerified=$true;sourceSnapshotExact=$true;currentWholeTreeClaim=$false;focusedChecks=130;nativeRegressionChecks=5287;protocolChecks=5;originalConstructorCases=3;originalClassSlotSelectorCases=84;installedEventChecks=19;originalInstalledEventCases=3;canonicalStatsChanged=$false;serverConnections=0;nativeBuilds=0;gpuTests=0;npcServerOutcomeAccepted=$false;pixelsAccepted=$false;fullCombatAccepted=$false;fullUiAccepted=$false;goalComplete=$false;scope='Private original constructor class predicate plus received replacement/model/lifetime boundaries; original MDL event provenance and full scoped combat source regressions. No real NPC encounter or pixel/full combat acceptance.'}
[IO.File]::WriteAllText(($archive+'.verified.json'),($receipt|ConvertTo-Json -Depth 5)+[Environment]::NewLine)
[IO.File]::WriteAllText((Join-Path $project 'reports/native-combat-class-acceptance-v1.json'),($receipt|ConvertTo-Json -Depth 5)+[Environment]::NewLine)
$receipt|ConvertTo-Json -Compress
