$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$run=Join-Path $project ('.cache/modal-surface-geometry-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$copy=Join-Path $run 'project';[IO.Directory]::CreateDirectory($copy)|Out-Null
$paths=@('systems/native_data/modal_order.gd','systems/native_data/modal_lease.gd','systems/native_modal_surfaces.gd','tests/native_modal_surface_geometry_test.gd','tools/test-native-modal-surface-geometry.ps1');$hashes=@()
foreach($relative in $paths){$source=Join-Path $project $relative;$destination=Join-Path $copy $relative;[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null;$hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash;Copy-Item -LiteralPath $source -Destination $destination;$hashes+=@{path=$relative;sha256=$hash}}
[IO.File]::WriteAllText((Join-Path $copy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned modal surface geometry test""`n")
$exe=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe';if((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Existing pinned Godot required'}
$output=Join-Path $run 'result.json';$log=Join-Path $run 'engine.log';$info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$exe;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
foreach($arg in @('--headless','--max-fps','60','--path',$copy,'--log-file',$log,'--script','res://tests/native_modal_surface_geometry_test.gd','--',('--report='+$output))){$info.ArgumentList.Add($arg)}
$process=[Diagnostics.Process]::Start($info);$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();$timedOut=$false;$deadline=[DateTime]::UtcNow.AddSeconds(10)
while(-not $process.WaitForExit(1000)){if([DateTime]::UtcNow-ge$deadline){$timedOut=$true;$process.Kill($true);$process.WaitForExit();break}}
$process.Refresh();[IO.File]::WriteAllText((Join-Path $run 'stdout.log'),$stdout.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $run 'stderr.log'),$stderr.GetAwaiter().GetResult())
$result=if(Test-Path -LiteralPath $output){Get-Content -LiteralPath $output -Raw|ConvertFrom-Json}else{$null};$changed=@($hashes|Where-Object{(Get-FileHash -LiteralPath (Join-Path $project $_.path) -Algorithm SHA256).Hash-ne$_.sha256-or(Get-FileHash -LiteralPath (Join-Path $copy $_.path) -Algorithm SHA256).Hash-ne$_.sha256})
$clean=[IO.File]::ReadAllText($log)-notmatch'(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|still in use at exit'
$receipt=[ordered]@{success=[bool]($result-and$result.success-and$process.ExitCode-eq0-and-not$timedOut-and$clean-and$changed.Count-eq0);directory=$run;inputs=$hashes;changedInputs=$changed;exitCode=$process.ExitCode;timedOut=$timedOut;cleanEngine=$clean;result=$result;engineLog=$log;nativeBuilds=0;servers=0;gpu=$false}
[IO.File]::WriteAllText((Join-Path $run 'runner.json'),($receipt|ConvertTo-Json -Depth 9)+[Environment]::NewLine);$receipt|ConvertTo-Json -Depth 6
if(-not $receipt.success){throw ('Owned finite geometry diagnostic rejected: '+$run)}
