[CmdletBinding()]
param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='native-actions-live-v1',[switch]$Nui,[switch]$Effects,[switch]$Ranged,[switch]$Profile,[string]$ProtectedKeyFile='',[ValidateSet('bow','sling')][string]$RangedWeapon='bow',[switch]$Deflection,[switch]$Miss,[switch]$Parry,[switch]$Shield,[ValidateSet('small','large','tower')][string]$ShieldKind='small',[switch]$SpecialAttack,[ValidateSet('stun','quivering','ki')][string]$SpecialAttackKind='stun',[switch]$ParticleCrowd,[switch]$Correction,[switch]$Radial,[switch]$Feat,[switch]$Barter,[string]$BarterPeerKeyFile='',[switch]$Journal,[switch]$Map,[switch]$Players,[switch]$LobbyPages,[switch]$LocalVault,[switch]$LocalDelete)
if($LobbyPages -and ($Players -or $Barter -or $Map -or $Journal -or $Nui -or $Effects -or $Ranged -or $Parry -or $SpecialAttack -or $Correction -or $Radial -or $Feat -or $ParticleCrowd -or -not $BarterPeerKeyFile)){throw 'Lobby page checks require the isolated standard fixture and an explicit protected participant key'}
if($Players){if($Barter-or$Map-or$Journal-or$Nui-or$Effects-or$Ranged-or$Parry-or$SpecialAttack-or$Correction-or$Radial-or$Feat-or$ParticleCrowd){throw 'Players requires its isolated two-participant fixture'};$Barter=$true}
if($Correction-and($Nui-or$Effects-or$Ranged-or$Parry-or$SpecialAttack-or$ParticleCrowd)){throw 'Correction requires one isolated standard action fixture'}
if($Radial-and($Nui-or$Effects-or$Ranged-or$Parry-or$SpecialAttack-or$ParticleCrowd-or$Correction)){throw 'Radial requires the isolated standard action fixture'}
if($Feat-and($Nui-or$Effects-or$Ranged-or$Parry-or$SpecialAttack-or$ParticleCrowd-or$Correction-or$Radial)){throw 'Feat requires the isolated standard action fixture'}
if($ParticleCrowd-and(-not$Effects-or-not$Profile)){throw 'Particle crowd requires Effects and Profile'}
if($Deflection-and(-not$Ranged-or$RangedWeapon-ne'bow')){throw 'Deflection requires the isolated bow test'}
if($Miss-and(-not$Ranged-or$RangedWeapon-ne'sling'-or$Deflection)){throw 'Miss scenario requires the isolated sling test'}
if($Shield-and(-not$Ranged-or$RangedWeapon-ne'bow'-or$Deflection-or$Miss)){throw 'Shield scenario requires the isolated bow test'}
if(($Nui-and$Effects)-or($Ranged-and($Nui-or$Effects))){throw 'Choose one isolated action fixture'}
if($Parry-and($Nui-or$Effects-or$Ranged)){throw 'Parry requires one isolated melee fixture'}
if($SpecialAttack-and($Nui-or$Effects-or$Ranged-or$Parry)){throw 'Special attacks require one isolated melee check'}
$ErrorActionPreference='Stop'
if($LocalDelete -and (-not $LocalVault -or $LobbyPages)){throw 'Local Delete requires the isolated local-vault fixture'}
if($LocalVault -and ($Players -or $Barter -or $Map -or $Journal -or $Nui -or $Effects -or $Ranged -or $Parry -or $SpecialAttack -or $Correction -or $Radial -or $Feat -or $ParticleCrowd)){throw 'LocalVault requires the isolated standard action fixture'}
if($Map-and($Journal-or$Nui-or$Effects-or$Ranged-or$Parry-or$SpecialAttack-or$ParticleCrowd-or$Correction-or$Radial-or$Feat-or$Barter)){throw 'Map requires its isolated owned fixture'}
if($Journal-and($Nui-or$Effects-or$Ranged-or$Parry-or$SpecialAttack-or$ParticleCrowd-or$Correction-or$Radial-or$Feat-or$Barter)){throw 'Journal requires its isolated owned fixture'}
if($Barter-and($Nui-or$Effects-or$Ranged-or$Parry-or$SpecialAttack-or$Correction-or$Radial-or$Feat)){throw 'Barter requires an isolated two-participant fixture'}
$actionsWorkspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if($Barter-and-not$BarterPeerKeyFile){
 $BarterPeerKeyFile=Join-Path $actionsWorkspace 'runtime-logs/local-multiplayer-server/native-test-key.dpapi'
 if(-not(Test-Path -LiteralPath $BarterPeerKeyFile)){throw 'A protected second-participant key file is required for the owned barter check'}
}
$actionsHome=Join-Path $actionsWorkspace 'runtime-logs/native-playability-actions-server'
$actionsServer=[IO.Path]::GetFullPath((Join-Path $actionsWorkspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
if((Get-FileHash -LiteralPath $actionsServer).Hash-ne'98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6'){throw 'Unexpected original server executable'}
if(Get-NetUDPEndpoint -LocalPort 5125 -ErrorAction SilentlyContinue){throw 'Test port 5125 is occupied; existing session preserved'}
$actionsArgs=@((Join-Path $PSScriptRoot 'native-actions-fixture.mjs'));if($Nui){$actionsArgs+='--nui'}
if($Journal){$actionsArgs+='--journal'}
if($Map){$actionsArgs+='--map'}
if($Players){$actionsArgs+='--players'}
if(-not($Nui-or$Effects-or$Ranged-or$Parry-or$SpecialAttack-or$ParticleCrowd-or$Correction-or$Radial-or$Feat-or$Barter)){$actionsArgs+='--identify'}
if($Correction){$actionsArgs+='--correction'}
if($Effects){$actionsArgs+='--effects'}
if($ParticleCrowd){$actionsArgs+='--particle-crowd'}
if($Ranged){$actionsArgs+='--ranged'}
if($Deflection){$actionsArgs+='--deflection'}
if($Miss){$actionsArgs+='--miss'}
if($Parry){$actionsArgs+='--parry'}
if($Shield){$actionsArgs+=@('--shield',('--shield-kind='+$ShieldKind))}
if($SpecialAttack){$actionsArgs+='--special-attack'}
node @actionsArgs
$actionsFixture=Get-Content (Join-Path $actionsHome 'fixture.json') -Raw|ConvertFrom-Json
if($LASTEXITCODE-ne0){throw 'Authored fixture preparation failed'}
$actionsPrior=[Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','Process')
try{
 [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','1','Process')
 $actionsPartyOptions=if($Players){@('-oneparty','0')}else{@()}
 $actionsProcess=Start-Process -FilePath $actionsServer -WorkingDirectory (Split-Path $actionsServer) -ArgumentList (@('-userdirectory',('"'+$actionsHome+'"'),'-port','5125','-publicserver','0','-servername','"Native Godot action tests"','-maxclients','2','-servervault','0','-autosaveinterval','0','-module',$actionsFixture.module)+$actionsPartyOptions) -WindowStyle Hidden -PassThru
}finally{[Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH',$actionsPrior,'Process')}
$actionsDeleteFiles=@()
$actionsVaultFile=$null
try{
 $actionsDeadline=[DateTime]::UtcNow.AddSeconds(20)
 do{$actionsEndpoint=Get-NetUDPEndpoint -LocalPort 5125 -ErrorAction SilentlyContinue;if($actionsEndpoint){break};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow-lt$actionsDeadline)
 if(-not$actionsEndpoint-or$actionsEndpoint.OwningProcess-notcontains$actionsProcess.Id){throw 'Isolated server did not bind its requested loopback test port'}
 if($LocalVault){
  $actionsVaultDirectory=Join-Path $actionsHome 'client/localvault'
  New-Item -ItemType Directory -Path $actionsVaultDirectory -Force|Out-Null
  $actionsVaultCandidate=[IO.Path]::GetFullPath((Join-Path $actionsVaultDirectory 'nwn_local_ui.bic'))
  if(-not$actionsVaultCandidate.StartsWith([IO.Path]::GetFullPath($actionsHome)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Owned vault fixture escapes the action workspace'}
  if(Test-Path -LiteralPath $actionsVaultCandidate){throw 'Owned vault fixture already exists; existing data preserved'}
  $actionsVaultOriginal=Join-Path (Split-Path (Split-Path (Split-Path $actionsServer))) 'data/lcv/wizard.bic'
  [IO.File]::Copy($actionsVaultOriginal,$actionsVaultCandidate,$false)
  $actionsVaultFile=$actionsVaultCandidate
  $actionsVaultHash=(Get-FileHash -LiteralPath $actionsVaultFile).Hash
  if($LocalDelete){foreach($stem in @('nwn_delete_a','nwn_delete_b')){
   $candidate=Join-Path $actionsVaultDirectory ($stem+'.bic')
   if(Test-Path -LiteralPath $candidate){throw 'Owned deletion fixture already exists; preserved'}
   [IO.File]::Copy($actionsVaultOriginal,$candidate,$false);$actionsDeleteFiles+=@{path=$candidate;sha256=$actionsVaultHash}
  }}
 }
 & (Join-Path $PSScriptRoot '../join-native.ps1') -ActionCheck -LocalDeleteCheck:$LocalDelete -LocalVaultCheck:$LocalVault -LobbyPagesCheck:$LobbyPages -PlayersCheck:$Players -BarterCheck:$Barter -BarterPeerKeyFile $BarterPeerKeyFile -FeatCheck:$Feat -RadialCheck:$Radial -CorrectionCheck:$Correction -ParticleCrowdCheck:$ParticleCrowd -NuiCheck:$Nui -EffectsCheck:$Effects -RangedCheck:$Ranged -RangedWeapon $RangedWeapon -DeflectionCheck:$Deflection -MissCheck:$Miss -ParryCheck:$Parry -ShieldCheck:$Shield -ShieldKind $ShieldKind -SpecialAttackCheck:$SpecialAttack -SpecialAttackKind $SpecialAttackKind -Profile:$Profile -Debugger -Run $Run -ProtectedKeyFile $ProtectedKeyFile
 $actionsExit=$LASTEXITCODE
 if($Feat-and$actionsExit-eq0){
  $actionsFeatProof=Get-Content -LiteralPath (Join-Path $actionsWorkspace "godot-client/reports/$Run.json") -Raw|ConvertFrom-Json
  $actionsFeatChecks=@($actionsFeatProof.actions.checks|Where-Object {$_.label-in@('Server receives the signed variant shortcut and changes the character shape','Shaped native locomotion keeps cycling past one original clip length')})
  if($actionsFeatChecks.Count-ne2-or@($actionsFeatChecks|Where-Object {-not$_.passed}).Count){throw 'Authoritative feat variant and shaped locomotion proofs were not reached'}
 }
 if($Radial-and$actionsExit-eq0){
  $actionsRadialProof=Get-Content -LiteralPath (Join-Path $actionsWorkspace "godot-client/reports/$Run.json") -Raw|ConvertFrom-Json
  $actionsRadialCheck=@($actionsRadialProof.actions.checks|Where-Object {$_.label-eq'Native radial spell click consumes an authoritative prepared use'})
  if($actionsRadialCheck.Count-ne1-or-not$actionsRadialCheck[0].passed){throw 'Authoritative radial spell action proof was not reached'}
 }
 if($Correction-and$actionsExit-eq0){
  $actionsCorrectionProof=Get-Content -LiteralPath (Join-Path $actionsWorkspace "godot-client/reports/$Run.json") -Raw|ConvertFrom-Json
  $actionsCorrectionCheck=@($actionsCorrectionProof.actions.checks|Where-Object {$_.label-eq'One server correction queues one fitted step instead of restarting each frame'})
  if($actionsCorrectionCheck.Count-ne1-or-not$actionsCorrectionCheck[0].passed){throw 'Authoritative correction playback proof was not reached'}
  $actionsCorrectionDestination=@($actionsCorrectionProof.actions.checks|Where-Object {$_.label-eq'Server script, not a client-side pose edit, supplies the correction destination'})
  if($actionsCorrectionDestination.Count-ne1-or-not$actionsCorrectionDestination[0].passed){throw 'Server correction destination was not verified'}
  $actionsCorrectionWire=@($actionsCorrectionProof.correctionWirePositions)
  if($actionsCorrectionWire.Count-lt2){throw 'Incoming correction position history is missing'}
  $actionsCorrectionAfter=$actionsCorrectionDestination[0].details.after
  $actionsCorrectionBefore=$actionsCorrectionDestination[0].details.before
  foreach($actionsCorrectionPoint in @($actionsCorrectionBefore,$actionsCorrectionAfter)){
   $actionsCorrectionMatches=@($actionsCorrectionWire|Where-Object {[Math]::Abs($_.position[0]-$actionsCorrectionPoint[0])-lt0.001-and[Math]::Abs($_.position[1]-$actionsCorrectionPoint[1])-lt0.001-and[Math]::Abs($_.position[2]-$actionsCorrectionPoint[2])-lt0.001})
   if($actionsCorrectionMatches.Count-eq0){throw 'Native correction destination does not match an incoming authoritative wire position'}
  }
 }
}finally{
 try{
  foreach($fixture in $actionsDeleteFiles){
   $resolved=[IO.Path]::GetFullPath($fixture.path)
   if(-not $resolved.StartsWith([IO.Path]::GetFullPath($actionsHome)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Owned deletion cleanup escapes test workspace'}
   if(Test-Path -LiteralPath $resolved){if((Get-FileHash -LiteralPath $resolved).Hash-ne$fixture.sha256){throw 'Changed deletion fixture preserved'};Remove-Item -LiteralPath $resolved}
  }
  if($actionsVaultFile){
   if(-not$actionsVaultFile.StartsWith([IO.Path]::GetFullPath($actionsHome)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or(Get-FileHash -LiteralPath $actionsVaultFile).Hash-ne$actionsVaultHash){throw 'Owned vault fixture changed; preserved for inspection'}
   Remove-Item -LiteralPath $actionsVaultFile
  }
 }finally{
  $actionsOwned=Get-CimInstance Win32_Process -Filter "ProcessId = $($actionsProcess.Id)"
  if($actionsOwned-and$actionsOwned.ExecutablePath-eq$actionsServer-and$actionsOwned.CommandLine.Contains('"'+$actionsHome+'"')){Stop-Process -Id $actionsProcess.Id}
 }
}
exit $actionsExit
