param([ValidatePattern('^[a-z0-9-]+$')][string]$Run='native-light-motion-v1')
$ErrorActionPreference='Stop'
$nativeProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$nativeOutput=Join-Path $nativeProject ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $nativeOutput){throw 'Headless proof output exists'}
$nativeSources=@{}
foreach($nativeFolder in @('systems','tests')){
 foreach($nativeFile in Get-ChildItem -LiteralPath (Join-Path $nativeProject $nativeFolder) -Filter '*.gd' -Recurse){
  $nativeSources[$nativeFile.FullName.Substring($nativeProject.Length+1).Replace('\','/')]=(Get-FileHash -LiteralPath $nativeFile.FullName).Hash.ToLowerInvariant()
 }
}
foreach($nativeName in @('native_live_world.gd','project.godot','tools/test-native-light-motion.ps1','tools/native-local-world-host.mjs')){$nativeSources[$nativeName]=(Get-FileHash -LiteralPath (Join-Path $nativeProject $nativeName)).Hash.ToLowerInvariant()}
$nativeChecks=@(
 @{name='integration';script='tests/native_live_motion_test.gd'},
 @{name='play-input';script='tests/native_play_input_test.gd'},
 @{name='binary-motion';script='tests/network_motion_test.gd'},
 @{name='binary-tile-lights';script='tests/native_tile_lights_test.gd';fixture=(Join-Path $nativeProject '../backups/animations/native-tile-light-observations.json')},
 @{name='original-surfaces';script='tests/native_surface_test.gd';fixture=(Join-Path $nativeProject 'reports/native-surface-oracle-v1.json')},
 @{name='native-ui-text';script='tests/native_ui_text_test.gd';fixture=(Join-Path $nativeProject 'reports/native-ui-text-oracle-v1.json')},
 @{name='native-ui-skin';script='tests/native_ui_skin_test.gd';fixture=(Join-Path $nativeProject 'reports/native-ui-skin-oracle-v1.json')},
 @{name='native-inventory';script='tests/native_inventory_test.gd';fixture=(Join-Path $nativeProject 'reports/native-item-icon-oracle-v1.json')},
 @{name='native-streaming';script='tests/native_streaming_test.gd';fixture=(Join-Path $nativeProject 'reports/native-item-icon-oracle-v1.json')},
 @{name='native-animation-work';script='tests/native_animation_work_test.gd'},
 @{name='entry-parse';script='native_live_world.gd';parse=$true}
)
$nativeFailures=@();$nativeResults=@()
foreach($nativeCheck in $nativeChecks){
 $nativePrefix=Join-Path $nativeProject ('reports/'+$Run+'-'+$nativeCheck.name)
 $nativeLog=$nativePrefix+'.engine.log';$nativeReport=$nativePrefix+'.json'
 if((Test-Path -LiteralPath $nativeLog)-or(Test-Path -LiteralPath $nativeReport)){throw 'Headless child output exists'}
 $nativeArguments=@('--headless','--path',$nativeProject,'--log-file',$nativeLog,'--script',('res://'+$nativeCheck.script))
 if($nativeCheck.parse){$nativeArguments+='--check-only'}else{$nativeArguments+=@('--',('--report='+$nativeReport));if($nativeCheck.fixture){$nativeArguments+=('--fixture='+$nativeCheck.fixture)}}
 & (Join-Path $nativeProject '.tools/Godot_v4.7.2-stable_win64_console.exe') @nativeArguments
 $nativeExit=$LASTEXITCODE
 $nativeEngine=[IO.File]::ReadAllText($nativeLog)
 $nativeErrors=$nativeEngine-match'(?im)^(?:SCRIPT ERROR|ERROR):|ObjectDB instances leaked|resources still in use|Unicode parsing error'
 $nativeChild=$null
 if(-not$nativeCheck.parse){$nativeChild=Get-Content -LiteralPath $nativeReport -Raw|ConvertFrom-Json;if($nativeChild.failures.Count-or$nativeChild.passed-eq$false){$nativeFailures+=($nativeCheck.name+' assertions failed')}}
 if($nativeExit-or$nativeErrors){$nativeFailures+=($nativeCheck.name+' process/engine failure')}
 $nativeResults+=@{name=$nativeCheck.name;exit=$nativeExit;engineErrors=$nativeErrors;checks=$nativeChild.checks;report=if($nativeCheck.parse){$null}else{$nativeReport};log=$nativeLog}
}
$nativeUnchanged=$true
foreach($nativeName in $nativeSources.Keys){if((Get-FileHash -LiteralPath (Join-Path $nativeProject $nativeName)).Hash.ToLowerInvariant()-ne$nativeSources[$nativeName]){$nativeUnchanged=$false}}
if(-not$nativeUnchanged){$nativeFailures+='Source changed during headless proof'}
@{passed=($nativeFailures.Count-eq0);failures=$nativeFailures;sourceUnchanged=$nativeUnchanged;sourceSha256=$nativeSources;results=$nativeResults;gpuTested=$false;liveServerTested=$false;scope='Headless native raw movement integration, retained original-binary movement/tile-light observations and live-entry compilation. Does not accept graphics, playability or frame pacing.'}|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $nativeOutput -Encoding utf8
if($nativeFailures.Count){throw ($nativeFailures-join', ')}
Write-Output ('Headless proof passed: '+$nativeOutput)
