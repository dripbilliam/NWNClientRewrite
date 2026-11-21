param([Parameter(Mandatory=$true)][string]$Suite,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$SuiteSha,[switch]$Run)
$ErrorActionPreference='Stop'
if(-not$Run){throw 'Source-only isolated suite; require a new authorized native window'}
$suiteFile=[IO.Path]::GetFullPath($Suite)
if((Get-FileHash -LiteralPath $suiteFile).Hash.ToLowerInvariant()-ne$SuiteSha){throw 'Explicit isolated suite pin differs'}
$suiteData=Get-Content -LiteralPath $suiteFile -Raw|ConvertFrom-Json
$suiteRunner=@($suiteData.pins|Where-Object file -EQ $PSCommandPath)
if($suiteRunner.Count-ne1-or(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()-ne$suiteRunner[0].sha256){throw 'Frozen isolated queue source differs'}
& node (Join-Path $PSScriptRoot 'compare.cjs') --phase=pre ('--suite='+$suiteFile) ('--suite-sha='+$SuiteSha)
if($LASTEXITCODE-ne0){throw 'Isolated whole-capsule source precheck rejected'}
foreach($suiteCase in @($suiteData.jobs|Select-Object -ExpandProperty case -Unique)){
 foreach($suiteRole in @('baseline','candidate')){
  $suiteJob=@($suiteData.jobs|Where-Object{$_.case-eq$suiteCase-and$_.role-eq$suiteRole})
  if($suiteJob.Count-ne1){throw 'Exactly one owned child per case and role required'}
  & (Join-Path $PSScriptRoot 'run-child.ps1') -Suite $suiteFile -SuiteSha $SuiteSha -Index $suiteJob[0].index -Run
  if($LASTEXITCODE-ne0){throw 'Isolated child rejected; fail-fast native closure retained'}
 }
 & node (Join-Path $PSScriptRoot 'compare.cjs') --phase=case ('--suite='+$suiteFile) ('--suite-sha='+$SuiteSha) ('--case='+$suiteCase)
 # A transcript/error-policy rejection is retained; collect independent later cases.
}
& node (Join-Path $PSScriptRoot 'compare.cjs') --phase=suite ('--suite='+$suiteFile) ('--suite-sha='+$SuiteSha)
if($LASTEXITCODE-ne0){throw 'Isolated differential suite is NOT accepted; inspect retained exact case/log rejections'}
