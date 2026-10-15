param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Name,
  [string[]]$ExcludeCaptureNames=@())
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$destination=[IO.Path]::GetFullPath((Join-Path $workspace ('backups/'+$Name+'.zip')))
if(-not $destination.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint target is outside the workspace'}
if(Test-Path -LiteralPath $destination){throw 'Checkpoint already exists; choose a new name'}
$files=[Collections.Generic.List[IO.FileInfo]]::new()
foreach($directory in @('src','test','evidence','scripts','electron','.github')){
  foreach($file in Get-ChildItem -LiteralPath (Join-Path $workspace $directory) -Recurse -File){
    if($file.Extension -in @('.js','.mjs','.cjs','.json','.md','.txt','.ps1','.py','.java','.css','.html')){$files.Add($file)}
  }
}
foreach($file in Get-ChildItem -LiteralPath $workspace -File){if($file.Name -in @('README.md','REPLACEMENT_CLIENT_ROADMAP.MD','CASTING_RESUME_NOTE.md','package.json','package-lock.json','index.html','.gitignore')){$files.Add($file)}}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $workspace 'backups/animations') -File){
  if($file.Name -in $ExcludeCaptureNames){continue}
  if($file.Name -in @('missing-script-resource-audit.json','missing-script-installed-smoke.json','missing-script-rendered.png')){$files.Add($file);continue}
  if($file.Name -in @('native-door-queue-observations.json','native-string-float-crt-comparison.json','area-transition-dialog-route.json','area-transition-model-audit.json','area-transition-installed-smoke.json','area-transition-rendered.png')){$files.Add($file);continue}
  if($file.Name -in @('quickbar-lock-installed-smoke.json','quickbar-assignment-ui.json','quickbar-assignment-ui.png')){$files.Add($file);continue}
  if($file.Name -in @('feedback-engine-installed-smoke.json','feedback-engine-rendered.png')){$files.Add($file);continue}
  if($file.Name -in @('prelude-user-log-audit.json','prelude-walkmesh-probe.json','prelude-walkmesh-probe-fixed.json','prelude-render-coverage.json','prelude-render-coverage-fixed.json','prelude-library-restored.png','prelude-world-geometry-fixed.png')){$files.Add($file);continue}
  if($file.Name -in @('native-character-creation-observations.json','character-creation-installed-audit.json','character-frontend-smoke.json','character-selector.png','character-creation-appearance.png','character-creation-review.png','character-creation-in-world.png')){$files.Add($file);continue}
  if($file.Name -in @('native-control-constructor-observations-v3.json','native-silence-effect-observations.json','native-invisibility-effect-observations.json','native-invisibility-concealment-observations.json','spell-ecosystem-active-audit-v8.json','spell-ecosystem-active-audit-v9.json','persistent-spell-active-audit-v2.json','persistent-spell-active-audit-v3.json','casting-authored-silence-area-lifecycle-v1.json','casting-authored-area-lifecycle-v3.json','casting-authored-area-36-impact-probe-v2.json','casting-authored-area-163-impact-probe-v2.json','casting-authored-invisibility-lifecycle-v1.json','casting-authored-invisibility-lifecycle-v2.json','casting-authored-invisibility-lifecycle-v3.json')){$files.Add($file);continue}
  if($file.Name -in @('native-area-effect-observations.json','native-area-effect-overlap-observations.json','native-area-effect-overlap-observations-v2.json','native-area-effect-overlap-observations-v3.json','native-area-effect-creation-observations.json','persistent-spell-active-audit-v1.json','spell-ecosystem-active-audit-v7.json','casting-authored-area-lifecycle-v1.json','casting-authored-area-lifecycle-v2.json','casting-authored-entangle-53-impact-probe-v1.json','casting-authored-area-23-impact-probe-v1.json','casting-authored-area-23-impact-probe-v2.json','casting-authored-area-36-impact-probe-v1.json','casting-authored-area-66-impact-probe-v1.json','casting-authored-area-66-impact-probe-v2.json','casting-authored-area-163-impact-probe-v1.json')){$files.Add($file);continue}
  if($file.Name -in @('native-ability-effect-observations-v2.json','native-contents-weight-observations.json','native-linked-effect-observations-v2.json','spell-ecosystem-active-audit-v6.json','casting-authored-endurance-49-impact-probe-v1.json','casting-authored-bull-strength-9-impact-probe-v1.json','casting-authored-bull-strength-9-impact-probe-v2.json','casting-authored-fox-cunning-356-impact-probe-v1.json','casting-authored-ability-haste-lifecycle-v1.json')){$files.Add($file);continue}
  if($file.Name -in @('native-speed-effect-observations.json','native-enchantment-effect-observations.json','native-control-support-observations.json','native-effect-script-type-observations-v3.json','spell-ecosystem-active-audit-v5.json','casting-authored-haste-impact-probe-v2.json','casting-authored-sleep-165-impact-probe-v2.json','casting-authored-sleep-165-impact-probe-v3.json','casting-authored-sleep-165-impact-probe-v4-seed1.json','casting-authored-sleep-165-impact-probe-v4-seed2.json','casting-authored-sleep-165-impact-probe-v5-seed1.json')){$files.Add($file);continue}
  if($file.Name -eq 'native-campaign-query-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-spell-book-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-spell-save-dc-observations.json'){$files.Add($file);continue}
  if($file.Name -in @('native-linked-effect-observations.json','native-defense-effect-observations.json','native-item-property-query-observations.json','native-location-effect-observations.json','native-spell-shared-feedback-observations.json','native-effect-script-type-observations-v2.json','native-command-table-observations.json','native-effect-registration-observations.json','native-control-constructor-observations-v2.json','native-haste-effect-observations.json','spell-ecosystem-active-audit-v4.json','casting-active-spell-engine-api.json','casting-active-item-property-api-v2.json')){$files.Add($file);continue}
  if($file.Name -in @('authored-bless-impact-probe-v1.json','authored-fireball-impact-probe-v1.json','authored-bless-6-impact-probe-v2.json','authored-bless-6-impact-probe-v3.json','authored-fireball-58-impact-probe-v2.json','authored-fireball-58-impact-probe-v3.json','authored-fireball-58-impact-probe-v4.json','authored-fireball-58-impact-probe-v5.json','authored-haste-78-impact-probe-v1.json','authored-sleep-165-impact-probe-v1.json')){$files.Add($file);continue}
  if($file.Name -in @('native-visual-apply-observations.json','native-effect-script-type-observations.json','native-looping-visual-observations.json','native-script-log-observations.json','native-spell-resistance-observations.json','authored-magic-missile-impact-probe-v3.json','authored-magic-missile-impact-probe-v4.json','authored-magic-missile-impact-probe-v5.json','authored-magic-missile-impact-probe-v6.json','authored-heal-impact-probe-v3.json')){$files.Add($file);continue}
  if($file.Name -in @('native-spell-impact-event-observations.json','native-effect-creator-observations.json','native-spell-notification-observations.json','native-spell-script-support-observations.json','native-visual-constructor-observations.json','spell-ecosystem-active-audit-v2.json','spell-ecosystem-active-audit-v3.json','authored-magic-missile-impact-probe-v2.json','authored-heal-impact-probe-v2.json')){$files.Add($file);continue}
  if($file.Name -eq 'native-cast-request-observations.json'){$files.Add($file);continue}
  if($file.Name -in @('native-spell-queue-observations.json','native-cast-action-observations.json','native-casting-support-observations.json','native-spell-context-observations.json','native-empty-region-observations.json')){$files.Add($file);continue}
  if($file.Name -in @('native-logf-constants.json','native-logf-observations.json','native-logf-invalid-avx-observations.json','native-spell-projectile-observations.json','native-casting-metadata-observations.json','native-caster-level-observations.json','casting-active-data-1225.json')){$files.Add($file);continue}
  if($file.Name -in @('casting-live-wizard-spell-book-v2.png','casting-live-wizard-spell-book.png.failed.png')){$files.Add($file);continue}
  if($file.Name -eq 'native-unequip-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-unequip-action-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-script-equipment-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-corpse-bag-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-corpse-lifecycle-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-corpse-transfer-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-action-cancel-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-action-queue-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-los-interpolation-observations.json'){$files.Add($file);continue}
  if($file.Name -eq 'native-corpse-inventory-observations.json'){$files.Add($file);continue}
  if($file.Name -in @('native-intratile-coordinator-observations.json','native-tile-plot-observations.json','native-best-exit-observations.json','native-area-plot-observations.json')){$files.Add($file);continue}
  if($file.Name -in @('native-intra-walkable-observations.json','native-intratile-successor-observations.json')){$files.Add($file);continue}
  if($file.Name -in @('native-path-alternative-observations.json','native-intratile-search-observations.json','native-subdivision-observations.json')){$files.Add($file);continue}
  if($file.Name -in @('native-intertile-successor-observations.json','native-path-getter-observations.json')){$files.Add($file);continue}
  if($file.Name -eq 'native-intertile-search-observations.json'){$files.Add($file);continue}
  if($file.Name -in @('native-equipment-action-observations.json','native-run-equip-observations.json','native-round-recompute-observations.json')){$files.Add($file);continue}
  if($file.Name -in @('native-shape-associate-observations.json','native-script-cos-observations.json','native-script-location-observations.json','native-inventory-enumeration-observations.json','native-equipment-mutation-observations.json','native-equipment-ai-gate-observations.json','native-weapon-selection-observations.json')){$files.Add($file);continue}
  if($file.Name -in @('native-pickpocket-observations.json','native-inventory-control-observations.json','native-encounter-activation-observations.json','native-encounter-spawn-list-observations.json','native-spawn-placement-observations.json','native-encounter-spawn-observations.json','native-wandering-observations.json','native-encounter-death-observations.json')){$files.Add($file);continue}
  if($file.Name -in @('native-item-property-pool-observations.json','native-life-state-observations.json','native-repository-add-observations.json','native-item-possession-observations.json','native-item-presentation-observations.json','native-module-item-event-observations.json','native-module-equipment-event-observations.json','native-item-stack-compare-observations.json','native-gold-observations.json','native-equipment-weapon-observations.json','native-equipment-import-gate-observations.json','native-combat-query-observations.json','native-item-acquisition-observations.json')){$files.Add($file);continue}
  if($file.Extension -eq '.txt' -or $file.Name -in @('native-grid-rsqrt-reference.json','native-perception-oracle-observations.json','native-tile-path-node-observations.json','native-listen-expression-observations.json','native-talent-selector-observations.json','native-item-use-observations.json','native-repository-fit-observations.json','native-animation-name-observations.json','native-client-combat-animation-observations.json','native-body-transition-observations.json')){$files.Add($file)}
}
foreach($relativeCapture in @('backups/native-xp-oracle/native-xp-log.txt','backups/native-xp-oracle/native-xp-log.txt.capture.json','backups/native-xp-oracle/home/modules/codex_xp_oracle.mod.manifest.json')){
  $capturePath=Join-Path $workspace $relativeCapture
  if(Test-Path -LiteralPath $capturePath){$files.Add((Get-Item -LiteralPath $capturePath))}
}
foreach($auditDirectory in Get-ChildItem -LiteralPath (Join-Path $workspace 'backups') -Directory){
  if($auditDirectory.Name -notlike 'campaign-startup-*' -and $auditDirectory.Name -notlike 'casting-spell-*'){continue}
  foreach($capture in Get-ChildItem -LiteralPath $auditDirectory.FullName -File){
    if($capture.Extension -in @('.json','.jsonl')){$files.Add($capture)}
  }
}
Add-Type -AssemblyName System.IO.Compression
$stream=[IO.File]::Open($destination,[IO.FileMode]::CreateNew)
$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
$manifest=[Collections.Generic.List[object]]::new()
try{
  foreach($file in $files){
    $absolute=[IO.Path]::GetFullPath($file.FullName)
    if(-not $absolute.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Checkpoint source is outside the workspace'}
    $relative=$absolute.Substring($workspace.Length+1).Replace('\','/')
    $hash=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $entry=$zip.CreateEntry($relative,[IO.Compression.CompressionLevel]::Optimal)
    $input=[IO.File]::OpenRead($file.FullName);$output=$entry.Open()
    try{$input.CopyTo($output)}finally{$input.Dispose();$output.Dispose()}
    $manifest.Add([ordered]@{path=$relative;bytes=$file.Length;sha256=$hash})
  }
  $entry=$zip.CreateEntry('checkpoint-manifest.json');$writer=[IO.StreamWriter]::new($entry.Open())
  try{$writer.Write(($manifest|ConvertTo-Json -Depth 4))}finally{$writer.Dispose()}
}finally{$zip.Dispose();$stream.Dispose()}
$verify=[IO.Compression.ZipFile]::OpenRead($destination)
try{
  if($verify.Entries.Count -ne $files.Count+1){throw 'Checkpoint entry count mismatch'}
  foreach($requiredFile in @('src/perception_detection.js','src/native_ai_master.js','backups/animations/live-native-heartbeat-ai-update-state-asm.txt')){if(-not $verify.GetEntry($requiredFile)){throw ('Missing checkpoint file: '+$requiredFile)}}
  foreach($record in $manifest){
    $entry=$verify.GetEntry($record.path);if(-not $entry -or $entry.Length -ne $record.bytes){throw ('Checkpoint length mismatch: '+$record.path)}
    $entryStream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
    try{$actual=[Convert]::ToHexString($sha.ComputeHash($entryStream))}finally{$entryStream.Dispose();$sha.Dispose()}
    if($actual -ne $record.sha256){throw ('Checkpoint SHA256 mismatch: '+$record.path)}
  }
}finally{$verify.Dispose()}
[ordered]@{path=$destination;files=$files.Count;bytes=(Get-Item -LiteralPath $destination).Length}|ConvertTo-Json -Compress
