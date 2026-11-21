# Launcher option resolution and runtime verification only. These functions never stage or run an engine.
$nativeRuntimeCoreExe='.tools/native-core/Godot_native_core_e_win64.exe'
$nativeRuntimeCoreSha256='753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b'
$nativeRuntimeCoreBytes=90976256
$nativeRuntimeProofFile='.tools/native-core/accepted-core-e.json'
$nativeRuntimeProofSha256='29b1c6adcdecb11eebc859730c770e879a108279dfaaf60792e4c11c00add78a'
$nativeRuntimeKernelFile='.cache/native-kernel/nwn-particle-kernel.dll'
$nativeRuntimeKernelSha256='485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d'

function Get-NativeRuntimeSha256([string]$Path){
 (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Select-NativeEngineRuntime([string]$Project,[string]$Kind='editor',[string]$Selection=''){
 if($Kind -cnotin @('editor','release')){throw 'Invalid native engine runtime'}
 $projectPath=[IO.Path]::GetFullPath($Project)
 if($Kind -eq 'editor'){
  if($Selection){throw 'Editor runtime does not take a release package'}
  $executable=Join-Path $projectPath '.tools/Godot_v4.7.2-stable_win64.exe'
  return @{kind=$Kind;executable=$executable;directory=[IO.Path]::GetDirectoryName($projectPath);executableSha256=Get-NativeRuntimeSha256 $executable}
 }
 if(-not $Selection){throw 'Release runtime requires a prepared package'}
 $releaseRoot=Join-Path $projectPath '.cache/release-tests'
 $selectionPath=[IO.Path]::GetFullPath($Selection)
 $stageReceipt=[IO.Path]::GetRelativePath($releaseRoot,$selectionPath).Replace('\','/')
 if($stageReceipt -notmatch '^[a-f0-9]{16}/project/runtime\.json$'){throw 'Release package escaped its authored cache stage'}
 $info=Get-Content -LiteralPath $selectionPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable
 if($info -isnot [System.Collections.IDictionary] -or $info.kind -cne 'native-release-package' -or $info.sourceSignature -isnot [string] -or $info.sourceSignature -cnotmatch '^[a-f0-9]{64}$' -or $info.packSha256 -isnot [string] -or $info.packSha256 -cnotmatch '^[a-f0-9]{64}$' -or $info.originalGameAssetsPacked -isnot [bool] -or $info.originalGameAssetsPacked){throw 'Invalid prepared release runtime receipt'}
 $directory=Join-Path $releaseRoot ($info.sourceSignature.Substring(0,16)+'/project')
 $executable=Join-Path $directory 'NwnReleaseTest.exe'
 $pack=Join-Path $directory 'NwnReleaseTest.pck'
 $expected=@{directory=$directory;executable=$executable;pack=$pack}
 foreach($key in $expected.Keys){
  if($info[$key] -isnot [string] -or -not $info[$key] -or -not [string]::Equals([IO.Path]::GetFullPath($info[$key]),[IO.Path]::GetFullPath($expected[$key]),[StringComparison]::OrdinalIgnoreCase)){throw 'Release package escaped its authored cache stage'}
 }
 if(-not [string]::Equals($selectionPath,[IO.Path]::GetFullPath((Join-Path $directory 'runtime.json')),[StringComparison]::OrdinalIgnoreCase)){throw 'Release package escaped its authored cache stage'}
 $executableSha256=Get-NativeRuntimeSha256 $executable
 if($executableSha256 -cne 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562' -or (Get-NativeRuntimeSha256 $pack) -cne $info.packSha256){throw 'Prepared release executable or pack changed'}
 return @{kind=$Kind;executable=$executable;directory=$directory;executableSha256=$executableSha256;pack=$pack;packSha256=$info.packSha256;sourceSignature=$info.sourceSignature;receipt=$info.receipt}
}

function Resolve-NativeRenderThread([string]$Requested='default'){
 if($Requested -cnotin @('default','safe','separate')){throw 'Invalid native render thread selection'}
 $engineArguments=@()
 if($Requested -ne 'default'){$engineArguments=@('--render-thread',$Requested)}
 return @{requested=$Requested;arguments=$engineArguments;scope='Engine argument only; actual rendering thread IDs are verified separately.'}
}

function Resolve-NativeClientPerformance([string]$Project,[hashtable]$Options,[bool]$Isolated,[bool]$RuntimeExplicit,[bool]$ProfileSession){
 $registryPath=Join-Path $Project 'systems/native_data/client_feature_registry.json'
 $registry=Get-Content -LiteralPath $registryPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable
 if($registry.version -ne 1){throw 'Unsupported native feature registry'}
 $nativeSelectors=@('drive-collision','drive-height-plan','drive-preview-height-index','light-input-registry','binary-clips','particle-animation-snapshot')
 $managedNames=@('performance-runtime','render-thread','detailed-profiling','native-overhead-clocks')+$nativeSelectors
 $definitions=@{}
 $values=@{}
 foreach($feature in $registry.features){
  if($feature.name -cnotin $managedNames -and $feature.name -cne 'world-snapshot-preparation'){continue}
  $definitions[$feature.name]=$feature
  $values[$feature.name]=$feature.default
 }
 foreach($name in $managedNames){
  if(-not $definitions.ContainsKey($name)){throw ('Missing native feature definition: '+$name)}
  if(-not $Options.ContainsKey($name)){continue}
  $definition=$definitions[$name]
  $value=$Options[$name]
  if($value -cnotin $definition.choices){throw ('Invalid --'+$name+'; expected '+($definition.choices -join '|'))}
  $values[$name]=$value
 }
 foreach($name in $Options.Keys){
  if(-not $definitions.ContainsKey($name)){throw ('Unknown managed native option --'+$name)}
  if(-not $definitions[$name].requires){continue}
  foreach($dependency in $definitions[$name].requires.Keys){
   $required=$definitions[$name].requires[$dependency]
   if($values[$dependency] -cne $required){throw ('--'+$name+' requires --'+$dependency+'='+$required)}
  }
 }
 if($RuntimeExplicit -and $values['performance-runtime'] -ceq 'verified-native'){throw 'Explicit editor/release runtime conflicts with verified-native'}
 $explicitStandard=$Options.ContainsKey('performance-runtime') -and $values['performance-runtime'] -ceq 'standard'
 $normalGameplay=-not ($Isolated -or $RuntimeExplicit -or $explicitStandard)
 $verifiedCore=$normalGameplay -and $values['performance-runtime'] -ceq 'verified-native'
 if($normalGameplay){
  $preset=$registry.normalGameplayDefaults
  if($preset.version -ne 1){throw 'Normal gameplay performance policy is unavailable'}
  # The implicit Core E switch stays disabled until the active bundle matches.
  $presetNames=@('render-thread','detailed-profiling')
  if($verifiedCore){$presetNames+='light-input-registry'}
  foreach($name in $presetNames){
   if($Options.ContainsKey($name)){continue}
   $value=$preset.values[$name]
   if($value -cnotin $definitions[$name].choices){throw ('Invalid normal native preset value for --'+$name)}
   $values[$name]=$value
  }
 }
 $nativeArguments=@(foreach($name in $nativeSelectors){
  if($Options.ContainsKey($name) -or ($verifiedCore -and $name -eq 'light-input-registry')){'--'+$name+'='+$values[$name]}
 })
 if($ProfileSession){
  if($Options.ContainsKey('detailed-profiling') -and $values['detailed-profiling'] -cne 'saved'){throw 'Do not combine ProfileSession with an explicit detailed-profiling policy'}
  $values['detailed-profiling']='saved'
  $nativeArguments+='--profile=true'
 }elseif($values['detailed-profiling'] -cne 'saved'){
  $nativeArguments+=if($values['detailed-profiling'] -ceq 'on'){'--profile=true'}else{'--profile=false'}
 }
 if($values['native-overhead-clocks'] -ceq 'true'){$nativeArguments+='--native-overhead-clocks=true'}
 if(-not $definitions.ContainsKey('world-snapshot-preparation')){throw 'Missing native feature definition: world-snapshot-preparation'}
 $requested=@{}
 foreach($name in $values.Keys){$requested[$name]=@{value=$values[$name];explicit=$Options.ContainsKey($name)}}
 return @{
  runtime=$values['performance-runtime'];renderThread=$values['render-thread'];lightInput=$values['light-input-registry']
  verifiedCore=$verifiedCore;nativeArguments=$nativeArguments;requested=$requested
  registry=@{sha256=Get-NativeRuntimeSha256 $registryPath}
 }
}

function Get-AcceptedNativeRenderCore([string]$LightInput='builtin',[bool]$Enabled=$true){
 $typed=$Enabled -and $LightInput -ceq 'builtin'
 $flags=@()
 if($Enabled){
  $flags=@(
   '--particle-scene-boundary=native','--particle-scene-direct=pod','--particle-setup-boundary=bound',
   '--particle-hot-parameters=bound','--visibility-chain-cache=epochs','--light-input-read=typed',
   '--light-input-proof=segments','--light-pair-layer-repair=exact','--light-pair-filter=consumers',
   '--pair-record-reuse=exact','--rig-skin-publisher=native','--skeleton-force-pass=once',
   '--particle-resident-text=borrow','--particle-empty-clips=skip','--light-dictionary-read=single',
   '--light-input-lifetime=guarded'
  )
  if(-not $typed){
   $typedFlags=@('--light-input-read=typed','--light-input-proof=segments','--light-dictionary-read=single','--light-input-lifetime=guarded','--light-member-read=indices')
   $flags=@($flags | Where-Object {$_ -cnotin $typedFlags})
  }
 }
 $engineSha256=if($Enabled){$nativeRuntimeCoreSha256}else{$null}
 $policy=if($Enabled){'accepted-normal-combined-e'}else{'conservative-or-isolated'}
 return @{version=3;enabled=$Enabled;typed=$typed;flags=$flags;engineSha256=$engineSha256;nativeKernelSha256=$nativeRuntimeKernelSha256;policy=$policy;diagnosticTimers=$false;scope='Exact selected component bundle. Diagnostic timers off; conservative and script-light choices retain their branches.'}
}

function Select-NativePerformanceRuntime([string]$Project,[string]$Requested='standard'){
 if($Requested -cnotin @('standard','verified-native')){throw 'Invalid native performance runtime'}
 if($Requested -eq 'standard'){return $null}
 if([string]::IsNullOrWhiteSpace($Project)){throw 'Performance runtime requires a project path'}
 $projectPath=[IO.Path]::GetFullPath($Project)
 $executable=Join-Path $projectPath $nativeRuntimeCoreExe
 if(-not (Test-Path -LiteralPath $executable -PathType Leaf) -or (Get-Item -LiteralPath $executable -ErrorAction Stop).Length -ne $nativeRuntimeCoreBytes){throw 'Verified native executable size changed'}
 $executableSha256=Get-NativeRuntimeSha256 $executable
 if($executableSha256 -cne $nativeRuntimeCoreSha256){throw 'Verified native executable SHA256 changed'}
 $proofPath=Join-Path $projectPath $nativeRuntimeProofFile
 if((Get-NativeRuntimeSha256 $proofPath) -cne $nativeRuntimeProofSha256){throw 'Accepted native bundle proof changed'}
 $artifact=Get-Content -LiteralPath $proofPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable
 if($artifact.engineSha256 -cne $nativeRuntimeCoreSha256 -or $artifact.engineBytes -ne $nativeRuntimeCoreBytes -or $artifact.nativeKernelSha256 -cne $nativeRuntimeKernelSha256 -or $artifact.originalGameAssetsPacked -isnot [bool] -or $artifact.originalGameAssetsPacked){throw 'Accepted native bundle proof differs'}
 $descriptor=Get-Content -LiteralPath (Join-Path $projectPath 'native/particle_kernel.gdextension') -ErrorAction Stop
 $windowsLibraries=@($descriptor | Where-Object {$_ -match '^\s*windows(?:\.[^=]+)?\s*='})
 $escapedLibrary=[regex]::Escape('res://'+$nativeRuntimeKernelFile)
 if($windowsLibraries.Count -ne 1 -or $windowsLibraries[0] -cnotmatch ('^\s*windows\.x86_64\s*=\s*"'+$escapedLibrary+'"\s*$')){throw 'Active native particle extension does not select the accepted bundle DLL path'}
 if((Get-NativeRuntimeSha256 (Join-Path $projectPath $nativeRuntimeKernelFile)) -cne $nativeRuntimeKernelSha256){throw 'Accepted native bundle DLL changed'}
 $requiredProjectFiles=@(foreach($name in @('project.godot','.godot/global_script_class_cache.cfg')){
  $path=Join-Path $projectPath $name
  if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw ('Verified native runtime requires current project file: '+$name)}
  try{
   @{relative=$name;bytes=(Get-Item -LiteralPath $path -ErrorAction Stop).Length;sha256=Get-NativeRuntimeSha256 $path}
  }catch{throw ('Verified native runtime requires current project file: '+$name)}
 })
 $expectedCapabilities=@'
[
 {"class":"NwnBuiltinLightInputRegistry","parent":"RefCounted","instantiable":true,"methods":[{"name":"dispatch","arguments":2,"returns":"Dictionary"}],"operations":[0,1,2,3,4,6,8,9]},
 {"class":"NwnParticleSceneSnapshot","parent":"RefCounted","methods":[{"name":"snapshot_nodes","arguments":2,"static":true},{"name":"abi_version","arguments":0,"static":true}],"abiVersions":{"abi_version":1}},
 {"class":"NwnParticleSceneBoundary","parent":"RefCounted","methods":[{"name":"abi_version","arguments":0,"static":true},{"name":"eligibility_flags","arguments":1,"static":true},{"name":"global_transform","arguments":1,"static":true},{"name":"pose_status","arguments":0,"static":true},{"name":"direct_abi_version","arguments":0,"static":true}],"abiVersions":{"abi_version":1,"direct_abi_version":1}},
 {"class":"NwnRigSkinPublisher","parent":"RefCounted","instantiable":true,"methods":[{"name":"abi_version","arguments":0,"static":true},{"name":"configure","arguments":1},{"name":"publish","arguments":0},{"name":"take_continuation","arguments":0,"returns":"Dictionary"},{"name":"inspect","arguments":0,"returns":"Dictionary"}],"abiVersions":{"abi_version":2}},
 {"class":"NwnFrameProbe","parent":"RefCounted","methods":[{"name":"feature_totals","arguments":0,"static":true,"returns":"Dictionary"}]},
 {"class":"NwnFramePacing","parent":"RefCounted","methods":[{"name":"snapshot","arguments":1,"static":true,"returns":"Dictionary"}]}
]
'@ | ConvertFrom-Json -AsHashtable
 return @{
  kind='verified-native';executable=$executable;directory=[IO.Path]::GetDirectoryName($projectPath);executableSha256=$executableSha256
  requiresProjectPath=$true;requiredProjectFiles=$requiredProjectFiles;expectedCapabilities=$expectedCapabilities
  selectionEvidence=@{
   sourceClosure=$artifact.engineBuildProof;revision='verified-native-normal-bundle-e';verification='Exact engine/native SHA256, engine byte count and accepted component proof'
   executableBytes=$nativeRuntimeCoreBytes;sourceCommit='ed1daf0bf001b61586d9930840f2f1394092c079';pathOverridesEnabled=$true
   engineVersion=@{major=4;minor=7;patch=2;status='stable';build='custom_build';hash='unknown'}
   sourcePolicy='Caller current project supplied with --path and --script; normal-preset validation remains distinct from installed promotion'
   particleExtensionPolicy='Exact accepted combined-b DLL plus corresponding native sources; conservative flag-absent branches retained'
   referenceEngineDescriptor=@{relative=$nativeRuntimeProofFile;sha256=$nativeRuntimeProofSha256}
  }
 }
}
