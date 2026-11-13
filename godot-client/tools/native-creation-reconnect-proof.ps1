function Test-CreationProofFlag($Value){return $Value-is[bool]-and$Value}
function Test-OwnedCreationReconnectResult {
 param([Parameter(Mandatory)]$Result)
 $wire=$Result.creationWireProof;$play=$wire.play
 return (Test-CreationProofFlag $Result.success)-and(Test-CreationProofFlag $Result.creationReconnectSelection.success)-and(Test-CreationProofFlag $wire.success)-and$wire.uploads-eq0-and$wire.plays-eq1-and$play.major-eq2-and$play.minor-eq17-and$play.source-eq17-and(Test-CreationProofFlag $play.canonical)-and$null-eq$Result.nativeCreation-and(Test-CreationProofFlag $Result.creationHpProof.success)-and(Test-CreationProofFlag $Result.creationTailExportProof.success)
}
