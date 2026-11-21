param([Parameter(Mandatory=$true)][string]$Suite,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$SuiteSha,[switch]$Run)
$ErrorActionPreference='Stop'
if(-not$Run){throw 'Private whole-suite runner requires the root authorized native slot'}
$suiteFile=[IO.Path]::GetFullPath($Suite)
if((Get-FileHash -LiteralPath $suiteFile).Hash.ToLowerInvariant()-ne$SuiteSha){throw 'Exact full-suite manifest differs'}
$suiteData=Get-Content -LiteralPath $suiteFile -Raw|ConvertFrom-Json
$runner=@($suiteData.pins|Where-Object file -EQ $PSCommandPath)
if($runner.Count-ne1-or(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()-ne$runner[0].sha256){throw 'Frozen whole-suite runner differs'}
& node (Join-Path $PSScriptRoot 'verify-child.cjs') --phase=suite-pre ('--suite='+$suiteFile) ('--suite-sha='+$SuiteSha)
if($LASTEXITCODE-ne0){throw 'Whole-suite precheck rejected'}
foreach($job in $suiteData.jobs){
 & (Join-Path $PSScriptRoot 'run-child.ps1') -Suite $suiteFile -SuiteSha $SuiteSha -Index $job.index -Run
 if($LASTEXITCODE-ne0){throw 'Whole-suite child rejected; exact outputs retained'}
}
& node (Join-Path $PSScriptRoot 'verify-child.cjs') --phase=suite-post ('--suite='+$suiteFile) ('--suite-sha='+$SuiteSha)
if($LASTEXITCODE-ne0){throw 'Whole-suite final acceptance rejected'}
