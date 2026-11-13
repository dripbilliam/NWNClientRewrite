[CmdletBinding()]
param([string]$Name='native-associate-names-v1')
$ErrorActionPreference='Stop'
if($Name-notmatch'^[a-z0-9-]+$'){throw 'Use a simple unique receipt name'}
$featProject=Split-Path -Parent $PSScriptRoot
$featWorkspace=Split-Path -Parent $featProject
$featGodot=Join-Path $featProject '.tools/Godot_v4.7.2-stable_win64.exe'
$featOracle=Join-Path $featProject '../backups/animations/native-creation-feat-choice-observations-v1.json'
$featReceipt=Join-Path $featProject ('reports/'+$Name+'-receipt.json')
if(Test-Path -LiteralPath $featReceipt){throw 'Preserve the existing receipt; choose another Name'}
if((Get-FileHash -LiteralPath $featGodot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected installed runtime; this test never builds or downloads'}
$featRun=Join-Path $featProject ('.cache/associate-names-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$featCopy=Join-Path $featRun 'project'
[IO.Directory]::CreateDirectory($featCopy)|Out-Null
$featFiles=@(& rg --files (Join-Path $featProject 'systems') -g '*.gd' -g '*.gdshader'|ForEach-Object{[IO.Path]::GetRelativePath($featProject,$_).Replace('\','/')})
$featFiles+=@('tests/native_associate_names_test.gd','systems/native_data/feedback_descriptors.json','native/particle_kernel.gdextension')
$featHashes=@{}
$featFiles+=@(& rg --files (Join-Path $featProject 'tests') -g '*.gd'|ForEach-Object{[IO.Path]::GetRelativePath($featProject,$_).Replace('\','/')}); $featFiles=@($featFiles|Sort-Object -Unique)
foreach($relative in $featFiles){
 $source=Join-Path $featProject $relative;$destination=Join-Path $featCopy $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
 $before=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
 Copy-Item -LiteralPath $source -Destination $destination
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$before){throw ('Source changed while copying: '+$relative)}
 $featHashes[$relative]=$before
}
# The isolated snapshot retains every native library for normal script parsing.
# Current-source acceptance pins the entry's entire static preload/extends
# closure; unrelated agents may continue changing modules this case never uses.
$featPending=[Collections.Generic.Queue[string]]::new();$featPending.Enqueue('tests/native_associate_names_test.gd')
$featClosure=[Collections.Generic.HashSet[string]]::new()
while($featPending.Count){
 $relative=$featPending.Dequeue()
 if(-not$featClosure.Add($relative)){continue}
 if(-not$featHashes.ContainsKey($relative)){throw ('Missing copied dependency: '+$relative)}
 $body=[IO.File]::ReadAllText((Join-Path $featCopy $relative))
 foreach($match in [regex]::Matches($body,'(?:preload|load)\(\s*"res://([^"]+)"\s*\)|extends\s+"res://([^"]+)"')){
  $dependency=if($match.Groups[1].Success){$match.Groups[1].Value}else{$match.Groups[2].Value}
  $featPending.Enqueue($dependency)
 }
}
Copy-Item -LiteralPath $featOracle -Destination (Join-Path $featCopy 'oracle.json')
$featOracleHash=(Get-FileHash -LiteralPath $featOracle -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $featCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Native Spells Binding Test""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
$featOutput=Join-Path $featRun 'result.json';$featLog=Join-Path $featRun 'engine.log'
$featInfo=[Diagnostics.ProcessStartInfo]::new();$featInfo.FileName=$featGodot;$featInfo.WorkingDirectory=$featWorkspace;$featInfo.UseShellExecute=$false;$featInfo.CreateNoWindow=$true;$featInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$featInfo.RedirectStandardOutput=$true;$featInfo.RedirectStandardError=$true
foreach($argument in @('--headless','--max-fps','60','--path',$featCopy,'--log-file',$featLog,'--script','res://tests/native_associate_names_test.gd','--',('--report='+$featOutput),'--oracle=res://oracle.json',('--install='+[IO.Path]::GetFullPath((Join-Path $featWorkspace '../FullDecomp/NwnRootInstall'))),'--entity-api-rest=false')){$featInfo.ArgumentList.Add($argument)}
$featProcess=[Diagnostics.Process]::Start($featInfo);$featStdout=$featProcess.StandardOutput.ReadToEndAsync();$featStderr=$featProcess.StandardError.ReadToEndAsync();$featTimedOut=$false
$featDeadline=[DateTime]::UtcNow.AddSeconds(65)
while(-not$featProcess.WaitForExit(500)){
 if([DateTime]::UtcNow-ge$featDeadline){$featTimedOut=$true;$featProcess.Kill($true);$featProcess.WaitForExit();break}
}
$featProcess.Refresh()
[IO.File]::WriteAllText((Join-Path $featRun 'stdout.log'),$featStdout.GetAwaiter().GetResult())
[IO.File]::WriteAllText((Join-Path $featRun 'stderr.log'),$featStderr.GetAwaiter().GetResult())
$featChanged=@($featClosure|Where-Object{(Get-FileHash -LiteralPath (Join-Path $featProject $_) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$featHashes[$_]})
$featResult=if(Test-Path -LiteralPath $featOutput){Get-Content -LiteralPath $featOutput -Raw|ConvertFrom-Json}else{$null}
$featClean=(Test-Path -LiteralPath $featLog)-and[IO.File]::ReadAllText($featLog)-notmatch'(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|Unicode parsing error|ObjectDB instances leaked|Leaked instance|still in use at exit'
$featSuccess=-not$featTimedOut-and$featProcess.ExitCode-eq0-and$null-ne$featResult-and$featResult.success-and$featClean-and$featChanged.Count-eq0
$featPacket=[ordered]@{success=$featSuccess;testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$featRun;engineSha256=(Get-FileHash -LiteralPath $featGodot -Algorithm SHA256).Hash.ToLowerInvariant();pid=$featProcess.Id;exitCode=$featProcess.ExitCode;timedOut=$featTimedOut;engineClean=$featClean;changedInputs=$featChanged;inputs=@($featClosure|Sort-Object|ForEach-Object{@{path=$_;sha256=$featHashes[$_]}});copiedSnapshotInputs=$featHashes;oracleSha256=$featOracleHash;result=$featResult;nativeBuilds=0;gpu=$false;serverConnections=0;scope='Actual native asset worker/cache/scoped generation with installed and active override LTR/filter, lifecycle and capture-gap checks. No creator/server/GPU/pixels acceptance.'}
[IO.File]::WriteAllText((Join-Path $featRun 'receipt.json'),($featPacket|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
if(-not$featSuccess){throw ('Owned feat-binding case rejected; inspect '+$featRun)}
Copy-Item -LiteralPath (Join-Path $featRun 'receipt.json') -Destination $featReceipt
[pscustomobject]@{success=$true;checks=$featResult.checks;receipt=$featReceipt;directory=$featRun}|ConvertTo-Json -Depth 4
