param([ValidateRange(0,1000000)][int]$Frames=0,[string]$Report='',[int]$PreserveOriginalPid=0,[switch]$CaptureCrash,[switch]$NormalHeap)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath($PSScriptRoot)
. (Join-Path $project 'tools/local-test-guard.ps1'); Assert-NativeLocalTestAvailable $project -PreserveOriginalPid $PreserveOriginalPid
$fixture=Get-Content -LiteralPath (Join-Path $project 'reports/native-capture-input-v1.json') -Raw|ConvertFrom-Json
if((Get-FileHash -LiteralPath $fixture.input -Algorithm SHA256).Hash.ToLowerInvariant()-ne$fixture.sha256){throw 'Private decoded protocol fixture differs'}
if($Report){$Report=[IO.Path]::GetFullPath($Report);if(Test-Path -LiteralPath $Report){throw 'Native world output already exists'}}
if($CaptureCrash-and-not$Report){throw 'Crash capture requires an unused report path'}
if($NormalHeap-and-not$CaptureCrash){throw 'NormalHeap only applies to debugger-protected checks'}
$nativeArgs=@('--path',$project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--script','res://native_capture_world.gd')
if($Report){$nativeArgs+=@('--verbose','--log-file',([IO.Path]::ChangeExtension($Report,'.engine.log')))}
$nativeArgs+=@('--',('--input='+$fixture.input),('--input-sha256='+$fixture.sha256));if($Frames){$nativeArgs+=('--frames='+$Frames)};if($Report){$nativeArgs+=('--report='+$Report)}
$engine=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
$sources=@{}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $project 'systems') -Recurse -Filter '*.gd'){$sources[$file.FullName.Substring($project.Length+1).Replace('\','/')]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
foreach($name in @('native-world.ps1','native_capture_world.gd','project.godot')){$sources[$name]=(Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()}
$start=[Diagnostics.ProcessStartInfo]::new();$start.WorkingDirectory=$project;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
if($CaptureCrash){
 $commands=[IO.Path]::ChangeExtension($Report,'.cdb.txt');$debugLog=[IO.Path]::ChangeExtension($Report,'.cdb.log')
 foreach($file in @($commands,$debugLog)){if(Test-Path -LiteralPath $file){throw 'Native debugger output exists'}}
 $break='.echo NATIVE_WORLD_EXCEPTION;.exr -1;.ecxr;kv;~* k;q'
 @('.echo NATIVE_WORLD_START',('sxe -c "'+$break+'" av'),('sxe -c "'+$break+'" 0xc0000374'),('sxe -c "'+$break+'" 0xc0000409'),('sxe -c "'+$break+'" 0xc000001d'),'.echo NATIVE_WORLD_ARMED','g')|Set-Content -LiteralPath $commands -Encoding ascii
 $start.FileName='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe'
 if($NormalHeap){$start.ArgumentList.Add('-hd')}
 foreach($arg in @('-G','-sins','-y',(Join-Path $project '.tools'),'-logo',$debugLog,'-cf',$commands,$engine)+$nativeArgs){$start.ArgumentList.Add($arg)}
}else{$start.FileName=$engine;foreach($arg in $nativeArgs){$start.ArgumentList.Add($arg)}}
$process=[Diagnostics.Process]::Start($start);$process.WaitForExit();$exitCode=$process.ExitCode
$armed=$false;$exception=$false
if($CaptureCrash){$log=Get-Content -LiteralPath $debugLog -Raw;$armed=$log-match'(?m)^NATIVE_WORLD_ARMED\r?$';$exception=$log-match'(?m)^NATIVE_WORLD_EXCEPTION\r?$';if(-not$armed-or$exception){$exitCode=1}}
if($Report){
 $errors=@();$unchanged=$true
 foreach($name in $sources.Keys){if((Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$sources[$name]){$unchanged=$false}}
 if(-not$unchanged){$errors+='Source changed during native world check'}
 if(-not(Test-Path -LiteralPath $Report)){$errors+='Native world report missing'}else{$result=Get-Content -LiteralPath $Report -Raw|ConvertFrom-Json;if(-not$result.success-or$result.worker_tasks_remaining-ne0){$errors+='Native world preparation/cleanup incomplete'}}
 $engineLog=[IO.Path]::ChangeExtension($Report,'.engine.log')
 if(-not(Test-Path -LiteralPath $engineLog)){$errors+='Engine log missing'}elseif((Get-Content -LiteralPath $engineLog -Raw)-match'(?im)^(?:SCRIPT ERROR|ERROR):|ObjectDB instances leaked|resources still in use'){$errors+='Engine or lifetime error'}
 if($exitCode){$errors+='Process or debugger failure'}
 @{passed=($errors.Count-eq0);failures=@($errors);sourceUnchanged=$unchanged;sourceSha256=$sources;nativeArguments=$nativeArgs;debuggerArmed=$armed;nativeException=$exception;debugHeapDisabled=[bool]$NormalHeap;nativeExecutableSha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant();cleanBenchmark=$false;scope='Functional native captured terrain/static/actor assembly; no JS rendering or network; complete effects/gameplay incomplete'}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath ([IO.Path]::ChangeExtension($Report,'.verification.json')) -Encoding utf8
 if($errors.Count){$exitCode=1}
}
exit $exitCode
