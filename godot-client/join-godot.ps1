param(
 [string]$Install='',
 [string]$Profile='',
 [string]$SettingsDirectory='',
 [string]$UserDataDirectory='',
 [string]$ServerHost='',
 [ValidateRange(1,65535)][int]$Port=5121,
 [ValidateRange(0,15)][int]$Screen=0,
 [switch]$UseScreen,
 [switch]$Headless,
 [switch]$HeadlessCheck,
 [switch]$GraphicalMenuCheck,
 [switch]$GraphicalMenuExitCheck,
 [ValidatePattern('^[A-Za-z0-9_-]+\.bic$')][string]$PreGeneratedBic='fighter.bic',
 [string]$Report='',
 [switch]$CheckOnly
)
$ErrorActionPreference='Stop'
if($HeadlessCheck -and (-not$Headless -or -not$ServerHost)){throw 'HeadlessCheck requires Headless and ServerHost'}
if($GraphicalMenuCheck -and ($Headless -or $HeadlessCheck -or $ServerHost -or -not$Report)){throw 'GraphicalMenuCheck requires graphical mode, no server connection and a fresh Report path'}
if($GraphicalMenuExitCheck -and ($GraphicalMenuCheck -or $Headless -or $HeadlessCheck -or $ServerHost -or -not$Report)){throw 'GraphicalMenuExitCheck requires graphical mode, no server connection and a fresh Report path'}
$project=[IO.Path]::GetFullPath($PSScriptRoot)
$workspace=Split-Path -Path $project -Parent
$packaged=Test-Path -LiteralPath (Join-Path $project 'godot-delivery-manifest.json') -PathType Leaf
$console=Join-Path $project '.tools/Godot_v4.7.2-stable_win64_console.exe'
$desktop=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
# The Windows console executable is a launcher for the desktop executable. In
# a staged package it can fail CreateProcess with error 193; the pinned desktop
# executable runs headlessly itself when passed --headless.
$engine=$desktop
if(-not(Test-Path -LiteralPath $desktop)){
 if($packaged){throw 'Pinned Godot executable is missing from this delivery'}
 if($CheckOnly){throw 'Pinned Godot is missing; run .\tools\setup.ps1 first'}
 & (Join-Path $project 'tools/setup.ps1') | Out-Null
}
if(-not(Test-Path -LiteralPath $engine)){throw 'Pinned Godot executable is unavailable'}
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
if($packaged){
 & (Join-Path $project 'tools/nwn79/verify-godot-delivery.ps1') -PackageRoot $workspace | Out-Null
 & (Join-Path $project 'tools/nwn79/check-godot-only.ps1') | Out-Null
}elseif($CheckOnly){
 & (Join-Path $project 'tools/nwn79/check-godot-only.ps1') | Out-Null
 & (Join-Path $project 'tools/ensure-resource-index.ps1') -CheckOnly
 & (Join-Path $project 'tools/ensure-particle-kernel.ps1') -CheckOnly
}else{
 & (Join-Path $project 'tools/nwn79/check-godot-only.ps1') | Out-Null
 & (Join-Path $project 'tools/build-window-modes.ps1') | Out-Null
 & (Join-Path $project 'tools/ensure-resource-index.ps1')
 & (Join-Path $project 'tools/ensure-particle-kernel.ps1')
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
$arguments=@('--path',$project,'--script','res://native_direct_session_world.gd')
if($Headless){$arguments=@('--headless')+$arguments}
if($UseScreen -and -not$Headless){$arguments=@('--screen',"$Screen")+$arguments}
$arguments+=@('--','--direct-session')
if($installed){$arguments+=('--direct-install='+$installed)}
if($Profile){$arguments+=('--direct-profile='+$Profile)}
if($SettingsDirectory){$arguments+=('--direct-settings='+$SettingsDirectory)}
if($ServerHost){$arguments+=@("--direct-host=$ServerHost","--direct-port=$Port")}
if($Report){$arguments+=('--report='+$Report)}
if($HeadlessCheck){$arguments+=@('--direct-headless-check=true',"--direct-pregen-bic=$PreGeneratedBic")}
if($GraphicalMenuCheck){$arguments+='--direct-graphical-menu-check=true'}
if($GraphicalMenuExitCheck){$arguments+='--direct-graphical-menu-exit-check=true'}
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$engine
$start.WorkingDirectory=$project
$start.UseShellExecute=$false
$start.CreateNoWindow=[bool]$Headless
if($UserDataDirectory){$start.Environment['APPDATA']=$UserDataDirectory}
foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
$process=[Diagnostics.Process]::Start($start)
if($process -eq $null){throw 'Godot-only native client did not start'}
try{
 $process.WaitForExit()
 $exitCode=$process.ExitCode
}finally{$process.Dispose()}
if($exitCode -ne 0){throw ('Godot-only native client exited with code '+$exitCode)}
