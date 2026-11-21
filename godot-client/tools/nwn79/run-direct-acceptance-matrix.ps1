param(
 [string]$ProjectRoot='',
 [string]$Install='',
 [string]$SettingsSource='',
 [string]$OutputRoot='',
 [string]$WorldTextureTargetReport='',
 [ValidateSet('baseline','browser-auth','manual-character','inventory-dialog','reconnect','travel','character-export','local-smoke','local-smoke-graphical','nwsync','nwsync-failure','nwsync-cancel','nwsync-visual-admission','nwsync-visual-graphical','nwsync-world-control','nwsync-world-candidate')][string[]]$Scenarios=@('baseline','browser-auth','manual-character','inventory-dialog','reconnect','travel'),
 [ValidateRange(30,180)][int]$ScenarioTimeoutSeconds=110,
 [switch]$Run
)
$ErrorActionPreference='Stop'
$sourceClient=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Split-Path -Path $sourceClient -Parent
$project=if($ProjectRoot){[IO.Path]::GetFullPath($ProjectRoot)}else{$sourceClient}
$installed=if($Install){[IO.Path]::GetFullPath($Install)}else{[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall'))}
$serverScript=Join-Path $workspace 'scripts/local-multiplayer-server.ps1'
$nwsyncFixtureScript=Join-Path $sourceClient 'tools/nwn79/nwsync-loopback-fixture.ps1'
$serverHome=Join-Path $workspace 'runtime-logs/local-multiplayer-server'
$engine=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'

$matrix=@(
 [ordered]@{id='baseline';module='Prelude';flags=@('--direct-pregen-bic=fighter.bic');proves='Saved-key login, installed resources, local fighter Play, admitted world and clean shutdown'},
 [ordered]@{id='browser-auth';module='Prelude';flags=@('--direct-headless-browser-check=true','--direct-pregen-bic=fighter.bic');proves='Main menu/Direct browser, rejected mismatched profile and malformed temporary key, then authenticated Play'},
 [ordered]@{id='manual-character';module='Prelude';flags=@('--direct-headless-manual-check=true');proves='Original character chooser selects and plays the installed fighter BIC'},
 [ordered]@{id='inventory-dialog';module='Prelude';flags=@('--direct-pregen-bic=fighter.bic','--direct-headless-inventory-check=true','--direct-headless-chat-dialog-check=true');proves='Self-inventory open/page/close requests, received inventory channels, chat echo and NPC dialog'},
 [ordered]@{id='reconnect';module='Prelude';flags=@('--direct-pregen-bic=fighter.bic','--direct-headless-reconnect-check=true');proves='Disconnect retires the world, Direct browser reopens, and a second admitted world is presented'},
 [ordered]@{id='travel';module='GodotBuffs1';flags=@('--direct-pregen-bic=fighter.bic','--direct-headless-travel-check=true');proves='Private-server A→B→A travel with generation changes'},
 [ordered]@{id='character-export';module='Prelude';flags=@('--direct-pregen-bic=fighter.bic','--direct-headless-character-export-check=true');proves='Admitted character Save request, private server 3/10 reply, durable Godot vault list and reopened BIC readback'},
 [ordered]@{id='local-smoke';module='Prelude';flags=@('--direct-pregen-bic=fighter.bic','--direct-headless-local-smoke-check=true');proves='UI waypoint send, server-observed displacement, chat echo, camera follow and controlled actor animation sample/clip witness'},
 [ordered]@{id='local-smoke-graphical';module='Prelude';flags=@('--direct-pregen-bic=fighter.bic','--direct-headless-local-smoke-check=true','--direct-local-smoke-capture=true');proves='Pure legacy Smoke path: UI waypoint, authoritative movement, chat, camera, model-rig walk/run witness and captured graphical world frame'},
 [ordered]@{id='nwsync';module='Prelude';flags=@('--direct-pregen-bic=fighter.bic');proves='Private-server NWSync cold fetch, warm reuse and corrupt-cache repair with Godot admission'},
 [ordered]@{id='nwsync-failure';module='Prelude';flags=@('--direct-pregen-bic=fighter.bic');proves='Godot reports authored NWSync blob HTTP 404 without world admission'},
 [ordered]@{id='nwsync-cancel';module='Prelude';flags=@('--direct-headless-nwsync-cancel-check=true');proves='Real character-lobby Cancel during a pending NWSync manifest request retires session and returns to menu'},
 [ordered]@{id='nwsync-visual-admission';module='GodotFeedback1';flags=@('--direct-pregen-bic=fighter.bic');proves='Private-server thirteen-resource NWSync cold/warm fetch, mounted cache hashes and world admission; UI capture is a separate row'},
 [ordered]@{id='nwsync-visual-graphical';module='GodotFeedback1';flags=@('--direct-pregen-bic=fighter.bic');proves='Private-server thirteen-resource cold graphical world admission and authored TGA overlay frame on secondary screen'},
 [ordered]@{id='nwsync-world-control';module='GodotFeedback1';flags=@('--direct-pregen-bic=fighter.bic','--direct-nwsync-world-material-check=true');proves='No-advertisement control: original dense_a tile ttr01_g01_01 material and graphical world frame'},
 [ordered]@{id='nwsync-world-candidate';module='GodotFeedback1';flags=@('--direct-pregen-bic=fighter.bic','--direct-nwsync-world-material-check=true');proves='Private NWSync replacement of a real dense_a tile bitmap and graphical world frame; compare with control'}
)
if(-not(Test-Path -LiteralPath $project -PathType Container) -or -not(Test-Path -LiteralPath $installed -PathType Container) -or -not(Test-Path -LiteralPath $engine -PathType Leaf) -or -not(Test-Path -LiteralPath $serverScript -PathType Leaf)){throw 'Godot project, installation, pinned engine or owned server script is unavailable'}
if((Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'){throw 'Direct matrix requires the pinned Godot engine'}
if(@($Scenarios|Where-Object {$_ -in @('nwsync-visual-graphical','local-smoke-graphical','nwsync-world-control','nwsync-world-candidate')}).Count){

 . (Join-Path $sourceClient 'tools/native-window-screen.ps1')
 $graphicalScreen=Get-NativeSecondaryScreen
 if($graphicalScreen -lt 0){throw 'Graphical capture needs a secondary screen'}
}
if(-not(Test-Path -LiteralPath (Join-Path $project 'native_direct_session_world.gd') -PathType Leaf)){throw 'Godot direct-world script is unavailable'}
if(Test-Path -LiteralPath (Join-Path $project 'godot-delivery-manifest.json')){& (Join-Path $project 'tools/nwn79/verify-godot-delivery.ps1') -PackageRoot (Split-Path $project -Parent) -Strict | Out-Null}
& (Join-Path $project 'tools/nwn79/check-godot-only.ps1') | Out-Null
$selected=@($matrix | Where-Object {$_.id -in $Scenarios})
if($selected.Count -ne @($Scenarios|Select-Object -Unique).Count){throw 'Unknown or duplicate matrix scenario'}
if(-not$Run){
 [ordered]@{mode='plan-only';project=$project;scenarios=@($selected|ForEach-Object {[ordered]@{id=$_.id;module=$_.module;proves=$_.proves}});credentialImport='pending: first-launch one-time import, marker/backup, second launch without old source and failed-key re-entry are separate credential acceptance';nwsync=if($Scenarios -contains 'nwsync'){'selected: cold/warm/repair using authored PowerShell loopback repository and private-server advertisement'}else{'pending: select the one-entry private-server NWSync scenario'};nwsyncVisual=if($Scenarios -contains 'nwsync-visual-admission'){'selected: thirteen-resource cold/warm private-server admission; graphical progress/texture capture and stale-progress checks remain separate'}else{'pending: select the authored thirteen-resource private-server admission scenario'};alternateContainer='pending: this self-inventory fixture does not exercise server 13/1 alternate-container receipts';liveProfileWrites=0;fpsMeasurements=0}|ConvertTo-Json -Depth 6
 return
}
if(-not$SettingsSource -or -not$OutputRoot){throw 'Live matrix requires SettingsSource and a fresh OutputRoot'}
$settingsSource=[IO.Path]::GetFullPath($SettingsSource)
$output=[IO.Path]::GetFullPath($OutputRoot)
if(-not$output.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($project+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Matrix receipts must be staged inside the workspace but outside the running project'}
if(Test-Path -LiteralPath $output){throw 'Matrix OutputRoot already exists'}
if(-not(Test-Path -LiteralPath (Join-Path $settingsSource 'client-settings.json') -PathType Leaf)){throw 'Saved-key settings source is unavailable'}
$settingsVersion=(Get-Content -LiteralPath (Join-Path $settingsSource 'client-settings.json') -Raw|ConvertFrom-Json).version
if($settingsVersion -ne 3){throw 'Direct matrix requires an already imported Godot version-3 settings store; one-time import is a separate acceptance row'}
$worldTarget=$null
$worldName=''
$worldRows=@($selected|Where-Object {$_.id -in @('nwsync-world-control','nwsync-world-candidate')})
if($worldRows.Count){
 if($worldRows.Count -ne 2){throw 'Ordinary-world NWSync acceptance requires both matched control and candidate'}
 if(-not$WorldTextureTargetReport){throw 'Ordinary-world NWSync acceptance requires the source tile texture target receipt'}
 $targetPath=[IO.Path]::GetFullPath($WorldTextureTargetReport)
 if(-not$targetPath.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not(Test-Path -LiteralPath $targetPath -PathType Leaf)){throw 'World texture target receipt must be an existing workspace file'}
 $worldTarget=Get-Content -LiteralPath $targetPath -Raw|ConvertFrom-Json
 $worldName=[string]$worldTarget.selected.name
 if($worldTarget.format -ne 'nwn79-nwsync-world-texture-target-v1' -or $worldTarget.success -ne $true -or $worldTarget.module -ne 'GodotFeedback1' -or $worldTarget.area -ne 'dense_a' -or $worldTarget.tileModel -ne 'ttr01_g01_01' -or $worldName -cnotmatch '^[a-z0-9_]{1,16}$' -or [int]$worldTarget.selected.indexReferences -lt 3 -or [string]$worldTarget.selected.originalSha256 -cnotmatch '^[0-9a-f]{64}$'){throw 'World texture target receipt does not identify an original rendered dense_a bitmap'}
 if(-not(Get-Content -LiteralPath (Join-Path $project 'native_direct_session_world.gd') -Raw).Contains('direct-nwsync-world-material-check')){throw 'This Godot project lacks the ordinary-world NWSync test hook; use a reviewed source build or a newly sealed package'}
}
$travelSource=Join-Path $sourceClient '.cache/nwn79/travel-profile/nwm/GodotBuffs1.nwm'
$travelTarget=Join-Path $serverHome 'nwm/GodotBuffs1.nwm'
if($selected.id -contains 'travel'){
 if(-not(Test-Path -LiteralPath $travelSource -PathType Leaf) -or -not(Test-Path -LiteralPath $travelTarget -PathType Leaf) -or (Get-FileHash -LiteralPath $travelSource -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $travelTarget -Algorithm SHA256).Hash){throw 'Owned GodotBuffs1 module fixture is missing or changed'}
}

function Require([bool]$condition,[string]$reason){if(-not$condition){throw ('Receipt assertion failed: '+$reason)}}
function Validate-Receipt([string]$id,[string]$path,[int]$exitCode){
 Require (Test-Path -LiteralPath $path -PathType Leaf) "$id report exists"
 $r=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
 if($id -eq 'nwsync-failure'){
  Require ([string]$r.failure -match 'NWSync repository returned HTTP 404' -and [int]$r.received_snapshots -eq 0 -and $r.world.ready -ne $true) 'authored NWSync HTTP 404 rejects admission'
  Require ($r.protocol_finish_ack -eq $true -and $r.direct_status.phase -eq 'closed') 'failed NWSync session releases protocol and world'
  return [ordered]@{status='pass';report=$path;reportSha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();expectedFailure=[string]$r.failure;worldAdmitted=$false;protocolReleased=$true;exitCode=$exitCode}
 }
 if($id -eq 'nwsync-cancel'){
  $cancel=$r.direct_nwsync_cancel
  Require (-not$r.failure -and $cancel.phase_before -eq 'loading-content' -and [int]$cancel.pending_requests_before -ge 1 -and $cancel.listener_started -eq $true -and $cancel.via -eq 'visible-native-wait-cancel-button') 'actual visible native wait Cancel during accepted pending NWSync request'
  Require ($cancel.session_released -eq $true -and $cancel.repository_closed -eq $true -and $cancel.world_retired -eq $true -and $cancel.lobby_phase -eq 'menu' -and [int]$r.received_snapshots -eq 0) 'NWSync Cancel retires session/world and restores menu'
  Require ($r.clean_exit -eq $true -and $r.protocol_finish_ack -eq $true) 'NWSync Cancel clean acknowledged shutdown'
  return [ordered]@{status='pass';report=$path;reportSha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();pendingRequests=[int]$cancel.pending_requests_before;lobbyPhase=$cancel.lobby_phase;sessionReleased=$true;repositoryClosed=$true;worldRetired=$true;cleanExit=$true}
 }
 if($r.failure){throw ("$id reported: "+[string]$r.failure)}
 Require ($exitCode -eq 0) "$id process exit 0"
 Require ($r.success -eq $true -and $r.clean_exit -eq $true -and -not$r.failure -and $r.protocol_finish_ack -eq $true) "$id clean acknowledged shutdown"
 Require ($r.direct_headless_check -and [int]$r.direct_headless_check.snapshots -ge 2 -and [int]$r.direct_headless_check.objects -ge 1 -and [int]$r.direct_headless_check.quickbar -eq 36) "$id admitted world, snapshots and quickbar"
 Require ($r.direct_headless_check.catalog_shared -eq $true -and [int]$r.direct_headless_check.ui_generation -ge 1) "$id shared catalog and UI generation"
 Require ($r.world.ready -eq $true -and [int]$r.received_snapshots -ge 2) "$id renderer world receipt"
 if($id -in @('nwsync-world-control','nwsync-world-candidate')){Require ($null -ne $r.direct_nwsync_world_check) 'ordinary-world NWSync hook receipt exists'}
 switch($id){
  'browser-auth' {Require ($r.direct_browser_check.mismatched_profile_rejected -eq $true -and $r.direct_browser_check.invalid_temporary_key_rejected -eq $true -and $r.direct_browser_check.direct_tab -eq $true) 'Direct browser credential validation'}
  'manual-character' {Require ($r.direct_headless_check.manual_selected -eq $true -and $r.direct_headless_check.manual_played -eq $true) 'manual installed-character selection'}
  'inventory-dialog' {
   $requests=@($r.direct_inventory_check.requests)
   Require ($requests.Count -eq 3 -and $requests[0].kind -eq 'inventory-open' -and $requests[1].kind -eq 'inventory-page' -and $requests[2].kind -eq 'inventory-close' -and @($requests|Where-Object {$_.accepted -ne $true}).Count -eq 0 -and [int]$r.direct_inventory_check.received_inventory_channels -ge 2) 'self-inventory open/page/close and received channels'
   Require ($r.direct_chat_dialog_check.speech_echo -eq $true -and $r.direct_chat_dialog_check.reply_advanced -eq $true -and @($r.direct_chat_dialog_check.events).Count -ge 3) 'chat and dialog roundtrip'
  }
  'reconnect' {Require ($r.direct_reconnect.browser_reopened -eq $true -and $r.direct_reconnect.first_world -and $r.direct_reconnect.second_world -and [int]$r.direct_reconnect.second_world.ui_generation -gt [int]$r.direct_reconnect.first_world.ui_generation) 'second world after reconnect'}
  'travel' {Require ($r.direct_travel_check.returned -eq $true -and [long]$r.direct_travel_check.first_area -ne [long]$r.direct_travel_check.second_area -and [int]$r.direct_travel_check.third_generation -ge 3) 'A→B→A travel generations'}
  'character-export' {
   $export=$r.direct_character_export_check
   Require ($export.requestSent -eq $true -and $export.serverReply -eq $true -and $export.saved -eq $true -and $export.durableReadback -eq $true -and $export.sessionAlive -eq $true) 'private Save Character request, server reply and reopened durable vault readback'
   Require ([int]$export.revision -gt 0 -and [int]$export.bytes -gt 0 -and [string]$export.sha256 -cmatch '^[0-9a-f]{64}$') 'saved character revision, BIC bytes and SHA256'
  }
  {$_ -in @('local-smoke','local-smoke-graphical')} {
   & (Join-Path $sourceClient 'tools/nwn79/verify-local-smoke-receipt.ps1') -Report $path | Out-Null
   if($id -eq 'local-smoke-graphical'){
    $capture=[string]$r.direct_local_smoke_check.visualCapture
    Require ($capture -and (Test-Path -LiteralPath $capture -PathType Leaf)) 'graphical local smoke saved a world frame after movement'
   Require ([long]$r.direct_local_smoke_check.visualArea -eq [long]$r.direct_local_smoke_check.destinationArea -and [int]$r.direct_local_smoke_check.visualGeneration -eq [int]$r.direct_local_smoke_check.destinationGeneration -and [long]$r.direct_local_smoke_check.visualControlled -eq [long]$r.direct_headless_check.controlled) 'graphical local smoke captured the admitted controlled actor area and generation'
    Add-Type -AssemblyName System.Drawing
    $bitmap=[System.Drawing.Bitmap]::new($capture)
    try{
     Require ($bitmap.Width -ge 640 -and $bitmap.Height -ge 480) 'graphical local smoke frame has world viewport extent'
     $different=@($bitmap.GetPixel(20,20),$bitmap.GetPixel([int]($bitmap.Width/2),[int]($bitmap.Height/2)),$bitmap.GetPixel([int]($bitmap.Width-20),[int]($bitmap.Height-20))|ForEach-Object {$_.ToArgb()}|Select-Object -Unique).Count
     Require ($different -ge 2) 'graphical local smoke frame contains rendered scene variation'
    }finally{$bitmap.Dispose()}
   }
  }
  {$_ -in @('nwsync-world-control','nwsync-world-candidate')} {
   $world=$r.direct_nwsync_world_check
   Require ($world.model -eq 'ttr01_g01_01' -and $world.textureName -eq $worldName -and $world.boundMaterial -eq $true -and [long]$world.area -gt 0 -and [int]$world.generation -ge 1 -and $null -ne $world.camera) 'actual dense_a tile material bound the selected original model texture'
   Require ([string]$world.textureSha256 -cmatch '^[0-9a-f]{64}$') 'published tile texture has a source SHA256'
   if($id -eq 'nwsync-world-control'){
    Require ($world.sourceKind -ne 'nwsync' -and [int]$world.textureType -eq [int]$worldTarget.selected.type -and $world.textureSha256 -eq $worldTarget.selected.originalSha256) 'no-advertisement control bound the original installed tile bitmap'
   }else{
    $visual=$r.direct_nwsync_visual_check
    Require ([int]$visual.resourcesVerified -eq 13 -and $visual.iconDecoded -eq $true -and $visual.iconPixel -eq $true -and $visual.worldReady -eq $true) 'world candidate mounted and decoded all thirteen NWSync resources'
    $fixtureDirectory=Join-Path $output ($id+'-http')
    $descriptor=Get-Content -LiteralPath (Join-Path $fixtureDirectory 'descriptor.json') -Raw|ConvertFrom-Json
    $authored=@($descriptor.entries|Where-Object {$_.name -eq $worldName -and [int]$_.type -eq 3})
    Require ($authored.Count -eq 1 -and $descriptor.worldTextureName -eq $worldName) 'world candidate descriptor names the selected tile bitmap'
    $rawPath=Join-Path $fixtureDirectory ('zstd-input/'+[string]$authored[0].hash+'.bin')
    Require (Test-Path -LiteralPath $rawPath -PathType Leaf) 'authored source TGA exists'
    $authoredSha256=(Get-FileHash -LiteralPath $rawPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Require ($world.sourceKind -eq 'nwsync' -and [int]$world.textureType -eq 3 -and $world.textureSha256 -eq $authoredSha256) 'world candidate bound the authored NWSync TGA in its tile material'
   }
   $capture=[string]$world.visualCapture
   Require ($capture -and (Test-Path -LiteralPath $capture -PathType Leaf)) 'ordinary world frame was captured without a fixture overlay'
   Add-Type -AssemblyName System.Drawing
   $bitmap=[System.Drawing.Bitmap]::new($capture)
   try{
    Require ($bitmap.Width -ge 640 -and $bitmap.Height -ge 480) 'ordinary world frame has viewport extent'
    $variation=@($bitmap.GetPixel(20,20),$bitmap.GetPixel([int]($bitmap.Width/2),[int]($bitmap.Height/2)),$bitmap.GetPixel([int]($bitmap.Width-20),[int]($bitmap.Height-20))|ForEach-Object {$_.ToArgb()}|Select-Object -Unique).Count
    Require ($variation -ge 2) 'ordinary world frame contains rendered scene variation'
   }finally{$bitmap.Dispose()}
  }
  {$_ -in @('nwsync-visual-admission','nwsync-visual-graphical')} {
   $visual=$r.direct_nwsync_visual_check
   Require ([int]$visual.resourcesVerified -eq 13 -and $visual.iconDecoded -eq $true -and $visual.iconPixel -eq $true -and $visual.lobbyControlsRetired -eq $true -and $visual.staleProgressIgnored -eq $true -and $visual.settingsUnchanged -eq $true -and $visual.worldReady -eq $true) 'thirteen mounted resources, TGA pixel, retired lobby, ignored stale progress and unchanged settings'
   $content=@($visual.progress|Where-Object {$_.phase -eq 'server-content'})
   Require ($content.Count -ge 1) 'private-server content progress reached Godot lobby'
   if($visual.phase -eq 'cold'){
    Require (@($content|Where-Object {[int]$_.total -eq 13 -and [int]$_.completed -gt 0 -and [int]$_.completed -lt 13}).Count -ge 1 -and @($content|Where-Object {[int]$_.total -eq 13 -and [int]$_.completed -eq 13}).Count -ge 1) 'cold Godot lobby observed intermediate and final thirteen-resource progress'
    Require (@($content|Where-Object {[int]$_.total -eq 13 -and ($_.playGated -ne $true -or $_.cancelVisible -ne $true)}).Count -eq 0) 'cold Godot lobby gated Play and exposed a usable native Cancel'
   }
   if($id -eq 'nwsync-visual-graphical'){
    Require ($visual.visualCapture -and (Test-Path -LiteralPath ([string]$visual.visualCapture) -PathType Leaf)) 'graphical NWSync frame was captured'
    Add-Type -AssemblyName System.Drawing
    $bitmap=[System.Drawing.Bitmap]::new([string]$visual.visualCapture)
    try{
     Require ($bitmap.Width -ge 148 -and $bitmap.Height -ge 148) 'graphical viewport has overlay extent'
     $pixel=$bitmap.GetPixel(24,24)
     Require ($pixel.R -eq 240 -and $pixel.G -eq 170 -and $pixel.B -eq 20) 'authored TGA pixel appears in rendered viewport'
    }finally{$bitmap.Dispose()}
   }
  }
 }
 return [ordered]@{status='pass';report=$path;reportSha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();snapshots=[int]$r.received_snapshots;objects=[int]$r.direct_headless_check.objects;quickbar=[int]$r.direct_headless_check.quickbar;worldReady=[bool]$r.world.ready;cleanExit=[bool]$r.clean_exit;gameplaySuccess=[bool]$r.gameplay_success;visualsComplete=[bool]$r.object_visuals_complete}
}
function Invoke-Direct([System.Collections.IDictionary]$spec,[string]$phase=''){
 $private=Join-Path $output ($spec.id+'-private')
 $settings=Join-Path $private 'settings'
 $profile=Join-Path $private 'profile'
 $userData=Join-Path $private 'user-data'
 $process=$null
 try{
 if(-not$phase -or $phase -eq 'cold'){
  if(Test-Path -LiteralPath $private){throw ('Private matrix scenario directory already exists: '+$private)}
  New-Item -ItemType Directory -Path $settings,$profile,$userData -Force | Out-Null
  foreach($name in @('client-settings.json','Local State')){$source=Join-Path $settingsSource $name;if(Test-Path -LiteralPath $source -PathType Leaf){Copy-Item -LiteralPath $source -Destination (Join-Path $settings $name)}}
 }elseif(-not(Test-Path -LiteralPath $settings -PathType Container) -or -not(Test-Path -LiteralPath $profile -PathType Container) -or -not(Test-Path -LiteralPath $userData -PathType Container)){throw 'Warm NWSync run lacks its owned private profile'}
 $stem=if($phase){$spec.id+'-'+$phase}else{$spec.id}
 $report=Join-Path $output ($stem+'.json')
 $stdout=Join-Path $output ($stem+'.stdout.log')
 $stderr=Join-Path $output ($stem+'.stderr.log')
 $start=[Diagnostics.ProcessStartInfo]::new()
 $graphical=$spec.id -in @('nwsync-visual-graphical','local-smoke-graphical','nwsync-world-control','nwsync-world-candidate')
 $start.FileName=$engine;$start.WorkingDirectory=$project;$start.UseShellExecute=$false;$start.CreateNoWindow=(-not$graphical);$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.Environment['APPDATA']=$userData
 $arguments=@()
 if($graphical){$arguments+=@('--screen',[string]$graphicalScreen)}else{$arguments+='--headless'}
 $arguments+=@('--path',$project,'--script','res://native_direct_session_world.gd','--','--direct-session',('--direct-install='+$installed),('--direct-profile='+$profile),('--direct-settings='+$settings),('--report='+$report),'--direct-headless-check=true')
 if($spec.id -ne 'browser-auth'){$arguments+=@('--direct-host=127.0.0.1','--direct-port=5121')}
 if($spec.id -eq 'nwsync-cancel'){$arguments+=('--direct-nwsync-fixture-ready='+(Join-Path $output 'nwsync-cancel-http/request-starts.log'))}
 if($spec.id -in @('nwsync-visual-admission','nwsync-visual-graphical')){$visualPhase=if($phase){$phase}else{'cold'};$visualDescriptor=(Join-Path $output ($spec.id+'-http/descriptor.json')).Replace([char]92,[char]47);$arguments+=@(('--direct-nwsync-visual-fixture='+$visualDescriptor),('--direct-nwsync-visual-phase='+$visualPhase))}
 if($spec.id -in @('nwsync-world-control','nwsync-world-candidate')){$arguments+=('--direct-nwsync-world-material-name='+$worldName)}
 if($spec.id -eq 'nwsync-world-candidate'){$visualDescriptor=(Join-Path $output ($spec.id+'-http/descriptor.json')).Replace([char]92,[char]47);$arguments+=@(('--direct-nwsync-visual-fixture='+$visualDescriptor),'--direct-nwsync-visual-phase=cold')}
 $arguments+=@($spec.flags)
 if($spec.id -in @('nwsync-visual-admission','nwsync-visual-graphical') -and @($arguments|Where-Object {$_ -like '--direct-nwsync-visual-*'}).Count -ne 2){throw 'Visual NWSync fixture arguments did not stay separate'}
 foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($start)
 if($process -eq $null){throw ('Godot did not start for '+$spec.id)}
  $outputTask=$process.StandardOutput.ReadToEndAsync();$errorTask=$process.StandardError.ReadToEndAsync()
  if(-not$process.WaitForExit($ScenarioTimeoutSeconds*1000)){$process.Kill($true);[void]$process.WaitForExit(10000);throw ('Godot direct scenario timed out: '+$spec.id)}
  if(-not$outputTask.Wait(10000) -or -not$errorTask.Wait(10000)){throw ('Godot output stream did not close: '+$spec.id)}
  [IO.File]::WriteAllText($stdout,$outputTask.Result);[IO.File]::WriteAllText($stderr,$errorTask.Result)
  return Validate-Receipt $spec.id $report $process.ExitCode
 }finally{
  if($process -ne $null){
   if(-not$process.HasExited){$process.Kill($true);[void]$process.WaitForExit(10000)}
   $process.Dispose()
  }
  $private=[IO.Path]::GetFullPath($private)
  if(-not$private.StartsWith($output+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe matrix credential cleanup path'}
  if(-not$phase -and (Test-Path -LiteralPath $private)){Remove-Item -LiteralPath $private -Recurse -Force}
 }
}
function Invoke-NWSyncVisualPreflight([string]$fixtureDirectory){
 $descriptor=(Join-Path $fixtureDirectory 'descriptor.json').Replace([char]92,[char]47)
 Require (Test-Path -LiteralPath $descriptor -PathType Leaf) 'visual descriptor exists before server startup'
 $stem=Split-Path -Path $fixtureDirectory -Leaf
 $report=(Join-Path $output ($stem+'-preflight.json')).Replace([char]92,[char]47)
 $stdout=Join-Path $output ($stem+'-preflight.stdout.log')
 $stderr=Join-Path $output ($stem+'-preflight.stderr.log')
 $userData=Join-Path $output ($stem+'-preflight-user-data')
 New-Item -ItemType Directory -Path $userData -Force|Out-Null
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$engine;$start.WorkingDirectory=$sourceClient;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
 $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.Environment['APPDATA']=$userData
 foreach($argument in @('--headless','--path',$sourceClient,'--script','res://tools/nwn79/nwsync-visual-fixture-check.gd','--',('--descriptor='+$descriptor),('--report='+$report))){$start.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($start)
 if($process -eq $null){throw 'Godot visual fixture preflight did not start'}
 try{
  $outTask=$process.StandardOutput.ReadToEndAsync();$errorTask=$process.StandardError.ReadToEndAsync()
  if(-not$process.WaitForExit(20000)){$process.Kill($true);[void]$process.WaitForExit(10000);throw 'Godot visual fixture preflight timed out'}
  if(-not$outTask.Wait(10000) -or -not$errorTask.Wait(10000)){throw 'Godot visual fixture preflight output did not close'}
  [IO.File]::WriteAllText($stdout,$outTask.Result);[IO.File]::WriteAllText($stderr,$errorTask.Result)
  Require (Test-Path -LiteralPath $report -PathType Leaf) 'Godot opened the exact visual descriptor path'
  $receipt=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
  Require ($process.ExitCode -eq 0 -and $receipt.success -eq $true -and [int]$receipt.manifestEntries -eq 13 -and @($receipt.entries).Count -eq 13 -and $receipt.iconPixel -eq $true) 'Godot decoded exact thirteen-resource authored manifest/blobs/TGA before server startup'
  return $report
 }finally{if(-not$process.HasExited){$process.Kill($true);[void]$process.WaitForExit(10000)};$process.Dispose()}
}
function Invoke-NWSyncRepairProbe([System.Collections.IDictionary]$fixture,[string]$cache){
 $report=Join-Path $output 'nwsync-repair-probe.json'
 $stdout=Join-Path $output 'nwsync-repair-probe.stdout.log'
 $stderr=Join-Path $output 'nwsync-repair-probe.stderr.log'
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$engine;$start.WorkingDirectory=$project;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
 $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 $start.Environment['APPDATA']=Join-Path $output 'nwsync-private/user-data'
 foreach($argument in @('--headless','--path',$project,'--script','res://tools/nwn79/nwsync-cache-repair.gd','--',('--url='+$fixture.url),('--cache='+$cache),('--manifest='+$fixture.manifestHash),('--resource='+$fixture.resourceHash),('--report='+$report))){$start.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($start)
 if($process -eq $null){throw 'Godot NWSync repair probe did not start'}
 try{
  $outTask=$process.StandardOutput.ReadToEndAsync();$errorTask=$process.StandardError.ReadToEndAsync()
  if(-not$process.WaitForExit(30000)){$process.Kill($true);[void]$process.WaitForExit(10000);throw 'Godot NWSync repair probe timed out'}
  if(-not$outTask.Wait(10000) -or -not$errorTask.Wait(10000)){throw 'Godot NWSync repair output did not close'}
  [IO.File]::WriteAllText($stdout,$outTask.Result);[IO.File]::WriteAllText($stderr,$errorTask.Result)
  Require (Test-Path -LiteralPath $report -PathType Leaf) 'Godot NWSync repair receipt exists'
  $receipt=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
  Require ($process.ExitCode -eq 0 -and $receipt.success -eq $true -and $receipt.wasCorrupt -eq $true -and $receipt.blobRefetched -eq $true) ('Godot NWSync repair probe: '+[string]$receipt.error)
  return $report
 }finally{if(-not$process.HasExited){$process.Kill($true);[void]$process.WaitForExit(10000)};$process.Dispose()}
}
function Invoke-NWSyncPhases([System.Collections.IDictionary]$spec,[System.Collections.IDictionary]$fixture){
 $private=[IO.Path]::GetFullPath((Join-Path $output 'nwsync-private'))
 if(-not$private.StartsWith($output+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe private NWSync cleanup path'}
 $cache=Join-Path $private 'profile/replacement-client/server-content'
 $manifestCached=Join-Path $cache ('manifests/'+$fixture.manifestHash)
 $blobCached=Join-Path $cache ('objects/'+$fixture.resourceHash)
 $manifestSource=Join-Path $fixture.directory 'manifest.bin'
 $blobSource=Join-Path $fixture.directory 'blob.bin'
 $requestPath=Join-Path $fixture.directory 'requests.log'
 $manifestRoute='/manifests/'+$fixture.manifestHash+' 200 OK'
 $blobRoute='/data/sha1/'+$fixture.resourceHash.Substring(0,2)+'/'+$fixture.resourceHash.Substring(2,2)+'/'+$fixture.resourceHash+' 200 OK'
 try{
  foreach($phase in @('cold','warm','repair')){
   try{
    if($phase -eq 'repair'){
     Require ((Test-Path -LiteralPath $manifestCached -PathType Leaf) -and (Test-Path -LiteralPath $blobCached -PathType Leaf)) 'private NWSync cache exists before repair'
     [IO.File]::WriteAllText($manifestCached,'corrupt authored manifest')
     [IO.File]::WriteAllText($blobCached,'corrupt authored resource')
    }
    $before=if(Test-Path -LiteralPath $requestPath){@(Get-Content -LiteralPath $requestPath)}else{@()}
    $receipt=Invoke-Direct $spec $phase
    $probeReport=if($phase -eq 'repair'){Invoke-NWSyncRepairProbe $fixture $cache}else{''}
    $after=if(Test-Path -LiteralPath $requestPath){@(Get-Content -LiteralPath $requestPath)}else{@()}
    $newRequests=@($after|Select-Object -Skip $before.Count)
    if($phase -eq 'warm'){Require ($newRequests.Count -eq 0) 'warm NWSync cache avoids all HTTP downloads'}
    else{
     Require (@($newRequests|Where-Object {$_ -eq ($manifestRoute+' complete')}).Count -ge 1) "$phase NWSync manifest download"
     Require (@($newRequests|Where-Object {$_ -eq ($blobRoute+' complete')}).Count -ge 1) "$phase NWSync blob download"
    }
    Require ((Test-Path -LiteralPath $manifestCached -PathType Leaf) -and (Get-FileHash -LiteralPath $manifestCached -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $manifestSource -Algorithm SHA256).Hash) "$phase verified NWSync manifest cache"
    Require ((Test-Path -LiteralPath $blobCached -PathType Leaf) -and (Get-FileHash -LiteralPath $blobCached -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $blobSource -Algorithm SHA256).Hash) "$phase verified NWSync blob cache"
    $receipt.nwsync=[ordered]@{phase=$phase;manifestHash=$fixture.manifestHash;resourceHash=$fixture.resourceHash;newHttpRequests=$newRequests.Count;manifestCached=$true;blobCached=$true;repairProbe=$probeReport}
    $script:nwsyncPhases[$phase]=$receipt
   }catch{
    $script:nwsyncPhases[$phase]=[ordered]@{status='fail';reason=$_.Exception.Message;report=(Join-Path $output ('nwsync-'+$phase+'.json'))}
    throw
   }
  }
  return [ordered]@{status='pass';phases=$script:nwsyncPhases;manifestHash=$fixture.manifestHash;resourceHash=$fixture.resourceHash}
 }finally{if(Test-Path -LiteralPath $private){Remove-Item -LiteralPath $private -Recurse -Force}}
}
function Invoke-NWSyncVisualAdmissionPhases([System.Collections.IDictionary]$spec,[System.Collections.IDictionary]$fixture){
 $private=[IO.Path]::GetFullPath((Join-Path $output 'nwsync-visual-admission-private'))
 if(-not$private.StartsWith($output+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe visual NWSync credential cleanup path'}
 $cache=Join-Path $private 'profile/replacement-client/server-content'
 $manifestCached=Join-Path $cache ('manifests/'+$fixture.manifestHash)
 $manifestSource=Join-Path $fixture.directory 'manifest.bin'
 $requestPath=Join-Path $fixture.directory 'requests.log'
 try{
  foreach($phase in @('cold','warm')){
   try{
    $before=if(Test-Path -LiteralPath $requestPath){@(Get-Content -LiteralPath $requestPath)}else{@()}
    $receipt=Invoke-Direct $spec $phase
    $after=if(Test-Path -LiteralPath $requestPath){@(Get-Content -LiteralPath $requestPath)}else{@()}
    $newRequests=@($after|Select-Object -Skip $before.Count)
    $expected=if($phase -eq 'cold'){14}else{0}
    Require ($newRequests.Count -eq $expected) "$phase thirteen-resource NWSync HTTP request count"
    if($phase -eq 'cold'){
     $routes=@('/manifests/'+$fixture.manifestHash+' 200 OK complete')
     foreach($entry in $fixture.entries){$hash=[string]$entry.hash;$routes+=('/data/sha1/'+$hash.Substring(0,2)+'/'+$hash.Substring(2,2)+'/'+$hash+' 200 OK complete')}
     foreach($route in $routes){Require (@($newRequests|Where-Object {$_ -eq $route}).Count -eq 1) ('Cold authored NWSync route: '+$route)}
    }
    Require ((Test-Path -LiteralPath $manifestCached -PathType Leaf) -and (Get-FileHash -LiteralPath $manifestCached -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $manifestSource -Algorithm SHA256).Hash) "$phase thirteen-resource manifest cache"
    foreach($entry in $fixture.entries){
     $hash=[string]$entry.hash
     $cached=Join-Path $cache ('objects/'+$hash)
     $source=Join-Path $fixture.directory ('blobs/'+$hash+'.bin')
     Require ((Test-Path -LiteralPath $cached -PathType Leaf) -and (Get-FileHash -LiteralPath $cached -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash) ("$phase authored resource cache: "+[string]$entry.name)
    }
    $receipt.nwsyncVisual=[ordered]@{phase=$phase;manifestHash=$fixture.manifestHash;resources=13;newHttpRequests=$newRequests.Count;allCacheBlobsMatched=$true;graphicalCapture='pending'}
    $script:nwsyncVisualPhases[$phase]=$receipt
   }catch{
    $script:nwsyncVisualPhases[$phase]=[ordered]@{status='fail';reason=$_.Exception.Message;report=(Join-Path $output ('nwsync-visual-admission-'+$phase+'.json'))}
    throw
   }
  }
  return [ordered]@{status='pass';scope='Private thirteen-resource NWSync cold/warm admission and exact cached bytes; graphical frame acceptance pending';preflight=$script:nwsyncVisualPreflight;phases=$script:nwsyncVisualPhases;manifestHash=$fixture.manifestHash;resources=13}
 }finally{if(Test-Path -LiteralPath $private){Remove-Item -LiteralPath $private -Recurse -Force}}
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$results=[ordered]@{}
$nwsyncPhases=[ordered]@{}
$nwsyncVisualPhases=[ordered]@{}
$serverStarted=$false
$failure=''
try{
 foreach($spec in $selected){
  $httpProcess=$null
  $nwsyncFixture=$null
  try{
   if($spec.id -like 'nwsync*' -and $spec.id -ne 'nwsync-world-control'){
    $fixtureDirectory=Join-Path $output ($spec.id+'-http')
    $fixtureArgs=@{Directory=$fixtureDirectory;Port=31879;VisualCohort=($spec.id -in @('nwsync-visual-admission','nwsync-visual-graphical','nwsync-world-candidate'))}
    if($spec.id -eq 'nwsync-world-candidate'){$fixtureArgs.WorldTextureName=$worldName}
    & $nwsyncFixtureScript @fixtureArgs | Out-Null
    $descriptor=Get-Content -LiteralPath (Join-Path $fixtureDirectory 'descriptor.json') -Raw|ConvertFrom-Json
    $nwsyncFixture=[ordered]@{directory=$fixtureDirectory;url=$descriptor.url;manifestHash=$descriptor.manifestHash;resourceHash=$descriptor.resourceHash;entries=@($descriptor.entries)}
    if($spec.id -in @('nwsync-visual-admission','nwsync-visual-graphical','nwsync-world-candidate')){$script:nwsyncVisualPreflight=Invoke-NWSyncVisualPreflight $fixtureDirectory}
    if($spec.id -eq 'nwsync-failure'){@{failBlob=$true;delayMilliseconds=0}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $fixtureDirectory 'control.json') -Encoding utf8}
    if($spec.id -eq 'nwsync-cancel'){@{failBlob=$false;delayMilliseconds=5000}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $fixtureDirectory 'control.json') -Encoding utf8}
    $httpStart=[Diagnostics.ProcessStartInfo]::new()
    $httpStart.FileName=(Get-Command pwsh -ErrorAction Stop).Source
    $httpStart.WorkingDirectory=$workspace;$httpStart.UseShellExecute=$false;$httpStart.CreateNoWindow=$true
    foreach($argument in @('-NoProfile','-File',$nwsyncFixtureScript,'-Directory',$fixtureDirectory,'-Port','31879','-Serve')){$httpStart.ArgumentList.Add($argument)}
    $httpProcess=[Diagnostics.Process]::Start($httpStart)
    if($httpProcess -eq $null){throw 'PowerShell NWSync loopback server did not start'}
    $httpDeadline=[DateTime]::UtcNow.AddSeconds(10)
    while(-not(Test-Path -LiteralPath (Join-Path $fixtureDirectory 'ready')) -and -not$httpProcess.HasExited -and [DateTime]::UtcNow -lt $httpDeadline){Start-Sleep -Milliseconds 100}
    if(-not(Test-Path -LiteralPath (Join-Path $fixtureDirectory 'ready'))){throw 'PowerShell NWSync loopback server did not bind'}
    & $serverScript -Action Start -Port 5121 -Module $spec.module -NWSyncUrl $nwsyncFixture.url -NWSyncHash $nwsyncFixture.manifestHash | Out-Null
   }else{& $serverScript -Action Start -Port 5121 -Module $spec.module | Out-Null}
   $serverStarted=$true
   $deadline=[DateTime]::UtcNow.AddSeconds(30)
   while(-not(Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue)){
    if([DateTime]::UtcNow -gt $deadline){throw ('Owned '+$spec.module+' server did not bind UDP 5121')}
    Start-Sleep -Milliseconds 250
   }
   $results[$spec.id]=if($spec.id -eq 'nwsync'){Invoke-NWSyncPhases $spec $nwsyncFixture}elseif($spec.id -eq 'nwsync-visual-admission'){Invoke-NWSyncVisualAdmissionPhases $spec $nwsyncFixture}else{Invoke-Direct $spec}
   if($spec.id -in @('local-smoke','local-smoke-graphical')){$results[$spec.id].animationParity='passed: controlled actor before/after model-rig sample, matching the legacy skin or rigid-clocks witness';$results[$spec.id].legacySmokeRetired=$false}
   if($spec.id -eq 'local-smoke-graphical'){$results[$spec.id].visualCapture=(Get-Content -LiteralPath $results[$spec.id].report -Raw|ConvertFrom-Json).direct_local_smoke_check.visualCapture;$results[$spec.id].screen=$graphicalScreen}
   if($spec.id -eq 'nwsync-failure'){
    $requests=@(Get-Content -LiteralPath (Join-Path $fixtureDirectory 'requests.log'))
    Require (@($requests|Where-Object {$_ -eq ('/manifests/'+$nwsyncFixture.manifestHash+' 200 OK complete')}).Count -ge 1 -and @($requests|Where-Object {$_ -like '/data/sha1/* 404 Not Found complete'}).Count -ge 1) 'authored repository served manifest then rejected blob'
    $results[$spec.id].httpRequests=$requests.Count
   }
   if($spec.id -eq 'nwsync-cancel'){
    $starts=@(Get-Content -LiteralPath (Join-Path $fixtureDirectory 'request-starts.log'))
    Require (@($starts|Where-Object {$_ -eq ('/manifests/'+$nwsyncFixture.manifestHash+' started')}).Count -ge 1) 'delayed manifest request started before real Cancel'
    $results[$spec.id].httpStarts=$starts.Count
   }
   if($spec.id -eq 'nwsync-visual-graphical'){
    $requests=@(Get-Content -LiteralPath (Join-Path $fixtureDirectory 'requests.log'))
    Require ($requests.Count -eq 14) 'graphical cold NWSync requested manifest and thirteen resources exactly once'
    $results[$spec.id].httpRequests=$requests.Count
    $results[$spec.id].visualCapture=(Get-Content -LiteralPath $results[$spec.id].report -Raw|ConvertFrom-Json).direct_nwsync_visual_check.visualCapture
    $results[$spec.id].screen=$graphicalScreen
   }
   if($spec.id -eq 'nwsync-world-candidate'){
    $requests=@(Get-Content -LiteralPath (Join-Path $fixtureDirectory 'requests.log'))
    Require ($requests.Count -eq 14) 'ordinary-world candidate fetched one manifest and thirteen authored resources'
    Require (@($requests|Where-Object {$_ -notlike '* 200 OK complete'}).Count -eq 0) 'ordinary-world candidate completed all loopback HTTP resource reads'
    $results[$spec.id].httpRequests=$requests.Count
   }
  }catch{
   $reason=$_.Exception.Message
   $results[$spec.id]=[ordered]@{status='fail';reason=$reason;report=(Join-Path $output ($spec.id+'.json'))}
   if(-not$failure){$failure=$reason}
  }finally{
   try{if($serverStarted){& $serverScript -Action Stop -Port 5121 | Out-Null;$serverStarted=$false}}
   finally{if($httpProcess -ne $null){if(-not$httpProcess.HasExited){$httpProcess.Kill($true);[void]$httpProcess.WaitForExit(10000)};$httpProcess.Dispose()}}
  }
 }
}catch{
 $failure=$_.Exception.Message
 $current=$spec.id
 if($current -and -not$results.Contains($current)){$results[$current]=[ordered]@{status='fail';reason=$failure}}
}finally{
 if($serverStarted){& $serverScript -Action Stop -Port 5121 | Out-Null;$serverStarted=$false}
 if($worldRows.Count -eq 2 -and $results.Contains('nwsync-world-control') -and $results.Contains('nwsync-world-candidate') -and $results['nwsync-world-control'].status -eq 'pass' -and $results['nwsync-world-candidate'].status -eq 'pass'){
  try{
   $control=(Get-Content -LiteralPath $results['nwsync-world-control'].report -Raw|ConvertFrom-Json).direct_nwsync_world_check
   $candidate=(Get-Content -LiteralPath $results['nwsync-world-candidate'].report -Raw|ConvertFrom-Json).direct_nwsync_world_check
   Require ($control.model -eq $candidate.model -and $control.textureName -eq $candidate.textureName -and [long]$control.area -eq [long]$candidate.area -and [int]$control.generation -eq [int]$candidate.generation) 'world control and candidate used the same tile, bitmap name, area and generation'
   $controlCamera=$control.camera|ConvertTo-Json -Compress -Depth 6
   $candidateCamera=$candidate.camera|ConvertTo-Json -Compress -Depth 6
   Require ($controlCamera -eq $candidateCamera) 'world control and candidate used the same camera pose'
   Require ($control.textureSha256 -ne $candidate.textureSha256 -and $control.sourceKind -ne $candidate.sourceKind) 'world candidate changed the actual tile material source'
   $controlCaptureSha=(Get-FileHash -LiteralPath ([string]$control.visualCapture) -Algorithm SHA256).Hash.ToLowerInvariant()
   $candidateCaptureSha=(Get-FileHash -LiteralPath ([string]$candidate.visualCapture) -Algorithm SHA256).Hash.ToLowerInvariant()
   Require ($controlCaptureSha -ne $candidateCaptureSha) 'ordinary rendered world frame changed with the advertised material'
   $results['nwsync-world-candidate'].matchedControl=[ordered]@{status='pass';textureName=$worldName;controlTextureSha256=[string]$control.textureSha256;candidateTextureSha256=[string]$candidate.textureSha256;controlCaptureSha256=$controlCaptureSha;candidateCaptureSha256=$candidateCaptureSha;sameCamera=$true;sameArea=$true}
  }catch{
   $reason='World-material paired comparison failed: '+$_.Exception.Message
   $results['nwsync-world-candidate'].status='fail'
   $results['nwsync-world-candidate'].reason=$reason
   if(-not$failure){$failure=$reason}
  }
 }
 $nwsyncRow=if($results.Contains('nwsync')){$results['nwsync']}else{[ordered]@{status='pending';reason='Select the private-server NWSync scenario for an end-to-end receipt'}}
 $nwsyncVisualRow=if($results.Contains('nwsync-visual-admission')){$results['nwsync-visual-admission']}else{[ordered]@{status='pending';reason='Select the authored thirteen-resource private-server NWSync scenario'}}
 $summary=[ordered]@{format='nwn79-direct-private-matrix-v1';project=$project;engineSha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant();selected=@($selected|ForEach-Object {$_.id});results=$results;nwsyncPhases=$nwsyncPhases;nwsyncVisualPhases=$nwsyncVisualPhases;credentialImport=[ordered]@{status='pending';reason='First-launch one-time import, marker/backup, second launch without old source, and failed credential re-entry belong to the isolated credential fixture; this matrix consumes an already imported version-3 store'};nwsync=$nwsyncRow;nwsyncVisual=$nwsyncVisualRow;alternateContainer=[ordered]@{status='pending';reason='The self-inventory fixture receives inventory channels but does not emit server 13/1 alternate-container receipts'};publicServer='not-tested';graphicalParity='not-tested';fpsMeasurements=0;liveSettingsWrites=0;allSelectedPassed=($failure -eq '' -and @($results.Values|Where-Object {$_.status -ne 'pass'}).Count -eq 0);nwn79Complete=$false}
 $summaryPath=Join-Path $output 'matrix-summary.json'
 [IO.File]::WriteAllText($summaryPath,($summary|ConvertTo-Json -Depth 9))
 Write-Output ('Direct private matrix receipt: '+$summaryPath)
}
if($failure){throw $failure}
Write-Output 'Godot-only direct private matrix selected scenarios PASS; remaining acceptance rows are recorded in the summary'
