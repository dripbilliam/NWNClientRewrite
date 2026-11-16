param([switch]$WeatherSmoke, [switch]$PortalRegionSmoke, [switch]$Smoke, [switch]$LifecycleSmoke, [switch]$ContentSmoke, [switch]$TransitionSmoke, [switch]$MovementSmoke, [switch]$TextSmoke, [switch]$RadialSmoke, [switch]$BookSmoke, [switch]$CombatSmoke, [switch]$ParticleSmoke, [switch]$VisualModelSmoke, [switch]$VisualDefinitionSmoke, [switch]$VisualSmoke, [switch]$InventorySmoke, [switch]$ShortcutReconnectSmoke, [switch]$FeedbackSmoke, [switch]$CameraSmoke, [switch]$CameraCommandSmoke, [switch]$NWSyncSmoke, [switch]$NWSyncCancel, [string]$NWSyncFixture='', [switch]$ContainerSmoke, [switch]$StoreSmoke, [switch]$CharacterSmoke, [switch]$LevelSmoke, [switch]$RecordsSmoke, [switch]$NuiSmoke, [switch]$NuiActionSmoke, [switch]$NuiReconnectSmoke, [switch]$NuiSkinSmoke, [switch]$NuiPopupSmoke, [switch]$BuffSmoke, [switch]$PartySmoke, [switch]$SettingsSmoke, [switch]$MenuExitSmoke, [switch]$CreationSmoke, [switch]$BuffPreview, [switch]$AutoPlay, [switch]$Headless, [switch]$NativeVerbose, [int]$PreserveOriginalPid=0, [string]$Report='', [switch]$PointVisualSmoke, [switch]$WorldAudioSmoke)
$ErrorActionPreference='Stop'
if($NWSyncSmoke -and -not$NWSyncCancel){
 throw 'The original NWSync success smoke is retired. Run tools/nwn79/run-direct-acceptance-matrix.ps1 -Scenarios nwsync -Run with an isolated output root.'
}
if($NWSyncCancel){throw 'The original NWSync Cancel smoke is retired. Use tools/nwn79/run-direct-acceptance-matrix.ps1 -Scenarios nwsync-cancel for the verified visible native wait Cancel.'}
if($NWSyncFixture){throw 'The original NWSync fixture input is retired; use the Godot-only NWSync acceptance matrix.'}
# NWN79_GODOT_LOCAL_SMOKE: the pure caller keeps its private-server and graphical presentation contract.
if($Smoke -and $PSBoundParameters.Count -eq 1){
 $smokeSettings=Join-Path $env:APPDATA 'nwn-model-viewer-research'
 if(-not(Test-Path -LiteralPath $smokeSettings -PathType Container)){throw 'Godot local smoke needs the current imported settings profile'}
 $smokeOutput=Join-Path (Split-Path $PSScriptRoot -Parent) ('.cache/nwn79-local-smoke-entry-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
 & (Join-Path $PSScriptRoot 'tools/nwn79/run-direct-acceptance-matrix.ps1') -Scenarios local-smoke-graphical -SettingsSource $smokeSettings -OutputRoot $smokeOutput -Run
 $smokeSummary=Get-Content -LiteralPath (Join-Path $smokeOutput 'matrix-summary.json') -Raw|ConvertFrom-Json
 if($smokeSummary.allSelectedPassed -ne $true -or $smokeSummary.results.'local-smoke-graphical'.status -ne 'pass'){throw 'Godot local graphical smoke did not pass its movement and presentation receipt'}
 Write-Output ('Godot local graphical smoke PASS: '+(Join-Path $smokeOutput 'matrix-summary.json'))
 return
}
# NWN79_GODOT_MENU_EXIT: the pure no-server Exit check uses the actual Godot menu control.
if($MenuExitSmoke -and -not @($PSBoundParameters.Keys|Where-Object {$_ -notin @('MenuExitSmoke','Report')}).Count){
 $exitName=if($Report){$Report}else{'nwn79-menu-exit-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)+'.json'}
 if($exitName -notmatch '^[a-z0-9-]+\.json$'){throw 'MenuExitSmoke report must be a simple .json filename'}
 $exitReport=Join-Path $PSScriptRoot ('reports/'+$exitName)
 if(Test-Path -LiteralPath $exitReport){throw 'Use a fresh Godot menu Exit report name'}
 $exitScratch=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot ('.cache/nwn79/'+$exitName.Substring(0,$exitName.Length-5))))
 $exitCache=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.cache/nwn79'))
 if(-not$exitScratch.StartsWith($exitCache+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Menu Exit scratch escaped the private cache'}
 try{
  foreach($name in @('settings','profile','user-data')){New-Item -ItemType Directory -Path (Join-Path $exitScratch $name) -Force|Out-Null}
  . (Join-Path $PSScriptRoot 'tools/native-window-screen.ps1')
  $exitScreen=Get-NativeSecondaryScreen
  $exitLaunch=@{GraphicalMenuExitCheck=$true;Report=$exitReport;SettingsDirectory=(Join-Path $exitScratch 'settings');Profile=(Join-Path $exitScratch 'profile');UserDataDirectory=(Join-Path $exitScratch 'user-data')}
  if($exitScreen -ge 0){$exitLaunch.UseScreen=$true;$exitLaunch.Screen=$exitScreen}
  & (Join-Path $PSScriptRoot 'join-godot.ps1') @exitLaunch
  $exitReceipt=Get-Content -LiteralPath $exitReport -Raw|ConvertFrom-Json
  $exitState=$exitReceipt.direct_menu_exit_check
  if($exitReceipt.success -ne $true -or $exitReceipt.clean_exit -ne $true -or $exitReceipt.protocol_finish_ack -ne $true -or $exitState.success -ne $true -or $exitState.resource -ne 'pre_main' -or $exitState.control -ne 'exitbutton' -or $exitState.via -ne 'pressed-signal' -or $exitState.world_present -ne $false -or $exitState.connected -ne $false -or $exitReceipt.startup_menu.preload.ready -ne $true){throw 'Godot main-menu Exit receipt failed'}
  Write-Output ('Godot menu Exit check PASS: '+$exitReport)
 }finally{if(Test-Path -LiteralPath $exitScratch){Remove-Item -LiteralPath $exitScratch -Recurse -Force}}
 return
}
$unsupportedLocal=@($PSBoundParameters.Keys|Where-Object {$_ -notin @('Headless','NativeVerbose','PreserveOriginalPid')})
if($unsupportedLocal.Count){throw ('Original-host local diagnostic flags are retired: '+($unsupportedLocal -join ', ')+'. Use the Godot/PowerShell NWN-79 fixtures for supported checks.')}
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'tools/local-test-guard.ps1')
Assert-NativeLocalTestAvailable $PSScriptRoot -PreserveOriginalPid $PreserveOriginalPid
$ownedHome=[IO.Path]::GetFullPath((Join-Path $root 'runtime-logs/local-multiplayer-server'))
$installedServer=[IO.Path]::GetFullPath((Join-Path $root '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
$owned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" | Where-Object {$_.ExecutablePath-eq $installedServer -and $_.CommandLine -and $_.CommandLine.Contains('"'+$ownedHome+'"')})
if(-not $owned.Count){& (Join-Path $root 'scripts/local-multiplayer-server.ps1') -Action Start -Port 5121 -Module Prelude}
$deadline=[DateTime]::UtcNow.AddSeconds(30)
do{
 $endpoint=Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue
 if($endpoint){break}
 Start-Sleep -Milliseconds 250
}while([DateTime]::UtcNow-lt $deadline)
if(-not $endpoint){throw 'Owned local server did not open UDP 5121'}
$owned=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" | Where-Object {$_.ExecutablePath-eq $installedServer -and $_.CommandLine -and $_.CommandLine.Contains('"'+$ownedHome+'"')})
if(-not @($owned | Where-Object {$_.ProcessId-in $endpoint.OwningProcess}).Count){throw 'UDP 5121 belongs to another process; it was preserved'}
$diagnosticArguments=@($PSBoundParameters.Keys | Where-Object {$_ -notin @('Headless','NativeVerbose','PreserveOriginalPid')})
if(-not $diagnosticArguments.Count){
 & (Join-Path $PSScriptRoot 'join-native.ps1') -LocalOnly -Server '127.0.0.1:5121' -Headless:$Headless
 exit $LASTEXITCODE
}
# NWN79_UNSUPPORTED_LOCAL_DIAGNOSTICS: no original-host fallback remains.
throw 'Original-host local diagnostics are retired; use the Godot/PowerShell NWN-79 fixtures.'
