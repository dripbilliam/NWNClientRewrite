param([string]$LedgerPath=(Join-Path $PSScriptRoot 'js-runtime-function-ledger-v1.json'))
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$ledger=[IO.Path]::GetFullPath($LedgerPath)
if(-not$ledger.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Ledger escaped workspace'}
$data=Get-Content -LiteralPath $ledger -Raw | ConvertFrom-Json
$modules=@{}
foreach($path in @('electron/main.cjs','electron/network_ipc.cjs','electron/preload.cjs')){
 $module=@($data.moduleRecords|Where-Object {$_.oldPath -eq $path})
 if($module.Count -ne 1){throw ('Missing Electron ledger module: '+$path)}
 $modules[$path]=$module[0]
}
function Annotate([string]$path,[string]$symbol,[string]$replacement,[string]$caller,[string[]]$evidence,[string]$gap){
 $rows=@($modules[$path].functions|Where-Object {$_.oldSymbol -eq $symbol})
 if($rows.Count -ne 1){throw ('Missing or ambiguous Electron function row: '+$path+'::'+$symbol)}
 $row=$rows[0]
 $row.status='mapped-focused'
 $row.godotReplacement=$replacement
 $row.actualGodotCaller=$caller
 $row.evidence=@($evidence)
 $row.gap=$gap
}
$g='.cache/nwn79-local-visible-20261116-a/summary.json'
$h='.cache/nwn79-local-visible-20261116-a/exit-h-r1.probe.json'
$package='.cache/nwn79-final-ordinary-package-20261116-h-acceptance.json'
Annotate 'electron/main.cjs' 'createWindow' 'godot-client/join-godot.ps1; Godot native window and NativeSessionWorld.open_startup_menu' 'godot-client/join-native.ps1 normal branch -> join-godot.ps1 -> native_live_world.gd::run -> native_direct_session_world.gd::run -> native_session_world.gd::open_startup_menu' @($package,$h) 'Electron BrowserWindow sizing, sandbox and preload mechanics are retired platform APIs; graphical menu/world acceptance covers the normal Godot window, not exact window-option equivalence.'
Annotate 'electron/main.cjs' 'app.ready' 'godot-client/join-godot.ps1; NativeSessionWorld startup' 'join-godot.ps1 launches pinned Godot -> native_live_world.gd::run -> native_direct_session_world.gd::run' @($package,$g) 'Old startup also registered debug, scene capture, prepared-model and IPC services; their individual normal behaviors need separate rows.'
$maps=@(
 @{channel='network:connect';bridge='connect';replacement='NativeDirectSessionWorld.direct_connect/direct_begin_connect; NativeNetworkSession.start';caller='NativeServerBrowser selection -> DirectWorld.direct_connect:230/direct_begin_connect:264 -> Session.start:1013';evidence=@($g);gap='Old IPC trust/error envelope and all endpoint variants are not separately exercised.'},
 @{channel='network:disconnect';bridge='disconnect';replacement='NativeDirectSessionWorld.direct_disconnect; NativeNetworkSession.close';caller='NativeMainMenu Exit -> DirectWorld.direct_disconnect:1158 -> Session.close:1433';evidence=@($h);gap='Old optional save/export-on-close and portal cancellation branches remain separate checks.'},
 @{channel='network:server-characters';bridge='serverCharacters';replacement='NativeNetworkSession 17/2 request; NativeDirectSessionWorld.direct_character_list';caller='Session character-selection phase -> DirectWorld.direct_character_list:1222 -> CharacterLobby.apply_state';evidence=@($g);gap='Old IPC frame-scoped owner envelope is replaced by in-process Session scope; no exact IPC-byte parity claim.'},
 @{channel='network:server-character-preview';bridge='previewServerCharacter';replacement='NativeNetworkSession.request_preview';caller='DirectWorld.lobby_request choose:1430-1439 -> Session.request_preview:938';evidence=@($g);gap='Accepted one local server-vault row; other row/error variants remain pending.'},
 @{channel='network:server-character-play';bridge='playServerCharacter';replacement='NativeNetworkSession.play_character';caller='DirectWorld.lobby_request play:1449-1452 -> Session.play_character:949';evidence=@($g,$h);gap='Accepted local server-vault Play and same-process rejoin; other failure variants pending.'},
 @{channel='network:server-character-create';bridge='createServerCharacter';replacement='NativeNetworkSession.play_local_character(bytes,true)';caller='NativeCreation.begin_build -> DirectWorld.direct_creation_request:1791-1811 -> Session.play_local_character:966';evidence=@($g);gap='One new Fighter/server-vault path accepted; other creator/rules variants pending.'},
 @{channel='network:lobby-exit';bridge='exitApplication';replacement='NativeMainMenu native Exit action; NativeDirectSessionWorld.direct_disconnect';caller='NativeMainMenu Exit button -> DirectWorld.direct_disconnect:1158 -> NativeSessionWorld.open_startup_menu';evidence=@($h);gap='H proves Exit from world to menu and rejoin; original lobby-exit closed the Electron window, while full application quit has separate menu fixture.'},
 @{channel='network:characters';bridge='savedCharacters';replacement='NativeNetworkSession.saved_character_list; NativeCharacterExportVault.list';caller='DirectWorld.direct_character_list:1222 -> Session.saved_character_list:503 -> CharacterLobby.apply_state';evidence=@($g);gap='ServerVault-on roster accepted; exact local-vault listing behavior is a separate branch.'},
 @{channel='network:character';bridge='selectCharacter';replacement='NativeNetworkSession.play_local_character(bytes,false)';caller='DirectWorld.lobby_request local selection:1459 -> Session.play_local_character:966';evidence=@();gap='Local-vault selection and old IPC envelope require caller-level acceptance.'},
 @{channel='network:saved-character-play';bridge='playSavedCharacter';replacement='NativeNetworkSession.play_local_character(bytes,false)';caller='DirectWorld.lobby_request local selection:1459 -> Session.play_local_character:966';evidence=@();gap='Saved local-vault Play and zeroization behavior require direct acceptance.'},
 @{channel='network:character-export';bridge='exportCharacter';replacement='NativeNetworkSession.request_character_export';caller='DirectWorld.lobby_request lobby-export:1417 -> Session.request_character_export:511';evidence=@();gap='Private export B has a separate receipt; exact saved-vault caller and close path not yet attached to this row.'},
 @{channel='network:area-ready';bridge='areaReady';replacement='NativeNetworkSession.area_ready';caller='DirectWorld world admission -> Session.area_ready:1001';evidence=@($g);gap='One local world admission; old IPC generation validation not compared branch by branch.'},
 @{channel='network:settings';bridge='clientSettings';replacement='GodotSettingsBridge.client_setup; ClientSettingsStore.status; ClientSetup.open';caller='NativeMainMenu.client_settings_requested -> NativeSessionWorld.open_client_settings:462 -> ClientSetup.open:53 -> NativeSessionWorld.client_setup_request:451 -> GodotSettingsBridge.client_setup:60';evidence=@('.cache/nwn79-client-setup-menu-20261117-e.json','.cache/nwn79-client-setup-menu-20261117-visual.json');gap='Focused normal-menu source route passes; package I local acceptance and old IPC envelope equivalence remain separate.'},
 @{channel='network:settings-save';bridge='saveClientSettings';replacement='GodotSettingsBridge.client_setup; ClientSettingsStore.update';caller='ClientSetup.save_settings:63 -> NativeSessionWorld.client_setup_request:451 -> GodotSettingsBridge.client_setup:60 -> ClientSettingsStore.update:159';evidence=@('.cache/nwn79-client-setup-menu-20261117-e.json','.cache/nwn79-packaged-credential-recovery-20261116.json');gap='Disposable normal-menu save/reopen passes; package I local acceptance and every settings field remain separate.'},
 @{channel='network:install';bridge='chooseInstall';replacement='NativeInstallSelector.begin/select; ClientSetup.open';caller='NativeSessionWorld startup -> NativeInstallSelector.begin/select -> ClientSetup.open';evidence=@();gap='Physical install chooser cancellation and every precedence branch need caller-level acceptance.'},
 @{channel='network:mods-list';bridge='modsList';replacement='GodotSettingsBridge.client_setup; WorkshopIndex.scan; ClientSetup.receive/render';caller='ClientSetup.scan:59 -> NativeSessionWorld.client_setup_request:451 -> GodotSettingsBridge.client_setup:60 -> WorkshopIndex.scan:11 -> ClientSetup.receive:76';evidence=@('.cache/nwn79-client-setup-menu-20261117-e.json','.cache/nwn79-client-setup-menu-20261117-visual.json');gap='Disposable synthetic Workshop rows pass focused source UI; package I local acceptance and broader installed mods remain separate.'}
)
foreach($map in $maps){
 Annotate 'electron/network_ipc.cjs' ('handle['+$map.channel+']') $map.replacement $map.caller $map.evidence $map.gap
 Annotate 'electron/preload.cjs' ('nativeNetwork.'+$map.bridge) $map.replacement $map.caller $map.evidence ('Bridge method is replaced by direct Godot caller. '+$map.gap)
}
Annotate 'electron/network_ipc.cjs' 'handle[network:mods-folder]' 'ClientSetup FileDialog and scan; GodotSettingsBridge.client_setup' 'NativeMainMenu.client_settings_requested -> NativeSessionWorld.open_client_settings:462 -> ClientSetup FileDialog/scan:25/59 -> GodotSettingsBridge.client_setup:60' @('.cache/nwn79-client-setup-menu-20261117-e.json','.cache/nwn79-client-setup-menu-20261117-visual.json') 'Normal-menu settings source route passes; physical OS folder-dialog selection and package I acceptance remain separate.'
Annotate 'electron/preload.cjs' 'nativeNetwork.chooseModsFolder' 'ClientSetup FileDialog and scan; GodotSettingsBridge.client_setup' 'NativeMainMenu.client_settings_requested -> NativeSessionWorld.open_client_settings:462 -> ClientSetup FileDialog/scan:25/59' @('.cache/nwn79-client-setup-menu-20261117-e.json','.cache/nwn79-client-setup-menu-20261117-visual.json') 'Normal-menu settings source route passes; physical OS folder-dialog selection and package I acceptance remain separate.'
Annotate 'electron/main.cjs' 'chooseMods' 'ClientSetup FileDialog and scan; GodotSettingsBridge.client_setup' 'NativeSessionWorld.open_client_settings:462 -> ClientSetup FileDialog/scan:25/59' @('.cache/nwn79-client-setup-menu-20261117-e.json','.cache/nwn79-client-setup-menu-20261117-visual.json') 'Original Electron dialog is a retired platform API; physical Godot folder-dialog selection and package I acceptance remain separate.'
Annotate 'electron/main.cjs' 'chooseInstall' 'NativeInstallSelector.begin/select' 'native_live_world.gd:315-329 invokes selector only when no valid explicit/remembered/default install exists' @() 'First-run chooser is wired; old in-session install replacement branch needs acceptance and exact UI caller.'
$pendingChannels=@{'network:install'='chooseInstall'}
foreach($entry in $pendingChannels.GetEnumerator()){
 $targets=@(@{path='electron/network_ipc.cjs';symbol=('handle['+$entry.Key+']')},@{path='electron/preload.cjs';symbol=('nativeNetwork.'+$entry.Value)})
 foreach($target in $targets){
  $row=@($modules[$target.path].functions|Where-Object {$_.oldSymbol -eq $target.symbol})
  if($row.Count -ne 1){throw ('Missing settings bridge row: '+$target.path+'::'+$target.symbol)}
  $row[0].status='pending'
  $row[0].gap=([string]$row[0].gap).TrimEnd()+ ' Normal in-app installation replacement, distinct from first-run selection, is not established.'
 }
}
Annotate 'electron/network_ipc.cjs' 'publish' 'NativeNetworkSession signals and NativeDirectSessionWorld scoped signal handlers' 'NativeNetworkSession state/message signals -> NativeDirectSessionWorld direct_phase_changed/direct_lobby_* -> NativeGameplayUI' @($g,$h) 'Old Electron sender-frame/event-envelope filtering is a retired platform mechanism; exact per-event branch coverage remains pending.'
Annotate 'electron/network_ipc.cjs' 'watchSession' 'NativeNetworkSession phase/message/portal signals' 'NativeDirectSessionWorld receives Session signals and direct_portal_handoff:1097-1118' @('.cache/nwn79-portal-live-20261115-170300/portal.json') 'Private 43/2 BIC portal passed; 43/3 reference, failure, timeout and stale-event branches remain pending.'
Annotate 'electron/network_ipc.cjs' 'active' 'NativeNetworkSession connection/generation scope' 'NativeDirectSessionWorld direct_portal_handoff:1097-1118 and direct_disconnect:1158' @($h,'.cache/nwn79-portal-live-20261115-170300/portal.json') 'Old sender-id owner comparison has no one-to-one Godot IPC equivalent; stale portal/connection branches need focused evidence.'
Annotate 'electron/network_ipc.cjs' 'replace' 'NativeNetworkSession.begin_portal/finish_portal; NativeDirectSessionWorld.direct_portal_handoff' 'Session.begin_portal:280/finish_portal:291 -> DirectWorld.direct_portal_handoff:1097-1118 -> direct_connect destination' @('.cache/nwn79-portal-live-20261115-170300/portal.json') 'Private 43/2 BIC portal passed; 43/3 reference and destination failure/timeout parity remain pending.'
Annotate 'electron/network_ipc.cjs' 'disconnect' 'NativeDirectSessionWorld.direct_disconnect; NativeNetworkSession.close' 'NativeMainMenu Exit -> DirectWorld.direct_disconnect:1158 -> Session.close:1433' @($h) 'Optional save/export-on-close, pending portal cancellation and failure handling need separate evidence.'
Annotate 'electron/network_ipc.cjs' 'connect' 'NativeDirectSessionWorld.direct_connect/direct_begin_connect; NativeNetworkSession.start' 'NativeServerBrowser selection -> DirectWorld.direct_connect:230/direct_begin_connect:264 -> Session.start:1013' @($g,$h) 'Old sender/frame validation and every endpoint/key failure variant need separate evidence.'
Annotate 'electron/network_ipc.cjs' 'session' 'NativeNetworkSession connection/generation scope' 'NativeDirectSessionWorld owns current NativeNetworkSession and forwards scoped lobby/gameplay requests' @($g,$h) 'Exact old opaque session-id mismatch/closed rejection cases remain pending.'
function Exclude-Diagnostic([string]$path,[string]$symbol,[int]$line,[string]$reason){
 $row=@($modules[$path].functions|Where-Object {$_.oldSymbol -eq $symbol -and $_.oldLocation -eq ($path+':'+$line)})
 if($row.Count -ne 1){throw ('Missing diagnostic function row: '+$path+'::'+$symbol+'@'+$line)}
 $row[0].status='excluded-diagnostic'
 $row[0].gap=''
 $row[0].godotReplacement='Outside supported normal client operation'
 $row[0].actualGodotCaller='None; old callback executes only under --record-scene'
 $row[0].evidence=@('HEAD:'+ $path+':'+$line,'godot-client/join-native.ps1 normal entry','godot-client/join-godot.ps1 supported flags')
 $row[0]|Add-Member -NotePropertyName acceptanceScope -NotePropertyValue $reason -Force
}
Exclude-Diagnostic 'electron/main.cjs' 'window.page-title-updated' 36 'The callback is nested under if(recording); --record-scene is an obsolete diagnostic entrypoint.'
Exclude-Diagnostic 'electron/main.cjs' 'app.before-quit' 62 'This second before-quit callback exists only to close an opt-in scene capture; ordinary cache disposal at line 60 remains pending.'
$data | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ledger -Encoding utf8
Write-Output ('Electron bootstrap focused mappings: '+(13+($maps.Count*2)))
