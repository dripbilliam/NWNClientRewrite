param([Parameter(Mandatory=$true)][string]$Config)
$ErrorActionPreference='Stop'
& node (Join-Path $PSScriptRoot 'current-session.cjs') verify $Config
if($LASTEXITCODE-ne0){throw 'Current Tracy session changed'}
$tracyCurrent=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
if(Test-Path -LiteralPath (Join-Path $tracyCurrent.out 'launch.json')){throw 'Fresh session launch required'}
$tracyStart=[Diagnostics.ProcessStartInfo]::new()
$tracyStart.FileName=$tracyCurrent.electron
$tracyStart.WorkingDirectory=Split-Path -Parent $tracyCurrent.project
$tracyStart.UseShellExecute=$false
$tracyStart.CreateNoWindow=$true
foreach($tracyName in @($tracyStart.Environment.Keys)){if($tracyName.StartsWith('NWN_',[StringComparison]::OrdinalIgnoreCase)-or$tracyName-in@('ELECTRON_RUN_AS_NODE','NODE_OPTIONS')){$tracyStart.Environment.Remove($tracyName)|Out-Null}}
$tracyStart.Environment['NWN_PARTICLE_KERNEL']='compiled'
$tracyStart.Environment['NWN_PARTICLE_BACKEND']='native'
$tracyStart.Environment['NWN_PRIVATE_TRACY_CONFIG']=[IO.Path]::GetFullPath($Config)
$tracyStart.Environment['NODE_OPTIONS']='--require="'+(Join-Path $tracyCurrent.source 'bootstrap-preload.cjs').Replace('\','/')+'"'
foreach($tracyArgument in $tracyCurrent.bootstrapArguments){$tracyStart.ArgumentList.Add($tracyArgument)}
. $tracyCurrent.screenHelper
$tracyScreen=Get-NativeSecondaryScreen
if($tracyScreen-ge0){$tracyStart.ArgumentList.Add('--native-screen='+$tracyScreen)}
$tracyChild=[Diagnostics.Process]::Start($tracyStart)
@{version=1;pid=$tracyChild.Id;run=$tracyCurrent.run;diagnosticOnly=$true;originalParticleSystem=$true;screen=$tracyScreen;automaticLogin=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $tracyCurrent.out 'launch.json') -Encoding utf8
Write-Output ('Opened current Tracy client; launcher PID '+$tracyChild.Id)
