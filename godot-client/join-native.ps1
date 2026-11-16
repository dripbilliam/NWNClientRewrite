# Implicit ordinary gameplay policy is resolved centrally in native-client-flags.
# An implicit editor fallback is not an explicit EngineRuntime choice; explicit
# standard/editor/release and NWN_GODOT_RUNTIME choices remain authoritative.
param([string]$PlayerName='',[string]$ProtectedKeyFile='',[string]$Server='',[switch]$LocalOnly,[switch]$MenuCheck,[switch]$LocalCheck,[switch]$ActionCheck,[switch]$CreationCheck,[ValidatePattern('^[a-z0-9_]+$')][string]$CreationClass='fighter',[ValidateSet('manual','recommended')][string]$CreationPackage='manual',[string]$CreationDirectory='',[ValidateSet(5121,5129)][int]$CreationPort=5121,[string]$CreationReconnectFrom='',[switch]$NuiCheck,[switch]$EffectsCheck,[switch]$Headless,[switch]$Debugger,[ValidatePattern('^[a-z0-9-]+$')][string]$Run='',[switch]$GdParticles,[switch]$SharedParticles,[switch]$ListFlags,[ValidateSet('standard','verified-native')][string]$PerformanceRuntime='standard',[ValidateSet('default','safe','separate')][string]$RenderThread='default',[ValidateSet('legacy','indexed')][string]$DriveCollision='indexed',[ValidateSet('off','worker')][string]$DriveHeightPlan='off',[ValidateSet('off','on')][string]$DrivePreviewHeightIndex='off',[ValidateSet('script','builtin')][string]$LightInputRegistry='script',[ValidateSet('script','workers')][string]$WorldSnapshotPreparation='script',[ValidateSet('on','off')][string]$WorldSnapshotVerifiedPacket='on',[ValidateSet('saved','on','off')][string]$DetailedProfiling='saved',[ValidateSet('gameplay','legacy')][string]$RenderProfile,[ValidateSet('ordinary','streamed','merged')][string]$LoadingPipeline='ordinary',[switch]$SharedAnimationPreparation,[switch]$NativeDrawCache,[ValidateScript({ $_ -cmatch '^[1-9][0-9]{1,3}$' -and [int]$_ -ge 25 -and [int]$_ -le 1024 })][string]$NativeCacheGiB='25',[ValidateRange(1,8)][int]$LocalCycles=1,[switch]$LocalStreamAbort,[switch]$LocalCancelCheck,[switch]$Profile,[switch]$RangedCheck,[ValidateSet('bow','sling')][string]$RangedWeapon='bow',[switch]$DeflectionCheck,[switch]$MissCheck,[switch]$ParryCheck,[switch]$ShieldCheck,[ValidateSet('small','large','tower')][string]$ShieldKind='small',[switch]$SpecialAttackCheck,[ValidateSet('stun','quivering','ki')][string]$SpecialAttackKind='stun',[switch]$ParticleCrowdCheck,[switch]$CorrectionCheck,[switch]$RadialCheck,[switch]$FeatCheck,[switch]$BarterCheck,[string]$BarterPeerKeyFile='',[switch]$PlayersCheck,[switch]$LobbyPagesCheck,[switch]$LocalVaultCheck,[switch]$LocalDeleteCheck,[ValidateSet('standard','wizard','cleric')][string]$RadialCaster='standard',[ValidateSet('editor','release')][string]$EngineRuntime,[ValidateSet('godot','enhanced')][string]$Lighting,[ValidateRange(0,4)][int]$ShadowLights=1,[switch]$QuickbarCheck,[switch]$PolymorphCheck,[switch]$WorldRadialCheck,[switch]$CombatPresentationCheck,[switch]$AssociateRecordCheck,[string]$AssociateRecordDirectory='',[string]$AssociateRecordDistinctAudit='',[switch]$NpcCombatCheck,[string]$NpcCombatDistinctAudit='',[switch]$LevelUpSourceCheck,[ValidateSet('wizard-multiclass','sorcerer-caster','cleric-new-class')][string]$LevelUpSourceCase='wizard-multiclass',[string]$LevelUpSourceDirectory='',[switch]$ScriptFloatingCheck,[string]$ScriptFloatingDirectory='',[switch]$OrdinarySpeechCheck,[switch]$ScriptFloatingVisual,[ValidateRange(30,180)][int]$VisualSeconds=120,[switch]$DirectHandoffCheck,[string]$DirectHandoffDirectory='',[ValidateSet('roundtrip','cancel','failure')][string]$DirectHandoffScenario='roundtrip')
$ErrorActionPreference='Stop'
if($ListFlags){
 throw 'The original ListFlags diagnostic is retired. Normal gameplay uses join-godot.ps1.'
}
# NWN79_GODOT_MENU_CHECK: the ordinary no-server menu fixture is Godot-owned.
$godotMenuAllowed=@('MenuCheck','Run')
if($MenuCheck -and $env:NWN_NATIVE_MENU_EXIT_CHECK -ne '1' -and -not @($PSBoundParameters.Keys|Where-Object {$_ -notin $godotMenuAllowed}).Count){
 $menuRun=if($Run){$Run}else{'nwn79-menu-check-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)}
 $menuReport=Join-Path $PSScriptRoot ('reports/'+$menuRun+'.json')
 if(Test-Path -LiteralPath $menuReport){throw 'Use a fresh Godot menu check run name'}
 $menuScratch=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot ('.cache/nwn79/'+$menuRun)))
 $menuCache=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.cache/nwn79'))
 if(-not$menuScratch.StartsWith($menuCache+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Menu check scratch escaped the private cache'}
 try{
  foreach($name in @('settings','profile','user-data')){New-Item -ItemType Directory -Path (Join-Path $menuScratch $name) -Force|Out-Null}
  . (Join-Path $PSScriptRoot 'tools/native-window-screen.ps1')
  $menuScreen=Get-NativeSecondaryScreen
  $menuLaunch=@{GraphicalMenuCheck=$true;Report=$menuReport;SettingsDirectory=(Join-Path $menuScratch 'settings');Profile=(Join-Path $menuScratch 'profile');UserDataDirectory=(Join-Path $menuScratch 'user-data')}
  if($menuScreen -ge 0){$menuLaunch.UseScreen=$true;$menuLaunch.Screen=$menuScreen}
  & (Join-Path $PSScriptRoot 'join-godot.ps1') @menuLaunch
  $menuReceipt=Get-Content -LiteralPath $menuReport -Raw|ConvertFrom-Json
  $menuState=$menuReceipt.direct_graphical_menu_check
  if($menuReceipt.success -ne $true -or $menuReceipt.clean_exit -ne $true -or $menuReceipt.protocol_finish_ack -ne $true -or $menuState.main_menu_ready -ne $true -or $menuState.main_menu_visible_before_chooser -ne $true -or $menuState.chooser_ready -ne $true -or $menuState.chooser_visible -ne $true -or $menuState.connected -ne $false){throw 'Godot menu/chooser readiness receipt failed'}
  Write-Output ('Godot menu check PASS: '+$menuReport)
 }finally{if(Test-Path -LiteralPath $menuScratch){Remove-Item -LiteralPath $menuScratch -Recurse -Force}}
 return
}
# NWN79_GODOT_NORMAL_ENTRY: ordinary launches use the Godot-owned session.
# Historical diagnostic flags keep their existing harness until their coverage
# is migrated; they are not part of the supported normal client entry.
$godotNormalParameters=@('PlayerName','ProtectedKeyFile','Server','LocalOnly','Headless')
if(-not @($PSBoundParameters.Keys|Where-Object {$_ -notin $godotNormalParameters}).Count){
 if($PlayerName){throw 'Choose the player name in the Godot login profile; PlayerName is not accepted by the Godot-only launcher'}
 if($ProtectedKeyFile){throw 'Choose or re-enter the key in the Godot login profile; ProtectedKeyFile is not accepted by the Godot-only launcher'}
 $hostName='';$portNumber=5121
 if($Server){
  if($Server -notmatch '^([A-Za-z0-9._-]+):([0-9]{1,5})$'){throw 'Server must be a DNS name or IPv4 address followed by a UDP port'}
  $hostName=$Matches[1];$portNumber=[int]$Matches[2]
  if($portNumber -lt 1 -or $portNumber -gt 65535){throw 'Server UDP port is out of range'}
 }
 if($LocalOnly){
  if($hostName -and $hostName -ne '127.0.0.1'){throw 'LocalOnly requires the private loopback server'}
  if(-not$hostName){$hostName='127.0.0.1'}
 }
 if($Headless -and -not$hostName){throw 'Headless normal entry requires an explicit server'}
 $godotArguments=@{}
 if($hostName){$godotArguments.ServerHost=$hostName;$godotArguments.Port=$portNumber}
 if($Headless){$godotArguments.Headless=$true}
 & (Join-Path $PSScriptRoot 'join-godot.ps1') @godotArguments
 exit 0
}
# NWN79_UNSUPPORTED_DIAGNOSTICS: retired original-host options cannot start a Node client.
throw 'Original-host diagnostic flags are retired. Use join-godot.ps1 for gameplay or the Godot/PowerShell NWN-79 fixtures for supported checks.'
