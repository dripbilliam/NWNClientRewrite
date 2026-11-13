[CmdletBinding()]
param([ValidateRange(3,8)][int]$Seconds=3)
$ErrorActionPreference='Stop'
$tracyStage=Join-Path $PSScriptRoot '.cache/native-tracy/live/manual-cache-a'
$tracyConfigFile=Join-Path $tracyStage 'config.json'
$tracyConfig=Get-Content -LiteralPath $tracyConfigFile -Raw|ConvertFrom-Json
& $tracyConfig.node (Join-Path $tracyConfig.source 'verify.cjs') $tracyConfigFile
if($LASTEXITCODE-ne0){throw 'Private Tracy client files changed'}
$tracyStartFile=Join-Path $tracyStage 'native-start.json'
if(-not(Test-Path -LiteralPath $tracyStartFile)){throw 'Open tracy-client.ps1 and enter the game first'}
$tracyStart=Get-Content -LiteralPath $tracyStartFile -Raw|ConvertFrom-Json
$tracyClient=Get-Process -Id $tracyStart.pid -ErrorAction Stop
if(-not$tracyClient.MainModule.FileName.Equals($tracyConfig.engineLaunch,[StringComparison]::OrdinalIgnoreCase)){throw 'Recorded PID no longer belongs to this private client'}
$tracyLifetime=$tracyClient.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()
$tracyModules=@($tracyClient.Modules|Where-Object ModuleName -EQ 'nwn-particle-kernel.dll')
if($tracyModules.Count-ne1-or(Get-FileHash -LiteralPath $tracyModules[0].FileName).Hash.ToLowerInvariant()-ne$tracyConfig.particleSha256){throw 'Actual private native DLL differs'}
$tracyStartupFile=Join-Path $PSScriptRoot ('reports/'+$tracyConfig.run+'.startup.json')
$tracyStartup=Get-Content -LiteralPath $tracyStartupFile -Raw|ConvertFrom-Json
if($tracyStartup.verification.status-ne'observed'-or$tracyStartup.worldVerification.status-ne'observed'){throw 'Enter an area and wait for verified world startup before capturing'}
if($tracyStartup.source.sha256-ne$tracyConfig.predictedSourceIdentity-or$tracyStartup.runtime.executableSha256-ne$tracyConfig.engineSha256){throw 'Live startup does not identify this private client'}
$tracyManifest=Get-Content -LiteralPath (Join-Path $tracyStage 'manifest.json') -Raw|ConvertFrom-Json
$tracyDescriptor=Get-Content -LiteralPath (Join-Path $tracyConfig.view $tracyConfig.descriptorRelative) -Raw|ConvertFrom-Json
if(($tracyStartup.renderCore.flags|ConvertTo-Json -Compress)-ne($tracyDescriptor.fullFunctionalFlags|ConvertTo-Json -Compress)){throw 'Live options differ from all16 selected flags'}
$tracyLabel='arelith-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
$tracyInput=Join-Path $tracyStage ($tracyLabel+'-expectations.json')
@{cpuZones=@(@{name='Main::iteration';minimumEvents=5},@{name='NWNCapture/Render/draw_cpu';minimumEvents=5});minimumCPUThreads=2;minimumSpanSeconds=1.5;maximumSpanSeconds=$Seconds+10;differentThreadZones=(,@('Main::iteration','NWNCapture/Render/draw_cpu'));gpu=@{required=$false}}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $tracyInput -Encoding utf8
$tracyBuilder=Join-Path $PSScriptRoot 'tools/native-tracy/capture-c/capture-plan.cjs'
$tracyBuildProof=$tracyManifest.sourceReceipts.engine
$tracyPrepared=& $tracyConfig.node $tracyBuilder --mode=prepare ('--label='+$tracyLabel) --port=48135 ('--seconds='+$Seconds) ('--client='+$tracyConfig.engineLaunch) ('--client-sha='+$tracyConfig.engineSha256) ('--client-proof='+$tracyBuildProof.file) ('--client-proof-sha='+$tracyBuildProof.sha256) ('--expectations='+$tracyInput) ('--expectations-sha='+(Get-FileHash -LiteralPath $tracyInput).Hash.ToLowerInvariant()) --export-mb=256
if($LASTEXITCODE-ne0){throw 'Could not prepare bounded capture'}
$tracyPrepared=$tracyPrepared|ConvertFrom-Json
Write-Output ('Capture starts in 3 seconds and records '+$Seconds+' seconds. Switch to the game and perform the movement or activity you want to inspect.')
Start-Sleep -Seconds 3
& $tracyPrepared.run -Plan $tracyPrepared.file -PlanSha $tracyPrepared.sha256 -ClientPid $tracyClient.Id -ClientFileTimeUtc $tracyLifetime -Run
Write-Output ('Saved '+$tracyPrepared.trace)
