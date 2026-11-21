param([Parameter(Mandatory=$true)][string]$Config,[switch]$Launch,[switch]$Diagnostic,[string]$NativeAcceptance)
$ErrorActionPreference='Stop'
$liveConfig=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
if(-not$Launch){Write-Output 'PREPARED ONLY: no process started. Native parser/lifetime acceptance and materialized view are required.';return}
& $liveConfig.node (Join-Path $liveConfig.out 'source/verify-source.cjs') $Config
if($LASTEXITCODE-ne0){throw 'Private live source verification failed'}
if(-not$NativeAcceptance){throw 'Private native parser/functional/lifetime acceptance is required before launch'}
$liveAcceptance=Get-Content -LiteralPath $NativeAcceptance -Raw|ConvertFrom-Json
$liveMaterialized=Join-Path $liveConfig.out 'materialized.json'
if(-not(Test-Path -LiteralPath $liveMaterialized)){throw 'Source view is not materialized'}
if(-not$liveAcceptance.nativeParsed-or-not$liveAcceptance.functionalPassed-or-not$liveAcceptance.lifetimePassed-or$liveAcceptance.stageManifestSha256-ne(Get-FileHash -LiteralPath (Join-Path $liveConfig.out 'manifest.json')).Hash.ToLowerInvariant()){throw 'Acceptance is not for this exact private stage'}
foreach($livePin in $liveConfig.launchPins){if((Get-FileHash -LiteralPath $livePin.file).Hash.ToLowerInvariant()-ne$livePin.sha256){throw 'Private launch/source pin drift'}}
if((Get-FileHash -LiteralPath $liveConfig.host).Hash.ToLowerInvariant()-ne$liveConfig.hostSha256-or(Get-FileHash -LiteralPath $liveConfig.bootstrap).Hash.ToLowerInvariant()-ne$liveConfig.bootstrapSha256){throw 'Ordinary host/bootstrap drift'}
if((Get-FileHash -LiteralPath $liveConfig.engine).Hash.ToLowerInvariant()-ne$liveConfig.engineSha256){throw 'Accepted engine drift'}
if((Get-FileHash -LiteralPath $liveConfig.engineLaunch).Hash.ToLowerInvariant()-ne$liveConfig.engineSha256){throw 'Independent private engine copy drift'}
if(Test-Path -LiteralPath (Join-Path $liveConfig.out 'launch.json')){throw 'Preserve prior launch'}
$liveStart=[Diagnostics.ProcessStartInfo]::new();$liveStart.FileName=$liveConfig.electron;$liveStart.WorkingDirectory=Split-Path -Parent $liveConfig.project;$liveStart.UseShellExecute=$false;$liveStart.CreateNoWindow=$true
$liveStart.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
$liveStart.Environment['NWN_PARTICLE_KERNEL']='compiled';$liveStart.Environment['NWN_PRIVATE_LIVE_CONFIG']=[IO.Path]::GetFullPath($Config)
$liveStart.Environment['NWN_PRIVATE_TRANSPORT_DIAGNOSTIC']=if($Diagnostic){'1'}else{'0'}
$liveStart.Environment['NODE_OPTIONS']='--require="'+(Join-Path $liveConfig.out 'source/bootstrap-preload.cjs').Replace('\','/')+'"'
foreach($liveArgument in @($liveConfig.bootstrap,('--run='+$liveConfig.run),'--public-servers','--detailed-profiling=off')){$liveStart.ArgumentList.Add($liveArgument)}
. $liveConfig.screenHelper
$liveScreen=Get-NativeSecondaryScreen
if($liveScreen-ge0){$liveStart.ArgumentList.Add('--native-screen='+$liveScreen)}
$liveChild=[Diagnostics.Process]::new();$liveChild.StartInfo=$liveStart;[void]$liveChild.Start()
@{version=1;pid=$liveChild.Id;createdFileTimeUtcExact=$liveChild.StartTime.ToUniversalTime().ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture);run=$liveConfig.run;diagnosticRequested=[bool]$Diagnostic;automaticLogin=$false;automaticFrontendInputs=$false;scope='Private source-view normal menu. User alone selects server, logs in and plays. Independent host/native exact-lifetime watcher is still required before a measurement window.'}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $liveConfig.out 'launch.json') -Encoding utf8
Write-Output ('Opened user-controlled private menu; launcher PID '+$liveChild.Id)
