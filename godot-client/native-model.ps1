param([ValidatePattern('^[a-zA-Z0-9_]{1,32}$')][string]$Model='c_golstone',[string]$Install='',[ValidateRange(0,1000000)][int]$Frames=0,[string]$Report='',[int]$PreserveOriginalPid=0,[switch]$CaptureCrash)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath($PSScriptRoot)
. (Join-Path $project 'tools/local-test-guard.ps1'); Assert-NativeLocalTestAvailable $project -PreserveOriginalPid $PreserveOriginalPid
if(-not$Install){$Install=Join-Path (Split-Path $project -Parent) '../FullDecomp/NwnRootInstall'}
$Install=[IO.Path]::GetFullPath($Install)
if(-not(Test-Path -LiteralPath (Join-Path $Install 'data/nwn_base.key'))){throw 'Original game installation is unavailable'}
if($Report){$Report=[IO.Path]::GetFullPath($Report);if(Test-Path -LiteralPath $Report){throw 'Native preview report exists'}}
$nativeArgs=@('--path',$project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--script','res://native_model_view.gd')
if($Report){$nativeArgs+=@('--verbose','--log-file',([IO.Path]::ChangeExtension($Report,'.engine.log')))}
$nativeArgs+=@('--',('--install='+$Install),('--model='+$Model));if($Frames){$nativeArgs+=('--frames='+$Frames)};if($Report){$nativeArgs+=('--report='+$Report)}
$engine=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
$sources=@{}
foreach($file in @((Get-ChildItem (Join-Path $project 'systems/native_data') -Filter '*.gd'),(Get-ChildItem (Join-Path $project 'systems/native_render') -Filter '*.gd'))){foreach($source in $file){$sources[$source.FullName.Substring($project.Length+1).Replace('\','/')]=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}}
foreach($name in @('native-model.ps1','native_model_view.gd','systems/camera_controller.gd')){$sources[$name]=(Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()}
$start=[Diagnostics.ProcessStartInfo]::new();$start.WorkingDirectory=$project;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
if($CaptureCrash){
 if(-not$Report){throw 'Crash capture requires an unused report path'}
 $commands=[IO.Path]::ChangeExtension($Report,'.cdb.txt');$debugLog=[IO.Path]::ChangeExtension($Report,'.cdb.log')
 if((Test-Path -LiteralPath $commands)-or(Test-Path -LiteralPath $debugLog)){throw 'Native preview debugger output exists'}
 $break='.echo NATIVE_PREVIEW_EXCEPTION;.exr -1;.ecxr;kv;~* k;q'
 @('.echo NATIVE_PREVIEW_START',('sxe -c "'+$break+'" av'),('sxe -c "'+$break+'" 0xc0000374'),('sxe -c "'+$break+'" 0xc0000409'),('sxe -c "'+$break+'" 0xc000001d'),'.echo NATIVE_PREVIEW_ARMED','g')|Set-Content -LiteralPath $commands -Encoding ascii
 $start.FileName='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe'
 foreach($arg in @('-G','-sins','-y',(Join-Path $project '.tools'),'-logo',$debugLog,'-cf',$commands,$engine)+$nativeArgs){$start.ArgumentList.Add($arg)}
}else{$start.FileName=$engine;foreach($arg in $nativeArgs){$start.ArgumentList.Add($arg)}}
$process=[Diagnostics.Process]::Start($start);$process.WaitForExit();$nativeExit=$process.ExitCode
if($CaptureCrash){$log=Get-Content -LiteralPath $debugLog -Raw;if($log-notmatch'(?m)^NATIVE_PREVIEW_ARMED\r?$'-or$log-match'(?m)^NATIVE_PREVIEW_EXCEPTION\r?$'){$nativeExit=1}}
if($Report){
 $errors=@();$unchanged=$true
 foreach($name in $sources.Keys){if((Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$sources[$name]){$unchanged=$false}}
 if(-not$unchanged){$errors+='Source changed during preview'}
 if(-not(Test-Path -LiteralPath $Report)){$errors+='Native preview report missing'}else{$result=Get-Content -LiteralPath $Report -Raw|ConvertFrom-Json;if(-not$result.success-or$result.worker_tasks_remaining-ne0){$errors+='Preview load or retirement failed'}}
 $engineLog=[IO.Path]::ChangeExtension($Report,'.engine.log')
 if(-not(Test-Path -LiteralPath $engineLog)){$errors+='Engine log missing'}elseif((Get-Content -LiteralPath $engineLog -Raw)-match'(?im)^(?:SCRIPT ERROR|ERROR):|ObjectDB instances leaked|resources still in use'){$errors+='Engine or lifetime error'}
 if($nativeExit){$errors+='Process or debugger failure'}
 @{passed=($errors.Count-eq0);failures=@($errors);sourceUnchanged=$unchanged;sourceSha256=$sources;nativeExecutableSha256=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant();nativeArguments=$nativeArgs;debuggerArmed=[bool]$CaptureCrash;nativeException=([bool]$CaptureCrash-and$log-match'(?m)^NATIVE_PREVIEW_EXCEPTION\r?$');cleanBenchmark=$false;scope='Native model entry; no JS/network; static functional check only'}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath ([IO.Path]::ChangeExtension($Report,'.verification.json')) -Encoding utf8
 if($errors.Count){$nativeExit=1}
}
exit $nativeExit
