param([Parameter(Mandatory=$true)][ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Run,[ValidateSet('adapter','index','collision')][string]$Case='adapter')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$scriptEntry=if($Case -eq 'index'){'native_drive_spatial_index_test.gd'}elseif($Case -eq 'collision'){'native_drive_collision_test.gd'}else{'native_drive_spatial_adapter_test.gd'}
$runRoot=Join-Path $projectRoot ('.cache/native-drive-spatial-index/'+$Run)
if(Test-Path -LiteralPath $runRoot){throw 'Fresh label required; evidence retained'}
$copyRoot=Join-Path $runRoot 'project'
New-Item -ItemType Directory -Path $copyRoot -Force | Out-Null
$engine=Join-Path $projectRoot '.tools/Godot_v4.7.2-stable_win64.exe'
$expectedEngine='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
if((Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant() -ne $expectedEngine){throw 'Engine differs'}
$discovered=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$todo=[Collections.Generic.Queue[string]]::new()
foreach($entry in @('tests/native_drive_spatial_adapter_test.gd','tests/native_drive_collision_test.gd','tests/native_drive_spatial_index_test.gd')){$todo.Enqueue($entry)}
while($todo.Count){
 $relative=$todo.Dequeue()
 if(-not$discovered.Add($relative)){continue}
 $target=[IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
 if(-not$target.StartsWith($projectRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Resource path escaped project'}
 $body=[IO.File]::ReadAllText($target)
 foreach($match in [regex]::Matches($body,'["'']res://([^"'']+\.gd)["'']')){$todo.Enqueue($match.Groups[1].Value)}
}
$sourceFiles=@($discovered|Sort-Object)+@('NATIVE-DRIVE-SPATIAL-INDEX.md','tools/test-native-drive-spatial-index.ps1')
$sourcePins=@();$copyPins=@()
foreach($relative in $sourceFiles){
 $source=Join-Path $projectRoot $relative
 $hash=(Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant()
 $sourcePins+=@{path=$source;sha256=$hash}
 if($relative.EndsWith('.gd')){
  $destination=Join-Path $copyRoot $relative
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $destination
  $copyPins+=@{path=$destination;sha256=$hash}
 }
}
$guardNames=@('project.godot','native/particle_kernel.gdextension','.godot/extension_list.cfg','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json')
$guards=@($guardNames|ForEach-Object{$target=Join-Path $projectRoot $_;@{path=$target;exists=(Test-Path -LiteralPath $target);sha256=if(Test-Path -LiteralPath $target){(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant()}else{$null}}})
$protected=@(Get-Process -Id 7568,25060 -ErrorAction Stop|ForEach-Object{@{id=$_.Id;name=$_.ProcessName;path=$_.Path;start=$_.StartTime.ToUniversalTime().ToString('o')}})
[IO.File]::WriteAllLines((Join-Path $copyRoot 'project.godot'),@('config_version=5','[application]','config/name="Isolated Drive Spatial Correctness"','[rendering]','renderer/rendering_method="gl_compatibility"'),[Text.UTF8Encoding]::new($false))
$child=$null;$timedOut=$false;$failure=$null;$exitCode=$null
try{
 $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$engine;$start.WorkingDirectory=$copyRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 $reportArgument='--report='+(Join-Path $runRoot 'result.json')
 foreach($argument in @('--headless','--path',$copyRoot,'--script',('res://tests/'+$scriptEntry),'--log-file',(Join-Path $runRoot 'engine.log'),'--',$reportArgument)){$start.ArgumentList.Add($argument)}
 [IO.File]::WriteAllText((Join-Path $runRoot 'arguments.json'),($start.ArgumentList|ConvertTo-Json))
 $child=[Diagnostics.Process]::Start($start);$childStart=$child.StartTime.ToUniversalTime();Write-Output ('Owned headless PID '+$child.Id)
 $stdout=$child.StandardOutput.ReadToEndAsync();$stderr=$child.StandardError.ReadToEndAsync()
 if(-not $child.WaitForExit(65000)){
  $current=Get-Process -Id $child.Id -ErrorAction Stop
  if($current.Path -ne $engine -or $current.StartTime.ToUniversalTime() -ne $childStart){throw 'Owned engine identity changed; preserved'}
  $timedOut=$true;$child.Kill();$child.WaitForExit(10000)|Out-Null
 }
 $exitCode=$child.ExitCode
 $out=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult()
 if([Text.Encoding]::UTF8.GetByteCount($out)+[Text.Encoding]::UTF8.GetByteCount($err) -gt 2097152){throw 'Engine output exceeded2MiB'}
 [IO.File]::WriteAllText((Join-Path $runRoot 'stdout.txt'),$out)
 [IO.File]::WriteAllText((Join-Path $runRoot 'stderr.txt'),$err)
}catch{$failure=$_.Exception.Message}
$sourceResults=@($sourcePins|ForEach-Object{@{path=$_.path;sha256=$_.sha256;unchanged=(Get-FileHash -LiteralPath $_.path).Hash.ToLowerInvariant() -eq $_.sha256}})
$copyResults=@($copyPins|ForEach-Object{@{path=$_.path;sha256=$_.sha256;unchanged=(Get-FileHash -LiteralPath $_.path).Hash.ToLowerInvariant() -eq $_.sha256}})
$guardResults=@($guards|ForEach-Object{$exists=Test-Path -LiteralPath $_.path;@{path=$_.path;unchanged=$exists -eq $_.exists -and (-not$exists -or (Get-FileHash -LiteralPath $_.path).Hash.ToLowerInvariant() -eq $_.sha256)}})
$processResults=@($protected|ForEach-Object{$current=Get-Process -Id $_.id -ErrorAction SilentlyContinue;@{id=$_.id;unchanged=$current -and $current.ProcessName -eq $_.name -and $current.Path -eq $_.path -and $current.StartTime.ToUniversalTime().ToString('o') -eq $_.start}})
$result=$null
if(Test-Path -LiteralPath (Join-Path $runRoot 'result.json')){$result=Get-Content -LiteralPath (Join-Path $runRoot 'result.json') -Raw|ConvertFrom-Json}
$passed=$exitCode -eq 0 -and $result.success -eq $true -and -not$timedOut -and -not$failure -and -not($sourceResults.unchanged -contains$false) -and -not($copyResults.unchanged -contains$false) -and -not($guardResults.unchanged -contains$false) -and -not($processResults.unchanged -contains$false) -and (Get-FileHash -LiteralPath $engine).Hash.ToLowerInvariant() -eq $expectedEngine
$proof=[ordered]@{success=$passed;exitCode=$exitCode;pid=if($child){$child.Id}else{$null};closed=$null -eq$child -or$child.HasExited;timedOut=$timedOut;failure=$failure;result=$result;sources=$sourceResults;copies=$copyResults;guards=$guardResults;protected=$processResults;engineSha256=$expectedEngine;nativeBuilds=0;network=$false;gpu=$false;nativeExtensionsLoaded=$false}
[IO.File]::WriteAllText((Join-Path $runRoot 'proof.json'),($proof|ConvertTo-Json -Depth 10))
[ordered]@{success=$passed;exitCode=$exitCode;pid=$proof.pid;closed=$proof.closed;failure=$failure;result=$result;sourceGuards=@($sourceResults|Where-Object{-not$_.unchanged}).Count;copyGuards=@($copyResults|Where-Object{-not$_.unchanged}).Count;otherGuards=@($guardResults|Where-Object{-not$_.unchanged}).Count;processGuards=@($processResults|Where-Object{-not$_.unchanged}).Count}|ConvertTo-Json -Depth 5
if(-not$passed){Get-Content -LiteralPath (Join-Path $runRoot 'stderr.txt') -ErrorAction SilentlyContinue;exit 1}
