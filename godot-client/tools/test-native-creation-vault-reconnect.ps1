[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^native-creation-[a-z0-9-]+$')][string]$Run,[Parameter(Mandatory)][string]$AcceptedCreate,[ValidateSet('wizard','cleric')][string]$CreationClass='wizard',[switch]$ApplyDiagnostic)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'native-creation-shared-log.ps1')
. (Join-Path $PSScriptRoot 'native-creation-reconnect-proof.ps1')
. (Join-Path $PSScriptRoot 'native-creation-reconnect-mode.ps1')
$reconnectProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$reconnectRoot=[IO.Path]::GetFullPath((Join-Path $reconnectProject '.cache/creation-full-vault-tests'))+[IO.Path]::DirectorySeparatorChar
$reconnectReference=[IO.Path]::GetFullPath($AcceptedCreate)
$reconnectReports=[IO.Path]::GetFullPath((Join-Path $reconnectProject 'reports'))+[IO.Path]::DirectorySeparatorChar
if(-not$reconnectReference.StartsWith($reconnectReports)-or[IO.Path]::GetFileName($reconnectReference)-notmatch'^native-creation-[a-z0-9-]+\.json$'){throw 'Explicit accepted owned create report required'}
$reconnectCreate=Get-Content -LiteralPath $reconnectReference -Raw|ConvertFrom-Json
$reconnectClassId=Resolve-OwnedCreationReconnectClass -CreationClass $CreationClass -AcceptedCreate $reconnectCreate
if(-not$reconnectCreate.success-or-not$reconnectCreate.creationProof.success-or-not$reconnectCreate.creationHpProof.success-or-not$reconnectCreate.creationTailExportProof.success-or-not$reconnectCreate.creationPostAdmissionExportComplete-or$reconnectCreate.creationWireProof.expectedSubtype-ne19-or-not$reconnectCreate.creationWireProof.success-or$reconnectCreate.endpoint-ne'127.0.0.1:5129'){throw 'Accepted original explicit-class server-vault create/HP/export proof is required'}
$reconnectHome=[IO.Path]::GetFullPath($reconnectCreate.creationVaultFixture.directory)
if(-not$reconnectHome.StartsWith($reconnectRoot)-or[IO.Path]::GetFileName($reconnectHome)-ne'server'){throw 'Retained owned fixture path differs'}
$reconnectFixturePath=Join-Path $reconnectHome 'fixture.json'
$reconnectFixture=Get-Content -LiteralPath $reconnectFixturePath -Raw|ConvertFrom-Json
$reconnectFixtureHash=(Get-FileHash -LiteralPath $reconnectFixturePath).Hash.ToLowerInvariant()
if($reconnectFixtureHash-ne$reconnectCreate.creationVaultFixture.descriptorSha256-or$reconnectFixture.directory-ne$reconnectHome-or$reconnectFixture.kind-ne'owned-native-first-level-vault'-or$reconnectFixture.port-ne5129-or$reconnectFixture.module-ne'Prelude'-or-not$reconnectFixture.serverVault-or$reconnectFixture.public-or$reconnectFixture.maxClients-ne1-or-not$reconnectFixture.enforceLegal){throw 'Retained fixture identity/rules differ'}
$reconnectInstall=[IO.Path]::GetFullPath((Join-Path $reconnectProject '../../FullDecomp/NwnRootInstall'))
if($reconnectFixture.serverPath-ne(Join-Path $reconnectInstall 'bin/win32/nwserver.exe')-or$reconnectFixture.modulePath-ne(Join-Path $reconnectInstall 'data/nwm/Prelude.nwm')-or$reconnectFixture.serverSha256-ne'98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6'-or(Get-FileHash -LiteralPath $reconnectFixture.serverPath).Hash.ToLowerInvariant()-ne$reconnectFixture.serverSha256-or(Get-FileHash -LiteralPath $reconnectFixture.modulePath).Hash.ToLowerInvariant()-ne$reconnectFixture.moduleSha256){throw 'Original server/module changed'}
if(Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue){throw '5129 is occupied; existing process preserved'}
if(Get-CimInstance Win32_Process -Filter "Name='nwserver.exe'"|Where-Object{$_.CommandLine-and$_.CommandLine.Contains($reconnectHome)}){throw 'Retained fixture already has a process'}
if($env:NWN_CREATION_APPLY_DIAGNOSTIC){throw 'Reconnect mode must be selected explicitly, not inherited'}
$reconnectDirectory=Join-Path $reconnectProject ('.cache/creation-vault-reconnect-tests/'+$Run)
if((Test-Path -LiteralPath $reconnectDirectory)-or(Test-Path -LiteralPath (Join-Path $reconnectProject ('reports/'+$Run+'.json')))){throw 'Existing reconnect evidence retained'}
$reconnectProcess=$null;$reconnectFailure=$null;$reconnectResult=$null;$reconnectAccepted=$false;$reconnectCleaned=$false
$reconnectReferenceHash=(Get-FileHash -LiteralPath $reconnectReference).Hash.ToLowerInvariant()
$reconnectDriverHash=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()
$reconnectLogHelper=Join-Path $PSScriptRoot 'native-creation-shared-log.ps1'
$reconnectLogHelperHash=(Get-FileHash -LiteralPath $reconnectLogHelper).Hash.ToLowerInvariant()
$reconnectProofHelper=Join-Path $PSScriptRoot 'native-creation-reconnect-proof.ps1'
$reconnectProofHelperHash=(Get-FileHash -LiteralPath $reconnectProofHelper).Hash.ToLowerInvariant()
$reconnectModeHelper=Join-Path $PSScriptRoot 'native-creation-reconnect-mode.ps1'
$reconnectModeHelperHash=(Get-FileHash -LiteralPath $reconnectModeHelper).Hash.ToLowerInvariant()
# Secret content/digests stay in memory only; never copy into evidence.
$reconnectSecretPath=Join-Path $reconnectHome 'cryptographic_secret'
$reconnectSecretBefore=(Get-FileHash -LiteralPath $reconnectSecretPath).Hash
function Get-OwnedVaultView {
 $vaultRoot=Join-Path $reconnectHome 'servervault'
 $rows=@(Get-ChildItem -LiteralPath $vaultRoot -Recurse -File -Filter '*.bic')
 if($rows.Count-ne1-or$rows[0].Length-gt2MB){throw 'Expected exactly the one retained owned vault character'}
 $relative=$rows[0].FullName.Substring($vaultRoot.Length+1)
 $sha=[Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($relative))
 return [pscustomobject]@{path=$rows[0].FullName;relativeIdentity=[Convert]::ToHexString($sha).ToLowerInvariant();sha256=(Get-FileHash -LiteralPath $rows[0].FullName).Hash.ToLowerInvariant();bytes=$rows[0].Length}
}
$reconnectBefore=Get-OwnedVaultView
$reconnectLease=[IO.File]::Open((Join-Path $reconnectProject '.cache/creation-full-alt-key.lease'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try{
 New-Item -ItemType Directory -Path $reconnectDirectory|Out-Null
 Copy-Item -LiteralPath $reconnectReference -Destination (Join-Path $reconnectDirectory 'accepted-create.json')
 Copy-Item -LiteralPath $reconnectFixturePath -Destination (Join-Path $reconnectDirectory 'fixture.json')
 Copy-Item -LiteralPath $reconnectBefore.path -Destination (Join-Path $reconnectDirectory 'accepted-vault-before.bic')
 $reconnectLog=Join-Path $reconnectHome 'logs/nwengineLog.txt'
 if(Test-Path -LiteralPath $reconnectLog){Copy-Item -LiteralPath $reconnectLog -Destination (Join-Path $reconnectDirectory 'nwengineLog-before.txt')}
 $reconnectStart=[Diagnostics.ProcessStartInfo]::new();$reconnectStart.FileName=$reconnectFixture.serverPath;$reconnectStart.WorkingDirectory=Split-Path $reconnectFixture.serverPath;$reconnectStart.UseShellExecute=$false;$reconnectStart.CreateNoWindow=$true;$reconnectStart.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$reconnectStart.Environment['NWN_DO_NOT_NAT_PUNCH']='1'
 foreach($argument in @('-userdirectory',$reconnectHome,'-port','5129','-publicserver','0','-servername','OwnedNativeCreationVault','-maxclients','1','-servervault','1','-autosaveinterval','0','-module','Prelude')){$reconnectStart.ArgumentList.Add($argument)}
 $reconnectStartedAt=[DateTime]::UtcNow;$reconnectProcess=[Diagnostics.Process]::Start($reconnectStart)
 $reconnectDeadline=[DateTime]::UtcNow.AddSeconds(25)
 do{$endpoint=Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue;if($endpoint.OwningProcess-contains$reconnectProcess.Id){break};if($reconnectProcess.HasExited){throw 'Owned reconnect server exited'};Start-Sleep -Milliseconds 200}while([DateTime]::UtcNow-lt$reconnectDeadline)
 if($endpoint.OwningProcess-notcontains$reconnectProcess.Id){throw 'Owned retained server did not bind5129'}
 $reconnectReady=$false
 for($attempt=0;$attempt-lt8;$attempt++){
  & node (Join-Path $reconnectProject 'tools/query-native-creation-server.mjs') --port=5129 ('--output='+(Join-Path $reconnectDirectory ('ready-'+$attempt+'.json')))
  if($LASTEXITCODE-eq0){$reconnectReady=$true;break};Start-Sleep -Milliseconds 250
 }
 if(-not$reconnectReady-or(Get-Item -LiteralPath $reconnectLog).LastWriteTimeUtc-lt$reconnectStartedAt){throw 'New owned log/query readiness not established'}
 if((Get-FileHash -LiteralPath $reconnectSecretPath).Hash-ne$reconnectSecretBefore){throw 'Owned server identity changed; no login sent'}
 $publicMatches=[Regex]::Matches((Read-OwnedCreationLog -Path $reconnectLog),'cryptographic public identity is: ([A-Za-z0-9+/=]+)')
 if(-not$publicMatches.Count){throw 'Owned public identity not ready'}
 $publicHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($publicMatches[$publicMatches.Count-1].Groups[1].Value))).ToLowerInvariant()
 if($publicHash-ne$reconnectCreate.creationServerIdentitySource.identitySha256){throw 'Retained public server identity differs; no login sent'}
 Invoke-OwnedCreationReconnectMode -Diagnostic:$ApplyDiagnostic -Body {
  & (Join-Path $reconnectProject 'tools/test-native-creation-full-live.ps1') -Run $Run -CreationClass $CreationClass -CreationDirectory $reconnectHome -OwnedServerProcessId $reconnectProcess.Id -CreationReconnectFrom $reconnectReference -KeyLease $reconnectLease
 }
 $reconnectResult=Get-Content -LiteralPath (Join-Path $reconnectProject ('reports/'+$Run+'.json')) -Raw|ConvertFrom-Json
 $reconnectAccepted=Test-OwnedCreationReconnectResult -Result $reconnectResult
 if(-not$reconnectAccepted){throw 'Saved-row17/re-admission/export was not accepted'}
}catch{$reconnectFailure=$_.Exception.Message}
finally{
 $reconnectCleaned=$null-eq$reconnectProcess
 if($reconnectProcess){
  if(-not$reconnectProcess.HasExited){$identity=Get-CimInstance Win32_Process -Filter ('ProcessId='+$reconnectProcess.Id);if($identity.ExecutablePath-eq$reconnectFixture.serverPath-and$identity.CommandLine.Contains($reconnectHome)){$reconnectProcess.Kill();$reconnectProcess.WaitForExit(10000)|Out-Null}else{$reconnectFailure='Owned reconnect server identity changed; unrelated process preserved'}}
  $reconnectCleaned=-not(Get-NetUDPEndpoint -LocalPort 5129 -ErrorAction SilentlyContinue|Where-Object OwningProcess -eq $reconnectProcess.Id)
 }
 $reconnectLease.Dispose()
 if(Test-Path -LiteralPath $reconnectDirectory){
  $after=$null;try{$after=Get-OwnedVaultView}catch{$reconnectFailure=$_.Exception.Message}
  if(Test-Path -LiteralPath $reconnectLog){Copy-Item -LiteralPath $reconnectLog -Destination (Join-Path $reconnectDirectory 'nwengineLog-after.txt')}
  $guards=[ordered]@{fixtureUnchanged=(Get-FileHash -LiteralPath $reconnectFixturePath).Hash.ToLowerInvariant()-eq$reconnectFixtureHash;acceptedReportUnchanged=(Get-FileHash -LiteralPath $reconnectReference).Hash.ToLowerInvariant()-eq$reconnectReferenceHash;secretUnchanged=(Get-FileHash -LiteralPath $reconnectSecretPath).Hash-eq$reconnectSecretBefore;sameVaultFile=$after.relativeIdentity-eq$reconnectBefore.relativeIdentity;driverUnchanged=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()-eq$reconnectDriverHash;logHelperUnchanged=(Get-FileHash -LiteralPath $reconnectLogHelper).Hash.ToLowerInvariant()-eq$reconnectLogHelperHash;proofHelperUnchanged=(Get-FileHash -LiteralPath $reconnectProofHelper).Hash.ToLowerInvariant()-eq$reconnectProofHelperHash;modeHelperUnchanged=(Get-FileHash -LiteralPath $reconnectModeHelper).Hash.ToLowerInvariant()-eq$reconnectModeHelperHash;diagnosticEnvironmentRestored=-not[Environment]::GetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC','Process')}
  $passed=$reconnectAccepted-and$reconnectCleaned-and-not$reconnectFailure-and-not($guards.Values-contains$false)
  $receipt=[ordered]@{success=$passed;run=$Run;creationClass=$CreationClass;physicalClassId=$reconnectClassId;diagnostic=[bool]$ApplyDiagnostic;reconnectOnly=$true;createPerformed=$false;failure=$reconnectFailure;acceptedCreateSha256=$reconnectReferenceHash;fixtureSha256=$reconnectFixtureHash;driverSha256=$reconnectDriverHash;logHelperSha256=$reconnectLogHelperHash;proofHelperSha256=$reconnectProofHelperHash;modeHelperSha256=$reconnectModeHelperHash;guards=$guards;vaultBefore=@{sha256=$reconnectBefore.sha256;bytes=$reconnectBefore.bytes;relativeIdentity=$reconnectBefore.relativeIdentity};vaultAfter=@{sha256=$after.sha256;bytes=$after.bytes;relativeIdentity=$after.relativeIdentity};serverProcessId=if($reconnectProcess){$reconnectProcess.Id}else{$null};serverCleaned=$reconnectCleaned;publicConnections=0;privateSecretsArchived=$false;nativeBuilds=0;scope='Reconnect only from exact accepted retained owned explicit-class vault: physical fresh received row17/no upload, authoritative export/HP/native readiness through existing guarded driver. Before vault/log evidence preserved; server secret remains in original owned profile and only internal equality is checked. Existing5121/editor/protected profiles/outputs are guarded by child.'}
  [IO.File]::WriteAllText((Join-Path $reconnectDirectory 'runner.json'),($receipt|ConvertTo-Json -Depth 9)+[Environment]::NewLine)
  [pscustomobject]@{success=$passed;failure=$reconnectFailure;serverCleaned=$reconnectCleaned;directory=$reconnectDirectory}|ConvertTo-Json
 }
}
if(-not$receipt.success){throw 'Owned retained-vault reconnect failed; evidence preserved'}
