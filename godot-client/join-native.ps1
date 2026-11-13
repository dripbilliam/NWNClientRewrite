# Implicit ordinary gameplay policy is resolved centrally in native-client-flags.
# An implicit editor fallback is not an explicit EngineRuntime choice; explicit
# standard/editor/release and NWN_GODOT_RUNTIME choices remain authoritative.
param([string]$PlayerName='',[string]$ProtectedKeyFile='',[string]$Server='',[switch]$LocalOnly,[switch]$MenuCheck,[switch]$LocalCheck,[switch]$ActionCheck,[switch]$CreationCheck,[ValidatePattern('^[a-z0-9_]+$')][string]$CreationClass='fighter',[ValidateSet('manual','recommended')][string]$CreationPackage='manual',[string]$CreationDirectory='',[ValidateSet(5121,5129)][int]$CreationPort=5121,[string]$CreationReconnectFrom='',[switch]$NuiCheck,[switch]$EffectsCheck,[switch]$Headless,[switch]$Debugger,[ValidatePattern('^[a-z0-9-]+$')][string]$Run='',[switch]$GdParticles,[switch]$SharedParticles,[switch]$ListFlags,[ValidateSet('standard','verified-native')][string]$PerformanceRuntime='standard',[ValidateSet('default','safe','separate')][string]$RenderThread='default',[ValidateSet('legacy','indexed')][string]$DriveCollision='indexed',[ValidateSet('script','builtin')][string]$LightInputRegistry='script',[ValidateSet('script','workers')][string]$WorldSnapshotPreparation='script',[ValidateSet('saved','on','off')][string]$DetailedProfiling='saved',[ValidateSet('gameplay','legacy')][string]$RenderProfile,[ValidateSet('ordinary','streamed','merged')][string]$LoadingPipeline='ordinary',[switch]$SharedAnimationPreparation,[switch]$NativeDrawCache,[ValidateScript({ $_ -cmatch '^[1-9][0-9]{1,3}$' -and [int]$_ -ge 25 -and [int]$_ -le 1024 })][string]$NativeCacheGiB='25',[ValidateRange(1,8)][int]$LocalCycles=1,[switch]$LocalStreamAbort,[switch]$LocalCancelCheck,[switch]$Profile,[switch]$RangedCheck,[ValidateSet('bow','sling')][string]$RangedWeapon='bow',[switch]$DeflectionCheck,[switch]$MissCheck,[switch]$ParryCheck,[switch]$ShieldCheck,[ValidateSet('small','large','tower')][string]$ShieldKind='small',[switch]$SpecialAttackCheck,[ValidateSet('stun','quivering','ki')][string]$SpecialAttackKind='stun',[switch]$ParticleCrowdCheck,[switch]$CorrectionCheck,[switch]$RadialCheck,[switch]$FeatCheck,[switch]$BarterCheck,[string]$BarterPeerKeyFile='',[switch]$PlayersCheck,[switch]$LobbyPagesCheck,[switch]$LocalVaultCheck,[switch]$LocalDeleteCheck,[ValidateSet('standard','wizard','cleric')][string]$RadialCaster='standard',[ValidateSet('editor','release')][string]$EngineRuntime,[ValidateSet('godot','enhanced')][string]$Lighting,[ValidateRange(0,4)][int]$ShadowLights=1,[switch]$QuickbarCheck,[switch]$PolymorphCheck,[switch]$WorldRadialCheck,[switch]$CombatPresentationCheck,[switch]$AssociateRecordCheck,[string]$AssociateRecordDirectory='',[string]$AssociateRecordDistinctAudit='',[switch]$NpcCombatCheck,[string]$NpcCombatDistinctAudit='',[switch]$LevelUpSourceCheck,[ValidateSet('wizard-multiclass','sorcerer-caster','cleric-new-class')][string]$LevelUpSourceCase='wizard-multiclass',[string]$LevelUpSourceDirectory='',[switch]$ScriptFloatingCheck,[string]$ScriptFloatingDirectory='',[switch]$OrdinarySpeechCheck,[switch]$ScriptFloatingVisual,[ValidateRange(30,180)][int]$VisualSeconds=120,[switch]$DirectHandoffCheck,[string]$DirectHandoffDirectory='',[ValidateSet('roundtrip','cancel','failure')][string]$DirectHandoffScenario='roundtrip')
$ErrorActionPreference='Stop'
if($ListFlags){& node (Join-Path $PSScriptRoot 'tools/native-client-flags.cjs') --list-flags;if($LASTEXITCODE-ne0){throw 'Client flag listing failed'};return}
if($PSBoundParameters.ContainsKey('NativeCacheGiB')-and-not$NativeDrawCache){throw 'NativeCacheGiB requires NativeDrawCache'}
if($DirectHandoffCheck){
 $directAllowed=@('DirectHandoffCheck','DirectHandoffDirectory','DirectHandoffScenario','Headless','LocalOnly','ProtectedKeyFile','EngineRuntime','Run','Debugger')
 if(-not$Headless-or-not$LocalOnly-or-not$ProtectedKeyFile-or-not$DirectHandoffDirectory-or($EngineRuntime-and$EngineRuntime-ne'editor')-or@($PSBoundParameters.Keys|Where-Object{$_-notin$directAllowed}).Count-or$Run-notmatch'^native-direct-handoff-[a-z0-9-]+$'-or$env:NWN_RECORD_LOADING-eq'1'){throw 'Direct handoff requires its exclusive protected headless local editor check'}
}elseif($DirectHandoffDirectory-or$PSBoundParameters.ContainsKey('DirectHandoffScenario')){throw 'Direct handoff parameters require their explicit check'}
if($OrdinarySpeechCheck-and-not$ScriptFloatingCheck){throw 'Ordinary speech requires the composed ScriptFloating check'}
if($ScriptFloatingVisual){
 $visualAllowed=@('ScriptFloatingVisual','ScriptFloatingDirectory','VisualSeconds','LocalOnly','ProtectedKeyFile','EngineRuntime','Run')
 if($Headless-or-not$LocalOnly-or-not$ProtectedKeyFile-or-not$ScriptFloatingDirectory-or($EngineRuntime-and$EngineRuntime-ne'editor')-or@($PSBoundParameters.Keys|Where-Object{$_-notin$visualAllowed}).Count-or$Run-notmatch'^native-script-floating-[a-z0-9-]+$'-or$env:NWN_RECORD_LOADING-eq'1'){throw 'Visual mode requires its exclusive protected graphical original-local editor route'}
}elseif($PSBoundParameters.ContainsKey('VisualSeconds')){throw 'VisualSeconds requires the distinct visual mode'}
if($ScriptFloatingCheck){
 $floatingAllowedParameters=@('ScriptFloatingCheck','ScriptFloatingDirectory','OrdinarySpeechCheck','Headless','LocalOnly','ProtectedKeyFile','EngineRuntime','Run')
 if(-not$Headless-or-not$LocalOnly-or-not$ProtectedKeyFile-or-not$ScriptFloatingDirectory-or($EngineRuntime-and$EngineRuntime-ne'editor')-or@($PSBoundParameters.Keys|Where-Object{$_-notin$floatingAllowedParameters}).Count){throw 'ScriptFloating requires its exclusive protected headless original-local editor check'}
 if($env:NWN_RECORD_LOADING-eq'1'){throw 'ScriptFloating cannot combine the loading-recording mode'}
}elseif($ScriptFloatingDirectory-and-not$ScriptFloatingVisual){throw 'ScriptFloating directory requires its explicit check'}
if($LevelUpSourceCheck-and(-not$Headless-or-not$LocalOnly-or-not$Debugger-or-not$ProtectedKeyFile-or-not$LevelUpSourceDirectory-or$ActionCheck-or$CreationCheck-or$LocalCheck-or$MenuCheck-or$LocalCycles-ne1-or$LocalStreamAbort-or$LocalCancelCheck-or($EngineRuntime-and$EngineRuntime-ne'editor'))){throw 'Source level-up requires its exclusive protected headless original-local editor check'}
if(-not$LevelUpSourceCheck-and($LevelUpSourceDirectory-or$PSBoundParameters.ContainsKey('LevelUpSourceCase'))){throw 'Source level-up arguments require their explicit check'}
if($LevelUpSourceCheck){
 $sourceAllowedParameters=@('LevelUpSourceCheck','LevelUpSourceCase','LevelUpSourceDirectory','Headless','LocalOnly','Debugger','ProtectedKeyFile','EngineRuntime','Run')
 if(@($PSBoundParameters.Keys|Where-Object{$_-notin$sourceAllowedParameters}).Count){throw 'Source level-up cannot combine unrelated launch or check parameters'}
}
$menuExitCheck=$env:NWN_NATIVE_MENU_EXIT_CHECK-eq'1'
if($menuExitCheck-and-not$MenuCheck){throw 'Native menu Exit check requires the isolated menu check'}
$nativeRuntime=if($EngineRuntime){$EngineRuntime}elseif($env:NWN_GODOT_RUNTIME){$env:NWN_GODOT_RUNTIME}else{'editor'}
if($nativeRuntime-notin@('editor','release')){throw 'Invalid native engine runtime'}
if($LevelUpSourceCheck-and$nativeRuntime-ne'editor'){throw 'Source level-up requires the existing editor engine; no release preparation authorized'}
if(($DirectHandoffCheck-or$ScriptFloatingCheck-or$ScriptFloatingVisual)-and$nativeRuntime-ne'editor'){throw 'ScriptFloating requires the existing editor engine; no release preparation authorized'}
if($PlayersCheck-and(-not$ActionCheck-or-not$BarterCheck)){throw 'Players checks require the owned two-participant action harness'}
if($BarterPeerKeyFile -and (-not $ActionCheck -or (-not $BarterCheck -and -not $LobbyPagesCheck))){throw 'Participant credentials require an isolated two-participant check'}
if($ActionCheck-and($LocalCheck-or$MenuCheck)){throw 'Choose either action or ordinary local checks'}
if($CreationCheck-and($ActionCheck-or$LocalCheck-or$MenuCheck-or$LocalCycles-ne1-or$LocalStreamAbort)){throw 'Creation checks require one isolated local connection'}
if($LocalCycles-ne1-and-not$LocalCheck){throw 'Repeated connection checks require LocalCheck'}
if($LocalStreamAbort-and(-not$LocalCheck-or$LocalCycles-lt2)){throw 'Streaming abort check requires LocalCheck and at least two full cycles'}
if($LocalCancelCheck-and-not$LocalCheck){throw 'Cancel checks require LocalCheck'}
$nativeRoot=Split-Path $PSScriptRoot -Parent
if($DirectHandoffCheck-or$LevelUpSourceCheck-or$ScriptFloatingCheck-or$ScriptFloatingVisual){
 . (Join-Path $PSScriptRoot 'tools/native-level-up-no-build.ps1')
 Assert-NativeLevelUpNoBuild -Root $PSScriptRoot
}else{
 & (Join-Path $PSScriptRoot 'tools/build-window-modes.ps1')
 if(-not$GdParticles){& (Join-Path $PSScriptRoot 'tools/ensure-particle-kernel.ps1')}
 & (Join-Path $PSScriptRoot 'tools/ensure-resource-index.ps1')
}
if(-not$Run){$Run='native-session-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}
$nativeStart=[Diagnostics.ProcessStartInfo]::new()
$nativeStart.FileName=Join-Path $nativeRoot 'node_modules/electron/dist/electron.exe'
$nativeStart.WorkingDirectory=$nativeRoot;$nativeStart.UseShellExecute=$false;$nativeStart.CreateNoWindow=$true
$nativeStart.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
$nativeStart.Environment['NWN_PARTICLE_KERNEL']=if($GdParticles){'gd'}else{'compiled'}
if($Headless){$nativeStart.ArgumentList.Add('--disable-gpu')}
$nativeStart.ArgumentList.Add((Join-Path $PSScriptRoot 'tools/native-session-bootstrap.cjs'))
$nativeStart.ArgumentList.Add('--run='+$Run)
if($PSBoundParameters.ContainsKey('EngineRuntime')-or$env:NWN_GODOT_RUNTIME){$nativeStart.ArgumentList.Add('--native-runtime='+$nativeRuntime)}
if($PSBoundParameters.ContainsKey('PerformanceRuntime')){$nativeStart.ArgumentList.Add('--performance-runtime='+$PerformanceRuntime.ToLowerInvariant())}
if($PSBoundParameters.ContainsKey('RenderThread')){$nativeStart.ArgumentList.Add('--render-thread='+$RenderThread.ToLowerInvariant())}
if($PSBoundParameters.ContainsKey('DriveCollision')){$nativeStart.ArgumentList.Add('--drive-collision='+$DriveCollision.ToLowerInvariant())}
if($PSBoundParameters.ContainsKey('LightInputRegistry')){$nativeStart.ArgumentList.Add('--light-input-registry='+$LightInputRegistry.ToLowerInvariant())}
if($PSBoundParameters.ContainsKey('WorldSnapshotPreparation')){$nativeStart.ArgumentList.Add('--world-snapshot-preparation='+$WorldSnapshotPreparation.ToLowerInvariant())}
if($PSBoundParameters.ContainsKey('DetailedProfiling')){$nativeStart.ArgumentList.Add('--detailed-profiling='+$DetailedProfiling.ToLowerInvariant())}
if($PSBoundParameters.ContainsKey('LoadingPipeline')){$nativeStart.ArgumentList.Add('--loading-pipeline='+$LoadingPipeline.ToLowerInvariant())}
if($SharedAnimationPreparation){$nativeStart.ArgumentList.Add('--shared-animation-preparation=true')}
if($NativeDrawCache){$nativeStart.ArgumentList.Add('--native-draw-cache=prepared')}
if($PSBoundParameters.ContainsKey('NativeCacheGiB')){$nativeStart.ArgumentList.Add('--native-draw-cache-gib='+$NativeCacheGiB)}
if($SharedParticles){$nativeStart.ArgumentList.Add('--particle-presentation=shared');$nativeStart.ArgumentList.Add('--particle-lighting=pooled')}
if($RenderProfile){$nativeStart.ArgumentList.Add('--render-profile='+$RenderProfile)}
elseif($GdParticles){$nativeStart.ArgumentList.Add('--render-profile=legacy')}
if($Lighting){$nativeStart.ArgumentList.Add('--native-lighting='+$Lighting)}
if($PSBoundParameters.ContainsKey('ShadowLights')){$nativeStart.ArgumentList.Add('--native-shadow-lights='+$ShadowLights)}
if($nativeRuntime-eq'release'){$nativePackage=& (Join-Path $PSScriptRoot 'tools/prepare-release-test.ps1');$nativeStart.ArgumentList.Add('--native-runtime-package='+$nativePackage.selection)}
if(-not$Headless){
 . (Join-Path $PSScriptRoot 'tools/native-window-screen.ps1')
 $nativeSecondaryScreen=Get-NativeSecondaryScreen
 if($nativeSecondaryScreen-ge0){$nativeStart.ArgumentList.Add('--native-screen='+$nativeSecondaryScreen)}
}
if(-not$LocalOnly-and-not$MenuCheck-and-not$LocalCheck-and-not$ActionCheck-and-not$CreationCheck){$nativeStart.ArgumentList.Add('--public-servers')}
if($PlayerName){$nativeStart.ArgumentList.Add('--player-name='+$PlayerName)}
if($Server){$nativeStart.ArgumentList.Add('--server='+$Server)}
if($MenuCheck){$nativeStart.ArgumentList.Add('--menu-check')}
if($menuExitCheck){$nativeStart.ArgumentList.Add('--menu-exit-check')}
if($CorrectionCheck){if(-not$ActionCheck){throw 'Correction checks require isolated local action mode'};$nativeStart.ArgumentList.Add('--action-correction-check')}
if($RadialCheck){if(-not$ActionCheck){throw 'Radial checks require isolated local action mode'};$nativeStart.ArgumentList.Add('--action-radial-check')}
if($QuickbarCheck){if(-not$ActionCheck-or-not$Headless){throw 'Quickbar checks require the owned headless local action mode'};$nativeStart.ArgumentList.Add('--action-quickbar-check')}
if($PolymorphCheck){if(-not$ActionCheck-or-not$Headless-or$QuickbarCheck){throw 'Polymorph requires its isolated headless local action mode'};$nativeStart.ArgumentList.Add('--action-polymorph-check')}
if($CombatPresentationCheck){if(-not$ActionCheck-or-not$Headless-or$QuickbarCheck-or$PolymorphCheck-or$WorldRadialCheck){throw 'CombatPresentation requires its isolated headless local action mode'};$nativeStart.ArgumentList.Add('--action-combat-presentation-check')}
if($NpcCombatCheck){if(-not$ActionCheck-or-not$Headless-or$QuickbarCheck-or$PolymorphCheck-or$WorldRadialCheck-or$CombatPresentationCheck-or$AssociateRecordCheck-or-not$NpcCombatDistinctAudit-or-not$ProtectedKeyFile){throw 'NPC combat requires its isolated headless loopback mode and explicit protected participant/audit'};$nativeStart.ArgumentList.Add('--action-npc-combat-check');$nativeStart.ArgumentList.Add('--npc-combat-distinct-audit='+[IO.Path]::GetFullPath($NpcCombatDistinctAudit))}
elseif($NpcCombatDistinctAudit){throw 'NPC combat audit requires its isolated check'}
if($AssociateRecordCheck){if(-not$ActionCheck-or-not$Headless-or$QuickbarCheck-or$PolymorphCheck-or$WorldRadialCheck-or$CombatPresentationCheck-or-not$AssociateRecordDirectory-or-not$AssociateRecordDistinctAudit){throw 'Associate Record requires its isolated owned headless directory'};$nativeStart.ArgumentList.Add('--action-associate-record-check');$nativeStart.ArgumentList.Add('--associate-record-directory='+[IO.Path]::GetFullPath($AssociateRecordDirectory));$nativeStart.ArgumentList.Add('--associate-record-distinct-audit='+[IO.Path]::GetFullPath($AssociateRecordDistinctAudit))}
elseif($AssociateRecordDirectory-or$AssociateRecordDistinctAudit){throw 'Associate Record directory/audit requires its isolated check'}
if($WorldRadialCheck){if(-not$ActionCheck-or-not$Headless-or$QuickbarCheck-or$PolymorphCheck){throw 'WorldRadial requires its isolated headless local action mode'};$nativeStart.ArgumentList.Add('--action-world-radial-check')}
if($RadialCaster-ne'standard'){if(-not$ActionCheck-or-not$RadialCheck){throw 'Radial spell fixtures require owned local radial checks'};$nativeStart.ArgumentList.Add('--radial-caster='+$RadialCaster)}
if($FeatCheck){if(-not$ActionCheck){throw 'Feat checks require isolated local action mode'};$nativeStart.ArgumentList.Add('--action-feat-check')}
if($BarterCheck){if(-not$ActionCheck){throw 'Barter checks require isolated local action mode'};$nativeStart.ArgumentList.Add('--action-barter-check')}
if($PlayersCheck){$nativeStart.ArgumentList.Add('--action-players-check')}
if($LobbyPagesCheck){if(-not $ActionCheck -or $Headless -or $BarterCheck -or -not $BarterPeerKeyFile){throw 'Lobby page checks require the graphical owned action fixture and a protected participant key'};$nativeStart.ArgumentList.Add('--action-lobby-pages-check')}
if($LocalDeleteCheck){if(-not $LocalVaultCheck -or -not $ActionCheck -or $Headless){throw 'Local Delete requires the graphical owned local-vault check'};$nativeStart.ArgumentList.Add('--action-local-delete-check')}
if($LocalVaultCheck){if(-not$ActionCheck){throw 'Local vault checks require the owned action fixture'};$nativeStart.ArgumentList.Add('--action-local-vault-check')}
if($LocalCheck){$nativeStart.ArgumentList.Add('--local-check')}
if($ActionCheck){$nativeStart.ArgumentList.Add('--action-check')}
if($CreationPackage-ne'manual'-and-not$CreationCheck){throw 'Package route requires the isolated creation check'}
if(($CreationDirectory-or$CreationPort-ne5121-or$CreationReconnectFrom)-and(-not$CreationCheck-or-not$CreationDirectory-or$CreationPort-ne5129)){throw 'Vault parameters require the isolated creation check on5129'}
if($LevelUpSourceCheck){$nativeStart.ArgumentList.Add('--level-source-check');$nativeStart.ArgumentList.Add('--level-source-case='+$LevelUpSourceCase);$nativeStart.ArgumentList.Add('--level-source-directory='+[IO.Path]::GetFullPath($LevelUpSourceDirectory))}
if($DirectHandoffCheck){$nativeStart.ArgumentList.Add('--direct-handoff-check');$nativeStart.ArgumentList.Add('--direct-handoff-directory='+[IO.Path]::GetFullPath($DirectHandoffDirectory));$nativeStart.ArgumentList.Add('--direct-handoff-scenario='+$DirectHandoffScenario)}
if($ScriptFloatingCheck){$nativeStart.ArgumentList.Add('--script-floating-check');$nativeStart.ArgumentList.Add('--script-floating-directory='+[IO.Path]::GetFullPath($ScriptFloatingDirectory))}
if($ScriptFloatingVisual){$nativeStart.ArgumentList.Add('--script-floating-visual');$nativeStart.ArgumentList.Add('--script-floating-directory='+[IO.Path]::GetFullPath($ScriptFloatingDirectory));$nativeStart.ArgumentList.Add('--visual-seconds='+$VisualSeconds)}
if($OrdinarySpeechCheck){$nativeStart.ArgumentList.Add('--ordinary-speech-check')}
if($CreationCheck){$nativeStart.ArgumentList.Add('--creation-check');$nativeStart.ArgumentList.Add('--creation-class='+$CreationClass);$nativeStart.ArgumentList.Add('--creation-package='+$CreationPackage);if($CreationDirectory){$nativeStart.ArgumentList.Add('--creation-directory='+[IO.Path]::GetFullPath($CreationDirectory));$nativeStart.ArgumentList.Add('--creation-port=5129')};if($CreationReconnectFrom){$nativeStart.ArgumentList.Add('--creation-reconnect-from='+[IO.Path]::GetFullPath($CreationReconnectFrom))}}
if($NuiCheck){if(-not$ActionCheck){throw 'NUI checks require isolated action mode'};$nativeStart.ArgumentList.Add('--action-nui-check')}
if($EffectsCheck){if(-not$ActionCheck-or$NuiCheck){throw 'Effects checks require isolated action mode'};$nativeStart.ArgumentList.Add('--action-effects-check')}
if($ParticleCrowdCheck){if(-not$EffectsCheck-or-not$Profile){throw 'Particle crowd requires EffectsCheck and Profile'};$nativeStart.ArgumentList.Add('--action-particle-crowd')}
if($RangedCheck){if(-not$ActionCheck-or$NuiCheck-or$EffectsCheck){throw 'Ranged checks require isolated action mode'};$nativeStart.ArgumentList.Add('--action-ranged-check');$nativeStart.ArgumentList.Add('--ranged-weapon='+$RangedWeapon)}
elseif($RangedWeapon-ne'bow'){throw 'Alternate ranged weapon requires an isolated ranged check'}
if($DeflectionCheck){if(-not$RangedCheck-or$RangedWeapon-ne'bow'){throw 'Deflection requires the isolated bow check'};$nativeStart.ArgumentList.Add('--action-deflection-check')}
if($MissCheck){if(-not$RangedCheck-or$RangedWeapon-ne'sling'-or$DeflectionCheck){throw 'Miss scenario requires the isolated sling check'};$nativeStart.ArgumentList.Add('--action-miss-check')}
if($ParryCheck){if(-not$ActionCheck-or$NuiCheck-or$EffectsCheck-or$RangedCheck){throw 'Parry requires one isolated melee check'};$nativeStart.ArgumentList.Add('--action-parry-check')}
if($SpecialAttackCheck){if(-not$ActionCheck-or$NuiCheck-or$EffectsCheck-or$RangedCheck-or$ParryCheck){throw 'Special attacks require one isolated melee check'};$nativeStart.ArgumentList.Add('--action-special-attack-check');$nativeStart.ArgumentList.Add('--special-attack-kind='+$SpecialAttackKind)}
if($ShieldCheck){if(-not$RangedCheck-or$RangedWeapon-ne'bow'-or$DeflectionCheck-or$MissCheck){throw 'Shield requires one isolated bow check'};$nativeStart.ArgumentList.Add('--action-shield-check');$nativeStart.ArgumentList.Add('--shield-kind='+$ShieldKind)}
if($LocalCycles-ne1){$nativeStart.ArgumentList.Add('--local-cycles='+$LocalCycles)}
if($LocalStreamAbort){$nativeStart.ArgumentList.Add('--local-stream-abort')}
if($LocalCancelCheck){$nativeStart.ArgumentList.Add('--local-cancel-check')}
if($Headless){$nativeStart.ArgumentList.Add('--native-headless')}
if($Debugger){$nativeStart.ArgumentList.Add('--native-debugger')}
if($Profile){$nativeStart.ArgumentList.Add('--native-profile')}
if($env:NWN_RECORD_LOADING-eq'1'){$nativeStart.ArgumentList.Add('--record-loading')}
if($ProtectedKeyFile){
 $nativePipeName='nwn-private-login-'+[Guid]::NewGuid().ToString('N')
 $nativeStart.ArgumentList.Add('--private-login-pipe='+$nativePipeName)
 try{
  $nativeSecure=Get-Content -LiteralPath $ProtectedKeyFile -Raw|ConvertTo-SecureString
  $nativePlain=[Net.NetworkCredential]::new('', $nativeSecure).Password
  $nativePayload=@{cdKey=$nativePlain}|ConvertTo-Json -Compress
 }finally{$nativePlain='';if($nativeSecure){$nativeSecure.Dispose()}}
 $nativePipe=[IO.Pipes.NamedPipeServerStream]::new($nativePipeName,[IO.Pipes.PipeDirection]::Out,1,[IO.Pipes.PipeTransmissionMode]::Byte,([IO.Pipes.PipeOptions]::Asynchronous -bor [IO.Pipes.PipeOptions]::CurrentUserOnly))
}
if($BarterPeerKeyFile){
 $barterPipeName='nwn-private-login-'+[Guid]::NewGuid().ToString('N')
 $nativeStart.ArgumentList.Add('--barter-peer-key-pipe='+$barterPipeName)
 try{
  $barterSecure=Get-Content -LiteralPath $BarterPeerKeyFile -Raw|ConvertTo-SecureString
  $barterPlain=[Net.NetworkCredential]::new('', $barterSecure).Password
  $barterPayload=@{cdKey=$barterPlain}|ConvertTo-Json -Compress
 }finally{$barterPlain='';if($barterSecure){$barterSecure.Dispose()}}
 $barterPipe=[IO.Pipes.NamedPipeServerStream]::new($barterPipeName,[IO.Pipes.PipeDirection]::Out,1,[IO.Pipes.PipeTransmissionMode]::Byte,([IO.Pipes.PipeOptions]::Asynchronous -bor [IO.Pipes.PipeOptions]::CurrentUserOnly))
}
$nativeOwnedSeconds=if($DirectHandoffCheck){480}else{360}
$nativeOwnedDeadline=[DateTime]::UtcNow.AddSeconds($nativeOwnedSeconds)
$nativeProcess=$null
try{
$nativeProcess=[Diagnostics.Process]::Start($nativeStart)
if($ProtectedKeyFile){
 try{
  $nativeTimeout=[Threading.CancellationTokenSource]::new(20000)
  $nativePipe.WaitForConnectionAsync($nativeTimeout.Token).GetAwaiter().GetResult()
  $nativeBytes=[Text.Encoding]::UTF8.GetBytes($nativePayload)
  $nativePipe.Write($nativeBytes,0,$nativeBytes.Length)
 }finally{$nativePayload='';if($nativeBytes){[Array]::Clear($nativeBytes,0,$nativeBytes.Length)};$nativePipe.Dispose();if($nativeTimeout){$nativeTimeout.Dispose()}}
}
if($BarterPeerKeyFile){
 try{
  $barterTimeout=[Threading.CancellationTokenSource]::new(20000)
  $barterPipe.WaitForConnectionAsync($barterTimeout.Token).GetAwaiter().GetResult()
  $barterBytes=[Text.Encoding]::UTF8.GetBytes($barterPayload)
  $barterPipe.Write($barterBytes,0,$barterBytes.Length)
 }finally{$barterPayload='';if($barterBytes){[Array]::Clear($barterBytes,0,$barterBytes.Length)};$barterPipe.Dispose();if($barterTimeout){$barterTimeout.Dispose()}}
}
if($DirectHandoffCheck-or$ScriptFloatingCheck-or$ScriptFloatingVisual){
 $nativeRemaining=[Math]::Max(1,[Math]::Min([int]::MaxValue,($nativeOwnedDeadline-[DateTime]::UtcNow).TotalMilliseconds))
 if(-not$nativeProcess.WaitForExit([int]$nativeRemaining)){throw 'Owned native check exceeded its broker deadline; no retry'}
}else{$nativeProcess.WaitForExit()}
$nativeExitCode=$nativeProcess.ExitCode
}finally{
 if(($DirectHandoffCheck-or$ScriptFloatingCheck-or$ScriptFloatingVisual)-and$nativeProcess-and-not$nativeProcess.HasExited){
  $nativeOwned=Get-CimInstance Win32_Process -Filter ('ProcessId='+$nativeProcess.Id)
  if($nativeOwned.ExecutablePath-eq$nativeStart.FileName-and$nativeOwned.CommandLine.Contains((Join-Path $PSScriptRoot 'tools/native-session-bootstrap.cjs'))-and$nativeOwned.CommandLine.Contains('--run='+$Run)-and[Math]::Abs(($nativeOwned.CreationDate.ToUniversalTime()-$nativeProcess.StartTime.ToUniversalTime()).TotalMilliseconds)-lt1000){$nativeProcess.Kill($true);$nativeProcess.WaitForExit(10000)|Out-Null}else{throw 'Owned ScriptFloating broker identity changed; unrelated processes preserved'}
 }
}
exit $nativeExitCode
