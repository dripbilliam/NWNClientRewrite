param([string]$Godot='',[string]$Install='')
$ErrorActionPreference='Stop'
$taskProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskWorkspace=[IO.Path]::GetFullPath((Join-Path $taskProject '..'))
if(-not$Godot){$Godot=Join-Path $taskProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not$Install){$Install=[IO.Path]::GetFullPath((Join-Path $taskWorkspace '../FullDecomp/NwnRootInstall'))}
if((Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot runtime; no build/download permitted'}
$taskRun=Join-Path $taskProject ('.cache/modal-gender-portrait-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$taskCopy=Join-Path $taskRun 'project';[IO.Directory]::CreateDirectory($taskCopy)|Out-Null
$taskFiles=@(& rg --files (Join-Path $taskProject 'systems') -g '*.gd' -g '*.gdshader'|ForEach-Object{[IO.Path]::GetRelativePath($taskProject,$_).Replace('\','/')})
$taskFiles+=@(& rg --files (Join-Path $taskWorkspace 'src') (Join-Path $taskWorkspace 'electron') -g '*.js' -g '*.mjs' -g '*.cjs'|ForEach-Object{[IO.Path]::GetRelativePath($taskProject,$_).Replace('\','/')})
$taskFiles+=@('reports/native-modal-activation-callers-v2.json','reports/native-portrait-pane-dossiers-v1.json','tests/native_modal_gender_portrait_test.gd','tests/native_modal_class_alignment_test.gd','tests/native_modal_owner_input_test.gd','tests/native_modal_late_chat_test.gd','tests/native_skill_description_source_test.gd','systems/native_data/feedback_descriptors.json','tools/test-native-modal-gender-portrait.ps1','../test/native-gui-context-events.test.js','../test/native-world-radial.test.js','../test/native-gui-panel-access.test.js')
$taskHashes=@()
foreach($relative in ($taskFiles|Sort-Object -Unique)){
 $source=Join-Path $taskProject $relative;$destination=Join-Path $taskCopy $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
 $before=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant();Copy-Item -LiteralPath $source -Destination $destination
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$before){throw ('Source changed while copying: '+$relative)}
 $taskHashes+=@{path=$relative;sha256=$before}
}
[IO.File]::WriteAllText((Join-Path $taskCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Gender Portrait Modal Test""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
function Invoke-TaskCase([string]$Script,[string]$Name){
 $taskOutput=Join-Path $taskRun ($Name+'.json');$taskLog=Join-Path $taskRun ($Name+'.engine.log')
 $taskInfo=[Diagnostics.ProcessStartInfo]::new();$taskInfo.FileName=$Godot;$taskInfo.WorkingDirectory=$taskWorkspace;$taskInfo.UseShellExecute=$false;$taskInfo.CreateNoWindow=$true;$taskInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$taskInfo.RedirectStandardOutput=$true;$taskInfo.RedirectStandardError=$true
 foreach($argument in @('--headless','--max-fps','60','--path',$taskCopy,'--log-file',$taskLog,'--script',('res://tests/'+$Script),'--',('--report='+$taskOutput),('--install='+$Install),'--entity-api-rest=false')){$taskInfo.ArgumentList.Add($argument)}
 $taskProcess=[Diagnostics.Process]::Start($taskInfo);$taskStdout=$taskProcess.StandardOutput.ReadToEndAsync();$taskStderr=$taskProcess.StandardError.ReadToEndAsync();$taskTimeout=$false
 $taskDeadline=[DateTime]::UtcNow.AddSeconds(35)
 while(-not$taskProcess.WaitForExit(1000)){if([DateTime]::UtcNow-ge$taskDeadline){$taskTimeout=$true;$taskProcess.Kill($true);$taskProcess.WaitForExit();break}}
 $taskProcess.Refresh();[IO.File]::WriteAllText((Join-Path $taskRun ($Name+'.stdout.log')),$taskStdout.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $taskRun ($Name+'.stderr.log')),$taskStderr.GetAwaiter().GetResult())
 $taskResult=if(Test-Path -LiteralPath $taskOutput){Get-Content -LiteralPath $taskOutput -Raw|ConvertFrom-Json}else{$null}
 $taskClean=([IO.File]::ReadAllText($taskLog)-notmatch '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit')
 return [ordered]@{name=$Name;script=$Script;success=[bool]($taskResult-and$taskResult.success-and$taskProcess.ExitCode-eq0-and-not$taskTimeout-and$taskClean);checks=if($taskResult){$taskResult.checks}else{0};result=$taskOutput;engineLog=$taskLog;exitCode=$taskProcess.ExitCode;timedOut=$taskTimeout;cleanEngine=$taskClean}
}
$taskResults=@()
$taskResults+=Invoke-TaskCase 'native_modal_gender_portrait_test.gd' 'gender-portrait'
$taskResults+=Invoke-TaskCase 'native_modal_class_alignment_test.gd' 'class-alignment'
$taskTap=Join-Path $taskRun 'protocol.tap'
& node --test (Join-Path $taskWorkspace 'test/native-gui-context-events.test.js') (Join-Path $taskWorkspace 'test/native-world-radial.test.js') (Join-Path $taskWorkspace 'test/native-gui-panel-access.test.js') 1>$taskTap 2>(Join-Path $taskRun 'protocol.stderr.log')
$taskNodeCode=$LASTEXITCODE;$taskNodeText=[IO.File]::ReadAllText($taskTap);$taskNodeCount=0
if($taskNodeText-match '(?m)^# tests (\d+)\r?$'){$taskNodeCount=[int]$Matches[1]}
$taskNodePass=$taskNodeCode-eq0-and$taskNodeText-match '(?m)^# fail 0\r?$'
$taskChanged=@($taskHashes|Where-Object{(Get-FileHash -LiteralPath (Join-Path $taskProject $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$taskCopiedChanged=@($taskHashes|Where-Object{(Get-FileHash -LiteralPath (Join-Path $taskCopy $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$taskPassed=$taskResults.Count-eq2-and-not($taskResults|Where-Object{-not$_.success})-and$taskNodePass-and$taskChanged.Count-eq0-and$taskCopiedChanged.Count-eq0
$taskReceipt=[ordered]@{success=[bool]$taskPassed;testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$taskRun;engineSha256=(Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash.ToLowerInvariant();inputs=$taskHashes;changedInputs=$taskChanged;changedCopiedInputs=$taskCopiedChanged;results=$taskResults;protocolTests=$taskNodeCount;protocolExitCode=$taskNodeCode;protocolTap=$taskTap;gameServerConnections=0;publicConnections=0;nativeBuilds=0;gpu=$false;scope='Actual Gender/Portrait creator factory and installed native input/lifetimes, Class/Alignment regression, controlled raster/fonts and authored choices/commits. No complete creator rules, level-up/server/pixels/GPU/build or global modal coverage acceptance.'}
[IO.File]::WriteAllText((Join-Path $taskRun 'runner.json'),($taskReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
if($taskPassed){[IO.File]::WriteAllText((Join-Path $taskProject 'reports/native-modal-gender-portrait-v1-receipt.json'),($taskReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)}
$taskChecks=0;foreach($entry in $taskResults){$taskChecks+=[int]$entry.checks}
[pscustomobject]@{success=$taskPassed;directory=$taskRun;nativeChecks=$taskChecks;protocolTests=$taskNodeCount;results=$taskResults;changedInputs=$taskChanged.Count;changedCopiedInputs=$taskCopiedChanged.Count}|ConvertTo-Json -Depth 5
if(-not$taskPassed){throw ('Owned Gender/Portrait checks rejected; finite logs and exact inputs retained: '+$taskRun)}
