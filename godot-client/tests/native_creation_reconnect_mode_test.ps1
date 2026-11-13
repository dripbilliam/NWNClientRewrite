$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../tools/native-creation-reconnect-mode.ps1')
$modeChecks=0
function Assert-Mode([bool]$Value,[string]$Label){$script:modeChecks++;if(-not$Value){throw $Label}}
foreach($entry in @(@('wizard',10),@('cleric',2))){
 $accepted=[pscustomobject]@{creationProof=[pscustomobject]@{expected=[pscustomobject]@{classId=$entry[1]}}}
 Assert-Mode ((Resolve-OwnedCreationReconnectClass -CreationClass $entry[0] -AcceptedCreate $accepted)-eq$entry[1]) 'Physical class mapping differs'
 foreach($bad in @(-1,0,1,3,(10+$entry[1]),'2',$null,$true,$false,2.0,2.5)){
  $accepted.creationProof.expected.classId=$bad;$rejected=$false
  try{Resolve-OwnedCreationReconnectClass -CreationClass $entry[0] -AcceptedCreate $accepted|Out-Null}catch{$rejected=$true}
  Assert-Mode $rejected 'Wrong or untyped class must reject before runtime'
 }
}
$original=[Environment]::GetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC','Process')
try{
 foreach($previous in @($null,'sentinel','1')){
  [Environment]::SetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC',$previous,'Process')
  $capturedPrevious=[Environment]::GetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC','Process')
  foreach($diagnostic in @($false,$true)){
   $seen=Invoke-OwnedCreationReconnectMode -Diagnostic:$diagnostic -Body {[Environment]::GetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC','Process')}
   Assert-Mode ($(if($diagnostic){$seen-eq'1'}else{[string]::IsNullOrEmpty($seen)})) 'Explicit mode not applied'
   Assert-Mode ([Environment]::GetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC','Process')-eq$capturedPrevious) 'Success must restore exact prior environment'
   $rejected=$false
   try{Invoke-OwnedCreationReconnectMode -Diagnostic:$diagnostic -Body {throw 'owned failure'}}catch{$rejected=$_.Exception.Message-eq'owned failure'}
   Assert-Mode $rejected 'Body failure must remain a failure'
   Assert-Mode ([Environment]::GetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC','Process')-eq$capturedPrevious) 'Failure must restore exact prior environment'
  }
 }
}finally{[Environment]::SetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC',$original,'Process')}
[pscustomobject]@{success=$true;checks=$modeChecks;serverConnections=0;keyReads=0;processLaunches=0}|ConvertTo-Json
