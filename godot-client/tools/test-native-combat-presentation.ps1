param([ValidatePattern('^[a-z0-9-]{3,80}$')][string]$Run='native-combat-presentation-v1')
$ErrorActionPreference='Stop'
$combatProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$combatWorkspace=[IO.Path]::GetFullPath((Join-Path $combatProject '..'))
$combatGodot=Join-Path $combatProject '.tools/Godot_v4.7.2-stable_win64.exe'
if((Get-FileHash -LiteralPath $combatGodot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot runtime'}
$combatDirectory=Join-Path $combatProject ('.cache/combat-presentation-tests/'+$Run)
if(Test-Path -LiteralPath $combatDirectory){throw 'Evidence already exists'}
$combatCopy=Join-Path $combatDirectory 'godot-client';[IO.Directory]::CreateDirectory($combatCopy)|Out-Null
$combatFiles=@(& rg --files (Join-Path $combatProject 'systems') -g '*.gd' -g '*.gdshader' -g '*.json'|ForEach-Object{[IO.Path]::GetRelativePath($combatProject,$_).Replace('\','/')})
$combatFiles+=@(Get-ChildItem -LiteralPath $combatProject -File -Filter '*.gd'|ForEach-Object{$_.Name})
$combatFiles+=@(& rg --files (Join-Path $combatProject 'tests') -g '*.gd'|ForEach-Object{[IO.Path]::GetRelativePath($combatProject,$_).Replace('\','/')})
$combatFiles+=@(& rg --files (Join-Path $combatWorkspace 'src') (Join-Path $combatWorkspace 'electron') -g '*.js' -g '*.mjs' -g '*.cjs'|ForEach-Object{[IO.Path]::GetRelativePath($combatProject,$_).Replace('\','/')})
$combatScripts=@('native_combat_handoff_test.gd','combat_animation_test.gd','native_direct_combat_test.gd','native_target_facing_test.gd','native_live_motion_test.gd','native_combat_facing_test.gd','native_combat_locomotion_test.gd','native_combat_world_handoff_test.gd','native_combat_probe_compile_test.gd','native_combat_class_default_test.gd')
$combatFiles+=@($combatScripts|ForEach-Object{'tests/'+$_})
$combatFiles+=@('reports/native-combat-base-handoff-original-v1.json','reports/combat-oracle-v1.json','reports/native-combat-gait-base-original-v1.json','reports/native-combat-locomotion-handoff-original-v1.json','tests/native_live_actions_probe.gd','tests/native_live_combat_presentation_probe.gd','tests/native_live_world_radial_probe.gd','tests/native_live_quickbar_probe.gd','tests/native_combat_facing_fixture.mjs','tools/native-session-host.cjs','../test/native-combat-facing.test.js','tools/test-native-combat-presentation.ps1')
$combatFiles+=@('native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json')
$combatFiles+=@('reports/native-combat-class-default-original-v1.json','reports/native-combat-class-owners-research-v1.json','../scripts/inspect-native-combat-class-default.py','../scripts/inspect-native-client-combat-animation.py')
$combatHashes=@()
foreach($relative in ($combatFiles|Sort-Object -Unique)){$source=Join-Path $combatProject $relative;$destination=Join-Path $combatCopy $relative;[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null;$hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant();Copy-Item -LiteralPath $source -Destination $destination;if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hash){throw ('Source changed during copy '+$relative)};$combatHashes+=@{path=$relative;sha256=$hash}}
[IO.File]::WriteAllText((Join-Path $combatCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Combat Presentation""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
$combatFixture=Join-Path $combatDirectory 'facing-fixture.json'
& node (Join-Path $combatCopy 'tests/native_combat_facing_fixture.mjs') ('--report='+$combatFixture)
if($LASTEXITCODE-ne0){throw 'Actual World facing fixture rejected'}
$combatTap=Join-Path $combatDirectory 'protocol.tap'
& node --test (Join-Path $combatCopy '../test/native-combat-facing.test.js') 1>$combatTap 2>(Join-Path $combatDirectory 'protocol.stderr.log');$combatNodeCode=$LASTEXITCODE
$combatNodePass=$combatNodeCode-eq0-and[IO.File]::ReadAllText($combatTap)-match '(?m)^# fail 0\r?$'
$combatResults=@()
foreach($script in $combatScripts){
 $name=$script.Replace('_test.gd','');$report=Join-Path $combatDirectory ($name+'.json');$log=Join-Path $combatDirectory ($name+'.engine.log')
 $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$combatGodot;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $combatExtra=if($script-eq'native_combat_class_default_test.gd'){@('--oracle='+(Join-Path $combatCopy 'reports/native-combat-class-default-original-v1.json'))}else{@()}
 foreach($argument in (@('--headless','--max-fps','60','--path',$combatCopy,'--log-file',$log,'--script',('res://tests/'+$script),'--',('--report='+$report),('--fixture='+$combatFixture),'--entity-api-rest=false')+$combatExtra)){$info.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($info);$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();$timeout=-not$process.WaitForExit(35000)
 if($timeout){$process.Kill($true);$process.WaitForExit()};$process.Refresh()
 [IO.File]::WriteAllText((Join-Path $combatDirectory ($name+'.stdout.log')),$stdout.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $combatDirectory ($name+'.stderr.log')),$stderr.GetAwaiter().GetResult())
 $result=if(Test-Path -LiteralPath $report){Get-Content -LiteralPath $report -Raw|ConvertFrom-Json}else{$null}
 $clean=(Test-Path -LiteralPath $log)-and([IO.File]::ReadAllText($log)-notmatch '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|still in use at exit')
 $combatResults+=@{name=$name;success=[bool]($result-and$result.success-and$process.ExitCode-eq0-and-not$timeout-and$clean);checks=if($result){$result.checks}else{0};report=$report;engineLog=$log;exitCode=$process.ExitCode;timedOut=$timeout;cleanEngine=$clean}
 if(-not$combatResults[-1].success){break}
}
$combatChanged=@($combatHashes|Where-Object{(Get-FileHash -LiteralPath (Join-Path $combatProject $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$combatProof=[ordered]@{success=[bool]($combatResults.Count-eq$combatScripts.Count-and-not($combatResults|Where-Object{-not$_.success})-and$combatNodePass-and$combatChanged.Count-eq0);directory=$combatDirectory;results=$combatResults;protocolTests=5;protocolExitCode=$combatNodeCode;inputs=$combatHashes;changedInputs=$combatChanged;nativeBuilds=0;gameServerConnections=0;publicConnections=0;gpu=$false;scope='Original-backed cast-base, gait/resting-base/path and private class-state rules; actual scheduler/private AnimationPlayer/LiveWorld/facing/model-lifetime regressions. No server/pixel/full-combat acceptance from this copied batch.'}
[IO.File]::WriteAllText((Join-Path $combatDirectory 'proof.json'),($combatProof|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
[pscustomobject]@{success=$combatProof.success;directory=$combatDirectory;results=$combatResults;protocolTests=5;changedInputs=$combatChanged.Count}|ConvertTo-Json -Depth 5
if(-not$combatProof.success){throw 'Combat presentation check rejected; finite evidence retained'}
