param(
 [ValidatePattern('^[a-z0-9-]+$')][string]$Run='nui-draw-fill-v2',
 [ValidateSet('nui_draw_fill_test.gd','nui_ui_test.gd')][string]$Script='nui_draw_fill_test.gd',
 [ValidatePattern('^[a-z0-9-]+\.json$')][string]$Fixture='nui-draw-fill-fixture-v2.json'
)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'local-test-guard.ps1'); Assert-NativeLocalTestAvailable $project
$reportPath=Join-Path $project ('reports/'+$Run+'.json')
$commandPath=Join-Path $project ('reports/'+$Run+'.cdb.txt')
$debugLog=Join-Path $project ('reports/'+$Run+'.cdb.log')
$engineLog=Join-Path $project ('reports/'+$Run+'.engine.log')
foreach($file in @($reportPath,$commandPath,$debugLog,$engineLog)){if(Test-Path -LiteralPath $file){throw 'Regression output already exists'}}
$sourceNames=@('systems/nui_canvas.gd','tools/nui-service.mjs','tools/nui-draw-values.mjs',('tests/'+$Script),('reports/'+$Fixture))
$hashes=@{};foreach($name in $sourceNames){$hashes[$name]=(Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()}
$exceptionCommands='.echo OWNED_NUI_EXCEPTION;.exr -1;.ecxr;kv;~* k;q'
@('.echo OWNED_NUI_START',('sxe -c "'+$exceptionCommands+'" av'),('sxe -c "'+$exceptionCommands+'" 0xc0000374'),('sxe -c "'+$exceptionCommands+'" 0xc0000409'),('sxe -c "'+$exceptionCommands+'" 0xc000001d'),'.echo OWNED_NUI_ARMED','g') | Set-Content -LiteralPath $commandPath -Encoding ascii
$debugStart=[Diagnostics.ProcessStartInfo]::new()
$debugStart.FileName='C:/Program Files (x86)/Windows Kits/10/Debuggers/x64/cdb.exe'
$debugStart.WorkingDirectory=Split-Path $project -Parent
$debugStart.UseShellExecute=$false; $debugStart.CreateNoWindow=$true
$debugStart.RedirectStandardOutput=$true; $debugStart.RedirectStandardError=$true
foreach($arg in @('-G','-sins','-y',(Join-Path $project '.tools'),'-logo',$debugLog,'-cf',$commandPath,(Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'),'--path',$project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--verbose','--log-file',$engineLog,'--script',('res://tests/'+$Script),'--',('--fixture='+(Join-Path $project ('reports/'+$Fixture))),('--report='+$reportPath))){$debugStart.ArgumentList.Add($arg)}
$debugProcess=[Diagnostics.Process]::Start($debugStart)
$debugOut=$debugProcess.StandardOutput.ReadToEndAsync(); $debugErr=$debugProcess.StandardError.ReadToEndAsync()
if(-not $debugProcess.WaitForExit(45000)){throw ('Debugger test still running PID '+$debugProcess.Id+'; preserved for inspection')}
($debugOut.GetAwaiter().GetResult()+$debugErr.GetAwaiter().GetResult()) | Set-Content -LiteralPath (Join-Path $project ('reports/'+$Run+'.stdout.log'))
$debugText=Get-Content -LiteralPath $debugLog -Raw; $engineText=Get-Content -LiteralPath $engineLog -Raw
$drawResult=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
$unchanged=$true;foreach($name in $sourceNames){if((Get-FileHash -LiteralPath (Join-Path $project $name) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$hashes[$name]){$unchanged=$false}}
$armed=$debugText -match '(?m)^OWNED_NUI_ARMED\r?$'; $exception=$debugText -match '(?m)^OWNED_NUI_EXCEPTION\r?$'
$scriptErrors=$engineText -match 'SCRIPT ERROR|Parse Error|ObjectDB instances leaked|resources still in use'
$result=@{passed=($drawResult.passed-and$armed-and-not$exception-and-not$scriptErrors-and$debugProcess.ExitCode-eq0-and$unchanged);checks=$drawResult.checks;failures=$drawResult.failures;debuggerExit=$debugProcess.ExitCode;debuggerArmed=$armed;nativeException=$exception;scriptOrLifetimeErrors=$scriptErrors;sourceUnchanged=$unchanged;sourceSha256=$hashes}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $project ('reports/'+$Run+'.debugger.json'))
$result | Select-Object passed,checks,failures,debuggerExit,debuggerArmed,nativeException,scriptOrLifetimeErrors,sourceUnchanged | ConvertTo-Json -Depth 3
if(-not$result.passed){exit 1}
