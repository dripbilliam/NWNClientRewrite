param([string]$Godot='',[string]$Install='')
$ErrorActionPreference='Stop'
$skillProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$skillWorkspace=[IO.Path]::GetFullPath((Join-Path $skillProject '..'))
if(-not$Godot){$Godot=Join-Path $skillProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not$Install){$Install=[IO.Path]::GetFullPath((Join-Path $skillWorkspace '../FullDecomp/NwnRootInstall'))}
if((Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot runtime; this runner never builds/downloads'}
$skillRun=Join-Path $skillProject ('.cache/skill-description-source-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$skillCopy=Join-Path $skillRun 'project'
[IO.Directory]::CreateDirectory($skillCopy)|Out-Null
$skillFiles=@(& rg --files (Join-Path $skillProject 'systems') -g '*.gd' -g '*.gdshader'|ForEach-Object{[IO.Path]::GetRelativePath($skillProject,$_).Replace('\','/')})
$skillFiles+=@('systems/native_data/feedback_descriptors.json','tests/native_skill_description_source_test.gd','tests/run-native-skill-description-source-tests.ps1')
$skillHashes=@()
foreach($relative in $skillFiles){
 $source=Join-Path $skillProject $relative;$destination=Join-Path $skillCopy $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
 $before=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
 Copy-Item -LiteralPath $source -Destination $destination
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$before){throw ('Source changed while copying: '+$relative)}
 $skillHashes+=@{path=$relative;sha256=$before}
}
[IO.File]::WriteAllText((Join-Path $skillCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Source Skill Description Test""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
$skillOutput=Join-Path $skillRun 'result.json';$skillLog=Join-Path $skillRun 'engine.log'
$skillInfo=[Diagnostics.ProcessStartInfo]::new();$skillInfo.FileName=$Godot;$skillInfo.WorkingDirectory=$skillWorkspace;$skillInfo.UseShellExecute=$false;$skillInfo.CreateNoWindow=$true;$skillInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$skillInfo.RedirectStandardOutput=$true;$skillInfo.RedirectStandardError=$true
foreach($argument in @('--headless','--max-fps','60','--path',$skillCopy,'--log-file',$skillLog,'--script','res://tests/native_skill_description_source_test.gd','--',('--report='+$skillOutput),('--install='+$Install),'--entity-api-rest=false')){$skillInfo.ArgumentList.Add($argument)}
$skillProcess=[Diagnostics.Process]::Start($skillInfo);$skillStdout=$skillProcess.StandardOutput.ReadToEndAsync();$skillStderr=$skillProcess.StandardError.ReadToEndAsync()
$skillDeadline=[DateTime]::UtcNow.AddSeconds(35)
while(-not$skillProcess.WaitForExit(1000)){
 if([DateTime]::UtcNow-ge$skillDeadline){$skillProcess.Kill($true);$skillProcess.WaitForExit();break}
}
$skillProcess.Refresh()
[IO.File]::WriteAllText((Join-Path $skillRun 'stdout.log'),$skillStdout.GetAwaiter().GetResult())
[IO.File]::WriteAllText((Join-Path $skillRun 'stderr.log'),$skillStderr.GetAwaiter().GetResult())
if(-not(Test-Path -LiteralPath $skillOutput)){throw ('Owned source skill test produced no result; inspect '+$skillLog)}
$skillResult=Get-Content -LiteralPath $skillOutput -Raw|ConvertFrom-Json
if($skillProcess.ExitCode-ne0-or-not$skillResult.success){throw ('Source skill test failed: '+($skillResult.failures -join ', '))}
if([IO.File]::ReadAllText($skillLog)-match '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit'){throw ('Source skill test engine/script/lifetime error; inspect '+$skillLog)}
foreach($input in $skillHashes){if((Get-FileHash -LiteralPath (Join-Path $skillProject $input.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$input.sha256){throw ('Source changed during source skill test: '+$input.path)}}
$skillReceipt=[ordered]@{success=$true;testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$skillRun;engineSha256=(Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash.ToLowerInvariant();inputs=$skillHashes;checks=$skillResult.checks;result=$skillOutput;engineLog=$skillLog;exitCode=$skillProcess.ExitCode;gameServerConnections=0;publicConnections=0;nativeBuilds=0;gpu=$false;scope='Copied/pinned real native sheet/frame/desktop/receive code, installed MDL geometry through native worker decoder, real headless pointer input and controlled rasters/fonts. Authored actor/token/TLK fixtures; no original-server or original pixel/font acceptance.'}
[IO.File]::WriteAllText((Join-Path $skillProject 'reports/native-skill-description-source-v1-receipt.json'),($skillReceipt|ConvertTo-Json -Depth 6)+[Environment]::NewLine)
[pscustomobject]@{success=$true;checks=$skillResult.checks;result=$skillOutput;engineLog=$skillLog;receipt=(Join-Path $skillProject 'reports/native-skill-description-source-v1-receipt.json');selection=$skillResult.diagnostic.selection_ms}|ConvertTo-Json -Depth 5
