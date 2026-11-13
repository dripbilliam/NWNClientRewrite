param([ValidatePattern('^[a-z0-9-]{3,80}$')][string]$Run='native-combat-locomotion-v1')
$ErrorActionPreference='Stop'
$combatProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$combatGodot=Join-Path $combatProject '.tools/Godot_v4.7.2-stable_win64.exe'
if((Get-FileHash -LiteralPath $combatGodot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot runtime'}
$combatDirectory=Join-Path $combatProject ('.cache/combat-locomotion-tests/'+$Run)
if(Test-Path -LiteralPath $combatDirectory){throw 'Evidence already exists'}
$combatCopy=Join-Path $combatDirectory 'project';[IO.Directory]::CreateDirectory($combatCopy)|Out-Null
$combatFiles=@('systems/combat_animation.gd','systems/animation_queue.gd','systems/attack_animation.gd','systems/native_data/movement_cue.gd','systems/native_data/combat_motion.gd','tests/native_combat_locomotion_test.gd','reports/native-combat-base-handoff-original-v1.json','tools/test-native-combat-locomotion.ps1','tests/native_combat_handoff_test.gd','reports/native-combat-gait-base-original-v1.json','reports/native-combat-locomotion-handoff-original-v1.json','../scripts/inspect-native-combat-gait-base.py','../scripts/inspect-native-combat-locomotion-handoff.py')
$combatHashes=@()
foreach($relative in $combatFiles){$source=Join-Path $combatProject $relative;$destination=Join-Path $combatCopy $relative;[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null;$hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant();Copy-Item -LiteralPath $source -Destination $destination;if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hash){throw 'Source changed during copy'};$combatHashes+=@{path=$relative;sha256=$hash}}
[IO.File]::WriteAllText((Join-Path $combatCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Combat Handoff""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
$combatReport=Join-Path $combatDirectory 'result.json';$combatLog=Join-Path $combatDirectory 'engine.log'
$combatInfo=[Diagnostics.ProcessStartInfo]::new();$combatInfo.FileName=$combatGodot;$combatInfo.UseShellExecute=$false;$combatInfo.CreateNoWindow=$true;$combatInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$combatInfo.RedirectStandardOutput=$true;$combatInfo.RedirectStandardError=$true
foreach($argument in @('--headless','--path',$combatCopy,'--log-file',$combatLog,'--script','res://tests/native_combat_locomotion_test.gd','--',('--report='+$combatReport))){$combatInfo.ArgumentList.Add($argument)}
$combatProcess=[Diagnostics.Process]::Start($combatInfo);$combatOut=$combatProcess.StandardOutput.ReadToEndAsync();$combatErr=$combatProcess.StandardError.ReadToEndAsync();$combatTimeout=-not$combatProcess.WaitForExit(20000)
if($combatTimeout){$combatProcess.Kill($true);$combatProcess.WaitForExit()}
$combatProcess.Refresh();[IO.File]::WriteAllText((Join-Path $combatDirectory 'stdout.log'),$combatOut.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $combatDirectory 'stderr.log'),$combatErr.GetAwaiter().GetResult())
$combatResult=if(Test-Path -LiteralPath $combatReport){Get-Content -LiteralPath $combatReport -Raw|ConvertFrom-Json}else{$null}
$combatClean=(Test-Path -LiteralPath $combatLog)-and([IO.File]::ReadAllText($combatLog)-notmatch '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|still in use at exit')
$combatChanged=@($combatHashes|Where-Object{(Get-FileHash -LiteralPath (Join-Path $combatProject $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$combatProof=[ordered]@{success=[bool]($combatResult-and$combatResult.success-and$combatProcess.ExitCode-eq0-and-not$combatTimeout-and$combatClean-and$combatChanged.Count-eq0);directory=$combatDirectory;report=$combatReport;checks=if($combatResult){$combatResult.checks}else{0};exitCode=$combatProcess.ExitCode;timedOut=$combatTimeout;cleanEngine=$combatClean;inputs=$combatHashes;changedInputs=$combatChanged;nativeBuilds=0;gameServerConnections=0;publicConnections=0;gpu=$false}
[IO.File]::WriteAllText((Join-Path $combatDirectory 'proof.json'),($combatProof|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
$combatProof|ConvertTo-Json -Depth 3
if(-not$combatProof.success){throw 'Combat handoff check rejected; retained finite evidence'}
