param([string]$Godot='',[string]$Install='')
$ErrorActionPreference='Stop'
$journalProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$journalWorkspace=[IO.Path]::GetFullPath((Join-Path $journalProject '..'))
if(-not$Godot){$Godot=Join-Path $journalProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not$Install){$Install=[IO.Path]::GetFullPath((Join-Path $journalWorkspace '../FullDecomp/NwnRootInstall'))}
if((Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot runtime; this runner never builds/downloads'}
$journalRun=Join-Path $journalProject ('.cache/journal-event-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$journalCopy=Join-Path $journalRun 'project';[IO.Directory]::CreateDirectory($journalCopy)|Out-Null
$journalFiles=@(& rg --files (Join-Path $journalProject 'systems') -g '*.gd' -g '*.gdshader'|ForEach-Object{[IO.Path]::GetRelativePath($journalProject,$_).Replace('\','/')})
$journalFiles+=@('systems/native_data/feedback_descriptors.json','tests/native_skill_description_source_test.gd','tests/native_journal_events_source_test.gd','tests/native_journal_state_test.gd','tests/map_journal_ui_test.gd','tests/run-native-journal-events-tests.ps1','../src/network_journal_events.js','../src/network_hud_input.js','../electron/network_game_session.mjs','../test/native-journal-events.test.js','../test/native-feat-description-protocol.test.js','../test/native-skill-description-protocol.test.js','../test/network-game-session.test.js')
$journalFiles+='../backups/animations/native-journal-date-observations-v1.json'
$journalHashes=@()
foreach($relative in $journalFiles){
 $source=Join-Path $journalProject $relative;$destination=Join-Path $journalCopy $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
 $before=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant();Copy-Item -LiteralPath $source -Destination $destination
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$before){throw ('Source changed while copying: '+$relative)}
 $journalHashes+=@{path=$relative;sha256=$before}
}
[IO.File]::WriteAllText((Join-Path $journalCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Journal Events Test""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
function Invoke-JournalGodot([string]$Script,[string]$Name){
 $journalOutput=Join-Path $journalRun ($Name+'.json');$journalLog=Join-Path $journalRun ($Name+'.engine.log')
 $journalInfo=[Diagnostics.ProcessStartInfo]::new();$journalInfo.FileName=$Godot;$journalInfo.WorkingDirectory=$journalWorkspace;$journalInfo.UseShellExecute=$false;$journalInfo.CreateNoWindow=$true;$journalInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$journalInfo.RedirectStandardOutput=$true;$journalInfo.RedirectStandardError=$true
 foreach($argument in @('--headless','--max-fps','60','--path',$journalCopy,'--log-file',$journalLog,'--script',('res://tests/'+$Script),'--',('--report='+$journalOutput),('--install='+$Install),'--entity-api-rest=false')){$journalInfo.ArgumentList.Add($argument)}
 $journalProcess=[Diagnostics.Process]::Start($journalInfo);$journalStdout=$journalProcess.StandardOutput.ReadToEndAsync();$journalStderr=$journalProcess.StandardError.ReadToEndAsync();$journalTimeout=$false
 $journalDeadline=[DateTime]::UtcNow.AddSeconds(35)
 while(-not$journalProcess.WaitForExit(1000)){if([DateTime]::UtcNow-ge$journalDeadline){$journalTimeout=$true;$journalProcess.Kill($true);$journalProcess.WaitForExit();break}}
 $journalProcess.Refresh();[IO.File]::WriteAllText((Join-Path $journalRun ($Name+'.stdout.log')),$journalStdout.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $journalRun ($Name+'.stderr.log')),$journalStderr.GetAwaiter().GetResult())
 $journalResult=if(Test-Path -LiteralPath $journalOutput){Get-Content -LiteralPath $journalOutput -Raw|ConvertFrom-Json}else{$null}
 $journalClean=([IO.File]::ReadAllText($journalLog)-notmatch '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit')
 $journalPassed=$journalResult-and($journalResult.success-or$journalResult.passed)-and$journalProcess.ExitCode-eq0-and-not$journalTimeout-and$journalClean
 return [ordered]@{name=$Name;script=$Script;success=[bool]$journalPassed;checks=if($journalResult){$journalResult.checks}else{0};result=$journalOutput;engineLog=$journalLog;exitCode=$journalProcess.ExitCode;timedOut=$journalTimeout;cleanEngine=$journalClean}
}
$journalResults=@()
foreach($case in @(@('native_journal_events_source_test.gd','source'),@('native_journal_state_test.gd','state'),@('map_journal_ui_test.gd','legacy-ui'))){$journalResults+=Invoke-JournalGodot $case[0] $case[1];if(-not$journalResults[-1].success){break}}
$journalTap=Join-Path $journalRun 'protocol.tap'
& node --test (Join-Path $journalWorkspace 'test/native-journal-events.test.js') (Join-Path $journalWorkspace 'test/native-feat-description-protocol.test.js') (Join-Path $journalWorkspace 'test/native-skill-description-protocol.test.js') (Join-Path $journalWorkspace 'test/network-game-session.test.js') 1>$journalTap 2>(Join-Path $journalRun 'protocol.stderr.log')
$journalNodeCode=$LASTEXITCODE;$journalNodeText=[IO.File]::ReadAllText($journalTap);$journalNodeCount=0
if($journalNodeText-match '(?m)^# tests (\d+)\r?$'){$journalNodeCount=[int]$Matches[1]}
$journalNodePass=$journalNodeCode-eq0-and$journalNodeText-match '(?m)^# fail 0\r?$'
$journalChanged=@($journalHashes|Where-Object{(Get-FileHash -LiteralPath (Join-Path $journalProject $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$journalPassed=$journalResults.Count-eq3-and-not($journalResults|Where-Object{-not$_.success})-and$journalNodePass-and$journalChanged.Count-eq0
$journalReceipt=[ordered]@{success=[bool]$journalPassed;testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$journalRun;engineSha256=(Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash.ToLowerInvariant();inputs=$journalHashes;changedInputs=$journalChanged;results=$journalResults;protocolTests=$journalNodeCount;protocolExitCode=$journalNodeCode;protocolTap=$journalTap;gameServerConnections=0;publicConnections=0;nativeBuilds=0;gpu=$false;scope='Copied/pinned actual native journal/frame/desktop controls with installed geometry and controlled rasters/fonts; actual session ordered-packet/lifecycle tests, existing state/map-journal UI and GUI3/4/session regressions. Authored owners, no original-server/live game-window acceptance.'}
$journalReceiptPath=Join-Path $journalRun 'runner.json';[IO.File]::WriteAllText($journalReceiptPath,($journalReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
if($journalPassed){[IO.File]::WriteAllText((Join-Path $journalProject 'reports/native-journal-events-v1-receipt.json'),($journalReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)}
$journalNativeChecks=0;foreach($journalEntry in $journalResults){$journalNativeChecks+=[int]$journalEntry.checks}
[pscustomobject]@{success=$journalPassed;directory=$journalRun;nativeChecks=$journalNativeChecks;protocolTests=$journalNodeCount;results=$journalResults;changedInputs=$journalChanged.Count}|ConvertTo-Json -Depth 5
if(-not$journalPassed){throw ('Owned journal checks failed; finite logs/inputs retained: '+$journalRun)}
