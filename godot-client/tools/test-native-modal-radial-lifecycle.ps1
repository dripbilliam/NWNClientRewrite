param([string]$Godot='',[string]$Install='')
$ErrorActionPreference='Stop'
$accessProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$accessWorkspace=[IO.Path]::GetFullPath((Join-Path $accessProject '..'))
if(-not$Godot){$Godot=Join-Path $accessProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not$Install){$Install=[IO.Path]::GetFullPath((Join-Path $accessWorkspace '../FullDecomp/NwnRootInstall'))}
if((Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot runtime; no build/download permitted'}
$accessRun=Join-Path $accessProject ('.cache/modal-radial-lifecycle-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$accessCopy=Join-Path $accessRun 'project';[IO.Directory]::CreateDirectory($accessCopy)|Out-Null
$accessFiles=@(& rg --files (Join-Path $accessProject 'systems') -g '*.gd' -g '*.gdshader'|ForEach-Object{[IO.Path]::GetRelativePath($accessProject,$_).Replace('\','/')})
$accessFiles+=@(& rg --files (Join-Path $accessWorkspace 'src') (Join-Path $accessWorkspace 'electron') -g '*.js' -g '*.mjs' -g '*.cjs'|ForEach-Object{[IO.Path]::GetRelativePath($accessProject,$_).Replace('\','/')})
$accessFiles+=@('systems/native_data/feedback_descriptors.json','tools/native-session-host.cjs','tests/native_skill_description_source_test.gd','tests/native_gui_panel_policy_test.gd','tests/native_gui_panel_access_source_test.gd','tests/native_gui_panel_access_fixture.mjs','tests/run-native-gui-panel-access-tests.ps1','tests/run-native-gui-context-tests.ps1','tools/test-native-creature-party-scope.ps1','tools/test-native-modal-radial-lifecycle.ps1','tests/native_modal_order_test.gd','tests/native_modal_radial_lifecycle_test.gd','tests/native_modal_late_chat_test.gd','tests/native_modal_popup_test.gd','reports/native-topmodal-close-original-v1.json','tests/native_quickbar_context_test.gd','tests/native_quickbar_polymorph_test.gd','tests/native_quickbar_associate_test.gd','tests/native_creature_radial_role_test.gd','reports/native-creature-party-radial-original-v2.json','tests/native_gui_context_policy_test.gd','tests/native_creature_radial_test.gd','tests/native_world_radial_input_test.gd','tests/native_radial_scope_test.gd','reports/native-creature-radial-original-v1.json','reports/native-world-context-callers-v1.json','../test/native-gui-context-events.test.js','../test/native-world-radial.test.js','tests/native_journal_events_source_test.gd','tests/native_journal_state_test.gd','tests/map_journal_ui_test.gd','reports/native-gui-panel-access-original-v2.json','../scripts/inspect-native-gui-panel-access.py','../backups/animations/native-journal-date-observations-v1.json','../test/native-gui-panel-access.test.js','../test/native-journal-events.test.js','../test/native-feat-description-protocol.test.js','../test/native-skill-description-protocol.test.js','../test/network-game-session.test.js')
$accessHashes=@()
foreach($relative in ($accessFiles|Sort-Object -Unique)){
 $source=Join-Path $accessProject $relative;$destination=Join-Path $accessCopy $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
 $before=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant();Copy-Item -LiteralPath $source -Destination $destination
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$before){throw ('Source changed while copying: '+$relative)}
 $accessHashes+=@{path=$relative;sha256=$before}
}
[IO.File]::WriteAllText((Join-Path $accessCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Modal Radial Lifecycle Test""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
function Invoke-AccessGodot([string]$Script,[string]$Name){
 $accessOutput=Join-Path $accessRun ($Name+'.json');$accessLog=Join-Path $accessRun ($Name+'.engine.log')
 $accessInfo=[Diagnostics.ProcessStartInfo]::new();$accessInfo.FileName=$Godot;$accessInfo.WorkingDirectory=$accessWorkspace;$accessInfo.UseShellExecute=$false;$accessInfo.CreateNoWindow=$true;$accessInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$accessInfo.RedirectStandardOutput=$true;$accessInfo.RedirectStandardError=$true
 $accessOracle=if($Script-eq'native_modal_order_test.gd'){Join-Path $accessCopy 'reports/native-topmodal-close-original-v1.json'}else{Join-Path $accessCopy 'reports/native-gui-panel-access-original-v2.json'}
 foreach($argument in @('--headless','--max-fps','60','--path',$accessCopy,'--log-file',$accessLog,'--script',('res://tests/'+$Script),'--',('--report='+$accessOutput),('--install='+$Install),('--oracle='+$accessOracle),'--entity-api-rest=false')){$accessInfo.ArgumentList.Add($argument)}
 $accessProcess=[Diagnostics.Process]::Start($accessInfo);$accessStdout=$accessProcess.StandardOutput.ReadToEndAsync();$accessStderr=$accessProcess.StandardError.ReadToEndAsync();$accessTimeout=$false
 $accessDeadline=[DateTime]::UtcNow.AddSeconds(35)
 while(-not$accessProcess.WaitForExit(1000)){if([DateTime]::UtcNow-ge$accessDeadline){$accessTimeout=$true;$accessProcess.Kill($true);$accessProcess.WaitForExit();break}}
 $accessProcess.Refresh();[IO.File]::WriteAllText((Join-Path $accessRun ($Name+'.stdout.log')),$accessStdout.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $accessRun ($Name+'.stderr.log')),$accessStderr.GetAwaiter().GetResult())
 $accessResult=if(Test-Path -LiteralPath $accessOutput){Get-Content -LiteralPath $accessOutput -Raw|ConvertFrom-Json}else{$null}
 $accessClean=([IO.File]::ReadAllText($accessLog)-notmatch '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit')
 return [ordered]@{name=$Name;script=$Script;success=[bool]($accessResult-and($accessResult.success-or$accessResult.passed)-and$accessProcess.ExitCode-eq0-and-not$accessTimeout-and$accessClean);checks=if($accessResult){$accessResult.checks}else{0};result=$accessOutput;engineLog=$accessLog;exitCode=$accessProcess.ExitCode;timedOut=$accessTimeout;cleanEngine=$accessClean}
}
$accessResults=@()
foreach($case in @(@('native_modal_popup_test.gd','source-popup'),@('native_modal_late_chat_test.gd','late-chat'),@('native_modal_order_test.gd','modal-order'),@('native_modal_radial_lifecycle_test.gd','modal-lifecycle'),@('native_gui_context_policy_test.gd','context-policy'),@('native_world_radial_input_test.gd','world-input'),@('native_radial_scope_test.gd','radial-scope'),@('native_quickbar_associate_test.gd','quickbar39'),@('native_quickbar_polymorph_test.gd','quickbar43'),@('native_quickbar_context_test.gd','quickbar-context'))){$accessResults+=Invoke-AccessGodot $case[0] $case[1];if(-not$accessResults[-1].success){break}}
$accessTap=Join-Path $accessRun 'protocol.tap'
& node --test (Join-Path $accessWorkspace 'test/native-gui-context-events.test.js') (Join-Path $accessWorkspace 'test/native-world-radial.test.js') (Join-Path $accessWorkspace 'test/native-gui-panel-access.test.js') 1>$accessTap 2>(Join-Path $accessRun 'protocol.stderr.log')
$accessNodeCode=$LASTEXITCODE;$accessNodeText=[IO.File]::ReadAllText($accessTap);$accessNodeCount=0
if($accessNodeText-match '(?m)^# tests (\d+)\r?$'){$accessNodeCount=[int]$Matches[1]}
$accessNodePass=$accessNodeCode-eq0-and$accessNodeText-match '(?m)^# fail 0\r?$'
$accessChanged=@($accessHashes|Where-Object{(Get-FileHash -LiteralPath (Join-Path $accessProject $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$accessPassed=$accessResults.Count-eq10-and-not($accessResults|Where-Object{-not$_.success})-and$accessNodePass-and$accessChanged.Count-eq0
$accessReceipt=[ordered]@{success=[bool]$accessPassed;testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$accessRun;engineSha256=(Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash.ToLowerInvariant();inputs=$accessHashes;changedInputs=$accessChanged;results=$accessResults;protocolTests=$accessNodeCount;protocolExitCode=$accessNodeCode;protocolTap=$accessTap;gameServerConnections=0;publicConnections=0;nativeBuilds=0;gpu=$false;scope='Copied/pinned modal model and actual three-wheel owner lifecycle/configuration bindings, actual Gameplay configure/worker-driven late chat assembly, and separate authored inventory/chat setup and explicit fixture-only complete membership; production coverage remains unavailable/no53/2close enabled. Existing world/39/43/context/Session regressions; no original pixels/server/GPU/liveuserclient.'}
[IO.File]::WriteAllText((Join-Path $accessRun 'runner.json'),($accessReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
if($accessPassed){[IO.File]::WriteAllText((Join-Path $accessProject 'reports/native-modal-radial-lifecycle-v1-receipt.json'),($accessReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)}
$accessNativeChecks=0;foreach($accessEntry in $accessResults){$accessNativeChecks+=[int]$accessEntry.checks}
[pscustomobject]@{success=$accessPassed;directory=$accessRun;nativeChecks=$accessNativeChecks;protocolTests=$accessNodeCount;results=$accessResults;changedInputs=$accessChanged.Count}|ConvertTo-Json -Depth 5
if(-not$accessPassed){throw ('Owned access checks failed; finite logs/inputs retained: '+$accessRun)}
