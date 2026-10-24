param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='weather-surface-stress-v1',[switch]$Debugger,[switch]$VerifyTrap)
$ErrorActionPreference='Stop'
if($VerifyTrap-and-not$Debugger){throw 'Exception-capture self-test requires the owned debugger mode'}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$workspace=Split-Path $project -Parent
$output=Join-Path $project ('reports/'+$Run+'.json')
$control=Join-Path $project ('reports/'+$Run+'.launcher.json')
foreach($file in @($output,$control)){if(Test-Path -LiteralPath $file){throw 'Native stress output exists'}}
. (Join-Path $PSScriptRoot 'local-test-guard.ps1')
Assert-NativeLocalTestAvailable $project
$engine=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
$sources=@('systems/particle_surface.gd','tests/particle_surface_stress.gd')
$sourceHashes=@{}
foreach($name in $sources){$sourceHashes[$name]=(Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()}
$engineSha=(Get-FileHash -LiteralPath $engine -Algorithm SHA256).Hash.ToLowerInvariant()
$engineLog=Join-Path $project ('reports/'+$Run+'.engine.log')
$nativeArguments=@('--path',$project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--script','res://tests/particle_surface_stress.gd','--verbose','--log-file',$engineLog,'--',('--report='+$output))
if($VerifyTrap){$nativeArguments+='--verify-exception-capture'}
$start=[Diagnostics.ProcessStartInfo]::new()
$debuggerLog=Join-Path $project ('reports/'+$Run+'.cdb.log')
if($Debugger){
 $cdbExecutable='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe'
 if(-not(Test-Path -LiteralPath $cdbExecutable)){throw 'Installed debugger is unavailable'}
 $commands=Join-Path $project ('reports/'+$Run+'.cdb.txt')
 $break='.echo OWNED_SURFACE_STRESS_EXCEPTION;.exr -1;.ecxr;kv;~* k;q'
 @('.echo OWNED_SURFACE_STRESS_START',('sxe -c "'+$break+'" av'),('sxe -c "'+$break+'" 0xc0000374'),('sxe -c "'+$break+'" 0xc0000409'),('sxe -c "'+$break+'" 0xc000001d'),'.echo OWNED_SURFACE_STRESS_ARMED','g') | Set-Content -LiteralPath $commands -Encoding ascii
 $start.FileName=$cdbExecutable
 foreach($arg in @('-G','-sins','-y',(Join-Path $project '.tools'),'-logo',$debuggerLog,'-cf',$commands,$engine)+$nativeArguments){$start.ArgumentList.Add($arg)}
}else{$start.FileName=$engine;foreach($arg in $nativeArguments){$start.ArgumentList.Add($arg)}}
$start.WorkingDirectory=$workspace;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
$process=[Diagnostics.Process]::new();$process.StartInfo=$start
if(-not$process.Start()){throw 'Native stress launch failed'}
$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();$clock=[Diagnostics.Stopwatch]::StartNew();$forced=$false
while(-not$process.WaitForExit(1000)){
 if($clock.Elapsed.TotalSeconds-gt90){$forced=$true;$process.Kill($true);$process.WaitForExit();break}
}
$stdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $project ('reports/'+$Run+'.stdout.log')) -Encoding utf8
$errors=$stderr.GetAwaiter().GetResult();$errors | Set-Content -LiteralPath (Join-Path $project ('reports/'+$Run+'.stderr.log')) -Encoding utf8
$result=$null;if(Test-Path -LiteralPath $output){$result=Get-Content -LiteralPath $output -Raw | ConvertFrom-Json}
$debugText=if($Debugger-and(Test-Path -LiteralPath $debuggerLog)){Get-Content -LiteralPath $debuggerLog -Raw}else{''}
$debugException=$debugText-match'(?m)^OWNED_SURFACE_STRESS_EXCEPTION\r?$'
$debugArmed=$debugText-match'(?m)^OWNED_SURFACE_STRESS_START\r?$'-and$debugText-match'(?m)^OWNED_SURFACE_STRESS_ARMED\r?$'
$unchanged=$true;foreach($name in $sources){if((Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$sourceHashes[$name]){$unchanged=$false}}
$workloadPassed=-not$forced-and-not$debugException-and(-not$Debugger-or$debugArmed)-and$process.ExitCode-eq0-and$result.passed-and$result.cycles.Count-eq12-and$result.allocations-eq2304-and$result.materialsCreated-eq288-and$result.materialSurvivors-eq0-and$result.surfacesRetired-eq288-and$result.survivors-eq0-and$unchanged-and$errors-notmatch'SCRIPT ERROR|(?:^|\n)ERROR:|ObjectDB instances.*leaked|RIDs?.*leaked'
$passed=if($VerifyTrap){$debugArmed-and$debugException-and-not$forced-and-not$workloadPassed-and$unchanged}else{$workloadPassed}
$row=@{passed=$passed;purpose=$(if($VerifyTrap){'expected exception capture only'}else{'allocation stress'});workloadPassed=$workloadPassed;exitCode=$process.ExitCode;forced=$forced;debugger=[bool]$Debugger;debuggerArmed=$debugArmed;debuggerException=$debugException;engineSha256=$engineSha;sourceSha256=$sourceHashes;allocations=$result.allocations;materialsCreated=$result.materialsCreated;materialSurvivors=$result.materialSurvivors;surfacesRetired=$result.surfacesRetired;survivors=$result.survivors;sourceUnchanged=$unchanged;scope='Owned native fixture only; expected exception self-test cannot qualify as completed rendering workload; no game-server connection or original binary instrumentation'}
$row | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $control -Encoding utf8
Write-Output ($row | ConvertTo-Json -Depth 5 -Compress)
if(-not$passed){throw 'Native surface stress did not complete cleanly'}
