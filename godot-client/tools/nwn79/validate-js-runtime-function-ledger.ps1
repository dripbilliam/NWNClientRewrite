param(
    [string]$LedgerPath = (Join-Path $PSScriptRoot 'js-runtime-function-ledger-v1.json'),
    [string]$ReachabilityPath = (Join-Path $PSScriptRoot 'js-runtime-reachability-v1.json'),
    [switch]$RequireComplete
)

$ErrorActionPreference = 'Stop'
$ledger = Get-Content -LiteralPath $LedgerPath -Raw | ConvertFrom-Json -AsHashtable
$reachability = Get-Content -LiteralPath $ReachabilityPath -Raw | ConvertFrom-Json -AsHashtable
$errors = [System.Collections.Generic.List[string]]::new()
$paths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$expected = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($file in $reachability.reachableFiles) { [void]$expected.Add([string]$file.path) }
$locations = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$rows = 0
$pending = 0
$withGap = 0
foreach ($module in $ledger.moduleRecords) {
    $path = [string]$module.oldPath
    if (-not $paths.Add($path)) { $errors.Add("Duplicate module: $path") }
    if (-not $expected.Contains($path)) { $errors.Add("Module not in mechanical reachability: $path") }
    if (@($module.functions).Count -eq 0) { $errors.Add("No function candidate rows: $path") }
    $moduleHasOpenRow = $false
    foreach ($row in $module.functions) {
        $rows++
        $symbol = [string]$row.oldSymbol
        $location = [string]$row.oldLocation
        if (-not $symbol -or $location -notmatch '^(.+\.(?:js|cjs|mjs)):(\d+)$' -or $Matches[1] -ne $path) {
            $errors.Add("Missing or unstable source location: ${path}::$symbol [$location]")
        }
        if (-not $locations.Add("${location}::$symbol")) { $errors.Add("Duplicate function declaration row: ${location}::$symbol") }
        if (-not [string]$row.oldQualifiedSymbol) { $errors.Add("Missing disambiguated symbol: ${location}::$symbol") }
        $status = [string]$row.status
        $gap = [string]$row.gap
        if ($status -eq 'pending' -or $status -eq 'partial' -or $status -eq 'mapped-focused') { $pending++; $moduleHasOpenRow = $true }
        if ($gap.Trim()) { $withGap++; $moduleHasOpenRow = $true }
        if ($status -eq 'complete' -or $status -eq 'verified') {
            if (-not [string]$row.godotReplacement -or -not [string]$row.actualGodotCaller -or @($row.evidence).Count -eq 0 -or $gap.Trim()) {
                $errors.Add("Complete function lacks replacement, actual caller, evidence, or gap closure: ${location}::$symbol")
            }
            if ($module.oldCallerChain -match 'pending|unverified|unknown') {
                $errors.Add("Complete function has pending old caller chain: ${location}::$symbol")
            }
        }
    }
    if ($module.moduleComplete -eq $true -and ($moduleHasOpenRow -or $module.oldCallerChain -match 'pending|unverified|unknown')) {
        $errors.Add("Module marked complete with open rows or caller chain: $path")
    }
}
foreach ($path in $expected) {
    if (-not $paths.Contains($path)) { $errors.Add("Reachable module missing from ledger: $path") }
}
if ($rows -ne [int]$ledger.sourceInventory.mechanicalCandidateCount) {
    $errors.Add("Function count drift: ledger rows=$rows inventory=$($ledger.sourceInventory.mechanicalCandidateCount)")
}
if ($RequireComplete) {
    if ($ledger.sourceInventory.complete -ne $true) { $errors.Add('Source inventory is not marked complete') }
    if ($ledger.exclusionInventoryComplete -ne $true) { $errors.Add('Excluded-file inventory is not complete') }
    if (@($reachability.unresolvedEdges).Count -gt 0) { $errors.Add("Unresolved import edges: $(@($reachability.unresolvedEdges).Count)") }
    if ($pending -gt 0 -or $withGap -gt 0) { $errors.Add("Pending functions=$pending; nonempty gaps=$withGap") }
    if (@($ledger.moduleRecords | Where-Object { $_.moduleComplete -ne $true }).Count -gt 0) { $errors.Add('One or more reachable modules lack moduleComplete=true') }
}
$result = [ordered]@{valid=($errors.Count -eq 0);completeRequested=[bool]$RequireComplete;modules=$paths.Count;functionRows=$rows;pendingRows=$pending;rowsWithGap=$withGap;unresolvedEdges=@($reachability.unresolvedEdges).Count;errors=@($errors)}
Write-Output ($result | ConvertTo-Json -Depth 5)
if ($errors.Count -gt 0) { exit 1 }
