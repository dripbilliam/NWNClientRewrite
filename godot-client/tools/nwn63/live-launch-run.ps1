param([Parameter(Mandatory=$true)][string]$Config)
$ErrorActionPreference='Stop'
if($env:NWN63_LIVE_RUN-ne'coordinator'){throw 'Coordinator live-run gate missing'}
if($env:NWN63_FPS_LEASE-ne'root-exclusive'){throw 'Exclusive FPS lease missing'}
$liveConfigFile=[IO.Path]::GetFullPath($Config)
& node (Join-Path $PSScriptRoot 'live-launch-stage.cjs') verify-only ('--config='+$liveConfigFile)
if($LASTEXITCODE-ne0){throw 'Frozen live candidate verification failed'}
$liveConfig=Get-Content -LiteralPath $liveConfigFile -Raw|ConvertFrom-Json
foreach($name in @('launch.json','launcher.stdout.log','launcher.stderr.log')){if(Test-Path -LiteralPath (Join-Path $liveConfig.out $name)){throw 'Fresh live launch evidence label required'}}
. $liveConfig.screenHelper
$liveScreen=Get-NativeSecondaryScreen
if($liveScreen-lt0){throw 'No secondary monitor is currently available'}
$liveStart=[Diagnostics.ProcessStartInfo]::new()
$liveStart.FileName=$liveConfig.electron
$liveStart.WorkingDirectory=Split-Path -Parent $liveConfig.project
$liveStart.UseShellExecute=$false
$liveStart.CreateNoWindow=$true
$liveStart.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$liveStart.RedirectStandardOutput=$true
$liveStart.RedirectStandardError=$true
foreach($name in @($liveStart.Environment.Keys)){if($name.StartsWith('NWN_',[StringComparison]::OrdinalIgnoreCase)-or$name-in@('ELECTRON_RUN_AS_NODE','NODE_OPTIONS')){$liveStart.Environment.Remove($name)|Out-Null}}
$liveStart.Environment['NWN_PARTICLE_KERNEL']='compiled'
$liveStart.Environment['NWN_PARTICLE_BACKEND']='native'
$liveStart.Environment['NWN63_LIVE_CONFIG']=$liveConfigFile
$liveStart.Environment['NODE_OPTIONS']='--require="'+$liveConfig.bootstrapPreload.Replace('\','/')+'"'
foreach($argument in $liveConfig.bootstrapArguments){$liveStart.ArgumentList.Add([string]$argument)}
$liveStart.ArgumentList.Add('--native-screen='+$liveScreen)
$stdout=[IO.File]::Open((Join-Path $liveConfig.out 'launcher.stdout.log'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
$stderr=[IO.File]::Open((Join-Path $liveConfig.out 'launcher.stderr.log'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
$liveChild=[Diagnostics.Process]::Start($liveStart)
try{
 $stdoutCopy=$liveChild.StandardOutput.BaseStream.CopyToAsync($stdout)
 $stderrCopy=$liveChild.StandardError.BaseStream.CopyToAsync($stderr)
 @{version=1;issue='NWN-63';pid=$liveChild.Id;createdFileTimeUtcExact=$liveChild.StartTime.ToUniversalTime().ToFileTimeUtc().ToString([Globalization.CultureInfo]::InvariantCulture);run=$liveConfig.run;screen=$liveScreen;sourceIdentity=$liveConfig.sourceIdentity;engineSha256=$liveConfig.engineSha256;kernelSha256=$liveConfig.kernelSha256;normalEngine=$true;tracy=$false;automaticLogin=$false}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $liveConfig.out 'launch.json') -Encoding utf8
 Write-Output ('Opened frozen NWN-63 candidate on secondary monitor '+$liveScreen+'; launcher PID '+$liveChild.Id)
 $liveChild.WaitForExit()
 [Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($stdoutCopy,$stderrCopy)).GetAwaiter().GetResult()
 Write-Output ('Frozen NWN-63 candidate exited '+$liveChild.ExitCode)
 exit $liveChild.ExitCode
}finally{$stdout.Dispose();$stderr.Dispose();$liveChild.Dispose()}
