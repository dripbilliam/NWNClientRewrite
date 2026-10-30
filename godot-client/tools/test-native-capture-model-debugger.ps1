param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='native-capture-model-render-v1',[int]$PreserveOriginalPid=0,[switch]$CreatureParts,[switch]$Actor,[switch]$Rigs,[switch]$NormalHeap,[switch]$Skeletal)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'local-test-guard.ps1'); Assert-NativeLocalTestAvailable $project -PreserveOriginalPid $PreserveOriginalPid
$reportPath=Join-Path $project ('reports/'+$Run+'.json'); $commandPath=Join-Path $project ('reports/'+$Run+'.cdb.txt')
$debugLog=Join-Path $project ('reports/'+$Run+'.cdb.log'); $engineLog=Join-Path $project ('reports/'+$Run+'.engine.log')
foreach($file in @($reportPath,$commandPath,$debugLog,$engineLog)){if(Test-Path -LiteralPath $file){throw 'Native rendering output already exists'}}
if((@($CreatureParts,$Actor,$Rigs)|Where-Object{$_}).Count-gt1){throw 'Choose one native model check'}
$testScript=if($Rigs){'tests/model_rigs_test.gd'}elseif($Actor){'tests/native_actor_render_test.gd'}elseif($CreatureParts){'tests/native_creature_parts_render_test.gd'}else{'tests/native_capture_model_render_test.gd'}
$fixtureName=if($Rigs){'reports/authored-rig-oracle-v4.json'}elseif($Actor){'reports/native-actor-oracle-v2.json'}elseif($CreatureParts){'reports/native-creature-oracle-v1.json'}else{'reports/native-ascii-oracle-v1.json'}
$fixtureArgument=if($Rigs){'--oracle='}else{'--fixture='}
$sourceNames=@($testScript,$fixtureName,'tools/test-native-capture-model-debugger.ps1')
if($Actor-or$Rigs){$sourceNames+=@('systems/model_rigs.gd','systems/model_native_animation.gd','systems/model_native_pose.gd','systems/model_runs.gd','systems/model_controllers.gd')}
if($Rigs){$sourceNames+=@('systems/entity_registry.gd','systems/local_connection.gd')}
foreach($folder in @('native_data','native_render')){foreach($file in Get-ChildItem -LiteralPath (Join-Path $project ('systems/'+$folder)) -Filter '*.gd'){$sourceNames+=('systems/'+$folder+'/'+$file.Name)}}
$hashes=@{};foreach($name in $sourceNames){$hashes[$name]=(Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()}
$exceptionCommands='.echo OWNED_CAPTURE_MODEL_EXCEPTION;.exr -1;.ecxr;kv;~* k;q'
@('.echo OWNED_CAPTURE_MODEL_START',('sxe -c "'+$exceptionCommands+'" av'),('sxe -c "'+$exceptionCommands+'" 0xc0000374'),('sxe -c "'+$exceptionCommands+'" 0xc0000409'),('sxe -c "'+$exceptionCommands+'" 0xc000001d'),'.echo OWNED_CAPTURE_MODEL_ARMED','g') | Set-Content -LiteralPath $commandPath -Encoding ascii
$start=[Diagnostics.ProcessStartInfo]::new(); $start.FileName='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe'
$start.WorkingDirectory=Split-Path $project -Parent; $start.UseShellExecute=$false; $start.CreateNoWindow=$true; $start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
if($NormalHeap){$start.ArgumentList.Add('-hd')}
foreach($arg in @('-G','-sins','-y',(Join-Path $project '.tools'),'-logo',$debugLog,'-cf',$commandPath,(Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'),'--path',$project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--verbose','--log-file',$engineLog,'--script',('res://'+$testScript),'--',($fixtureArgument+(Join-Path $project $fixtureName)),('--report='+$reportPath))){$start.ArgumentList.Add($arg)}
if($Skeletal){if(-not$Actor){throw 'Skeletal comparison requires the original actor check'};$start.ArgumentList.Add('--compare-skeleton=true')}
$debugProcess=[Diagnostics.Process]::Start($start); $stdout=$debugProcess.StandardOutput.ReadToEndAsync(); $stderr=$debugProcess.StandardError.ReadToEndAsync()
if(-not $debugProcess.WaitForExit($(if($Actor){240000}else{90000}))){
 @{passed=$false;timedOut=$true;debuggerPid=$debugProcess.Id;debugHeapDisabled=[bool]$NormalHeap;sourceSha256=$hashes;failure='Native model check exceeded its deadline; process preserved for inspection'}|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $project ('reports/'+$Run+'.debugger.json')) -Encoding utf8
 throw ('Native rendering test still running PID '+$debugProcess.Id+'; preserved for inspection')
}
($stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()) | Set-Content -LiteralPath (Join-Path $project ('reports/'+$Run+'.stdout.log'))
$debugText=Get-Content -LiteralPath $debugLog -Raw; $engineText=Get-Content -LiteralPath $engineLog -Raw
$report=if(Test-Path -LiteralPath $reportPath){Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json}else{$null}
$unchanged=$true;foreach($name in $sourceNames){if((Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hashes[$name]){$unchanged=$false}}
$armed=$debugText -match '(?m)^OWNED_CAPTURE_MODEL_ARMED\r?$'; $exception=$debugText -match '(?m)^OWNED_CAPTURE_MODEL_EXCEPTION\r?$'
$errors=$engineText -match '(?m)^ERROR:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|resources still in use'
$preservedOriginalAlive=$PreserveOriginalPid-eq0-or$null-ne(Get-Process -Id $PreserveOriginalPid -ErrorAction SilentlyContinue)
$result=@{passed=($null-ne$report-and$report.passed-and$armed-and-not$exception-and-not$errors-and$debugProcess.ExitCode-eq0-and$unchanged-and$preservedOriginalAlive);checks=$report.checks;failures=$report.failures;debuggerExit=$debugProcess.ExitCode;debuggerArmed=$armed;nativeException=$exception;scriptEngineOrLifetimeErrors=$errors;sourceUnchanged=$unchanged;sourceSha256=$hashes;debugHeapDisabled=[bool]$NormalHeap;preservedOriginalPid=$PreserveOriginalPid;preservedOriginalAlive=$preservedOriginalAlive;cleanBenchmark=$false;nativeExecutableSha256=(Get-FileHash -LiteralPath (Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe') -Algorithm SHA256).Hash.ToLowerInvariant();scope='Functional original native model/texture/animation drawing; no JS/network or performance acceptance'}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $project ('reports/'+$Run+'.debugger.json'))
$result | Select-Object passed,checks,failures,debuggerExit,debuggerArmed,nativeException,scriptEngineOrLifetimeErrors,sourceUnchanged | ConvertTo-Json -Depth 3
if(-not$result.passed){exit 1}
