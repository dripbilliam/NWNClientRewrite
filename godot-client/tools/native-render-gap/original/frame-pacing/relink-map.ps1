param([Parameter(Mandatory=$true)][string]$Plan,[switch]$Execute)
$ErrorActionPreference='Stop'
$mapPlan=Get-Content -LiteralPath $Plan -Raw|ConvertFrom-Json
$mapPlanSha=(Get-FileHash -LiteralPath $Plan).Hash.ToLowerInvariant()
$mapOut=Split-Path -Parent ([IO.Path]::GetFullPath($Plan))
function Assert-MapInputs {
 foreach($mapPin in @(@{file=$mapPlan.invocation;sha=$mapPlan.invocationSha256},@{file=$mapPlan.compiler;sha=$mapPlan.compilerSha256},@{file=$mapPlan.python;sha=$mapPlan.pythonSha256})){if((Get-FileHash -LiteralPath $mapPin.file).Hash.ToLowerInvariant()-ne$mapPin.sha){throw 'Map tool/invocation input drift'}}
 foreach($mapPin in $mapPlan.sourcePins){if((Get-FileHash -LiteralPath (Join-Path $mapPlan.source $mapPin.relative)).Hash.ToLowerInvariant()-ne$mapPin.sha256){throw 'Pinned build-script drift'}}
 if((Get-FileHash -LiteralPath $mapPlan.binary).Hash.ToLowerInvariant()-ne$mapPlan.baselineBinarySha256){throw 'Built baseline changed; prepare a new map plan for the new exact binary'}
}
Assert-MapInputs
if($Execute){
 $mapDry=Get-Content -LiteralPath (Join-Path $mapOut 'dry-run.json') -Raw|ConvertFrom-Json
 if(-not$mapDry.safeLinkOnly-or$mapDry.planSha256-ne$mapPlanSha){throw 'A matching link-only dry-run receipt is required'}
 if(Test-Path -LiteralPath $mapPlan.mapFile){throw 'Preserve existing map'}
 if(Test-Path -LiteralPath (Join-Path $mapOut 'baseline-pin.json')){throw 'Preserve prior relink baseline pin'}
 # The immutable build artifact is already retained; do not duplicate another
 # ninety-megabyte executable merely to refer to the same baseline bytes.
 @{file=$mapPlan.binary;sha256=$mapPlan.baselineBinarySha256}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $mapOut 'baseline-pin.json') -Encoding utf8
}
$mapStart=[Diagnostics.ProcessStartInfo]::new();$mapStart.FileName=$mapPlan.python;$mapStart.WorkingDirectory=$mapPlan.source;$mapStart.UseShellExecute=$false;$mapStart.CreateNoWindow=$true;$mapStart.RedirectStandardOutput=$true;$mapStart.RedirectStandardError=$true
$mapStart.Environment['PATH']=(Split-Path -Parent $mapPlan.compiler)+';'+$env:PATH
foreach($mapArgument in $mapPlan.arguments){$mapStart.ArgumentList.Add($mapArgument)}
if(-not$Execute){$mapStart.ArgumentList.Add('--dry-run')}
$mapChild=[Diagnostics.Process]::new();$mapChild.StartInfo=$mapStart;[void]$mapChild.Start();$mapStdout=$mapChild.StandardOutput.ReadToEndAsync();$mapStderr=$mapChild.StandardError.ReadToEndAsync();Write-Output ('Started owned SCons map '+$(if($Execute){'relink'}else{'dry-run'})+' PID '+$mapChild.Id)
$mapChild.WaitForExit();$mapCode=$mapChild.ExitCode;$mapText=$mapStdout.GetAwaiter().GetResult();$mapError=$mapStderr.GetAwaiter().GetResult();$mapChild.Dispose()
$mapKind=if($Execute){'relink'}else{'dry-run'};[IO.File]::WriteAllText((Join-Path $mapOut ($mapKind+'.stdout.log')),$mapText);[IO.File]::WriteAllText((Join-Path $mapOut ($mapKind+'.stderr.log')),$mapError)
if($mapCode-ne0){throw ('SCons map command failed '+$mapCode)}
if(-not$Execute){
 $mapSafe=$mapText-match'-Map='-and$mapText-notmatch'(?m)(?:^|\s)-c(?:\s|$)|Compiling |Generating |\.console\.exe'
 @{planSha256=$mapPlanSha;exit=$mapCode;safeLinkOnly=$mapSafe;stdoutSha256=(Get-FileHash -LiteralPath (Join-Path $mapOut 'dry-run.stdout.log')).Hash.ToLowerInvariant();scope='Dry-run only; no link performed. Review stdout before explicit -Execute.'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $mapOut 'dry-run.json') -Encoding utf8
 if(-not$mapSafe){throw 'Dry-run schedules more than the main link or no map-producing link; do not execute'}
 Assert-MapInputs
}else{
 if(-not(Test-Path -LiteralPath $mapPlan.mapFile)){throw 'Link did not produce the expected map'}
 Copy-Item -LiteralPath (Join-Path $mapPlan.source 'bin/godot.windows.template_release.x86_64.exe') -Destination (Join-Path $mapOut 'after.exe')
 @{planSha256=$mapPlanSha;exit=$mapCode;mapSha256=(Get-FileHash -LiteralPath $mapPlan.mapFile).Hash.ToLowerInvariant();afterSha256=(Get-FileHash -LiteralPath (Join-Path $mapOut 'after.exe')).Hash.ToLowerInvariant();scope='Relink finished. Section-layout/content comparison is mandatory before symbolizing any older binary; no automatic attribution.'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $mapOut 'relink.json') -Encoding utf8
}
