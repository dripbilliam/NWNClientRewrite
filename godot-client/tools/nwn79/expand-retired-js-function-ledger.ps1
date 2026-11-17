param(
    [string]$LedgerPath = (Join-Path $PSScriptRoot 'js-runtime-function-ledger-v1.json'),
    [string]$RetirementPath = (Join-Path $PSScriptRoot 'js-module-retirement-ledger.json'),
    [string]$ReachabilityPath = (Join-Path $PSScriptRoot 'js-runtime-reachability-v1.json')
)
$ErrorActionPreference = 'Stop'
$ledger = Get-Content -LiteralPath $LedgerPath -Raw | ConvertFrom-Json -AsHashtable
$retired = Get-Content -LiteralPath $RetirementPath -Raw | ConvertFrom-Json -AsHashtable
$reach = Get-Content -LiteralPath $ReachabilityPath -Raw | ConvertFrom-Json -AsHashtable
$modules = @{}
foreach ($module in $ledger.moduleRecords) { $modules[$module.oldPath] = $module }
$sources = @{}
foreach ($file in $reach.reachableFiles) { $sources[$file.path] = $file }
$incoming = @{}
foreach ($edge in $reach.importEdges) {
    if (-not $incoming.ContainsKey($edge.to)) { $incoming[$edge.to] = [System.Collections.Generic.List[string]]::new() }
    $incoming[$edge.to].Add("$($edge.from):$($edge.line) [$($edge.form)]")
}
$expansions = [System.Collections.Generic.List[object]]::new()
$exclusions = [System.Collections.Generic.List[object]]::new()
$matchedExports = 0
$unmatchedExports = 0
$reachable = 0
foreach ($nomination in $retired.nominations) {
    $path = [string]$nomination.path
    $isReachable = $modules.ContainsKey($path)
    if ($isReachable) { $reachable++ }
    $module = if ($isReachable) { $modules[$path] } else { $null }
    $exportRows = [System.Collections.Generic.List[object]]::new()
    foreach ($export in @($nomination.exports | Where-Object { $_ })) {
        $name = [string]$export
        $symbol = ($name -split '\.')[-1]
        if ($module) { $candidateRows = @($module.functions | Where-Object { $_.oldSymbol -eq $symbol }) }
        else { $candidateRows = @() }
        if ($candidateRows.Count -eq 1) {
            $matchedExports++
            $row = $candidateRows[0]
            $exportRows.Add([ordered]@{
                oldExport=$name
                oldQualifiedSymbol=$row.oldQualifiedSymbol
                oldLocation=$row.oldLocation
                status=$row.status
                godotReplacement=$row.godotReplacement
                actualGodotCaller=$row.actualGodotCaller
                evidence=@($row.evidence)
                gap=$row.gap
            })
        } else {
            $unmatchedExports++
            $exportRows.Add([ordered]@{
                oldExport=$name
                oldQualifiedSymbol=''
                oldLocation=''
                status=if ($isReachable) { 'pending-source-disambiguation' } else { 'excluded-outside-normal-runtime' }
                godotReplacement=''
                actualGodotCaller=''
                evidence=@()
                gap=if ($isReachable) { 'Export symbol not uniquely matched to a mechanical function row' } else { 'Research/debug entry not in the normal old runtime closure; no parity port required' }
            })
        }
    }
    $sourceState = if ($sources.ContainsKey($path)) { $sources[$path].sourceState } else { 'outside normal entrypoint closure' }
    if ($isReachable) {
        $module.retirementHistory = [ordered]@{
            status=$nomination.status
            retiredSha256=$nomination.retiredSha256
            retirementEvidence=$nomination.retirementEvidence
            fileLevelReplacementCandidates=@($nomination.godotReplacements)
            fileLevelFocusedEvidence=@($nomination.focusedEvidence)
            fileLevelLiveEvidence=$nomination.liveEvidence
            note='File-level candidates and receipts do not certify any pending function row; inspect each exact Godot caller and branch.'
        }
        if (-not $module.Contains('moduleComplete')) { $module.moduleComplete = $false }
    } else {
        $reason = if ($path -match 'scene_capture|scene_replay') { 'Conditional scene-record/replay research branch, outside normal client run' } elseif ($path -match 'debug') { 'Conditional Electron debug UI, outside normal client run' } else { 'Electron-only platform helper not reached by the normal old entrypoint closure; retired rather than ported' }
        $exclusions.Add([ordered]@{path=$path;retirementStatus=$nomination.status;reason=$reason;sourceEvidence=$nomination.retirementEvidence})
    }
    $expansions.Add([ordered]@{
        oldPath=$path
        retirementStatus=$nomination.status
        oldNormalReachable=$isReachable
        sourceState=$sourceState
        oldIncomingEdges=if ($incoming.ContainsKey($path)) { @($incoming[$path]) } else { @() }
        perFunctionRowsInCentralLedger=if ($module) { @($module.functions).Count } else { 0 }
        exports=@($exportRows)
        fileLevelReplacementCandidates=@($nomination.godotReplacements)
        fileLevelFocusedEvidence=@($nomination.focusedEvidence)
        fileLevelLiveEvidence=$nomination.liveEvidence
        retiredSha256=$nomination.retiredSha256
        retirementEvidence=$nomination.retirementEvidence
        moduleComplete=if ($module) { [bool]$module.moduleComplete } else { $false }
    })
}
$ledger.retiredModuleExpansions = @($expansions)
$ledger.excludedFiles = @($exclusions)
$ledger.exclusionInventoryComplete = $false
$ledger.retiredModuleSource.recordsExpandedCount = $expansions.Count
$ledger.retiredModuleSource.reachableRetiredCount = $reachable
$ledger.retiredModuleSource.excludedRetiredCount = $exclusions.Count
$ledger.retiredModuleSource.matchedExportRows = $matchedExports
$ledger.retiredModuleSource.unmatchedExportRows = $unmatchedExports
$ledger.retiredModuleSource.functionExpansionComplete = $false
$ledger.inventoryStatus = 'mechanical pending inventory with 29 retired-module provenance records; no whole-runtime completion claim'
[IO.File]::WriteAllText($LedgerPath, (($ledger | ConvertTo-Json -Depth 40) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output (@{retirementRecords=$expansions.Count;reachable=$reachable;excluded=$exclusions.Count;matchedExports=$matchedExports;unmatchedExports=$unmatchedExports;functionRows=$ledger.sourceInventory.mechanicalCandidateCount} | ConvertTo-Json -Compress)
