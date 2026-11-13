param([string]$Godot='')
$ErrorActionPreference='Stop'
$recordProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$recordWorkspace=[IO.Path]::GetFullPath((Join-Path $recordProject '..'))
if(-not$Godot){$Godot=Join-Path $recordProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if((Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot executable; no build/download permitted'}
$recordRun=Join-Path $recordProject ('.cache/associate-record-access-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$recordCopy=Join-Path $recordRun 'project';[IO.Directory]::CreateDirectory($recordCopy)|Out-Null
$recordGd=@('systems/native_gui_panel_access.gd','systems/native_data/gui_panel_access.gd','tests/native_gui_panel_policy_test.gd','tests/native_record_target_access_test.gd')
$recordNode=@('test/native-associate-record-target.test.js','test/native-gui-panel-access.test.js','test/native-gui-context-events.test.js','test/native-skill-description-protocol.test.js','test/native-feat-description-protocol.test.js','test/native-journal-events.test.js','test/network-game-session.test.js')
$recordFiles=@($recordGd|ForEach-Object{'godot-client/'+$_})+$recordNode+@('godot-client/tools/test-native-record-target-access.ps1')
$recordFiles+=@(& rg --files (Join-Path $recordWorkspace 'src') (Join-Path $recordWorkspace 'electron') -g '*.js' -g '*.mjs' -g '*.cjs'|ForEach-Object{[IO.Path]::GetRelativePath($recordWorkspace,$_).Replace('\','/')})
$recordPins=@()
foreach($relative in ($recordFiles|Sort-Object -Unique)){
 $source=Join-Path $recordWorkspace $relative;$digest=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
 $recordPins+=@{path=$relative;sha256=$digest}
 if($relative-in($recordGd|ForEach-Object{'godot-client/'+$_})){
  $destination=Join-Path $recordCopy $relative.Substring('godot-client/'.Length);[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null;Copy-Item -LiteralPath $source -Destination $destination
  if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$digest){throw 'Source changed during native copy'}
 }
}
[IO.File]::WriteAllText((Join-Path $recordCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Record Target Adapter""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
$recordLog=Join-Path $recordRun 'adapter.engine.log';$recordReport=Join-Path $recordRun 'adapter.json'
$recordInfo=[Diagnostics.ProcessStartInfo]::new();$recordInfo.FileName=$Godot;$recordInfo.UseShellExecute=$false;$recordInfo.CreateNoWindow=$true;$recordInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$recordInfo.RedirectStandardOutput=$true;$recordInfo.RedirectStandardError=$true
foreach($argument in @('--headless','--path',$recordCopy,'--log-file',$recordLog,'--script','res://tests/native_record_target_access_test.gd','--',('--report='+$recordReport),'--entity-api-rest=false')){$recordInfo.ArgumentList.Add($argument)}
$recordProcess=[Diagnostics.Process]::Start($recordInfo);$recordOut=$recordProcess.StandardOutput.ReadToEndAsync();$recordErr=$recordProcess.StandardError.ReadToEndAsync();$recordTimeout=$false
if(-not$recordProcess.WaitForExit(35000)){$recordTimeout=$true;$recordProcess.Kill($true);$recordProcess.WaitForExit()}
$recordProcess.Refresh();[IO.File]::WriteAllText((Join-Path $recordRun 'adapter.stdout.log'),$recordOut.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $recordRun 'adapter.stderr.log'),$recordErr.GetAwaiter().GetResult())
$recordResult=if(Test-Path -LiteralPath $recordReport){Get-Content -LiteralPath $recordReport -Raw|ConvertFrom-Json}else{$null}
$recordClean=([IO.File]::ReadAllText($recordLog)-notmatch '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit')
$recordNative=[ordered]@{success=[bool]($recordResult-and$recordResult.success-and$recordProcess.ExitCode-eq0-and-not$recordTimeout-and$recordClean);checks=if($recordResult){$recordResult.checks}else{0};exitCode=$recordProcess.ExitCode;timedOut=$recordTimeout;cleanEngine=$recordClean;result=$recordReport;log=$recordLog}
$recordNodeArgs=@('--test')+@($recordNode|ForEach-Object{Join-Path $recordWorkspace $_})
& node @recordNodeArgs 1>(Join-Path $recordRun 'node.tap') 2>(Join-Path $recordRun 'node.stderr.log')
$recordNodeCode=$LASTEXITCODE;$recordTap=[IO.File]::ReadAllText((Join-Path $recordRun 'node.tap'));$recordNodeCount=0
if($recordTap-match '(?m)^# tests (\d+)\r?$'){$recordNodeCount=[int]$Matches[1]}
$recordNodePass=$recordNodeCode-eq0-and$recordTap-match '(?m)^# fail 0\r?$'
$recordChanged=@($recordPins|Where-Object{(Get-FileHash -LiteralPath (Join-Path $recordWorkspace $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$recordPassed=$recordNative.success-and$recordNodePass-and$recordChanged.Count-eq0
$recordReceipt=[ordered]@{success=[bool]$recordPassed;testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$recordRun;engineSha256=(Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash.ToLowerInvariant();inputs=$recordPins;changedInputs=$recordChanged;native=$recordNative;nodeChecks=$recordNodeCount;nodeExitCode=$recordNodeCode;scope='Actual canonical adapter with authored Desktop target/readiness owners, plus actual Session target packets/admission/lifecycle and legacy regressions. Installed physical sheet UI and original-server callbacks are separate.';gameServerConnections=0;gpu=$false;nativeBuilds=0}
[IO.File]::WriteAllText((Join-Path $recordRun 'runner.json'),($recordReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
if($recordPassed){[IO.File]::WriteAllText((Join-Path $recordProject 'reports/native-record-target-access-v1-receipt.json'),($recordReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)}
[pscustomobject]@{success=$recordPassed;directory=$recordRun;native=$recordNative;nodeChecks=$recordNodeCount;nodeExitCode=$recordNodeCode;changedInputs=$recordChanged.Count}|ConvertTo-Json -Depth 6
if(-not$recordPassed){throw ('Owned target record checks rejected; finite evidence retained: '+$recordRun)}
