param([Parameter(Mandatory=$true)][string]$Engine,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$EngineSha,[ValidatePattern('^[a-z0-9-]+$')][string]$Label='a')
$ErrorActionPreference='Stop'
$traceRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$traceOut=Join-Path $traceRoot ('.cache/native-render-gap/original/script-owner/fixture-'+$Label)
$traceManifest=Get-Content -LiteralPath (Join-Path $traceOut 'manifest.json') -Raw|ConvertFrom-Json
$traceEngine=[IO.Path]::GetFullPath($Engine)
function Assert-TracePins {
 if((Get-FileHash -LiteralPath $traceEngine).Hash.ToLowerInvariant()-ne$EngineSha){throw 'Engine drift'}
 foreach($tracePin in $traceManifest.pins){if((Get-FileHash -LiteralPath (Join-Path $traceManifest.project $tracePin.relative)).Hash.ToLowerInvariant()-ne$tracePin.sha256){throw 'Fixture drift'}}
}
foreach($traceMode in @('control','on')) {
 Assert-TracePins
 $traceRun=Join-Path $traceOut $traceMode
 if(Test-Path -LiteralPath $traceRun){throw 'Preserve variant'}
 New-Item -ItemType Directory -Path $traceRun|Out-Null
 $traceStart=[Diagnostics.ProcessStartInfo]::new()
 $traceStart.FileName=$traceEngine;$traceStart.UseShellExecute=$false;$traceStart.CreateNoWindow=$true;$traceStart.RedirectStandardOutput=$true;$traceStart.RedirectStandardError=$true
 $traceArguments=@('--headless','--rendering-method','dummy','--audio-driver','Dummy','--fixed-fps','1000','--disable-render-loop','--path',$traceManifest.project,'--script','res://fixture.gd','--',('--report='+(Join-Path $traceRun 'native.json')))
 if($traceMode-eq'on'){$traceArguments+='--script-owner-trace=on'}
 foreach($traceArgument in $traceArguments){$traceStart.ArgumentList.Add($traceArgument)}
 $traceStart.Environment['APPDATA']=Join-Path $traceRun 'appdata';$traceStart.Environment['LOCALAPPDATA']=Join-Path $traceRun 'localappdata'
 $traceChild=[Diagnostics.Process]::new();$traceChild.StartInfo=$traceStart
 [void]$traceChild.Start()
 @{pid=$traceChild.Id;engine=$traceEngine;engineSha256=$EngineSha;arguments=$traceArguments;startedUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $traceRun 'process.json') -Encoding utf8
 Write-Output ('Started script-owner fixture '+$traceMode+' PID '+$traceChild.Id)
 $traceStdout=$traceChild.StandardOutput.ReadToEndAsync();$traceStderr=$traceChild.StandardError.ReadToEndAsync()
 if(-not$traceChild.WaitForExit(30000)){$traceChild.Kill();[void]$traceChild.WaitForExit(1000);throw 'Owned headless fixture timed out'}
 $traceCode=$traceChild.ExitCode;$traceOutput=$traceStdout.GetAwaiter().GetResult();$traceError=$traceStderr.GetAwaiter().GetResult();$traceChild.Dispose()
 [IO.File]::WriteAllText((Join-Path $traceRun 'stdout.log'),$traceOutput);[IO.File]::WriteAllText((Join-Path $traceRun 'stderr.log'),$traceError)
 Assert-TracePins
 if($traceCode-ne0-or($traceOutput+$traceError)-match'Parse Error|Compile Error|leaked|still in use|CrashHandler'){Get-Content -LiteralPath (Join-Path $traceRun 'stderr.log') -Tail 25;throw ('Fixture failed '+$traceMode+' exit '+$traceCode)}
 $traceReport=Get-Content -LiteralPath (Join-Path $traceRun 'native.json') -Raw|ConvertFrom-Json
 if(-not$traceReport.success-or$traceReport.failures.Count-ne0-or$traceReport.checks-lt150-or$traceReport.observations.Count-lt45){$traceReport.failures|ConvertTo-Json;throw 'Actual script-owner predicates failed'}
 @{exit=$traceCode;success=$true;checks=$traceReport.checks;observations=$traceReport.observations.Count;finishedUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $traceRun 'receipt.json') -Encoding utf8
}
$traceControl=Get-Content -LiteralPath (Join-Path $traceOut 'control/native.json') -Raw|ConvertFrom-Json
$traceOn=Get-Content -LiteralPath (Join-Path $traceOut 'on/native.json') -Raw|ConvertFrom-Json
if(($traceControl.observations|ConvertTo-Json -Depth 20 -Compress)-cne($traceOn.observations|ConvertTo-Json -Depth 20 -Compress)){throw 'Observable owner/return sequence differs'}
$traceControlErrors=[IO.File]::ReadAllText((Join-Path $traceOut 'control/stderr.log'))
$traceOnErrors=[IO.File]::ReadAllText((Join-Path $traceOut 'on/stderr.log'))
if($traceControlErrors-cne$traceOnErrors){throw 'Intentional error output differs'}
@{version=1;success=$true;engine=$traceEngine;engineSha256=$EngineSha;controlChecks=$traceControl.checks;onChecks=$traceOn.checks;observationRows=$traceOn.observations.Count;exactObservations=$true;exactErrorOutput=$true;registered=$traceOn.final.registered;activeAddress=$traceOn.final.active_id_address_hex;scope='Actual common-engine headless GDScript call/nesting/await/error/reentry/transient destruction/worker differential. Clean shutdown required. No FPS/overhead claim.'}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $traceOut 'acceptance.json') -Encoding utf8
Write-Output 'Script-owner actual VM differential PASS; both children closed.'
