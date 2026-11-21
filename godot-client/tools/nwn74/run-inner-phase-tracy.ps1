[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$stage=Join-Path $project '.cache/nwn74/inner-phase-tracy-a'
$build=Get-Content -LiteralPath (Join-Path $stage 'build-receipt.json') -Raw | ConvertFrom-Json
$driverReceipt=Get-Content -LiteralPath (Join-Path $stage 'driver-receipt.json') -Raw | ConvertFrom-Json
$prior=Get-Content -LiteralPath (Join-Path $project '.cache/nwn74/render-probe-a/staged.json') -Raw | ConvertFrom-Json
$capture=Join-Path $project '.cache/native-tracy/vendor/windows-0.13.0/tracy-capture.exe'
$trace=Join-Path $stage 'inner-phase-c.tracy'
$run='nwn74-inner-phase-tracy-c'
function Hash([string]$file){(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
if(-not $build.success -or -not $build.privateSourceRestored -or -not $build.acceptedSourceUnchanged){throw 'Private build receipt incomplete'}
if((Hash $build.binary.file) -ne $build.binary.sha256 -or (Hash $driverReceipt.driver) -ne $driverReceipt.driverSha256){throw 'Engine or driver differs'}
if((Hash $capture) -ne 'dcd67671e115a4ab047b9a9f181eec38a7873ff708efa139798b661df450fd04'){throw 'Tracy capture tool differs'}
if((Hash (Join-Path $project '.cache/nwn74/render-probe-a/staged.json')) -ne '31e6d21c9d74fb66837445f82637e70df93440195a3128133b8f01b40853460a'){throw 'Replay stage differs'}
if((Hash $prior.selection.file) -ne $prior.selection.sha256 -or (Hash (Join-Path $prior.capture 'recording.json')) -ne $prior.recordingSha256){throw 'Selection or recording differs'}
if(Test-Path -LiteralPath $trace){throw 'Preserve existing trace'}
if(Test-Path -LiteralPath (Join-Path $project "reports/$run.json")){throw 'Preserve existing replay report'}
if((Get-NetTCPConnection -LocalPort 48135 -State Listen -ErrorAction SilentlyContinue)){throw 'Tracy port 48135 already in use'}
if([long](Get-PSDrive C).Free -lt 10GB){throw 'Disk headroom below 10 GiB'}
$receipt=[ordered]@{issue='NWN-74';private=$true;scope='Offline original-scene Forward+ phase trace; no FPS output or comparison';startedUtc=[DateTime]::UtcNow.ToString('o');buildReceiptSha256=Hash (Join-Path $stage 'build-receipt.json');driverReceiptSha256=Hash (Join-Path $stage 'driver-receipt.json');selectionSha256=$prior.selection.sha256;recordingSha256=$prior.recordingSha256;captureToolSha256=Hash $capture;freeBeforeBytes=[long](Get-PSDrive C).Free;trace=$trace;run=$run}
$captureProc=$null
try{
 $captureProc=Start-Process -FilePath $capture -ArgumentList @('-o',('"'+$trace+'"'),'-a','127.0.0.1','-p','48135','-s','60','-m','3') -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $stage 'capture-c.stdout.log') -RedirectStandardError (Join-Path $stage 'capture-c.stderr.log')
 $receipt.capturePid=$captureProc.Id
 Start-Sleep -Milliseconds 300
 $captureProc.Refresh()
 if($captureProc.HasExited){throw "Capture exited before replay: $($captureProc.ExitCode)"}
 $args=@($driverReceipt.driver,"--capture=$($prior.capture)",'--generation=2',"--production-selection=$($prior.selection.file)","--production-selection-sha256=$($prior.selection.sha256)",'--engine=production-selection','--profiling=true','--observe-profile=false','--steady-ms=4000','--preview',"--run=$run")
 & node @args *> (Join-Path $stage 'driver-c.log')
 $receipt.driverExit=$LASTEXITCODE
 $captureProc.Refresh()
 if(-not $captureProc.HasExited){Wait-Process -Id $captureProc.Id -Timeout 75 -ErrorAction SilentlyContinue}
 $captureProc.Refresh()
 $receipt.captureExited=$captureProc.HasExited
 if($captureProc.HasExited){$receipt.captureExit=$captureProc.ExitCode}
 $receipt.reportExists=Test-Path -LiteralPath (Join-Path $project "reports/$run.json")
 if($receipt.reportExists){$receipt.reportSha256=Hash (Join-Path $project "reports/$run.json")}
 $receipt.traceExists=Test-Path -LiteralPath $trace
 if($receipt.traceExists){$receipt.traceBytes=(Get-Item -LiteralPath $trace).Length;$receipt.traceSha256=Hash $trace}
 $receipt.fpsFileAbsent=-not(Test-Path -LiteralPath (Join-Path $project "reports/$run.fps.jsonl"))
 $receipt.success=$receipt.captureExited -and $receipt.captureExit -eq 0 -and $receipt.traceExists -and $receipt.traceBytes -gt 10000 -and $receipt.fpsFileAbsent
}catch{$receipt.failure=$_.Exception.Message;$receipt.success=$false}
finally{
 if($captureProc){$captureProc.Refresh();if(-not $captureProc.HasExited){Stop-Process -Id $captureProc.Id -Force -ErrorAction SilentlyContinue;$receipt.captureStoppedByWatchdog=$true}}
 $receipt.freeAfterBytes=[long](Get-PSDrive C).Free
 $receipt.endedUtc=[DateTime]::UtcNow.ToString('o')
 $receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stage 'capture-c-receipt.json') -Encoding utf8
}
$receipt | ConvertTo-Json -Depth 3
if(-not $receipt.success){exit 1}
