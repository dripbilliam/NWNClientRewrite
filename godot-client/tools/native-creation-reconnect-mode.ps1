function Resolve-OwnedCreationReconnectClass {
 param([Parameter(Mandatory)][ValidateSet('wizard','cleric')][string]$CreationClass,[Parameter(Mandatory)]$AcceptedCreate)
 $physicalId=@{wizard=10;cleric=2}[$CreationClass]
 if(($AcceptedCreate.creationProof.expected.classId -isnot [int] -and $AcceptedCreate.creationProof.expected.classId -isnot [long]) -or $AcceptedCreate.creationProof.expected.classId -ne $physicalId){throw 'Accepted create class does not match the explicit reconnect class'}
 return $physicalId
}
function Invoke-OwnedCreationReconnectMode {
 param([switch]$Diagnostic,[Parameter(Mandatory)][scriptblock]$Body)
 $previous=[Environment]::GetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC','Process')
 try{
  [Environment]::SetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC',$(if($Diagnostic){'1'}else{$null}),'Process')
  & $Body
 }finally{
  [Environment]::SetEnvironmentVariable('NWN_CREATION_APPLY_DIAGNOSTIC',$previous,'Process')
 }
}
