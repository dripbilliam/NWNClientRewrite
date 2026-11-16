param([Parameter(Mandatory)][string]$OutputRoot,[switch]$Graphical)
$ErrorActionPreference='Stop'
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$client=Join-Path $workspace 'godot-client'
$output=[IO.Path]::GetFullPath($OutputRoot)
$profile=Join-Path $output 'profile'
$bic=Join-Path $profile 'localvault/levelup.bic'
$settings=Join-Path $output 'settings'
$userData=Join-Path $output 'user-data'
$sourceSettings=Join-Path $env:APPDATA 'nwn-model-viewer-research/client-settings.json'
$server=Join-Path $workspace 'scripts/local-multiplayer-server.ps1'
$godotName=if($Graphical){'.tools/Godot_v4.7.2-stable_win64.exe'}else{'.tools/Godot_v4.7.2-stable_win64_console.exe'}
$godot=Join-Path $client $godotName
$install=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall'))
if(-not$output.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not(Test-Path -LiteralPath $bic -PathType Leaf) -or -not(Test-Path -LiteralPath $sourceSettings -PathType Leaf)){throw 'Private Godot level-up fixture or settings source unavailable'}
if((Get-Content -LiteralPath $sourceSettings -Raw|ConvertFrom-Json).version -ne 3){throw 'Private level-up check requires an imported Godot settings store'}
if(Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue){throw 'Private server port 5121 occupied'}
if(Test-Path -LiteralPath (Join-Path $output 'levelup.json')){throw 'Private level-up receipt already exists'}
New-Item -ItemType Directory -Path $settings,$userData -Force | Out-Null
Copy-Item -LiteralPath $sourceSettings -Destination (Join-Path $settings 'client-settings.json')
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$godot;$start.WorkingDirectory=$client;$start.UseShellExecute=$false;$start.CreateNoWindow=(-not$Graphical)
$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.Environment['APPDATA']=$userData
$arguments=@()
if(-not$Graphical){$arguments+='--headless'}
$arguments+=@('--path',$client,'--script','res://native_direct_session_world.gd','--','--direct-session',('--direct-install='+$install),('--direct-profile='+$profile),('--direct-settings='+$settings),('--report='+(Join-Path $output 'levelup.json')),'--direct-headless-check=true','--direct-headless-levelup-check=true','--level-source-check=true','--level-source-case=wizard-multiclass','--direct-host=127.0.0.1','--direct-port=5121','--direct-local-bic=levelup.bic')
foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
$process=$null;$started=$false
try{
 & $server -Action Start -Port 5121 -Module Prelude | Out-Null
 $started=$true
 $deadline=[DateTime]::UtcNow.AddSeconds(30)
 while(-not(Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue)){
  if([DateTime]::UtcNow -gt$deadline){throw 'Private Prelude server did not bind'}
  Start-Sleep -Milliseconds 200
 }
 $process=[Diagnostics.Process]::Start($start)
 if($process -eq $null){throw 'Godot direct level-up check did not start'}
 $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
 if(-not$process.WaitForExit(200000)){$process.Kill($true);[void]$process.WaitForExit(10000);throw 'Godot direct level-up check timed out'}
 [IO.File]::WriteAllText((Join-Path $output 'levelup.stdout.log'),$stdout.Result)
 [IO.File]::WriteAllText((Join-Path $output 'levelup.stderr.log'),$stderr.Result)
 $receipt=if(Test-Path -LiteralPath (Join-Path $output 'levelup.json')){Get-Content -LiteralPath (Join-Path $output 'levelup.json') -Raw|ConvertFrom-Json}else{$null}
 [pscustomobject]@{exitCode=$process.ExitCode;success=$receipt.success;failure=$receipt.failure;levelUp=$receipt.direct_levelup_check;wait=$receipt.direct_levelup_wait;events=$receipt.direct_levelup_events;outbound=$receipt.direct_levelup_outbound;progress=$receipt.direct_levelup_probe_progress;receipt=(Join-Path $output 'levelup.json')}|ConvertTo-Json -Depth 10
}finally{
 if($process -and -not$process.HasExited){$process.Kill($true);[void]$process.WaitForExit(10000)}
 if($started){& $server -Action Stop -Port 5121 | Out-Null}
}
