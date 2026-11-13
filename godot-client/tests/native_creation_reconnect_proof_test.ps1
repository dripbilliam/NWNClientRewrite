param([Parameter(Mandatory)][string]$Report,[Parameter(Mandatory)][string]$Directory)
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $Directory){throw 'Existing proof test retained'}
New-Item -ItemType Directory -Path $Directory|Out-Null
. (Join-Path $PSScriptRoot '../tools/native-creation-reconnect-proof.ps1')
$json=[IO.File]::ReadAllText($Report);$original=$json|ConvertFrom-Json
if(-not(Test-OwnedCreationReconnectResult $original)){throw 'Real accepted reconnect schema rejected'}
$checks=1
foreach($fault in @('upload','duplicate-play','major','minor','source','canonical','canonical-string','wire','selection','hp','tail','native-upload')){
 $bad=$json|ConvertFrom-Json
 switch($fault){
  'upload'{$bad.creationWireProof.uploads=1}
  'duplicate-play'{$bad.creationWireProof.plays=2}
  'major'{$bad.creationWireProof.play.major=3}
  'minor'{$bad.creationWireProof.play.minor=19}
  'source'{$bad.creationWireProof.play.source=1}
  'canonical'{$bad.creationWireProof.play.canonical=$false}
  'canonical-string'{$bad.creationWireProof.play.canonical='true'}
  'wire'{$bad.creationWireProof.success=$false}
  'selection'{$bad.creationReconnectSelection.success=$false}
  'hp'{$bad.creationHpProof.success=$false}
  'tail'{$bad.creationTailExportProof.success=$false}
  'native-upload'{$bad|Add-Member -NotePropertyName nativeCreation -NotePropertyValue @{nativeGenerated=$true} -Force}
 }
 if(Test-OwnedCreationReconnectResult $bad){throw ('Invalid reconnect accepted: '+$fault)};$checks++
}
$result=@{success=$true;checks=$checks;sourceReportSha256=(Get-FileHash -LiteralPath $Report).Hash.ToLowerInvariant();scope='Real immutable saved-row17 child schema plus12 negative variants. No expectedSubtype field invented, no new login/runtime/server/key.'}
[IO.File]::WriteAllText((Join-Path $Directory 'proof.json'),($result|ConvertTo-Json)+[Environment]::NewLine)
$result|ConvertTo-Json -Compress
