param([string]$Godot='',[string]$Install='',[switch]$CheckOnly)
$ErrorActionPreference='Stop'
$flowProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if(-not$Godot){$Godot=Join-Path $flowProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not$Install){$Install=[IO.Path]::GetFullPath((Join-Path $flowProject '../../FullDecomp/NwnRootInstall'))}
if((Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot runtime; this runner never builds/downloads'}
$flowRun=Join-Path $flowProject ('.cache/pregame-navigation-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$flowCopy=Join-Path $flowRun 'project';[IO.Directory]::CreateDirectory($flowCopy)|Out-Null
$flowFiles=@(& rg --files (Join-Path $flowProject 'systems') (Join-Path $flowProject 'tests') -g '*.gd' -g '*.gdshader'|ForEach-Object{[IO.Path]::GetRelativePath($flowProject,$_).Replace('\','/')})
$flowFiles+=@([IO.Directory]::EnumerateFiles($flowProject,'*.gd',[IO.SearchOption]::TopDirectoryOnly)|ForEach-Object{[IO.Path]::GetRelativePath($flowProject,$_).Replace('\','/')})
$flowFiles+=@('systems/native_data/feedback_descriptors.json','native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','tools/test-native-pregame-flow.ps1')
$flowInputs=@()
foreach($relative in ($flowFiles|Sort-Object -Unique)){
 $source=Join-Path $flowProject $relative;$destination=Join-Path $flowCopy $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
 $hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant();Copy-Item -LiteralPath $source -Destination $destination
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hash){throw ('Source changed while copying: '+$relative)}
 $flowInputs+=@{path=$relative;sha256=$hash}
}
$flowHashes=@{};foreach($row in $flowInputs){$flowHashes[$row.path]=$row.sha256}
$flowQueue=[Collections.Generic.Queue[string]]::new();$flowQueue.Enqueue('tests/native_pregame_flow_test.gd')
$flowClosure=[Collections.Generic.HashSet[string]]::new()
while($flowQueue.Count){
 $relative=$flowQueue.Dequeue();if(-not$flowClosure.Add($relative)){continue}
 if(-not$flowHashes.ContainsKey($relative)){throw ('Missing copied static dependency: '+$relative)}
 $body=[IO.File]::ReadAllText((Join-Path $flowCopy $relative))
 foreach($match in [regex]::Matches($body,'(?:preload|load)\(\s*"res://([^"]+)"\s*\)|extends\s+"res://([^"]+)"')){
  $dependency=if($match.Groups[1].Success){$match.Groups[1].Value}else{$match.Groups[2].Value};$flowQueue.Enqueue($dependency)
 }
}
foreach($relative in @('systems/native_data/feedback_descriptors.json','native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','tools/test-native-pregame-flow.ps1')){[void]$flowClosure.Add($relative)}
[IO.File]::WriteAllText((Join-Path $flowCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Pregame Flow Test""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
$flowLog=Join-Path $flowRun 'engine.log';$flowOutput=Join-Path $flowRun 'result.json'
$flowInfo=[Diagnostics.ProcessStartInfo]::new();$flowInfo.FileName=$Godot;$flowInfo.WorkingDirectory=$flowProject;$flowInfo.UseShellExecute=$false;$flowInfo.CreateNoWindow=$true;$flowInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$flowInfo.RedirectStandardOutput=$true;$flowInfo.RedirectStandardError=$true
$flowArguments=@('--headless','--max-fps','60','--path',$flowCopy,'--log-file',$flowLog,'--script','res://tests/native_pregame_flow_test.gd')
if($CheckOnly){$flowArguments+='--check-only'}
$flowArguments+=@('--',('--report='+$flowOutput),('--install='+$Install),'--entity-api-rest=false')
foreach($argument in $flowArguments){$flowInfo.ArgumentList.Add($argument)}
function Read-FlowLiveLog {
 if(-not(Test-Path -LiteralPath $flowLog)){return ''}
 try{
  $liveStream=[IO.File]::Open($flowLog,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite-bor[IO.FileShare]::Delete))
  $liveReader=[IO.StreamReader]::new($liveStream)
  try{$liveBuffer=[char[]]::new(65536);$liveCount=$liveReader.Read($liveBuffer,0,$liveBuffer.Length);return [string]::new($liveBuffer,0,$liveCount)}finally{$liveReader.Dispose()}
 }catch [IO.IOException]{return ''} # A live writer can deny sharing; final scan remains mandatory.
}
$flowStdoutPath=Join-Path $flowRun 'stdout.log';$flowStderrPath=Join-Path $flowRun 'stderr.log'
$flowStdoutFile=[IO.File]::Create($flowStdoutPath);$flowStderrFile=[IO.File]::Create($flowStderrPath)
$flowProcess=[Diagnostics.Process]::Start($flowInfo);$flowOut=$flowProcess.StandardOutput.BaseStream.CopyToAsync($flowStdoutFile);$flowErr=$flowProcess.StandardError.BaseStream.CopyToAsync($flowStderrFile);$flowTimeout=$false;$flowRuntimeError=$false;$flowLogLimit=$false;$flowDeadline=[DateTime]::UtcNow.AddSeconds(65)
try{
 while(-not$flowProcess.WaitForExit(500)){
  $flowOversized=@(@($flowLog,$flowStdoutPath,$flowStderrPath)|Where-Object{(Test-Path -LiteralPath $_)-and(Get-Item -LiteralPath $_).Length-gt8388608})
  if($flowOversized.Count){$flowLogLimit=$true;$flowProcess.Kill($true);$flowProcess.WaitForExit();break}
  if((Read-FlowLiveLog)-match'(?m)^ERROR:|SCRIPT ERROR|Parse Error'){$flowRuntimeError=$true;$flowProcess.Kill($true);$flowProcess.WaitForExit();break}
  if([DateTime]::UtcNow-ge$flowDeadline){$flowTimeout=$true;$flowProcess.Kill($true);$flowProcess.WaitForExit();break}
 }
}finally{
 if(-not$flowProcess.HasExited){$flowProcess.Kill($true);$flowProcess.WaitForExit()}
 try{$flowOut.GetAwaiter().GetResult();$flowErr.GetAwaiter().GetResult()}finally{$flowStdoutFile.Dispose();$flowStderrFile.Dispose()}
}
$flowProcess.Refresh()
$flowResult=if(Test-Path -LiteralPath $flowOutput){Get-Content -LiteralPath $flowOutput -Raw|ConvertFrom-Json}else{$null}
$flowClean=Test-Path -LiteralPath $flowLog
if($flowClean){
 $flowFinalReader=[IO.File]::OpenText($flowLog)
 try{while($null-ne($flowLine=$flowFinalReader.ReadLine())){if($flowLine-match'^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|Unicode parsing error|ObjectDB instances leaked|Leaked instance|still in use at exit'){$flowClean=$false;break}}}finally{$flowFinalReader.Dispose()}
}
$flowChanged=@($flowInputs|Where-Object{$flowClosure.Contains($_.path)-and(Get-FileHash -LiteralPath (Join-Path $flowProject $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$flowOutsideChanges=@($flowInputs|Where-Object{-not$flowClosure.Contains($_.path)-and(Get-FileHash -LiteralPath (Join-Path $flowProject $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$flowCopiedChanged=@($flowInputs|Where-Object{(Get-FileHash -LiteralPath (Join-Path $flowCopy $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$flowSuccess=$flowProcess.ExitCode-eq0-and-not$flowTimeout-and-not$flowLogLimit-and$flowClean-and$flowChanged.Count-eq0-and$flowCopiedChanged.Count-eq0-and($CheckOnly-or($flowResult-and$flowResult.success))
$flowReceipt=[ordered]@{success=[bool]$flowSuccess;checkOnly=[bool]$CheckOnly;testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$flowRun;inputs=$flowInputs;staticClosure=@($flowClosure|Sort-Object);changedInputs=$flowChanged;outsideClosureChanges=$flowOutsideChanges;changedCopiedInputs=$flowCopiedChanged;checks=if($flowResult){$flowResult.checks}else{0};exitCode=$flowProcess.ExitCode;timedOut=$flowTimeout;runtimeErrorStopped=$flowRuntimeError;logLimitStopped=$flowLogLimit;observedLogLimitBytes=8388608;cleanEngine=[bool]$flowClean;engineLog=$flowLog;result=$flowOutput;gameServerConnections=0;publicConnections=0;nativeBuilds=0;gpu=$false;scope='Actual original Main/Multiplayer/Browser/Picker/Creator entry/navigation with installed Controls, authored received replies and controlled raster/fonts. Current-source acceptance covers static preload/extends closure plus explicit feedback/native dependencies; copied unused files can differ afterward. No login/server/user-client/GPU/pixel/full-character-completion acceptance. CheckOnly never establishes behavior.'}
[IO.File]::WriteAllText((Join-Path $flowRun 'runner.json'),($flowReceipt|ConvertTo-Json -Depth 7)+[Environment]::NewLine)
if($flowSuccess-and-not$CheckOnly){[IO.File]::WriteAllText((Join-Path $flowProject 'reports/native-pregame-flow-v1-receipt.json'),($flowReceipt|ConvertTo-Json -Depth 7)+[Environment]::NewLine)}
[pscustomobject]$flowReceipt|Select-Object success,checkOnly,directory,checks,exitCode,timedOut,cleanEngine,@{Name='changedInputs';Expression={$flowChanged.Count}},@{Name='changedCopiedInputs';Expression={$flowCopiedChanged.Count}}|ConvertTo-Json -Depth 4
if(-not$flowSuccess){throw ('Owned pregame flow check rejected; exact inputs/logs retained: '+$flowRun)}
