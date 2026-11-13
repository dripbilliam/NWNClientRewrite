param([Parameter(Mandatory=$true)][string]$Config)
$ErrorActionPreference='Stop'
$reviewConfig=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
if(Test-Path -LiteralPath (Join-Path $reviewConfig.out 'launch.json')){throw 'Review stage already launched'}
$reviewInfo=[Diagnostics.ProcessStartInfo]::new()
$reviewInfo.FileName=$reviewConfig.electron
$reviewInfo.WorkingDirectory=Split-Path -Parent $reviewConfig.project
$reviewInfo.UseShellExecute=$false
$reviewInfo.CreateNoWindow=$true
$reviewInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$reviewInfo.RedirectStandardOutput=$true
$reviewInfo.RedirectStandardError=$true
foreach($reviewName in @($reviewInfo.Environment.Keys)){if($reviewName.StartsWith('NWN_',[StringComparison]::OrdinalIgnoreCase)-or$reviewName-in@('ELECTRON_RUN_AS_NODE','NODE_OPTIONS')){$reviewInfo.Environment.Remove($reviewName)|Out-Null}}
$reviewInfo.Environment['NWN_PARTICLE_KERNEL']='compiled'
$reviewInfo.Environment['NWN_PARTICLE_BACKEND']='native'
$reviewInfo.Environment['NWN_LIVE_REVIEW_CONFIG']=[IO.Path]::GetFullPath($Config)
$reviewInfo.Environment['NODE_OPTIONS']='--require="'+(Join-Path $reviewConfig.source 'bootstrap-preload.cjs').Replace('\','/')+'"'
foreach($reviewArgument in $reviewConfig.bootstrapArguments){$reviewInfo.ArgumentList.Add($reviewArgument)}
. (Join-Path $reviewConfig.source 'native-window-screen.ps1')
$reviewScreen=Get-NativeSecondaryScreen
if($reviewScreen-ge0){$reviewInfo.ArgumentList.Add('--native-screen='+$reviewScreen)}
$reviewChild=[Diagnostics.Process]::Start($reviewInfo)
$reviewStdout=[IO.File]::Create((Join-Path $reviewConfig.out 'launcher.stdout.log'))
$reviewStderr=[IO.File]::Create((Join-Path $reviewConfig.out 'launcher.stderr.log'))
$reviewOutTask=$reviewChild.StandardOutput.BaseStream.CopyToAsync($reviewStdout)
$reviewErrTask=$reviewChild.StandardError.BaseStream.CopyToAsync($reviewStderr)
@{version=1;pid=$reviewChild.Id;controllerPid=$PID;run=$reviewConfig.run;screen=$reviewScreen;normalEngine=$true;tracy=$false;automaticLogin=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $reviewConfig.out 'launch.json') -Encoding utf8
Write-Output ('Opened reviewed client; launcher PID '+$reviewChild.Id)
$reviewChild.WaitForExit()
[Threading.Tasks.Task]::WhenAll([Threading.Tasks.Task[]]@($reviewOutTask,$reviewErrTask)).GetAwaiter().GetResult()
$reviewStdout.Dispose();$reviewStderr.Dispose()
Write-Output ('Reviewed client exited '+$reviewChild.ExitCode)
exit $reviewChild.ExitCode
