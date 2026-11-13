param([string]$RejectedProject)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source=[IO.Path]::GetFullPath($RejectedProject)
$prefix=[IO.Path]::GetFullPath((Join-Path $project '.cache/modal-owner-tests'))+[IO.Path]::DirectorySeparatorChar
if(-not $source.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)-or-not(Test-Path -LiteralPath (Join-Path $source 'tests/native_modal_owner_input_test.gd'))){throw 'Expected an owned preserved rejected modal project'}
$run=Join-Path $project ('.cache/modal-owner-diagnostics/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($run)|Out-Null
$copy=Join-Path $run 'project';Copy-Item -LiteralPath $source -Destination $copy -Recurse
$fixture=Join-Path $copy 'tests/native_modal_owner_input_test.gd';$body=[IO.File]::ReadAllText($fixture)
$body=$body.Replace('var menu_ready:=check(await ready(menu.native_frame)', 'var observations: Array=[]'+"`n`t"+'var menu_ready:=check(await ready(menu.native_frame)')
$needle="`t`tawait click(surface,menu.native_frame.buttons.resumegamebutton)"
$replacement=@'
		var resume_button: Button=menu.native_frame.buttons.resumegamebutton
		var hit_point:=resume_button.get_global_transform_with_canvas()*(resume_button.size*0.5)
		var observe_motion:=InputEventMouseMotion.new();observe_motion.position=hit_point;observe_motion.global_position=hit_point;surface.push_input(observe_motion,true);await frames()
		var hovered: Control=surface.gui_get_hovered_control()
		observations.append({"phase":"before","hit":str(hit_point),"hover":str(hovered.get_path()) if is_instance_valid(hovered) else null,"hoverClass":hovered.get_class() if is_instance_valid(hovered) else null,"mainVisible":menu.panel.visible,"examineVisible":ui.examine.visible,"mainLayer":menu.layer,"examineLayer":ui.examine.get_parent().get_parent().layer,"mainAdmission":menu.modal_lease.admits(),"examineAdmission":ui.examine.modal_lease.admits(),"mainMouseRecursive":menu.native_frame.stage.get("mouse_behavior_recursive"),"resumeRect":str(resume_button.get_global_rect()),"examineRect":str(ui.examine.get_global_rect()),"examineCloseRect":str(ui.examine.close_button.get_global_rect())})
		await click(surface,resume_button)
		observations.append({"phase":"after","mainVisible":menu.panel.visible,"examineVisible":ui.examine.visible,"mainAdmission":menu.modal_lease.admits(),"top":ui.modal_order.snapshot().records})
'@
$replacement=$replacement.Replace('\t',"`t")
if(-not $body.Contains($needle)){throw 'Diagnostic needle absent'}
$body=$body.Replace($needle,$replacement).Replace('"scope":"Real current Gameplay configure/alternate setup','"observations":observations,"scope":"Immutable rejected snapshot diagnostic only: real current-at-failure Gameplay configure/alternate setup')
[IO.File]::WriteAllText($fixture,$body)
$exe=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
$info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$exe;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
$output=Join-Path $run 'result.json';$log=Join-Path $run 'engine.log';$install=[IO.Path]::GetFullPath((Join-Path $project '../../FullDecomp/NwnRootInstall'))
foreach($arg in @('--headless','--max-fps','60','--path',$copy,'--log-file',$log,'--script','res://tests/native_modal_owner_input_test.gd','--',('--report='+$output),('--install='+$install),'--entity-api-rest=false')){$info.ArgumentList.Add($arg)}
$process=[Diagnostics.Process]::Start($info);$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();$timedOut=$false;$deadline=[DateTime]::UtcNow.AddSeconds(35)
while(-not $process.WaitForExit(1000)){if([DateTime]::UtcNow-ge$deadline){$timedOut=$true;$process.Kill($true);$process.WaitForExit();break}}
$process.Refresh();[IO.File]::WriteAllText((Join-Path $run 'stdout.log'),$stdout.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $run 'stderr.log'),$stderr.GetAwaiter().GetResult())
$result=if(Test-Path -LiteralPath $output){Get-Content -LiteralPath $output -Raw|ConvertFrom-Json}else{$null}
$receipt=[ordered]@{scope='One diagnostic over an immutable rejected source copy, fixture observations only; no current-source acceptance';source=$source;copy=$copy;fixtureSha256=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash;exitCode=$process.ExitCode;timedOut=$timedOut;result=$result;engine=$log;nativeBuilds=0;servers=0;gpu=$false}
[IO.File]::WriteAllText((Join-Path $run 'runner.json'),($receipt|ConvertTo-Json -Depth 9)+[Environment]::NewLine)
$receipt|ConvertTo-Json -Depth 7
