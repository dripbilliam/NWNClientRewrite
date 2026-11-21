param([Parameter(Mandatory=$true)][string]$Config,[switch]$Launch,[string]$NativeAcceptance)
$ErrorActionPreference='Stop'
$tracyConfig=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
if(-not $Launch){Write-Output 'SOURCE PLAN ONLY: no process started. Materialization and exact native/capture/lifetime acceptance are required.';return}
& $tracyConfig.node (Join-Path $tracyConfig.source 'verify.cjs') $Config
if($LASTEXITCODE-ne0){throw 'Private Tracy source/runtime file verification failed'}
if(-not $NativeAcceptance){throw 'Exact-stage native acceptance is required'}
$tracyAcceptance=Get-Content -LiteralPath $NativeAcceptance -Raw|ConvertFrom-Json
$tracyManifestHash=(Get-FileHash -LiteralPath (Join-Path $tracyConfig.out 'manifest.json')).Hash.ToLowerInvariant()
if($tracyAcceptance.stageManifestSha256-ne$tracyManifestHash-or-not$tracyAcceptance.nativeParsed-or-not$tracyAcceptance.functionalPassed-or-not$tracyAcceptance.bridgePassed-or-not$tracyAcceptance.lifetimePassed-or-not$tracyAcceptance.manuallyReviewed){throw 'Private Tracy acceptance is incomplete or for a different stage'}
if(Test-Path -LiteralPath (Join-Path $tracyConfig.out 'launch.json')){throw 'Preserve prior launch evidence'}
$tracyStart=[Diagnostics.ProcessStartInfo]::new();$tracyStart.FileName=$tracyConfig.electron;$tracyStart.WorkingDirectory=Split-Path -Parent $tracyConfig.project;$tracyStart.UseShellExecute=$false;$tracyStart.CreateNoWindow=$true
$tracyStart.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
$tracyStart.Environment['NWN_PARTICLE_KERNEL']='compiled';$tracyStart.Environment['NWN_PRIVATE_TRACY_CONFIG']=[IO.Path]::GetFullPath($Config)
$tracyStart.Environment['NODE_OPTIONS']='--require="'+(Join-Path $tracyConfig.source 'bootstrap-preload.cjs').Replace('\','/')+'"'
foreach($tracyArgument in $tracyConfig.bootstrapArguments){$tracyStart.ArgumentList.Add($tracyArgument)}
# Use the same normal secondary-screen helper, without changing display settings.
. $tracyConfig.screenHelper
$tracyScreen=Get-NativeSecondaryScreen
if($tracyScreen-ge0){$tracyStart.ArgumentList.Add('--native-screen='+$tracyScreen)}
$tracyChild=[Diagnostics.Process]::new();$tracyChild.StartInfo=$tracyStart;[void]$tracyChild.Start()
@{version=1;pid=$tracyChild.Id;createdFileTimeUtcExact=$tracyChild.StartTime.ToUniversalTime().ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture);run=$tracyConfig.run;diagnosticOnly=$true;performanceAccepted=$false;automaticLogin=$false;scope='Private Tracy normal menu. User owns server/login/gameplay. Independent exact native PID/FILETIME/loaded-DLL and connected capture verification remain required.'}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $tracyConfig.out 'launch.json') -Encoding utf8
Write-Output ('Opened user-controlled Tracy menu; launcher PID '+$tracyChild.Id)
