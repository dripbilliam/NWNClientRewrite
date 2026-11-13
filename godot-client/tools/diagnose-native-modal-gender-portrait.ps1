param([string]$Run='20261103-061457-153802ae')
$ErrorActionPreference='Stop'
$diagProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$diagFailed=Join-Path $diagProject ('.cache/modal-gender-portrait-tests/'+$Run)
$diagReceipt=Get-Content -LiteralPath (Join-Path $diagFailed 'runner.json') -Raw|ConvertFrom-Json
if($diagReceipt.success){throw 'Diagnostic requires preserved rejected input'}
$diagRun=Join-Path $diagProject ('.cache/modal-gender-portrait-diagnostics/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$diagCopy=Join-Path $diagRun 'project';[IO.Directory]::CreateDirectory($diagCopy)|Out-Null
$diagPins=@()
foreach($entry in $diagReceipt.inputs){
 if($entry.path.StartsWith('../')){continue}
 $source=Join-Path (Join-Path $diagFailed 'project') $entry.path;$destination=Join-Path $diagCopy $entry.path
 if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()-ne$entry.sha256){throw 'Failed-copy source hash differs'}
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null;Copy-Item -LiteralPath $source -Destination $destination
 $diagPins+=@{path=$entry.path;sha256=$entry.sha256}
}
Copy-Item -LiteralPath (Join-Path $diagFailed 'project/project.godot') -Destination (Join-Path $diagCopy 'project.godot')
$diagFixture=Join-Path $diagCopy 'tests/native_modal_gender_portrait_test.gd'
$diagSource=[IO.File]::ReadAllText($diagFixture)
$diagObserve=@'
var diagnostic_observations: Array=[]
func observe_bar(surface: SubViewport,pane,target: Control,label: String) -> void:
 var hovered: Control=surface.gui_get_hovered_control()
 diagnostic_observations.append({"label":label,"target_rect":str(target.get_global_rect()),"target_size":str(target.size),"bar_rect":str(pane.bar.get_global_rect()),"bar":pane.bar.snapshot(),"target_visible":target.is_visible_in_tree(),"target_pressed":target.is_pressed() if target is BaseButton else null,"target_disabled":target.disabled if target is BaseButton else null,"hover_path":str(hovered.get_path()) if is_instance_valid(hovered) else null,"hover_class":hovered.get_class() if is_instance_valid(hovered) else null,"admitted":pane.available(),"recursive_mouse":pane.get("mouse_behavior_recursive"),"art_bounds_count":pane.frame.art.bounds.size(),"thumb_key_has_bounds":pane.frame.art.bounds.has(pane.bar.thumb_image_key)})
func run() -> void:
'@
$diagObserve=$diagObserve.Replace("`n ","`n`t")
$diagSource=$diagSource.Replace('func run() -> void:',$diagObserve)
$diagSource=$diagSource.Replace('await pointer(surface,portrait.bar.down,true);check','await pointer(surface,portrait.bar.down,true);observe_bar(surface,portrait,portrait.bar.down,"arrow-start");check')
$diagSource=$diagSource.Replace('await pointer(surface,portrait.bar.thumb,true);check','await pointer(surface,portrait.bar.thumb,true);observe_bar(surface,portrait,portrait.bar.thumb,"thumb-start");check')
$diagSource=$diagSource.Replace('"success":failures.is_empty(),"checks":checks','"diagnosticOnly":true,"observations":diagnostic_observations,"success":failures.is_empty(),"checks":checks')
[IO.File]::WriteAllText($diagFixture,$diagSource)
$diagInfo=[Diagnostics.ProcessStartInfo]::new();$diagInfo.FileName=Join-Path $diagProject '.tools/Godot_v4.7.2-stable_win64.exe';$diagInfo.UseShellExecute=$false;$diagInfo.CreateNoWindow=$true;$diagInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$diagInfo.RedirectStandardOutput=$true;$diagInfo.RedirectStandardError=$true
if((Get-FileHash -LiteralPath $diagInfo.FileName -Algorithm SHA256).Hash.ToLowerInvariant()-ne$diagReceipt.engineSha256){throw 'Diagnostic runtime hash differs'}
$diagLog=Join-Path $diagRun 'engine.log';$diagReport=Join-Path $diagRun 'diagnostic.json';$diagInstall=[IO.Path]::GetFullPath((Join-Path $diagProject '../../FullDecomp/NwnRootInstall'))
foreach($argument in @('--headless','--max-fps','60','--path',$diagCopy,'--log-file',$diagLog,'--script','res://tests/native_modal_gender_portrait_test.gd','--',('--report='+$diagReport),('--install='+$diagInstall),'--entity-api-rest=false')){$diagInfo.ArgumentList.Add($argument)}
$diagProcess=[Diagnostics.Process]::Start($diagInfo);$diagOut=$diagProcess.StandardOutput.ReadToEndAsync();$diagErr=$diagProcess.StandardError.ReadToEndAsync();$diagTimeout=$false;$diagDeadline=[DateTime]::UtcNow.AddSeconds(35)
while(-not$diagProcess.WaitForExit(1000)){if([DateTime]::UtcNow-ge$diagDeadline){$diagTimeout=$true;$diagProcess.Kill($true);$diagProcess.WaitForExit();break}}
$diagProcess.Refresh();[IO.File]::WriteAllText((Join-Path $diagRun 'stdout.log'),$diagOut.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $diagRun 'stderr.log'),$diagErr.GetAwaiter().GetResult())
$diagClean=[IO.File]::ReadAllText($diagLog)-notmatch '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit'
$diagResult=if(Test-Path -LiteralPath $diagReport){Get-Content -LiteralPath $diagReport -Raw|ConvertFrom-Json}else{$null}
$diagSummary=[ordered]@{diagnosticOnly=$true;sourceRun=$Run;directory=$diagRun;exitCode=$diagProcess.ExitCode;timedOut=$diagTimeout;cleanEngine=$diagClean;checks=if($diagResult){$diagResult.checks}else{0};featureAccepted=$false;inputs=$diagPins;fixtureSha256=(Get-FileHash -LiteralPath $diagFixture -Algorithm SHA256).Hash.ToLowerInvariant()}
[IO.File]::WriteAllText((Join-Path $diagRun 'runner.json'),($diagSummary|ConvertTo-Json -Depth 5)+[Environment]::NewLine)
[pscustomobject]$diagSummary|Select-Object diagnosticOnly,directory,exitCode,timedOut,cleanEngine,checks,featureAccepted|ConvertTo-Json -Depth 4
if($diagResult){$diagResult.observations|ConvertTo-Json -Depth 6}
