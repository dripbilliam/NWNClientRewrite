param([switch]$WeatherSmoke, [switch]$PortalRegionSmoke, [switch]$Smoke, [switch]$LifecycleSmoke, [switch]$ContentSmoke, [switch]$TransitionSmoke, [switch]$MovementSmoke, [switch]$TextSmoke, [switch]$RadialSmoke, [switch]$BookSmoke, [switch]$CombatSmoke, [switch]$ParticleSmoke, [switch]$VisualModelSmoke, [switch]$VisualDefinitionSmoke, [switch]$VisualSmoke, [switch]$InventorySmoke, [switch]$ShortcutReconnectSmoke, [switch]$FeedbackSmoke, [switch]$CameraSmoke, [switch]$CameraCommandSmoke, [switch]$NWSyncSmoke, [switch]$NWSyncCancel, [string]$NWSyncFixture='', [switch]$ContainerSmoke, [switch]$StoreSmoke, [switch]$CharacterSmoke, [switch]$LevelSmoke, [switch]$RecordsSmoke, [switch]$NuiSmoke, [switch]$NuiActionSmoke, [switch]$NuiReconnectSmoke, [switch]$NuiSkinSmoke, [switch]$NuiPopupSmoke, [switch]$BuffSmoke, [switch]$PartySmoke, [switch]$SettingsSmoke, [switch]$MenuExitSmoke, [switch]$CreationSmoke, [switch]$BuffPreview, [switch]$AutoPlay, [switch]$Headless, [switch]$NativeVerbose, [int]$PreserveOriginalPid=0, [string]$Report='', [switch]$PointVisualSmoke, [switch]$WorldAudioSmoke)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'tools/local-test-guard.ps1')
Assert-NativeLocalTestAvailable $PSScriptRoot -PreserveOriginalPid $PreserveOriginalPid
$build=Join-Path $PSScriptRoot '.cache/local-bridge/latest.json'
if(-not (Test-Path -LiteralPath $build)){throw 'Build the bridge first: node godot-client/tools/build-local-bridge.mjs --version=v1'}
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
$electron=Join-Path $root 'node_modules/electron/dist/electron.exe'
$arguments=@((Join-Path $PSScriptRoot 'tools/local-host.cjs'))
if($WeatherSmoke){$arguments+='--weather-smoke'}
if($PortalRegionSmoke){$arguments+='--portal-region-smoke'}
if($Smoke){$arguments+='--smoke'}
if($LifecycleSmoke){$arguments+='--lifecycle-smoke'}
if($ContentSmoke){$arguments+='--content-smoke'}
if($TransitionSmoke){$arguments+='--transition-smoke'}
if($MovementSmoke){$arguments+='--movement-smoke'}
if($TextSmoke){$arguments+='--text-smoke'}
if($RadialSmoke){$arguments+='--radial-smoke'}
if($BookSmoke){$arguments+='--book-smoke'}
if($CombatSmoke){$arguments+='--combat-smoke'}
if($ParticleSmoke){$arguments+='--particle-smoke'}
if($VisualModelSmoke){$arguments+='--visual-model-smoke'}
if($VisualDefinitionSmoke){$arguments+='--visual-definition-smoke'}
if($VisualSmoke){$arguments+='--visual-smoke'}
if($PointVisualSmoke){$arguments+='--point-visual-smoke'}
if($WorldAudioSmoke){$arguments+='--world-audio-smoke'}
if($InventorySmoke){$arguments+='--inventory-smoke'}
if($ShortcutReconnectSmoke){$arguments+='--shortcut-reconnect-smoke'}
if($FeedbackSmoke){$arguments+='--feedback-smoke'}
if($NWSyncCancel){$arguments+='--nwsync-cancel'}
if($CameraSmoke){$arguments+='--camera-smoke'}
if($CameraCommandSmoke){$arguments+='--camera-command-smoke'}
if($NWSyncSmoke){$arguments+='--nwsync-smoke'; if(-not $NWSyncFixture){throw 'Provide the owned NWSync fixture descriptor'}; $arguments+='--nwsync-fixture='+$NWSyncFixture}
if($ContainerSmoke){$arguments+='--container-smoke'}
if($StoreSmoke){$arguments+='--store-smoke'}
if($CharacterSmoke){$arguments+='--character-smoke'}
if($LevelSmoke){$arguments+='--level-smoke'}
if($RecordsSmoke){$arguments+='--records-smoke'}
if($NuiSmoke){$arguments+='--nui-smoke'}
if($NuiActionSmoke){$arguments+='--nui-action-smoke'}
if($NuiReconnectSmoke){$arguments+='--nui-reconnect-smoke'}
if($NuiSkinSmoke){$arguments+='--nui-skin-smoke'}
if($NuiPopupSmoke){$arguments+='--nui-popup-smoke'}
if($BuffSmoke){$arguments+='--buff-smoke'}
if($PartySmoke){$arguments+='--party-smoke'}
if($SettingsSmoke){$arguments+='--settings-smoke'}
if($MenuExitSmoke){$arguments+='--menu-exit-smoke'}
if($CreationSmoke){$arguments+='--creation-smoke'}
if($BuffPreview){$arguments+='--buff-preview'}
if($AutoPlay){$arguments+='--auto-play'}
if($Headless){$arguments+='--native-headless'}
if($NativeVerbose){$arguments+='--native-verbose'}
if($Report){$arguments+='--report='+$Report}
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$electron
$start.WorkingDirectory=$root
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$start.Environment.Remove('ELECTRON_RUN_AS_NODE') | Out-Null
foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
$process=[Diagnostics.Process]::Start($start)
$process.WaitForExit()
exit $process.ExitCode
