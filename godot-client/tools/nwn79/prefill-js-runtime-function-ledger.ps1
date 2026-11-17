param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path,
    [string]$ReachabilityPath = (Join-Path $PSScriptRoot 'js-runtime-reachability-v1.json'),
    [string]$LedgerPath = (Join-Path $PSScriptRoot 'js-runtime-function-ledger-v1.json')
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
$reachability = Get-Content -LiteralPath $ReachabilityPath -Raw | ConvertFrom-Json -AsHashtable
$ledger = Get-Content -LiteralPath $LedgerPath -Raw | ConvertFrom-Json -AsHashtable
$old = @{}
foreach ($module in $ledger.moduleRecords) { $old[$module.oldPath] = $module }
$incoming = @{}
foreach ($edge in $reachability.importEdges) {
    if (-not $incoming.ContainsKey($edge.to)) { $incoming[$edge.to] = [System.Collections.Generic.List[string]]::new() }
    $incoming[$edge.to].Add("$($edge.from):$($edge.line)")
}

function Source-Text([string]$path) {
    $full = Join-Path $root ($path -replace '/', '\')
    if ([IO.File]::Exists($full)) { return [IO.File]::ReadAllText($full) }
    $revision = if (@($reachability.reachableFiles | Where-Object { $_.path -eq $path })[0].sourceState -like 'historical-blob:*') { [string]$reachability.historicalCommit } else { 'HEAD' }
    $lines = @(git -C $root show "${revision}:$path")
    if ($LASTEXITCODE -ne 0) { throw "Cannot read ${revision}:$path" }
    return ($lines -join "`n")
}

$records = [System.Collections.Generic.List[object]]::new()
$candidateCount = 0
$reviewedCount = 0
$scannerMisses = [System.Collections.Generic.List[object]]::new()
$keywords = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($word in @('if','for','while','switch','catch','with','function','return','throw','else','do','new','await')) { [void]$keywords.Add($word) }
foreach ($file in $reachability.reachableFiles) {
    $path = [string]$file.path
    $lines = (Source-Text $path) -split '\r?\n'
    $candidates = [System.Collections.Generic.List[object]]::new()
    $candidateKeys = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    for ($i=0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $found = [System.Collections.Generic.List[object]]::new()
        foreach ($match in [regex]::Matches($line, '\b(?:export\s+(?:default\s+)?)?(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(')) {
            $found.Add(@{symbol=$match.Groups[1].Value;kind='function declaration'})
        }
        if ($line -match '^\s*(?:export\s+(?:default\s+)?)?(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*(?:async\s*)?(?:function\b|\([^;]*?\)\s*=>|[A-Za-z_$][\w$]*\s*=>)') {
            $found.Add(@{symbol=$Matches[1];kind='function-valued binding'})
        }
        if ($line -match '^\s*(?:export\s+(?:default\s+)?)?class\s+([A-Za-z_$][\w$]*)\b') {
            $found.Add(@{symbol=$Matches[1];kind='class declaration'})
        }
        if ($line -match '^\s{2,}(?:(?:async|static|get|set)\s+)*([A-Za-z_$][\w$]*)\s*\([^;]*\)\s*\{') {
            if (-not $keywords.Contains($Matches[1])) { $found.Add(@{symbol=$Matches[1];kind='method candidate'}) }
        }
        if ($line -match '^\s*export\s+(?:default\s+)?(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=') {
            $found.Add(@{symbol=$Matches[1];kind='exported value candidate'})
        }
        if ($line -match '^\s*(?:parentPort\.on|self\.addEventListener)\s*\(\s*["'']message["'']\s*,') {
            $found.Add(@{symbol='message-handler';kind='top-level anonymous worker handler'})
        }
        foreach ($item in $found) {
            $key = "$($i+1):$($item.symbol)"
            if (-not $candidateKeys.Add($key)) { continue }
            $candidates.Add(@{oldSymbol=$item.symbol;oldQualifiedSymbol="${path}::$($item.symbol)@$($i+1)";oldLocation="$path`:$($i+1)";kind=$item.kind;status='pending';godotReplacement='';actualGodotCaller='';evidence=@();gap='Mechanical candidate; normal function invocation, replacement caller and parity unreviewed'})
        }
    }
    if ($old.ContainsKey($path)) {
        $module = $old[$path]
        $existing = @{}
        foreach ($row in $module.functions) { $existing["$($row.oldLocation):$($row.oldSymbol)"] = $true }
        foreach ($candidate in $candidates) {
            $key = "$($candidate.oldLocation):$($candidate.oldSymbol)"
            if (-not $existing.ContainsKey($key)) { $module.functions += $candidate }
        }
        foreach ($row in $module.functions) {
            if (-not ($candidateKeys.Contains((($row.oldLocation -split ':')[-1]) + ":$($row.oldSymbol)"))) {
                $scannerMisses.Add(@{path=$path;symbol=$row.oldSymbol;location=$row.oldLocation})
            }
        }
        $reviewedCount += @($module.functions | Where-Object { $_.status -ne 'pending' }).Count
    } else {
        $callers = if ($incoming.ContainsKey($path)) { @($incoming[$path] | Select-Object -Unique) } else { @('<entrypoint or unresolved caller>') }
        $module = [ordered]@{oldPath=$path;sourceState=$file.sourceState;oldCallerChain=($callers -join '; ');moduleDisposition='pending function-by-function runtime audit';functions=@($candidates)}
    }
    $candidateCount += @($module.functions).Count
    $records.Add($module)
}

$ledger.moduleRecords = @($records | Sort-Object oldPath)
$ledger.sourceInventory.currentReachableFiles = @($reachability.reachableFiles | Where-Object sourceState -eq 'present' | ForEach-Object path)
$ledger.sourceInventory.deletedReachableFiles = @($reachability.reachableFiles | Where-Object sourceState -ne 'present' | ForEach-Object path)
$ledger.sourceInventory.unresolvedDynamicEdges = @($reachability.unresolvedEdges)
$ledger.sourceInventory.complete = $false
$ledger.sourceInventory.mechanicalCandidateCount = $candidateCount
$ledger.sourceInventory.reviewedFunctionCount = $reviewedCount
$ledger.sourceInventory.scannerMissesAgainstReviewed = @($scannerMisses)
$ledger.sourceInventory.method = 'Mechanical literal import closure from HEAD old entrypoints, plus line-based named function/class/method/export candidate scan. Candidate inventory may omit multiline, computed, anonymous and runtime-selected functions. Manual AST/caller review and unresolved-edge closure required before complete=true.'
$ledger.inventoryStatus = 'mechanical pending inventory; no whole-runtime completion claim'
$ledger.retiredModuleSource.functionExpansionComplete = $false
[IO.File]::WriteAllText($LedgerPath, (($ledger | ConvertTo-Json -Depth 30) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output (@{modules=$records.Count;functionRows=$candidateCount;reviewedRows=$reviewedCount;scannerMisses=$scannerMisses.Count} | ConvertTo-Json -Compress)
