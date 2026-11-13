param([string]$Godot='',[switch]$HttpOnly,[switch]$TransportFailureProbe)
$ErrorActionPreference='Stop'
if($TransportFailureProbe-and-not$HttpOnly){throw 'The intentional transport-failure probe requires -HttpOnly'}
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if(-not$Godot){$Godot=Join-Path $projectRoot '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not(Test-Path -LiteralPath $Godot)){throw 'Existing Godot runtime is unavailable; this test runner never builds or downloads one'}
$runRoot=Join-Path $projectRoot ('.cache/entity-api-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
[IO.Directory]::CreateDirectory($runRoot)|Out-Null
$inputs=@('systems/client_api/client_api.gd','systems/client_api/access.gd','systems/client_api/entities.gd','systems/client_api/detached.gd','systems/client_api/native_binding.gd','systems/client_api/rest_server.gd','systems/client_api/rest_options.gd','systems/client_api/rest_routes.gd','systems/client_api/rest_json.gd','systems/client_api/explorer_assets.gd','systems/network_motion.gd','tests/native_entity_api_test.gd','tests/native_entity_api_binding_test.gd','tests/native_entity_api_rest_test.gd')
$hashes=@()
foreach($relative in $inputs){
 $original=Join-Path $projectRoot $relative
 $destination=Join-Path $runRoot $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
 Copy-Item -LiteralPath $original -Destination $destination
 $before=(Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash.ToLowerInvariant()
 $after=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
 if($before-ne$after){throw ('API test input changed while copying: '+$relative)}
 $hashes+=@{path=$relative;sha256=$before}
}
$hookInputs=if($HttpOnly){@('tests/run-native-entity-api-tests.ps1')}else{@('project.godot','native_session_world.gd','native_live_world.gd','tests/native_entity_api_session_test.gd','tests/run-native-entity-api-tests.ps1')}
foreach($relative in $hookInputs){$hashes+=@{path=$relative;sha256=(Get-FileHash -LiteralPath (Join-Path $projectRoot $relative) -Algorithm SHA256).Hash.ToLowerInvariant()}}
$configuration=@'
config_version=5
[application]
config/name="Isolated Native Entity API"
run/main_scene="res://api-binding-test.tscn"
[autoload]
ClientAPI="*res://systems/client_api/client_api.gd"
[rendering]
renderer/rendering_method="gl_compatibility"
'@
[IO.File]::WriteAllText((Join-Path $runRoot 'project.godot'),$configuration)
$bindingScene=@'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://tests/native_entity_api_binding_test.gd" id="1"]
[node name="EntityApiBindingTest" type="Node"]
script = ExtResource("1")
'@
[IO.File]::WriteAllText((Join-Path $runRoot 'api-binding-test.tscn'),$bindingScene)
$results=@()
$suites=if($HttpOnly){@('native_entity_api_rest_test')}else{@('native_entity_api_test','native_entity_api_binding_test','native_entity_api_session_test','native_entity_api_rest_test')}
foreach($name in $suites){
 $report=Join-Path $runRoot ($name+'.json')
 $log=Join-Path $runRoot ($name+'.engine.log')
 $engineProject=if($name-eq'native_entity_api_session_test'){$projectRoot}else{$runRoot}
 $engineArguments=@('--headless','--path',('"'+$engineProject+'"'),'--log-file',('"'+$log+'"'))
 if($name-eq'native_entity_api_rest_test'){$engineArguments+=@('--max-fps','60')}
 if($name-ne'native_entity_api_binding_test'){$engineArguments+=@('--script',('res://tests/'+$name+'.gd'))}
 $engineArguments+=@('--',('"--report='+$report+'"'))
 if($TransportFailureProbe){$engineArguments+='--test-fail-transport=true'}
 if($name-eq'native_entity_api_rest_test'){
  $discovery=Join-Path $runRoot 'http-discovery.json'
  $engineArguments+=@('--entity-api-rest=true','--entity-api-rest-port=0',('"--entity-api-rest-discovery='+$discovery+'"'))
 }else{$engineArguments+='--entity-api-rest=false'}
 $stdout=Join-Path $runRoot ($name+'.stdout.log')
 $stderr=Join-Path $runRoot ($name+'.stderr.log')
 $ownedProcess=$null
 try{
  $ownedProcess=Start-Process -FilePath $Godot -ArgumentList $engineArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  if(-not$ownedProcess.WaitForExit(45000)){
   $ownedProcess.Kill(); $ownedProcess.WaitForExit()
   throw ('Timed out; stopped only this runner-owned headless API test: '+$name)
  }
 }finally{
  # This unique test path cannot predate the runner. Never remove a file that
  # another owner replaced, even when the owned child hit a script error.
  if($name-eq'native_entity_api_rest_test'-and$null-ne$ownedProcess-and$ownedProcess.HasExited-and(Test-Path -LiteralPath $discovery)){
   $privateDiscovery=Get-Content -LiteralPath $discovery -Raw|ConvertFrom-Json
   if($privateDiscovery.kind-eq'nwn-client-entity-api-rest'-and$privateDiscovery.pid-eq$ownedProcess.Id){Remove-Item -LiteralPath $discovery}
   $privateDiscovery=$null
  }
 }
 $ownedProcess.Refresh(); $code=$ownedProcess.ExitCode
 Get-Content -LiteralPath $stdout|Out-Host
 Get-Content -LiteralPath $stderr|Out-Host
 if(-not(Test-Path -LiteralPath $report)){throw ('API test did not produce its receipt: '+$name)}
 $result=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
 if($TransportFailureProbe){
  $classified=$false
  if($result.transport_failures.Count-eq2){
   $connectionFailure=$result.transport_failures[0]
   $classified=switch($connectionFailure.reason){
    'ERROR' {$connectionFailure.status_after_poll-eq3}
    'NONE' {$connectionFailure.status_after_poll-eq0}
    'connect_error' {$connectionFailure.connect_result-ne0}
    'TIMEOUT' {$connectionFailure.status_after_poll-eq1-and$connectionFailure.elapsed_ms-ge1500}
    default {$false}
   }
  }
  if($code-ne1-or$result.success-or-not$result.transportFailureProbe-or$result.failures.Count-ne1-or-not$classified-or$result.transport_failures[0].listener-or$result.transport_failures[1].stage-ne'connect'-or(Test-Path -LiteralPath $discovery)){throw 'Intentional transport failure did not produce its classified fail-fast receipt and cleanup'}
 }elseif($code-ne0-or-not$result.success){throw ('API test failed: '+$name)}
 $engineText=[IO.File]::ReadAllText($log)
 if($engineText-match 'SCRIPT ERROR|Parse Error|Leaked instance|ObjectDB instances leaked|still in use at exit'){throw ('API test engine error/leak: '+$name)}
 $results+=@{test=$name;checks=$result.checks;report=$report;engineLog=$log;exitCode=$code}
}
foreach($input in $hashes){
 if((Get-FileHash -LiteralPath (Join-Path $projectRoot $input.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$input.sha256){throw ('API source changed during the isolated test window: '+$input.path)}
}
$receipt=[ordered]@{success=$true;testedAtUtc=[DateTime]::UtcNow.ToString('o');engine=$Godot;engineSha256=(Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash.ToLowerInvariant();isolatedProject=$runRoot;sessionTestProject=$projectRoot;headless=$true;gameServerConnections=0;publicConnections=0;loopbackHttpTested=$true;nativeBuilds=0;sharedSessionHooksIntegrated=$true;inputs=$hashes;results=$results;scope='Isolated provider/autoload, actual native motion/session hooks and actual IPv4-loopback HTTP; canonical game owners are authored fixtures, no live client or game-server acceptance'}
if($HttpOnly){
 $receipt.sessionTestProject=$null;$receipt.sharedSessionHooksIntegrated=$false
 $receipt.scope='Copied/pinned API-only real IPv4-loopback HTTP fixture; no shared session preload, running client, game-server connection or native build'
 $httpReceipt=if($TransportFailureProbe){$receipt.expectedFailureVerified=$true;'reports/native-entity-api-transport-failure-receipt.json'}else{'reports/native-entity-api-http-diagnostic-receipt.json'}
 [IO.File]::WriteAllText((Join-Path $projectRoot $httpReceipt),($receipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
}else{
 [IO.File]::WriteAllText((Join-Path $projectRoot 'reports/native-entity-api-v1-receipt.json'),($receipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
 [IO.File]::WriteAllText((Join-Path $projectRoot 'reports/native-entity-api-rest-v1-receipt.json'),($receipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
}
$receipt|ConvertTo-Json -Depth 8
