param([string]$Scratch='')
$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'run-focused-tests.ps1'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$root=if($Scratch){[IO.Path]::GetFullPath($Scratch)}else{Join-Path $workspace ('.cache/nwn79-focused-runner-'+[guid]::NewGuid().ToString('N'))}
if(-not$root.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Focused runner scratch escaped workspace'}
if(Test-Path -LiteralPath $root){throw 'Focused runner scratch must be fresh'}
New-Item -ItemType Directory -Path $root -Force|Out-Null
try{
 $positive=Join-Path $root 'positive';$negative=Join-Path $root 'negative'
 $shell=(Get-Command pwsh -ErrorAction Stop).Source
 & $shell -NoProfile -File $runner -Cases ps-local-smoke-receipt -OutputRoot $positive|Out-Null
 if($LASTEXITCODE -ne 0){throw 'Focused runner rejected passing PowerShell case'}
 $passed=Get-Content (Join-Path $positive 'summary.json') -Raw|ConvertFrom-Json
 if($passed.passed -ne $true -or $passed.cases.'ps-local-smoke-receipt'.status -ne 'pass'){throw 'Focused runner positive receipt is incomplete'}
 & $shell -NoProfile -File $runner -Cases _intentional_failure -AllowFailureProbe -OutputRoot $negative|Out-Null
 if($LASTEXITCODE -eq 0){throw 'Focused runner swallowed child test failure'}
 $failed=Get-Content (Join-Path $negative 'summary.json') -Raw|ConvertFrom-Json
 if($failed.passed -ne $false -or $failed.cases._intentional_failure.exitCode -ne 23 -or $failed.cases._intentional_failure.status -ne 'fail'){throw 'Focused runner negative receipt did not preserve child exit'}
 [ordered]@{format='nwn79-focused-runner-gate-v1';positive='ps-local-smoke-receipt';negative='child exit 23';passed=$true;nodeInvoked=$false;serverInvoked=$false}|ConvertTo-Json -Depth 3
}finally{if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}}
