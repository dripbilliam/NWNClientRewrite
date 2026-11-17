param(
    [string]$LedgerPath = (Join-Path $PSScriptRoot 'js-runtime-function-ledger-v1.json'),
    [string]$UiInventoryPath = (Join-Path $PSScriptRoot 'js-runtime-ui-pending-v1.json'),
    [string]$ReachabilityPath = (Join-Path $PSScriptRoot 'js-runtime-reachability-v1.json')
)

$ErrorActionPreference = 'Stop'
$ledger = Get-Content -LiteralPath $LedgerPath -Raw | ConvertFrom-Json -AsHashtable
$ui = Get-Content -LiteralPath $UiInventoryPath -Raw | ConvertFrom-Json -AsHashtable
$reach = Get-Content -LiteralPath $ReachabilityPath -Raw | ConvertFrom-Json -AsHashtable
$byPath = @{}
foreach ($module in $ledger.moduleRecords) { $byPath[$module.oldPath] = $module }
$added = 0
$outside = [System.Collections.Generic.List[string]]::new()
foreach ($file in $ui.files) {
    $path = [string]$file.file
    if ($path -notmatch '\.(?:js|cjs|mjs)$') { continue }
    if (-not $byPath.ContainsKey($path)) { $outside.Add($path); continue }
    $module = $byPath[$path]
    $keys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($row in $module.functions) { [void]$keys.Add("$($row.oldLocation)::$($row.oldSymbol)") }
    foreach ($function in $file.functions) {
        $name = [string]$function.name
        $line = [int]$function.line
        $location = "$path`:$line"
        if (-not $keys.Add("${location}::$name")) { continue }
        $module.functions += [ordered]@{
            oldSymbol=$name
            oldQualifiedSymbol="${path}::$name@$line"
            oldLocation=$location
            kind=[string]$function.kind
            status='pending'
            godotReplacement=''
            actualGodotCaller=''
            evidence=@()
            gap='AST candidate from UI inventory; old function invocation, Godot replacement caller and parity unreviewed'
        }
        $added++
    }
}
$ledger.sourceInventory.uiAstInventory = [ordered]@{
    path='godot-client/tools/nwn79/js-runtime-ui-pending-v1.json'
    candidateFiles=@($ui.files | Where-Object { $_.file -match '\.(?:js|cjs|mjs)$' }).Count
    functionCandidates=@($ui.files | Where-Object { $_.file -match '\.(?:js|cjs|mjs)$' } | ForEach-Object { $_.functions }).Count
    mergedRows=$added
    outsideMechanicalClosure=@($outside)
    status='pending, not parity acceptance'
}
$ledger.sourceInventory.reachableSourceProvenance = @($reach.reachableFiles)
$ledger.sourceInventory.nonFunctionAssetEdges = @($reach.nonFunctionAssetEdges)
$ledger.sourceInventory.externalPackageEdges = @($reach.externalPackageEdges)
$ledger.sourceInventory.excludedDiagnosticEdges = @($reach.excludedConditionalDiagnosticEdges)
$ledger.sourceInventory.mechanicalCandidateCount = @($ledger.moduleRecords | ForEach-Object { $_.functions }).Count
$ledger.sourceInventory.reviewedFunctionCount = @($ledger.moduleRecords | ForEach-Object { $_.functions } | Where-Object { $_.status -ne 'pending' }).Count
$ledger.sourceInventory.complete = $false
$ledger.inventoryStatus = 'mechanical pending inventory with AST UI subset; no whole-runtime completion claim'
[IO.File]::WriteAllText($LedgerPath, (($ledger | ConvertTo-Json -Depth 30) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output (@{added=$added;outside=@($outside);totalRows=$ledger.sourceInventory.mechanicalCandidateCount} | ConvertTo-Json -Compress)
