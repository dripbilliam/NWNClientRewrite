param([string[]]$SourcePaths=@())
$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Split-Path -Path $client -Parent
$fullWorkspace=Test-Path -LiteralPath (Join-Path $workspace '.git')
$defaultInventory=$SourcePaths.Count -eq 0
if($defaultInventory){
 $SourcePaths=@(
  (Join-Path $client 'join-godot.ps1'),
  (Join-Path $client 'join-native.ps1'),
  (Join-Path $client 'join-local.ps1'),
  (Join-Path $client 'replay-native-loading.ps1'),
  (Join-Path $client 'test-handoff.ps1'),
  (Join-Path $client 'native_direct_session_world.gd'),
  (Join-Path $client 'native_live_world.gd'),
  (Join-Path $client 'systems/native_install_selector.gd'),
  (Join-Path $client 'systems/native_data/client_settings_store.gd'),
  (Join-Path $client 'systems/native_data/native_startup_paths.gd'),
  (Join-Path $client 'systems/native_data/godot_login_profile_controller.gd'),
  (Join-Path $client 'systems/native_data/godot_server_browser_store.gd'),
  (Join-Path $client 'tools/setup.ps1'),
  (Join-Path $client 'tools/native-tracy/live/launch.ps1'),
  (Join-Path $client 'tools/native-live-review/launch.ps1'),
  (Join-Path $client 'tools/native-render-gap/transport/live/launch.ps1'),
  (Join-Path $client 'tools/native_parity/performance/check_production_local.ps1'),
  (Join-Path $client 'tools/native-window-screen.ps1'),
  (Join-Path $client 'tools/nwn79/build-windows-profile.ps1'),
  (Join-Path $client 'tests/nwn79_run_levelup_private.ps1'),
  (Join-Path $client 'tests/nwn79_install_launcher_test.ps1'),
  (Join-Path $client 'tools/nwn79/nwsync-cache-repair.gd'),
  (Join-Path $client 'tools/nwn79/nwsync-visual-fixture-check.gd'),
  (Join-Path $client 'tools/nwn79/nwsync-visual-repository-check.gd'),
  (Join-Path $client 'tools/nwn79/nwsync-visual-zstd.gd'),
  (Join-Path $workspace 'scripts/build-content-reader.ps1'),
  (Join-Path $workspace 'scripts/build-network-crypto.ps1')
 )+@(Get-ChildItem -LiteralPath (Join-Path $client 'systems/native_data') -Filter 'native_network_*.gd' -File|ForEach-Object FullName)
 $SourcePaths+=@('join-arelith.ps1','tools/nwn79/setup-godot-client.ps1','tools/nwn79/stage-clean-source.ps1','tools/nwn79/prepare-clean-restage.ps1','tools/nwn79/build-godot-delivery.ps1','tools/nwn79/verify-godot-delivery.ps1','tools/nwn79/run-direct-acceptance-matrix.ps1','tools/nwn79/verify-local-smoke-receipt.ps1','tools/nwn79/run-focused-tests.ps1','tools/nwn79/run-direct-handoff-roundtrip.ps1','tools/nwn79/verify-direct-handoff-roundtrip-receipt.ps1','tools/nwn79/nwsync-loopback-fixture.ps1','tools/nwn79/verify-nwsync-visual-repository.ps1','tools/nwn79/verify-native-loading-capture.ps1','tools/nwn79/test-retired-entrypoints.ps1')|ForEach-Object {Join-Path $client $_}
 # Supported client launchers, setup/build helpers, and NWN-79 test runners.
 # The other tests/*.ps1 and tools/* subtrees are archived research fixtures;
 # they are not called by the supported NWN-79 launch/acceptance entrypoints.
 $SourcePaths+=@(Get-ChildItem -LiteralPath $client -Filter '*.ps1' -File|ForEach-Object FullName)
 # These are the executable Godot sources and resources selected by clean
 # staging and delivery. Archived browser fixtures under scripts/ are separate.
 $SourcePaths+=@(Get-ChildItem -LiteralPath $client -Filter '*.gd' -File|ForEach-Object FullName)
 $SourcePaths+=@(Get-ChildItem -LiteralPath (Join-Path $client 'systems') -Recurse -File|Where-Object {$_.Name -match '\.(?:gd|gdshader|tscn|tres)(?:\.uid)?$'}|ForEach-Object FullName)
 $SourcePaths+=@(Get-ChildItem -LiteralPath (Join-Path $client 'tools/nwn79') -Filter '*.ps1' -File|ForEach-Object FullName)
 $SourcePaths+=@(Get-ChildItem -LiteralPath (Join-Path $client 'tools') -Filter '*.ps1' -File|Where-Object {$_.Name -match '^(?:setup|build-[^\\/]+|ensure-[^\\/]+|resource-index-build-inputs|local-test-guard)\.ps1$'}|ForEach-Object FullName)
 $SourcePaths=@($SourcePaths|Sort-Object -Unique)
 # A clean source stage and delivery package intentionally contain a subset of
 # development launchers. The complete checkout must retain every expected one.
 if(-not$fullWorkspace){$SourcePaths=@($SourcePaths|Where-Object {Test-Path -LiteralPath $_ -PathType Leaf})}
}
$forbidden=@(
 '(?i)\b(?:node|electron)\.exe\b',
 '(?i)\b(?:native-session-host|native-session-bootstrap)\.cjs\b',
 '(?i)\b(?:native-startup|godot-settings-proxy)\.mjs\b',
 '(?i)\b(?:require|import)\s*\(?\s*[\x27\x22]electron[\x27\x22]',
 '(?i)\b(?:from|import)\s*(?:\(\s*)?[\x27\x22](?:electron|three)(?:/[^\x27\x22]*)?[\x27\x22]',
 '(?i)\brequire\s*\(\s*[\x27\x22](?:electron|three)(?:/[^\x27\x22]*)?[\x27\x22]',
 '(?i)<script\b[^>]*\bsrc\s*=\s*[\x27\x22][^\x27\x22]*(?:src/main\.js|electron|three)[^\x27\x22]*[\x27\x22]'
)
$shellForbidden=@(
 '(?i)\b(?:Get-Command|Start-Process)\s+(?:node|electron|npm|npx)\b',
 '(?im)^\s*(?:&\s*)?(?:node|npm|npx)(?=\s|$)'
)
foreach($source in $SourcePaths){
 $absolute=[IO.Path]::GetFullPath($source)
 if(-not$absolute.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw ('Godot-only guard source escaped workspace: '+$absolute)}
 if(-not(Test-Path -LiteralPath $absolute -PathType Leaf)){throw ('Godot-only guard source missing: '+$absolute)}
 $content=[IO.File]::ReadAllText($absolute)
 $patterns=$forbidden
 if($absolute.EndsWith('.ps1',[StringComparison]::OrdinalIgnoreCase)){$patterns=$forbidden+$shellForbidden}
 foreach($pattern in $patterns){if([regex]::IsMatch($content,$pattern)){throw ('Electron/Node/Three runtime reintroduced in '+$absolute)}}
}
if($defaultInventory){
 # The old root index.html booted the preserved Three frontend. Reject that
 # entry while allowing unrelated HTML which has no such executable imports.
 $browserEntries=@(Get-ChildItem -LiteralPath $workspace -Filter '*.html' -File)+@(Get-ChildItem -LiteralPath $client -Filter '*.html' -File)
 foreach($entry in $browserEntries){
  if($entry.Name -eq 'index.html'){throw ('Browser frontend entry reintroduced: '+$entry.FullName)}
  $html=[IO.File]::ReadAllText($entry.FullName)
  foreach($pattern in $forbidden){if([regex]::IsMatch($html,$pattern)){throw ('Electron/Three browser entry reintroduced: '+$entry.FullName)}}
 }
 $tracyWrapperPath=Join-Path $client 'tracy-client.ps1'
 $tracyDirectPath=Join-Path $client 'tools/native-tracy/live/launch.ps1'
 if($fullWorkspace -or (Test-Path -LiteralPath $tracyWrapperPath)){
  $tracyWrapper=[IO.File]::ReadAllText($tracyWrapperPath)
  if(-not$tracyWrapper.Contains("throw 'The legacy Electron Tracy client launcher is retired.") -or $tracyWrapper.Contains('source/launch.ps1')){throw 'Legacy Tracy wrapper can launch cached source'}
 }
 if($fullWorkspace -or (Test-Path -LiteralPath $tracyDirectPath)){
  $tracyDirect=[IO.File]::ReadAllText($tracyDirectPath)
  if(-not$tracyDirect.Contains("throw 'The legacy Electron Tracy launch path is retired.") -or [regex]::IsMatch($tracyDirect,'(?i)ProcessStartInfo|\$tracyConfig\.(?:node|electron)\b')){throw 'Legacy Tracy direct launcher can start Electron'}
 }
 foreach($legacy in @(
  @{path='tools/native-live-review/launch.ps1';marker="throw 'The legacy Electron live-review launcher is retired."},
  @{path='tools/native-render-gap/transport/live/launch.ps1';marker="throw 'The legacy Electron transport live launcher is retired."},
  @{path='tools/native_parity/performance/check_production_local.ps1';marker="throw 'The legacy Electron production-local runner is retired."}
 )){
  $legacyPath=Join-Path $client $legacy.path
  if(-not$fullWorkspace -and -not(Test-Path -LiteralPath $legacyPath)){continue}
  $legacySource=[IO.File]::ReadAllText($legacyPath)
  if(-not$legacySource.Contains($legacy.marker) -or [regex]::IsMatch($legacySource,'(?i)ProcessStartInfo|\$\w+Config\.(?:node|electron)\b|\$inputPlan\.runtimes\.electron|\[Diagnostics\.Process\]::Start|Start-Process')){throw ('Legacy Electron launch branch reintroduced: '+$legacyPath)}
 }
 $projectPath=Join-Path $client 'project.godot'
 if(Test-Path -LiteralPath $projectPath){
  $projectConfig=[IO.File]::ReadAllText($projectPath)
  if([regex]::IsMatch($projectConfig,'(?m)^\s*run/main_scene\s*=')){throw 'Godot project default scene reintroduced; normal launchers must select their own entry'}
 }
 foreach($relative in @('tools/nwn79/stage-clean-source.ps1','tools/nwn79/prepare-clean-restage.ps1','tools/nwn79/build-godot-delivery.ps1')){
  $selectionPath=Join-Path $client $relative
  if(-not(Test-Path -LiteralPath $selectionPath)){continue}
  $selection=[IO.File]::ReadAllText($selectionPath)
  if(-not$selection.Contains('$file.Name -notin @(''main.gd'',''main.gd.uid'')') -or $selection.Contains("'main.tscn'")){throw ('Replay scene entered normal source or delivery selection: '+$relative)}
 }
 $packagePath=Join-Path $workspace 'package.json'
 $lockPath=Join-Path $workspace 'package-lock.json'
 if((Test-Path -LiteralPath $packagePath) -or (Test-Path -LiteralPath $lockPath)){throw 'Root npm package or lockfile reintroduced into Godot-only client workspace'}
 $directPath=Join-Path $client 'join-godot.ps1'
 if(Test-Path -LiteralPath $directPath){
  $direct=[IO.File]::ReadAllText($directPath)
  if(-not$direct.Contains("'--script','res://native_direct_session_world.gd'")){throw 'Normal Godot launcher no longer selects its direct-session script'}
  if(-not$direct.Contains('$engine=$desktop') -or -not$direct.Contains("if(`$Headless){`$arguments=@('--headless')+`$arguments}")){throw 'Headless Godot entry no longer uses the pinned desktop engine with --headless'}
  if($direct.Contains('$engine=if($Headless){$console}')){throw 'Broken Windows console wrapper became the supported headless engine'}
 }
 $ordinaryPath=Join-Path $client 'join-native.ps1'
 $localPath=Join-Path $client 'join-local.ps1'
 if($fullWorkspace -and (-not(Test-Path -LiteralPath $ordinaryPath) -or -not(Test-Path -LiteralPath $localPath))){throw 'Source normal launcher is missing'}
 if(Test-Path -LiteralPath $ordinaryPath){
  $ordinary=[IO.File]::ReadAllText($ordinaryPath)
  $menuBegin=$ordinary.IndexOf('NWN79_GODOT_MENU_CHECK',[StringComparison]::Ordinal)
  $listBegin=$ordinary.IndexOf('if($ListFlags){',[StringComparison]::Ordinal)
  $begin=$ordinary.IndexOf('NWN79_GODOT_NORMAL_ENTRY',[StringComparison]::Ordinal)
  $legacy=$ordinary.IndexOf('NWN79_UNSUPPORTED_DIAGNOSTICS',[StringComparison]::Ordinal)
  if($listBegin -lt 0 -or $menuBegin -le $listBegin -or $begin -le $menuBegin -or $legacy -le $begin){throw 'Godot-only listing, menu and ordinary launchers no longer precede the legacy diagnostic harness'}
  $listBranch=$ordinary.Substring($listBegin,$menuBegin-$listBegin)
  if(-not$listBranch.Contains("throw 'The original ListFlags diagnostic is retired.")){throw 'Retired ListFlags no longer fails before startup'}
  foreach($pattern in $forbidden){if([regex]::IsMatch($listBranch,$pattern)){throw 'Legacy runtime entered the PowerShell-only ListFlags branch'}}
  $menuBranch=$ordinary.Substring($menuBegin,$begin-$menuBegin)
  if(-not$menuBranch.Contains('GraphicalMenuCheck') -or -not$menuBranch.Contains('join-godot.ps1') -or -not$menuBranch.Contains('return')){throw 'Godot-only menu check no longer reaches the Godot fixture'}
  foreach($pattern in $forbidden){if([regex]::IsMatch($menuBranch,$pattern)){throw 'Legacy runtime entered the Godot-only menu check'}}
  $branch=$ordinary.Substring($begin,$legacy-$begin)
  if(-not$branch.Contains("join-godot.ps1") -or -not$branch.Contains('exit 0')){throw 'Godot-only ordinary launcher no longer reaches the Godot entry'}
  foreach($pattern in $forbidden){if([regex]::IsMatch($branch,$pattern)){throw 'Legacy runtime entered the Godot-only ordinary launcher'}}
  if(-not$ordinary.Contains("throw 'Original-host diagnostic flags are retired.")){throw 'Unsupported original-host diagnostics no longer fail before startup'}
 }
 if(Test-Path -LiteralPath $localPath){
  $local=[IO.File]::ReadAllText($localPath)
  $smokeBegin=$local.IndexOf('NWN79_GODOT_LOCAL_SMOKE',[StringComparison]::Ordinal)
  $exitBegin=$local.IndexOf('NWN79_GODOT_MENU_EXIT',[StringComparison]::Ordinal)
  $serverBegin=$local.IndexOf('$root=Split-Path',[StringComparison]::Ordinal)
  if($smokeBegin -lt 0 -or $exitBegin -le $smokeBegin -or $serverBegin -le $exitBegin){throw 'Godot-only local smoke and menu Exit fixtures no longer precede private-server startup'}
  $smokeBranch=$local.Substring($smokeBegin,$exitBegin-$smokeBegin)
  if(-not$smokeBranch.Contains('if($Smoke -and $PSBoundParameters.Count -eq 1)') -or -not$smokeBranch.Contains('run-direct-acceptance-matrix.ps1') -or -not$smokeBranch.Contains('local-smoke-graphical') -or -not$smokeBranch.Contains('return')){throw 'Pure local Smoke no longer reaches the Godot graphical fixture'}
  foreach($pattern in $forbidden){if([regex]::IsMatch($smokeBranch,$pattern)){throw 'Legacy runtime entered the Godot-only local Smoke fixture'}}
  $exitBranch=$local.Substring($exitBegin,$serverBegin-$exitBegin)
  if(-not$exitBranch.Contains('GraphicalMenuExitCheck') -or -not$exitBranch.Contains('join-godot.ps1') -or -not$exitBranch.Contains('return')){throw 'Godot-only menu Exit fixture no longer reaches the Godot entry'}
  foreach($pattern in $forbidden){if([regex]::IsMatch($exitBranch,$pattern)){throw 'Legacy runtime entered the Godot-only menu Exit fixture'}}
  if($local.IndexOf('$unsupportedLocal.Count',[StringComparison]::Ordinal) -lt $exitBegin -or $local.IndexOf('$unsupportedLocal.Count',[StringComparison]::Ordinal) -gt $serverBegin){throw 'Unsupported local diagnostics no longer fail before private-server startup'}
  if(-not$local.Contains('if($NWSyncSmoke -and -not$NWSyncCancel)')){throw 'Retired Node NWSync success smoke became reachable'}
  if(-not$local.Contains('if($NWSyncCancel)')){throw 'Retired Node NWSync Cancel smoke became reachable'}
  if(-not$local.Contains('if($NWSyncFixture)')){throw 'Retired Node NWSync fixture input became reachable'}
  if($local.Contains('--nwsync-smoke') -or $local.Contains('--nwsync-cancel') -or $local.Contains('--nwsync-fixture=')){throw 'Retired Node NWSync flags remain in the legacy host launch'}
  $localBegin=$local.IndexOf('if(-not $diagnosticArguments.Count)',[StringComparison]::Ordinal)
  $localLegacy=$local.IndexOf('NWN79_UNSUPPORTED_LOCAL_DIAGNOSTICS',[StringComparison]::Ordinal)
  if($localBegin -lt 0 -or $localLegacy -le $localBegin){throw 'Godot-only local launcher no longer precedes the legacy diagnostic harness'}
  $localBranch=$local.Substring($localBegin,$localLegacy-$localBegin)
  if(-not$localBranch.Contains('join-native.ps1')){throw 'Godot-only local launcher no longer reaches the normal Godot entry'}
  foreach($pattern in $forbidden){if([regex]::IsMatch($localBranch,$pattern)){throw 'Legacy runtime entered the Godot-only local launcher'}}
 }
 $replayPath=Join-Path $client 'replay-native-loading.ps1'
 if(Test-Path -LiteralPath $replayPath){
  $replay=[IO.File]::ReadAllText($replayPath)
  $verifyBegin=$replay.IndexOf('if($VerifyOnly){',[StringComparison]::Ordinal)
  $legacyBegin=$replay.IndexOf('NWN79_REPLAY_RETIRED',[StringComparison]::Ordinal)
  if($verifyBegin -lt 0 -or $legacyBegin -le $verifyBegin){throw 'PowerShell-only capture verification no longer precedes the legacy replay'}
  $verifyBranch=$replay.Substring($verifyBegin,$legacyBegin-$verifyBegin)
  if(-not$verifyBranch.Contains('verify-native-loading-capture.ps1') -or -not$verifyBranch.Contains('return')){throw 'Read-only capture verification no longer reaches the PowerShell verifier'}
  foreach($pattern in $forbidden){if([regex]::IsMatch($verifyBranch,$pattern)){throw 'Legacy runtime entered the PowerShell-only capture verifier'}}
  if(-not$replay.Contains("throw 'Native loading replay and timing modes are retired.")){throw 'Unsupported loading replay no longer fails before startup'}
 }
 $handoffPath=Join-Path $client 'test-handoff.ps1'
 if(Test-Path -LiteralPath $handoffPath){
  $handoff=[IO.File]::ReadAllText($handoffPath)
  if(-not$handoff.Contains('NWN79_HANDOFF_RETIRED') -or -not$handoff.Contains("throw 'Original-host handoff scenarios are retired.")){throw 'Unsupported handoff launcher no longer fails before startup'}
 }
}
Write-Output ('Godot-only runtime guard PASS ('+$SourcePaths.Count+' files)')
