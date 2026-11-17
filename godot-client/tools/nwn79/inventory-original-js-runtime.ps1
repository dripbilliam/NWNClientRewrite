param(
    [string]$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path,
    [string]$OutputPath = (Join-Path $PSScriptRoot 'js-runtime-reachability-v1.json')
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $WorkspaceRoot).Path
$historicalCommit = '864308cd613eefb7a61b513d361a338b41923252^'
$headPaths = @(git -C $root ls-tree -r --name-only HEAD -- src electron | Where-Object { $_ -match '\.(?:js|cjs|mjs)$' })
if ($LASTEXITCODE -ne 0) { throw 'git ls-tree failed' }
$historicalPaths = @(git -C $root ls-tree -r --name-only $historicalCommit -- src electron | Where-Object { $_ -match '\.(?:js|cjs|mjs)$' })
if ($LASTEXITCODE -ne 0) { throw 'historical git ls-tree failed' }
$known = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($path in $headPaths) { [void]$known.Add($path.Replace([char]92, [char]47)) }
foreach ($path in $historicalPaths) { [void]$known.Add($path.Replace([char]92, [char]47)) }
foreach ($dir in @('src','electron')) {
    Get-ChildItem -LiteralPath (Join-Path $root $dir) -File -Recurse -Include *.js,*.cjs,*.mjs | ForEach-Object {
        [void]$known.Add([IO.Path]::GetRelativePath($root, $_.FullName).Replace('\','/'))
    }
}

function Source-Text([string]$path) {
    $full = Join-Path $root ($path -replace '/', '\')
    if ([IO.File]::Exists($full)) { return [IO.File]::ReadAllText($full) }
    $revision = if ($headPaths -contains $path) { 'HEAD' } else { $historicalCommit }
    $lines = @(git -C $root show "${revision}:$path")
    if ($LASTEXITCODE -ne 0) { throw "Cannot read ${revision}:$path" }
    return ($lines -join "`n")
}

function Resolve-Import([string]$from, [string]$spec) {
    if ($spec.StartsWith('/src/')) { $candidate = $spec.TrimStart('/') }
    elseif ($spec.StartsWith('.')) {
        $base = [IO.Path]::GetDirectoryName((Join-Path $root ($from -replace '/', '\')))
        $candidate = [IO.Path]::GetRelativePath($root, [IO.Path]::GetFullPath((Join-Path $base ($spec -replace '/', '\')))).Replace('\','/')
    } else { return '' }
    foreach ($try in @($candidate, "$candidate.js", "$candidate.mjs", "$candidate.cjs", "$candidate/index.js", "$candidate/index.mjs", "$candidate/index.cjs")) {
        if ($known.Contains($try)) { return $try }
    }
    return ''
}

$queue = [System.Collections.Generic.Queue[string]]::new()
$queue.Enqueue('electron/main.cjs')
$queue.Enqueue('src/main.js')
$seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$records = [System.Collections.Generic.List[object]]::new()
$edges = [System.Collections.Generic.List[object]]::new()
$unresolved = [System.Collections.Generic.List[object]]::new()
$excludeDiagnostic = [System.Collections.Generic.List[object]]::new()
$assetEdges = [System.Collections.Generic.List[object]]::new()
$externalEdges = [System.Collections.Generic.List[object]]::new()
$processEdges = [System.Collections.Generic.List[object]]::new()
while ($queue.Count -gt 0) {
    $path = $queue.Dequeue()
    if (-not $seen.Add($path)) { continue }
    if (-not $known.Contains($path)) { $unresolved.Add(@{from='<entrypoint>';spec=$path;reason='entrypoint absent'}); continue }
    $full = Join-Path $root ($path -replace '/', '\')
    $state = if ([IO.File]::Exists($full)) { 'present' } elseif ($headPaths -contains $path) { 'deleted-from-worktree; read from HEAD' } else { "historical-blob:$historicalCommit" }
    $source = Source-Text $path
    $lines = $source -split '\r?\n'
    $records.Add(@{path=$path;sourceState=$state;lineCount=$lines.Count})
    for ($i=0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $specs = [System.Collections.Generic.List[object]]::new()
        foreach ($match in [regex]::Matches($line, '(?:\b(?:import|export)\s+.*?\bfrom\s*|\bimport\s*|\brequire\s*\(\s*|\bimport\s*\(\s*)["'']([^"'']+)["'']')) {
            $specs.Add(@{spec=$match.Groups[1].Value;form='literal'})
        }
        foreach ($match in [regex]::Matches($line, '\bnew\s+(?:Shared)?Worker\s*\(\s*new\s+URL\s*\(\s*["'']([^"'']+)["'']')) {
            $specs.Add(@{spec=$match.Groups[1].Value;form='worker-url'})
        }
        foreach ($match in [regex]::Matches($line, '\bimportScripts\s*\(\s*["'']([^"'']+)["'']')) {
            $specs.Add(@{spec=$match.Groups[1].Value;form='importScripts'})
        }
        foreach ($match in [regex]::Matches($line, '\bpreload\s*:\s*path\.join\s*\(\s*__dirname\s*,\s*["'']([^"'']+)["'']')) {
            $specs.Add(@{spec='./'+$match.Groups[1].Value;form='browser-preload'})
        }
        foreach ($match in [regex]::Matches($line, '\brequire\s*\(\s*path\.join\s*\(\s*__dirname\s*,\s*["'']([^"'']+)["'']')) {
            $specs.Add(@{spec='./'+$match.Groups[1].Value;form='require-literal-join'})
        }
        foreach ($match in [regex]::Matches($line, '\b(?:fork|spawn)\s*\(\s*["'']([^"'']+)["'']')) {
            $processEdges.Add(@{from=$path;line=$i+1;spec=$match.Groups[1].Value;form='child-process-literal';disposition='not assumed to be a JavaScript module; inspect executable target'})
        }
        foreach ($item in $specs) {
            $target = Resolve-Import $path $item.spec
            $edge = @{from=$path;line=$i+1;spec=$item.spec;to=$target;form=$item.form}
            if ($path -eq 'electron/main.cjs' -and $item.spec -match 'scene_capture|debug_window') {
                $edge.reason = 'conditional debug/diagnostic path; excluded from normal runtime'
                $excludeDiagnostic.Add($edge)
            } elseif ($target) {
                $edges.Add($edge)
                $queue.Enqueue($target)
            } elseif ($item.spec -match '\.(?:css|html|png|jpe?g|svg|json)$') {
                $edge.reason = 'non-JavaScript asset import; no function inventory'
                $assetEdges.Add($edge)
            } elseif ($item.spec.StartsWith('.') -or $item.spec.StartsWith('/src/')) {
                $edge.reason = 'local target unresolved'
                $unresolved.Add($edge)
            } else {
                $edge.reason = 'external package import; record package dependency separately'
                $externalEdges.Add($edge)
            }
        }
        if ($line -match '\b(?:import|require)\s*\(' -and $specs.Count -eq 0) {
            $unresolved.Add(@{from=$path;line=$i+1;reason='computed or multiline dynamic import/require; source review required'})
        }
        if ($line -match '\bnew\s+(?:Shared)?Worker\s*\(' -and -not($specs | Where-Object form -eq 'worker-url')) {
            $unresolved.Add(@{from=$path;line=$i+1;reason='computed Worker target; source review required'})
        }
        if ($line -match '\bimportScripts\s*\(' -and -not($specs | Where-Object form -eq 'importScripts')) {
            $unresolved.Add(@{from=$path;line=$i+1;reason='computed importScripts target; source review required'})
        }
    }
}

$result = [ordered]@{
    format='nwn79-old-normal-js-reachability-v1'
    inventoryStatus='mechanical import closure using worktree, HEAD and specified historical commit; function reachability and conditional edges require review'
    historicalCommit=$historicalCommit
    entrypoints=@('electron/main.cjs','src/main.js')
    reachableFiles=@($records | Sort-Object path)
    importEdges=@($edges)
    excludedConditionalDiagnosticEdges=@($excludeDiagnostic)
    nonFunctionAssetEdges=@($assetEdges)
    externalPackageEdges=@($externalEdges)
    childProcessLiteralEdges=@($processEdges)
    htmlScriptEdges=@(@{from='HEAD:index.html:174';to='src/main.js';form='module-script';status='verified old renderer entrypoint'})
    unresolvedEdges=@($unresolved)
    counts=@{reachableFiles=$records.Count;present=@($records | Where-Object sourceState -eq 'present').Count;deletedFromWorktree=@($records | Where-Object sourceState -ne 'present').Count;literalEdges=$edges.Count;unresolvedEdges=$unresolved.Count;excludedDiagnosticEdges=$excludeDiagnostic.Count;assetEdges=$assetEdges.Count;externalPackageEdges=$externalEdges.Count}
}
[IO.File]::WriteAllText($OutputPath, (($result | ConvertTo-Json -Depth 12) + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output ($result.counts | ConvertTo-Json -Compress)
