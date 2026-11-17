param(
 [ValidateSet('ServerOnly','ServerOnlyPlay','LocalAllowed')][string]$Mode,
 [Parameter(Mandatory)][string]$SettingsSource,
 [Parameter(Mandatory)][string]$OutputRoot,
 [string]$ProjectRoot='',
 [string]$OwnedServerFixtureRoot='',
 [ValidateRange(20,180)][int]$TimeoutSeconds=130
)
$ErrorActionPreference='Stop'
$sourceProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$project=if($ProjectRoot){[IO.Path]::GetFullPath($ProjectRoot)}else{$sourceProject}
$workspace=[IO.Path]::GetFullPath((Join-Path $sourceProject '..'))
$output=[IO.Path]::GetFullPath($OutputRoot)
$source=[IO.Path]::GetFullPath($SettingsSource)
if(-not(Test-Path -LiteralPath (Join-Path $project 'native_direct_session_world.gd') -PathType Leaf)){throw 'Selected Godot project is unavailable'}
if(-not $output.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($sourceProject+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($project+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)){throw 'OutputRoot must be fresh workspace scratch outside the Godot project'}
$settingsFile=Join-Path $source 'client-settings.json'
if(-not(Test-Path -LiteralPath $settingsFile -PathType Leaf) -or (Get-Content -LiteralPath $settingsFile -Raw|ConvertFrom-Json).version -ne 3){throw 'An isolated imported v3 settings source is required'}
$fixture=Get-Content -LiteralPath (Join-Path $sourceProject 'reports/vault-handoff-fixtures-v6.json') -Raw|ConvertFrom-Json
$seed=if($OwnedServerFixtureRoot){Join-Path ([IO.Path]::GetFullPath($OwnedServerFixtureRoot)) 'profile/servervault/UX7UUPRE/fighter.bic'}else{Join-Path $fixture.vault 'UX7UUPRE/fighter.bic'}
if($OwnedServerFixtureRoot -and $Mode -ne 'ServerOnlyPlay'){throw 'Fresh owned seeded fixture supports only ServerOnlyPlay'}
if($Mode -ne 'LocalAllowed' -and (-not $fixture.serverCharacterSeeded -or -not(Test-Path -LiteralPath $seed -PathType Leaf) -or (Get-FileHash -LiteralPath $seed -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'c7960f2cf99234e4c69883c5139142c6753925a571756af5fa918e1395c0b268')){throw 'Isolated server-vault seed is absent or changed'}
$server=if($OwnedServerFixtureRoot){Join-Path $PSScriptRoot 'vault-create-server.ps1'}else{Join-Path $PSScriptRoot 'vault-policy-server.ps1'}
$godot=Join-Path $project '.tools/Godot_v4.7.2-stable_win64_console.exe'
if(-not(Test-Path -LiteralPath $godot -PathType Leaf) -or (Get-FileHash -LiteralPath $godot -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643'){throw 'Pinned Godot console is absent or changed'}
$install=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall'))
$settings=Join-Path $output 'settings'
$profile=Join-Path $output 'profile'
$userData=Join-Path $output 'user-data'
$report=Join-Path $output 'chooser.json'
$summary=Join-Path $output 'summary.json'
$process=$null
$serverStarted=$false
$serverMode=if($Mode -eq 'LocalAllowed'){'LocalAllowed'}else{'ServerOnly'}
New-Item -ItemType Directory -Path $settings,$profile,$userData -Force|Out-Null
foreach($name in @('client-settings.json','Local State')){$inputFile=Join-Path $source $name;if(Test-Path -LiteralPath $inputFile -PathType Leaf){Copy-Item -LiteralPath $inputFile -Destination (Join-Path $settings $name)}}
try{
 $status=if($OwnedServerFixtureRoot){& $server -Action Status -OutputRoot $OwnedServerFixtureRoot|ConvertFrom-Json}else{& $server -Action Status -Mode $serverMode|ConvertFrom-Json}
 if(@($status.ownedPids).Count -ne 0){throw 'Owned server already running; refusing to take it over'}
 $started=if($OwnedServerFixtureRoot){& $server -Action Start -OutputRoot $OwnedServerFixtureRoot -AllowedSeedSha256 'c7960f2cf99234e4c69883c5139142c6753925a571756af5fa918e1395c0b268'}else{& $server -Action Start -Mode $serverMode}
 $serverStarted=$true
 $ready=$false
 for($i=0;$i -lt 50;$i++){if(@(Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue).Count -gt 0){$ready=$true;break};Start-Sleep -Milliseconds 100}
 if(-not $ready){throw 'Owned server did not bind UDP 5121'}
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$godot;$start.WorkingDirectory=$project;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
 $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.Environment['APPDATA']=$userData
 $modeArg=switch($Mode){'ServerOnly'{'server-only'}'ServerOnlyPlay'{'server-only-play'}'LocalAllowed'{'local-allowed'}}
 foreach($argument in @('--headless','--path',$project,'--script','res://native_direct_session_world.gd','--','--direct-session',('--direct-install='+$install),('--direct-profile='+$profile),('--direct-settings='+$settings),('--report='+$report),'--direct-headless-check=true','--direct-host=127.0.0.1','--direct-port=5121',('--direct-headless-vault-policy-check='+$modeArg))){$start.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($start)
 if($null -eq $process){throw 'Godot did not start'}
 $out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync()
 if(-not $process.WaitForExit($TimeoutSeconds*1000)){$process.Kill($true);[void]$process.WaitForExit(10000);throw 'Godot chooser check timed out'}
 if(-not $out.Wait(10000) -or -not $err.Wait(10000)){throw 'Godot output did not close'}
 [IO.File]::WriteAllText((Join-Path $output 'stdout.log'),$out.Result)
 [IO.File]::WriteAllText((Join-Path $output 'stderr.log'),$err.Result)
 if(-not(Test-Path -LiteralPath $report -PathType Leaf)){throw ('Godot made no chooser receipt; exit '+$process.ExitCode)}
 $r=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
 $policy=$r.direct_vault_policy_check
 $list=$r.direct_character_list
 $expectedLocal=$Mode -eq 'LocalAllowed'
 $passed=$process.ExitCode -eq 0 -and $r.clean_exit -eq $true -and -not $r.failure -and $policy.policyKnown -eq $true -and $policy.connected -eq $true -and $policy.phase -eq 'character-selection' -and $policy.localAllowed -eq $expectedLocal
 if($expectedLocal){$passed=$passed -and [int]$policy.localChoices -gt 0 -and [int]$policy.uiLocalChoices -gt 0}
 else{$passed=$passed -and [int]$policy.localChoices -eq 0 -and [int]$policy.uiLocalChoices -eq 0 -and [int]$policy.savedRows -eq 0 -and [int]$policy.serverChoices -eq 1}
 if($Mode -eq 'ServerOnlyPlay'){$passed=$passed -and $policy.serverPreviewRequested -eq $true -and $policy.serverPreviewReady -eq $true -and $policy.serverPlaySent -eq $true -and $policy.worldAdmitted -eq $true -and $r.world.ready -eq $true -and [int]$r.direct_headless_check.snapshots -ge 2 -and [int]$r.direct_headless_check.objects -ge 1}
 $receipt=[ordered]@{mode=$Mode;pass=[bool]$passed;exitCode=$process.ExitCode;failure=if($r.failure){[string]$r.failure}else{''};cleanExit=[bool]$r.clean_exit;policyKnown=[bool]$policy.policyKnown;connected=[bool]$policy.connected;phase=[string]$policy.phase;localAllowed=[bool]$policy.localAllowed;localChoices=[int]$policy.localChoices;uiLocalChoices=[int]$policy.uiLocalChoices;savedRows=[int]$policy.savedRows;serverChoices=[int]$policy.serverChoices;serverPreviewRequested=[bool]$policy.serverPreviewRequested;serverPreviewReady=[bool]$policy.serverPreviewReady;serverPlaySent=[bool]$policy.serverPlaySent;worldAdmitted=[bool]$policy.worldAdmitted;worldReady=[bool]$r.world.ready;snapshots=[int]$r.direct_headless_check.snapshots;objects=[int]$r.direct_headless_check.objects;acceptedPackets=[int]$list.acceptedPackets;receivedServerRows=[int]$list.receivedServerRows;projectedServerRows=[int]$list.projectedServerRows;projectedLocalRows=[int]$list.projectedLocalRows;projectedSavedRows=[int]$list.projectedSavedRows;characterListPackets=[int]$r.direct_status.characterListPackets;serverCharacterRows=[int]$r.direct_status.serverCharacterRows;reportSha256=(Get-FileHash -LiteralPath $report -Algorithm SHA256).Hash.ToLowerInvariant()}
 $receipt|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $summary -Encoding utf8
 $receipt|ConvertTo-Json -Compress
 if(-not $passed){throw ('Chooser policy receipt failed: '+$Mode)}
}finally{
 if($process){if(-not $process.HasExited){$process.Kill($true);[void]$process.WaitForExit(10000)};$process.Dispose()}
 if($serverStarted){if($OwnedServerFixtureRoot){& $server -Action Stop -OutputRoot $OwnedServerFixtureRoot|Out-Null}else{& $server -Action Stop -Mode $serverMode|Out-Null}}
 foreach($name in @('client-settings.json','Local State')){$copy=Join-Path $settings $name;if(Test-Path -LiteralPath $copy -PathType Leaf){Remove-Item -LiteralPath $copy -Force}}
}
