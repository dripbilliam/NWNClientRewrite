param([string]$PlayerName='',[string]$ProtectedKeyFile='',[string]$Server='',[switch]$LocalOnly,[switch]$MenuCheck,[switch]$LocalCheck,[switch]$ActionCheck,[switch]$CreationCheck,[ValidatePattern('^[a-z0-9_]+$')][string]$CreationClass='fighter',[switch]$NuiCheck,[switch]$EffectsCheck,[switch]$Headless,[switch]$Debugger,[ValidatePattern('^[a-z0-9-]+$')][string]$Run='',[switch]$GdParticles,[ValidateRange(1,8)][int]$LocalCycles=1,[switch]$LocalStreamAbort,[switch]$LocalCancelCheck,[switch]$Profile,[switch]$RangedCheck,[ValidateSet('bow','sling')][string]$RangedWeapon='bow',[switch]$DeflectionCheck,[switch]$MissCheck,[switch]$ParryCheck,[switch]$ShieldCheck,[ValidateSet('small','large','tower')][string]$ShieldKind='small',[switch]$SpecialAttackCheck,[ValidateSet('stun','quivering','ki')][string]$SpecialAttackKind='stun',[switch]$ParticleCrowdCheck,[switch]$CorrectionCheck,[switch]$RadialCheck,[switch]$FeatCheck,[switch]$BarterCheck,[string]$BarterPeerKeyFile='',[switch]$PlayersCheck,[switch]$LobbyPagesCheck,[switch]$LocalVaultCheck,[switch]$LocalDeleteCheck)
$ErrorActionPreference='Stop'
if($PlayersCheck-and(-not$ActionCheck-or-not$BarterCheck)){throw 'Players checks require the owned two-participant action harness'}
if($BarterPeerKeyFile -and (-not $ActionCheck -or (-not $BarterCheck -and -not $LobbyPagesCheck))){throw 'Participant credentials require an isolated two-participant check'}
if($ActionCheck-and($LocalCheck-or$MenuCheck)){throw 'Choose either action or ordinary local checks'}
if($CreationCheck-and($ActionCheck-or$LocalCheck-or$MenuCheck-or$LocalCycles-ne1-or$LocalStreamAbort)){throw 'Creation checks require one isolated local connection'}
if($LocalCycles-ne1-and-not$LocalCheck){throw 'Repeated connection checks require LocalCheck'}
if($LocalStreamAbort-and(-not$LocalCheck-or$LocalCycles-lt2)){throw 'Streaming abort check requires LocalCheck and at least two full cycles'}
if($LocalCancelCheck-and-not$LocalCheck){throw 'Cancel checks require LocalCheck'}
$nativeRoot=Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'tools/build-window-modes.ps1')
if(-not$GdParticles){& (Join-Path $PSScriptRoot 'tools/ensure-particle-kernel.ps1')}
if(-not$Run){$Run='native-session-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}
$nativeStart=[Diagnostics.ProcessStartInfo]::new()
$nativeStart.FileName=Join-Path $nativeRoot 'node_modules/electron/dist/electron.exe'
$nativeStart.WorkingDirectory=$nativeRoot;$nativeStart.UseShellExecute=$false;$nativeStart.CreateNoWindow=$true
$nativeStart.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
$nativeStart.Environment['NWN_PARTICLE_KERNEL']=if($GdParticles){'gd'}else{'compiled'}
$nativeStart.ArgumentList.Add((Join-Path $PSScriptRoot 'tools/native-session-bootstrap.cjs'))
$nativeStart.ArgumentList.Add('--run='+$Run)
if(-not$Headless){
 . (Join-Path $PSScriptRoot 'tools/native-window-screen.ps1')
 $nativeSecondaryScreen=Get-NativeSecondaryScreen
 if($nativeSecondaryScreen-ge0){$nativeStart.ArgumentList.Add('--native-screen='+$nativeSecondaryScreen)}
}
if(-not$LocalOnly-and-not$MenuCheck-and-not$LocalCheck-and-not$ActionCheck-and-not$CreationCheck){$nativeStart.ArgumentList.Add('--public-servers')}
if($PlayerName){$nativeStart.ArgumentList.Add('--player-name='+$PlayerName)}
if($Server){$nativeStart.ArgumentList.Add('--server='+$Server)}
if($MenuCheck){$nativeStart.ArgumentList.Add('--menu-check')}
if($CorrectionCheck){if(-not$ActionCheck){throw 'Correction checks require isolated local action mode'};$nativeStart.ArgumentList.Add('--action-correction-check')}
if($RadialCheck){if(-not$ActionCheck){throw 'Radial checks require isolated local action mode'};$nativeStart.ArgumentList.Add('--action-radial-check')}
if($FeatCheck){if(-not$ActionCheck){throw 'Feat checks require isolated local action mode'};$nativeStart.ArgumentList.Add('--action-feat-check')}
if($BarterCheck){if(-not$ActionCheck){throw 'Barter checks require isolated local action mode'};$nativeStart.ArgumentList.Add('--action-barter-check')}
if($PlayersCheck){$nativeStart.ArgumentList.Add('--action-players-check')}
if($LobbyPagesCheck){if(-not $ActionCheck -or $Headless -or $BarterCheck -or -not $BarterPeerKeyFile){throw 'Lobby page checks require the graphical owned action fixture and a protected participant key'};$nativeStart.ArgumentList.Add('--action-lobby-pages-check')}
if($LocalDeleteCheck){if(-not $LocalVaultCheck -or -not $ActionCheck -or $Headless){throw 'Local Delete requires the graphical owned local-vault check'};$nativeStart.ArgumentList.Add('--action-local-delete-check')}
if($LocalVaultCheck){if(-not$ActionCheck){throw 'Local vault checks require the owned action fixture'};$nativeStart.ArgumentList.Add('--action-local-vault-check')}
if($LocalCheck){$nativeStart.ArgumentList.Add('--local-check')}
if($ActionCheck){$nativeStart.ArgumentList.Add('--action-check')}
if($CreationCheck){$nativeStart.ArgumentList.Add('--creation-check');$nativeStart.ArgumentList.Add('--creation-class='+$CreationClass)}
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
$nativeProcess.WaitForExit()
exit $nativeProcess.ExitCode
