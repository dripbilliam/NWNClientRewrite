param(
 [string]$Install='',
 [string]$Profile='',
 [string]$SettingsDirectory='',
 [string]$UserDataDirectory='',
 [string]$ServerHost='',
 [ValidateRange(1,65535)][int]$Port=5121,
 [switch]$LocalOnly,
 [ValidateRange(0,15)][int]$Screen=0,
 [switch]$UseScreen,
 [switch]$Headless,
 [switch]$HeadlessCheck,
 [switch]$GraphicalMenuCheck,
 [switch]$GraphicalMenuExitCheck,
 [ValidatePattern('^[A-Za-z0-9_-]+\.bic$')][string]$PreGeneratedBic='fighter.bic',
 [ValidateSet('ordinary','packed','streamed','static-merged','base-merged','merged')][string]$LoadingPipeline='ordinary',
 [switch]$SharedAnimationPreparation,
 [switch]$NativeDrawCache,
 [ValidateScript({$_ -cmatch '^[1-9][0-9]{1,3}$' -and [int]$_ -ge 25 -and [int]$_ -le 1024})][string]$NativeCacheGiB='25',
 [ValidateSet('gameplay','legacy')][string]$RenderProfile,
 [ValidateSet('godot','enhanced')][string]$Lighting,
 [ValidateSet('0','1')][string]$LightHistory,
 [ValidateSet('true','false')][string]$SurfaceOutput,
 [ValidateSet('individual','shared')][string]$ParticlePresentation,
 [ValidateSet('scene','pooled')][string]$ParticleLighting,
 [string]$ShadowLights,
 [string]$MaximumLights,
 [string]$PostprocessMask,
 [string]$PostprocessMidpoint,
 [string]$PostprocessIntensity,
 [string]$PostprocessVibrance,
 [string]$NativeGamma,
 [ValidateSet('editor','release')][string]$EngineRuntime,
 [string]$RuntimePackage='',
 [ValidateSet('standard','verified-native')][string]$PerformanceRuntime='standard',
 [ValidateSet('default','safe','separate')][string]$RenderThread='default',
 [switch]$CompiledCpuSkin,
 [switch]$CpuSkinPicking,
 [ValidateSet('legacy','indexed')][string]$DriveCollision='indexed',
 [ValidateSet('off','worker')][string]$DriveHeightPlan='off',
 [ValidateSet('off','on')][string]$DrivePreviewHeightIndex='off',
 [ValidateSet('script','builtin')][string]$LightInputRegistry='script',
 [ValidateSet('off','parallel')][string]$BinaryClips='off',
 [ValidateSet('off','on')][string]$ParticleAnimationSnapshot='off',
 [ValidateSet('saved','on','off')][string]$DetailedProfiling='saved',
 [switch]$ProfileSession,
 [switch]$NativeOverheadClocks,
 [string]$Report='',
 [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
if($args.Count){throw 'Unsupported Godot launcher arguments'}
if($CompiledCpuSkin -and $PerformanceRuntime -ne 'standard'){throw 'Compiled CPU skinning requires the standard runtime build'}
if($PSBoundParameters.ContainsKey('NativeCacheGiB') -and -not $NativeDrawCache){throw 'NativeCacheGiB requires NativeDrawCache'}
if($HeadlessCheck -and (-not$Headless -or -not$ServerHost)){throw 'HeadlessCheck requires Headless and ServerHost'}
if($GraphicalMenuCheck -and ($Headless -or $HeadlessCheck -or $ServerHost -or -not$Report)){throw 'GraphicalMenuCheck requires graphical mode, no server connection and a fresh Report path'}
if($GraphicalMenuExitCheck -and ($GraphicalMenuCheck -or $Headless -or $HeadlessCheck -or $ServerHost -or -not$Report)){throw 'GraphicalMenuExitCheck requires graphical mode, no server connection and a fresh Report path'}

function Get-NativeRenderOption($Options,[string]$Name,[string]$Variable,$Fallback,[switch]$IgnoreEnvironment){
 if($Options.ContainsKey($Name)){return $Options[$Name]}
 if(-not $IgnoreEnvironment){
  $inherited=[Environment]::GetEnvironmentVariable($Variable)
  if($null -ne $inherited){return $inherited}
 }
 return $Fallback
}

function Convert-NativeRenderNumber([string]$Value,[string]$Option){
 $raw=$Value.Trim()
 $number=0.0
 $culture=[Globalization.CultureInfo]::InvariantCulture
 if($raw -cmatch '^0([xXoObB])([0-9a-fA-F]+)$'){
  $radix=@{x=16;o=8;b=2}[$Matches[1].ToLowerInvariant()]
  $whole=[System.Numerics.BigInteger]::Zero
  foreach($character in $Matches[2].ToCharArray()){
   $digit=[Convert]::ToInt32([string]$character,16)
   if($digit -ge $radix){throw ('Invalid native '+$Option)}
   $whole=$whole*$radix+$digit
  }
  $number=[double]$whole
 }elseif($raw -cnotmatch '^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$' -or -not [double]::TryParse($raw,[Globalization.NumberStyles]::Float,$culture,[ref]$number)){
  throw ('Invalid native '+$Option)
 }
 if([double]::IsNaN($number) -or [double]::IsInfinity($number)){throw ('Invalid native '+$Option)}
 if($number -eq 0){return 0.0}
 return $number
}

function Resolve-NativeRenderConfiguration([hashtable]$Options,[bool]$Isolated){
 $named=$Options.ContainsKey('RenderProfile')
 if($named -and $Options.RenderProfile -cnotin @('gameplay','legacy')){throw 'Invalid native render profile'}
 $lightingOverrides=$false
 foreach($option in @('Lighting','LightHistory','SurfaceOutput')){
  if($Options.ContainsKey($option)){$lightingOverrides=$true}
 }
 foreach($variable in @('NWN_NATIVE_LIGHTING','NWN_NATIVE_LIGHT_HISTORY','NWN_NATIVE_SURFACE_OUTPUT')){
  if($null -ne [Environment]::GetEnvironmentVariable($variable)){$lightingOverrides=$true}
 }
 $profile=if($named){$Options.RenderProfile}elseif($Isolated -or $lightingOverrides){'legacy'}else{'gameplay'}
 $default=if($profile -eq 'gameplay'){
  @{Lighting='enhanced';LightHistory='1';SurfaceOutput='true';ParticlePresentation='shared';ParticleLighting='pooled'}
 }else{
  @{Lighting='godot';LightHistory='0';SurfaceOutput='false';ParticlePresentation='individual';ParticleLighting='scene'}
 }
 $lighting=Get-NativeRenderOption $Options Lighting NWN_NATIVE_LIGHTING $default.Lighting -IgnoreEnvironment:$named
 $history=Get-NativeRenderOption $Options LightHistory NWN_NATIVE_LIGHT_HISTORY $default.LightHistory -IgnoreEnvironment:$named
 $surface=Get-NativeRenderOption $Options SurfaceOutput NWN_NATIVE_SURFACE_OUTPUT $default.SurfaceOutput -IgnoreEnvironment:$named
 if($lighting -cnotin @('godot','enhanced')){throw 'Invalid native lighting mode'}
 if($history -cnotin @('0','1')){throw 'Invalid native light history switch'}
 if($surface -cnotin @('true','false')){throw 'Invalid native surface-output switch'}
 if($history -eq '1' -and $lighting -ne 'enhanced'){throw 'Native light history requires enhanced lighting'}
 if($surface -eq 'true' -and ($lighting -ne 'enhanced' -or $history -ne '1')){throw 'Native surface output requires enhanced lighting and native light history'}
 $presentation=Get-NativeRenderOption $Options ParticlePresentation NWN_PARTICLE_PRESENTATION $default.ParticlePresentation -IgnoreEnvironment:$named
 $particleLighting=Get-NativeRenderOption $Options ParticleLighting NWN_PARTICLE_LIGHTING $default.ParticleLighting -IgnoreEnvironment:$named
 if($presentation -cnotin @('individual','shared')){throw 'Invalid native particle presentation'}
 if($particleLighting -cnotin @('scene','pooled')){throw 'Invalid native particle lighting'}
 $shadows=Convert-NativeRenderNumber (Get-NativeRenderOption $Options ShadowLights NWN_NATIVE_SHADOW_LIGHTS 1 -IgnoreEnvironment:$named) 'point-shadow limit'
 if($shadows -lt 0 -or $shadows -gt 4 -or $shadows -ne [Math]::Truncate($shadows)){throw 'Invalid native point-shadow limit'}
 # These selections are explicit because the direct renderer's bare defaults differ.
 $renderArguments=@("--native-shadow-lights=$([int]$shadows)","--native-lighting=$lighting")
 $maximum=Get-NativeRenderOption $Options MaximumLights NWN_NATIVE_MAX_LIGHTS $null -IgnoreEnvironment:$named
 if($null -ne $maximum -and $history -ne '1'){throw 'Native maximum lights requires native light history'}
 if($history -eq '1'){
  if($null -eq $maximum){$maximum=32}
  $maximum=Convert-NativeRenderNumber $maximum 'maximum lights'
  if($maximum -lt 0 -or $maximum -gt 128 -or $maximum -ne [Math]::Truncate($maximum)){throw 'Invalid native maximum lights'}
  $renderArguments+=@('--native-light-history',"--native-max-lights=$([int]$maximum)")
 }
 $culture=[Globalization.CultureInfo]::InvariantCulture
 $postprocess=@{mask=16;midpoint=0.4;intensity=0;vibrance=0}
 if($surface -eq 'true'){
  $renderArguments+='--native-surface-output=true'
  $tonalDefaults=if($profile -eq 'gameplay'){@{Mask='28';Midpoint='.4';Intensity='.15';Vibrance='.7'}}else{@{}}
  $floatOverflow=[Math]::Pow(2,128)-[Math]::Pow(2,103)
  foreach($field in @('Mask','Midpoint','Intensity','Vibrance')){
   $value=Get-NativeRenderOption $Options ('Postprocess'+$field) ('NWN_NATIVE_POSTPROCESS_'+$field.ToUpperInvariant()) $tonalDefaults[$field]
   if($null -eq $value){continue}
   $fieldName=$field.ToLowerInvariant()
   $number=Convert-NativeRenderNumber $value ('postprocess '+$fieldName)
   if([Math]::Abs($number) -ge $floatOverflow -or ($field -eq 'Mask' -and ($number -lt 0 -or $number -gt 28 -or $number -ne [Math]::Truncate($number) -or ([int]$number -band (-bnot 28)) -ne 0))){throw ('Invalid native postprocess '+$fieldName)}
   $renderArguments+=('--native-postprocess-'+$fieldName+'='+$number.ToString('R',$culture))
   $postprocess[$fieldName]=$number
  }
 }
 $gamma=Get-NativeRenderOption $Options NativeGamma NWN_NATIVE_GAMMA $null
 if($null -ne $gamma){
  $gamma=Convert-NativeRenderNumber $gamma 'gamma setting'
  if($gamma -lt 0 -or $gamma -gt 1000){throw 'Invalid native gamma setting'}
  $renderArguments+=('--native-gamma='+$gamma.ToString('R',$culture))
 }
 $selection=if($named){'explicit'}elseif($lightingOverrides){'lighting overrides'}elseif($Isolated){'isolated check'}else{'normal gameplay'}
 $summary=@{
  base_profile=$profile;selection=$selection;engine='godot-forward-plus';lighting=$lighting;light_history=$history -eq '1'
  point_shadow_lights=$shadows;surface_output=$surface -eq 'true';particle_presentation=$presentation;particle_lighting=$particleLighting;postprocess=$postprocess
 }
 if($history -eq '1'){$summary.maximum_lights=$maximum}
 if($null -ne $gamma){$summary.gamma=$gamma}
 $summary.profile='custom'
 if($shadows -eq 1){
  if($lighting -eq 'godot' -and $history -eq '0' -and $surface -eq 'false' -and $presentation -eq 'individual' -and $particleLighting -eq 'scene'){$summary.profile='legacy'}
  if($lighting -eq 'enhanced' -and $history -eq '1' -and $surface -eq 'true' -and $presentation -eq 'shared' -and $particleLighting -eq 'pooled' -and $maximum -eq 32 -and $postprocess.mask -eq 28 -and $postprocess.midpoint -eq 0.4 -and $postprocess.intensity -eq 0.15 -and $postprocess.vibrance -eq 0.7){$summary.profile='gameplay'}
 }
 return @{Arguments=$renderArguments;ParticlePresentation=$presentation;ParticleLighting=$particleLighting;Summary=$summary}
}

if(-not $CheckOnly){
 $renderOptions=@{}
 foreach($name in @('RenderProfile','Lighting','LightHistory','SurfaceOutput','ParticlePresentation','ParticleLighting','ShadowLights','MaximumLights','PostprocessMask','PostprocessMidpoint','PostprocessIntensity','PostprocessVibrance','NativeGamma')){
  if($PSBoundParameters.ContainsKey($name)){$renderOptions[$name]=$PSBoundParameters[$name]}
 }
 $renderConfiguration=Resolve-NativeRenderConfiguration $renderOptions ([bool]($HeadlessCheck -or $GraphicalMenuCheck -or $GraphicalMenuExitCheck))
}

$project=[IO.Path]::GetFullPath($PSScriptRoot)
$workspace=Split-Path -Path $project -Parent
. (Join-Path $project 'tools/native-runtime-selection.ps1')
$runtimeExplicit=$PSBoundParameters.ContainsKey('EngineRuntime')
$runtimeKind='editor'
if($runtimeExplicit){$runtimeKind=$EngineRuntime}
elseif($env:NWN_GODOT_RUNTIME){
 if($env:NWN_GODOT_RUNTIME -cnotin @('editor','release')){throw 'Invalid NWN_GODOT_RUNTIME'}
 $runtimeKind=$env:NWN_GODOT_RUNTIME
 $runtimeExplicit=$true
}
if($runtimeKind -cnotin @('editor','release')){throw 'Invalid native engine runtime'}
$performanceParameters=@{
 PerformanceRuntime='performance-runtime';RenderThread='render-thread';DriveCollision='drive-collision';DriveHeightPlan='drive-height-plan'
 DrivePreviewHeightIndex='drive-preview-height-index';LightInputRegistry='light-input-registry';BinaryClips='binary-clips'
 ParticleAnimationSnapshot='particle-animation-snapshot';DetailedProfiling='detailed-profiling'
}
$performanceOverrides=@{}
foreach($name in $performanceParameters.Keys){
 if($PSBoundParameters.ContainsKey($name)){$performanceOverrides[$performanceParameters[$name]]=$PSBoundParameters[$name].ToLowerInvariant()}
}
if($PSBoundParameters.ContainsKey('NativeOverheadClocks')){$performanceOverrides['native-overhead-clocks']=([bool]$NativeOverheadClocks).ToString().ToLowerInvariant()}
$isolatedPerformance=[bool]($HeadlessCheck -or $GraphicalMenuCheck -or $GraphicalMenuExitCheck -or $CheckOnly)
$performance=Resolve-NativeClientPerformance $project $performanceOverrides $isolatedPerformance $runtimeExplicit ([bool]$ProfileSession)
if($runtimeKind -eq 'release'){
 if(-not $CheckOnly){throw 'The authored release-test package contains the retired host entry. Use the Godot delivery for packaged gameplay or CheckOnly with RuntimePackage to verify the prepared receipt.'}
 Select-NativeEngineRuntime $project $runtimeKind $RuntimePackage
 return
}
if($RuntimePackage){throw 'Editor runtime does not take a release package'}
$runtimeSelection=Select-NativePerformanceRuntime $project $performance.runtime
$verifiedRuntime=$null -ne $runtimeSelection
$renderThreadSelection=Resolve-NativeRenderThread $performance.renderThread
$acceptedCore=Get-AcceptedNativeRenderCore $performance.lightInput ($verifiedRuntime -and $performance.verifiedCore)
$packaged=Test-Path -LiteralPath (Join-Path $project 'godot-delivery-manifest.json') -PathType Leaf
$console=Join-Path $project '.tools/Godot_v4.7.2-stable_win64_console.exe'
$desktop=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
# The Windows console executable is a launcher for the desktop executable. In
# a staged package it can fail CreateProcess with error 193; the pinned desktop
# executable runs headlessly itself when passed --headless.
if(-not $verifiedRuntime){
 if(-not(Test-Path -LiteralPath $desktop)){
  if($packaged){throw 'Pinned Godot executable is missing from this delivery'}
  if($CheckOnly){throw 'Pinned Godot is missing; run .\tools\setup.ps1 first'}
  & (Join-Path $project 'tools/setup.ps1') | Out-Null
 }
 if(-not(Test-Path -LiteralPath $desktop)){throw 'Pinned Godot executable is unavailable'}
 $runtimeSelection=Select-NativeEngineRuntime $project 'editor'
 $engine=$desktop
}else{
 $engine=$runtimeSelection.executable
}
$installed=if($Install){[IO.Path]::GetFullPath($Install)}else{''}
if($Install -and -not(Test-Path -LiteralPath $installed -PathType Container)){throw ('NWN installation is unavailable: '+$installed)}
if($Profile){$Profile=[IO.Path]::GetFullPath($Profile)}
if($SettingsDirectory){$SettingsDirectory=[IO.Path]::GetFullPath($SettingsDirectory)}
if($UserDataDirectory){
 $UserDataDirectory=[IO.Path]::GetFullPath($UserDataDirectory)
 if($CheckOnly -and -not(Test-Path -LiteralPath $UserDataDirectory -PathType Container)){throw 'Isolated Godot user-data directory is unavailable'}
 if(-not$CheckOnly){New-Item -ItemType Directory -Path $UserDataDirectory -Force | Out-Null}
}
if($Report){$Report=[IO.Path]::GetFullPath($Report);if(Test-Path -LiteralPath $Report){throw 'Report already exists'}}
if($ServerHost -and ($ServerHost -notmatch '^[A-Za-z0-9._-]+$')){throw 'ServerHost must be a DNS name or IPv4 address; specify port separately'}
if($LocalOnly -and $ServerHost -and $ServerHost -notin @('127.0.0.1','localhost')){throw 'LocalOnly requires the private loopback server'}
if($packaged){
 & (Join-Path $project 'tools/nwn79/verify-godot-delivery.ps1') -PackageRoot $workspace | Out-Null
 & (Join-Path $project 'tools/nwn79/check-godot-only.ps1') | Out-Null
}elseif($CheckOnly){
 & (Join-Path $project 'tools/nwn79/check-godot-only.ps1') | Out-Null
 & (Join-Path $project 'tools/ensure-resource-index.ps1') -CheckOnly
 if(-not $verifiedRuntime){& (Join-Path $project 'tools/ensure-particle-kernel.ps1') -CheckOnly}
}else{
 & (Join-Path $project 'tools/nwn79/check-godot-only.ps1') | Out-Null
 & (Join-Path $project 'tools/build-window-modes.ps1') | Out-Null
 & (Join-Path $project 'tools/ensure-resource-index.ps1')
 if(-not $verifiedRuntime){& (Join-Path $project 'tools/ensure-particle-kernel.ps1')}
 & (Join-Path $project 'tools/nwn79/build-windows-profile.ps1') | Out-Null
}
$credentialHelper=Join-Path $project '.cache/nwn79/windows-profile.exe'
if(-not(Test-Path -LiteralPath $credentialHelper)){throw 'Windows protected settings helper is unavailable'}
$contentReader=Join-Path $workspace 'tooling/native/content-reader/nwn-content-reader.exe'
if(-not(Test-Path -LiteralPath $contentReader)){
 if($CheckOnly -or $packaged){throw 'Native content reader is missing'}
 & (Join-Path $workspace 'scripts/build-content-reader.ps1') | Out-Null
}
if(-not(Test-Path -LiteralPath $contentReader)){throw 'Native content reader is unavailable'}
$cryptoHelper=Join-Path $workspace 'tooling/native/nwn-network-crypto.exe'
if(-not(Test-Path -LiteralPath $cryptoHelper)){
 if($CheckOnly -or $packaged){throw 'Native network crypto helper is missing'}
 & (Join-Path $workspace 'scripts/build-network-crypto.ps1') | Out-Null
}
if(-not(Test-Path -LiteralPath $cryptoHelper)){throw 'Native network crypto helper is unavailable'}
if($CheckOnly){
 if($Headless){
  $probeName='nwn79-headless-'+[guid]::NewGuid().ToString('N')
  $probeFile=Join-Path ([IO.Path]::GetTempPath()) ($probeName+'.gd')
  $probeReceipt=Join-Path ([IO.Path]::GetTempPath()) ($probeName+'.txt')
  $probeSource=@'
extends SceneTree
func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1 or not str(arguments[0]).begins_with("--probe-receipt="): quit(2); return
	var file := FileAccess.open(str(arguments[0]).trim_prefix("--probe-receipt="), FileAccess.WRITE)
	if file == null: quit(3); return
	file.store_string("NWN79_HEADLESS_ENGINE_PROBE_PASS")
	file.close()
	quit(0)
'@
  [IO.File]::WriteAllText($probeFile,$probeSource,[Text.UTF8Encoding]::new($false))
  $probeInfo=[Diagnostics.ProcessStartInfo]::new()
  $probeInfo.FileName=$engine
  $probeInfo.WorkingDirectory=$project
  $probeInfo.UseShellExecute=$false
  $probeInfo.CreateNoWindow=$true
  $probeInfo.RedirectStandardOutput=$true
  $probeInfo.RedirectStandardError=$true
  foreach($argument in $renderThreadSelection.arguments){$probeInfo.ArgumentList.Add($argument)}
  $probeInfo.ArgumentList.Add('--headless')
  $probeInfo.ArgumentList.Add('--path')
  $probeInfo.ArgumentList.Add($project.Replace('\','/'))
  $probeInfo.ArgumentList.Add('--script')
  $probeInfo.ArgumentList.Add($probeFile.Replace('\','/'))
  $probeInfo.ArgumentList.Add('--')
  $probeInfo.ArgumentList.Add('--probe-receipt='+$probeReceipt.Replace('\','/'))
  $probe=$null
  try{
   $probe=[Diagnostics.Process]::Start($probeInfo)
   if($probe -eq $null){throw 'Pinned Godot headless engine did not start'}
   $outputTask=$probe.StandardOutput.ReadToEndAsync()
   $errorTask=$probe.StandardError.ReadToEndAsync()
   if(-not$probe.WaitForExit(45000)){
    $probe.Kill();$probe.WaitForExit()
    throw ('Pinned Godot headless engine did not exit within 45 seconds: '+$outputTask.GetAwaiter().GetResult()+' '+$errorTask.GetAwaiter().GetResult())
   }
   $outputText=$outputTask.GetAwaiter().GetResult().Trim()
   $errorText=$errorTask.GetAwaiter().GetResult().Trim()
   if($probe.ExitCode -ne 0){throw ('Pinned Godot headless engine exited with code '+$probe.ExitCode+': '+$errorText)}
   if(-not(Test-Path -LiteralPath $probeReceipt -PathType Leaf) -or [IO.File]::ReadAllText($probeReceipt) -ne 'NWN79_HEADLESS_ENGINE_PROBE_PASS'){throw ('Pinned Godot headless script did not produce its receipt: '+$outputText+' '+$errorText)}
  }finally{
   if($probe -ne $null){$probe.Dispose()}
   foreach($file in @($probeFile,$probeReceipt)){if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file -Force}}
  }
  Write-Output 'Godot-only pinned headless engine launch PASS'
 }
 Write-Output 'Godot-only native client prerequisites PASS'
 return
}
$arguments=$renderThreadSelection.arguments+@('--path',$project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--script','res://native_direct_session_world.gd')
if($Headless){$arguments=@('--headless')+$arguments}
if($UseScreen -and -not$Headless){$arguments=@('--screen',"$Screen")+$arguments}
$arguments+=@('--','--direct-session','--native-startup-selection=true')
if($installed){$arguments+=('--direct-install='+$installed)}
if($Profile){$arguments+=('--direct-profile='+$Profile)}
if($SettingsDirectory){$arguments+=('--direct-settings='+$SettingsDirectory)}
if($ServerHost){$arguments+=@("--direct-host=$ServerHost","--direct-port=$Port")}
if($LocalOnly){$arguments+='--direct-local-only=true'}
if($Report){$arguments+=('--report='+$Report)}
if($HeadlessCheck){$arguments+=@('--direct-headless-check=true',"--direct-pregen-bic=$PreGeneratedBic")}
if($GraphicalMenuCheck){$arguments+='--direct-graphical-menu-check=true'}
if($GraphicalMenuExitCheck){$arguments+='--direct-graphical-menu-exit-check=true'}
$arguments+=$renderConfiguration.Arguments
$arguments+=$performance.nativeArguments
$arguments+=$acceptedCore.flags
if($CompiledCpuSkin){$arguments+='--cpu-skin-deform=compiled'}
if($CpuSkinPicking){$arguments+='--cpu-skin-pick=on-demand'}
switch($LoadingPipeline){
 'ordinary'{}
 'packed'{$arguments+='--model-template=packed'}
 default{
  $arguments+=@('--base-scenery-owner=retained','--base-scenery-templates=retained','--base-scenery-template-probe=ready','--base-scenery-admission=timed','--base-scenery-stream=continuous','--model-template=recipe')
 }
}
if($LoadingPipeline -in @('static-merged','merged')){$arguments+='--static-scenery=merged'}
if($LoadingPipeline -in @('base-merged','merged')){$arguments+='--base-scenery-draw=merged'}
if($SharedAnimationPreparation){$arguments+='--shared-animation-preparation=true'}
if($NativeDrawCache){$arguments+=@('--native-draw-cache=prepared',"--native-draw-cache-gib=$NativeCacheGiB")}
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$engine
$start.WorkingDirectory=if($verifiedRuntime){$runtimeSelection.directory}else{$project}
$start.UseShellExecute=$false
$start.CreateNoWindow=[bool]$Headless
$start.Environment['NWN_PARTICLE_PRESENTATION']=$renderConfiguration.ParticlePresentation
$start.Environment['NWN_PARTICLE_LIGHTING']=$renderConfiguration.ParticleLighting
$startupSelection=@{
 version=1;registry=$performance.registry;requested=$performance.requested;runtime=$runtimeSelection;renderCore=$acceptedCore
 project=$project;renderConfiguration=$renderConfiguration.Summary
 arguments=$renderThreadSelection.arguments+$renderConfiguration.Arguments+$performance.nativeArguments+$acceptedCore.flags
}
$startupSelectionJson=$startupSelection | ConvertTo-Json -Depth 14 -Compress
if([Text.Encoding]::UTF8.GetByteCount($startupSelectionJson) -gt 16384){throw 'Native startup selection exceeds its bound'}
$start.Environment['NWN_NATIVE_STARTUP_SELECTION']=$startupSelectionJson
if($UserDataDirectory){$start.Environment['APPDATA']=$UserDataDirectory}
foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
$process=[Diagnostics.Process]::Start($start)
if($process -eq $null){throw 'Godot-only native client did not start'}
try{
 $process.WaitForExit()
 $exitCode=$process.ExitCode
}finally{$process.Dispose()}
if($exitCode -ne 0){throw ('Godot-only native client exited with code '+$exitCode)}
