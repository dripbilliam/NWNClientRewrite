param([string]$Godot='',[string]$Install='')
$ErrorActionPreference='Stop'
$featProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$featWorkspace=[IO.Path]::GetFullPath((Join-Path $featProject '..'))
if(-not$Godot){$Godot=Join-Path $featProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not$Install){$Install=[IO.Path]::GetFullPath((Join-Path $featWorkspace '../FullDecomp/NwnRootInstall'))}
if((Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot runtime; this runner never builds/downloads'}
$featRun=Join-Path $featProject ('.cache/feat-description-source-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$featCopy=Join-Path $featRun 'project'
[IO.Directory]::CreateDirectory($featCopy)|Out-Null
$featFiles=@(& rg --files (Join-Path $featProject 'systems') -g '*.gd' -g '*.gdshader'|ForEach-Object{[IO.Path]::GetRelativePath($featProject,$_).Replace('\','/')})
$featFiles+=@('systems/native_data/feedback_descriptors.json','tests/native_skill_description_source_test.gd','../src/network_hud_input.js','../electron/network_game_session.mjs','../test/native-feat-description-protocol.test.js','../test/native-skill-description-protocol.test.js','../test/network-game-session.test.js','tests/native_feat_description_source_test.gd','tests/run-native-feat-description-source-tests.ps1')
$featHashes=@()
foreach($relative in $featFiles){
 $source=Join-Path $featProject $relative;$destination=Join-Path $featCopy $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
 $before=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
 Copy-Item -LiteralPath $source -Destination $destination
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$before){throw ('Source changed while copying: '+$relative)}
 $featHashes+=@{path=$relative;sha256=$before}
}
[IO.File]::WriteAllText((Join-Path $featCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Source Feat Description Test""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
$featOutput=Join-Path $featRun 'result.json';$featLog=Join-Path $featRun 'engine.log'
$featInfo=[Diagnostics.ProcessStartInfo]::new();$featInfo.FileName=$Godot;$featInfo.WorkingDirectory=$featWorkspace;$featInfo.UseShellExecute=$false;$featInfo.CreateNoWindow=$true;$featInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$featInfo.RedirectStandardOutput=$true;$featInfo.RedirectStandardError=$true
foreach($argument in @('--headless','--max-fps','60','--path',$featCopy,'--log-file',$featLog,'--script','res://tests/native_feat_description_source_test.gd','--',('--report='+$featOutput),('--install='+$Install),'--entity-api-rest=false')){$featInfo.ArgumentList.Add($argument)}
$featProcess=[Diagnostics.Process]::Start($featInfo);$featStdout=$featProcess.StandardOutput.ReadToEndAsync();$featStderr=$featProcess.StandardError.ReadToEndAsync()
$featDeadline=[DateTime]::UtcNow.AddSeconds(35)
while(-not$featProcess.WaitForExit(1000)){
 if([DateTime]::UtcNow-ge$featDeadline){$featProcess.Kill($true);$featProcess.WaitForExit();break}
}
$featProcess.Refresh()
[IO.File]::WriteAllText((Join-Path $featRun 'stdout.log'),$featStdout.GetAwaiter().GetResult())
[IO.File]::WriteAllText((Join-Path $featRun 'stderr.log'),$featStderr.GetAwaiter().GetResult())
if(-not(Test-Path -LiteralPath $featOutput)){throw ('Owned source feat test produced no result; inspect '+$featLog)}
$featResult=Get-Content -LiteralPath $featOutput -Raw|ConvertFrom-Json
if($featProcess.ExitCode-ne0-or-not$featResult.success){throw ('Source feat test failed: '+($featResult.failures -join ', '))}
if([IO.File]::ReadAllText($featLog)-match '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit'){throw ('Source feat test engine/script/lifetime error; inspect '+$featLog)}
foreach($input in $featHashes){if((Get-FileHash -LiteralPath (Join-Path $featProject $input.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$input.sha256){throw ('Source changed during source feat test: '+$input.path)}}
$featProtocolTap=Join-Path $featRun 'protocol.tap'
& node --test (Join-Path $featWorkspace 'test/native-feat-description-protocol.test.js') (Join-Path $featWorkspace 'test/native-skill-description-protocol.test.js') (Join-Path $featWorkspace 'test/network-game-session.test.js') 1>$featProtocolTap 2>(Join-Path $featRun 'protocol.stderr.log')
$featProtocolCode=$LASTEXITCODE
$featProtocolText=[IO.File]::ReadAllText($featProtocolTap)
if($featProtocolCode-ne0-or$featProtocolText-notmatch '(?m)^# tests (\d+)\r?$'){throw 'Feat/skill/session protocol regressions failed'}
$featProtocolCount=[int]$Matches[1]
if($featProtocolText-notmatch '(?m)^# fail 0\r?$'){throw 'Feat/skill/session protocol assertions failed'}
foreach($input in $featHashes){if((Get-FileHash -LiteralPath (Join-Path $featProject $input.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$input.sha256){throw ('Source changed during feat/protocol tests: '+$input.path)}}
$featReceipt=[ordered]@{success=$true;testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$featRun;engineSha256=(Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash.ToLowerInvariant();inputs=$featHashes;checks=$featResult.checks;result=$featOutput;engineLog=$featLog;exitCode=$featProcess.ExitCode;gameServerConnections=0;publicConnections=0;nativeBuilds=0;gpu=$false;scope='Copied/pinned real native sheet/frame/desktop/receive code, installed MDL geometry through native worker decoder, real headless pointer input and controlled rasters/fonts. Authored actor/token/TLK fixtures; no original-server or original pixel/font acceptance.'}
$featReceipt.protocolTests=$featProtocolCount;$featReceipt.protocolTap=$featProtocolTap
[IO.File]::WriteAllText((Join-Path $featProject 'reports/native-feat-description-source-v1-receipt.json'),($featReceipt|ConvertTo-Json -Depth 6)+[Environment]::NewLine)
[pscustomobject]@{success=$true;checks=$featResult.checks;result=$featOutput;engineLog=$featLog;receipt=(Join-Path $featProject 'reports/native-feat-description-source-v1-receipt.json');selection=$featResult.diagnostic.selection_ms}|ConvertTo-Json -Depth 5
