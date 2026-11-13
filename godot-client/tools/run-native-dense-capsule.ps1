[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidatePattern('^native-dense-[a-z0-9-]+$')][string]$Run,
 [Parameter(Mandatory)][ValidatePattern('^native-dense-[a-z0-9-]+$')][string]$Capsule,
 [ValidateSet('baseline','candidate')][string]$Variant='baseline',
 [ValidateRange(1000,120000)][int]$DurationMs=75000,
 [ValidateRange(0,60000)][int]$SteadyMs=0,
 [string]$ReuseCacheRun='',
 [ValidateSet('true','false')][string]$Profiling='true',
 [switch]$Headless
)
$ErrorActionPreference='Stop'
if($SteadyMs-gt0-and$PSBoundParameters.ContainsKey('DurationMs')){throw 'Choose a bounded observation or a steady measurement window'}
$benchProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$benchWorkspace=Split-Path -Parent $benchProject
$benchStage=Join-Path $benchProject ('.cache/native-dense-area/'+$Capsule)
$benchReceipt=Join-Path $benchStage ($Variant+'-sources.json')
$benchInput=Get-Content -LiteralPath $benchReceipt -Raw|ConvertFrom-Json
$benchSource=[IO.Path]::GetFullPath((Join-Path $benchStage $Variant))
if($benchInput.sourceProject-ne$benchSource-or$benchInput.variant-ne$Variant){throw 'Source capsule identity differs'}
foreach($pin in $benchInput.sourcePins){
 $file=[IO.Path]::GetFullPath((Join-Path $benchSource $pin.relative))
 if(-not$file.StartsWith($benchSource+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Capsule input escapes owned copy'}
 if((Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant()-ne$pin.finalSha256){throw ('Frozen source changed: '+$pin.relative)}
}
$benchReport=Join-Path $benchProject ('reports/'+$Run+'.json')
if(Test-Path -LiteralPath $benchReport){throw 'Existing result is preserved; choose a fresh run'}
$benchOwner=Join-Path $benchStage ($Run+'-owner.json')
if(Test-Path -LiteralPath $benchOwner){throw 'Existing run ownership is preserved'}
$benchApp=Join-Path $benchInput.privateUserData 'appdata';$benchLocal=Join-Path $benchInput.privateUserData 'localappdata'
[IO.Directory]::CreateDirectory($benchApp)|Out-Null;[IO.Directory]::CreateDirectory($benchLocal)|Out-Null
$benchCacheRun=if($ReuseCacheRun){$ReuseCacheRun}else{$Run}
if($benchCacheRun-notmatch'^native-dense-[a-z0-9-]+$'){throw 'Invalid explicit cache owner run'}
$benchTemp=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) ('nwn-native-benchmark-'+$benchCacheRun)))
$benchCache=Join-Path $benchTemp 'prepared'
if($ReuseCacheRun){
 $cacheOwner=Get-Content -LiteralPath (Join-Path $benchTemp 'owner.json') -Raw|ConvertFrom-Json
 if($cacheOwner.run-ne$ReuseCacheRun-or$cacheOwner.sourceProject-ne$benchSource-or$cacheOwner.variant-ne$Variant){throw 'Warm cache belongs to another source/variant'}
}else{
 if(Test-Path -LiteralPath $benchTemp){throw 'Existing benchmark cache is preserved'}
 [IO.Directory]::CreateDirectory($benchTemp)|Out-Null
 [IO.File]::WriteAllText((Join-Path $benchTemp 'owner.json'),(@{run=$Run;sourceProject=$benchSource;variant=$Variant;purpose='Explicit native prepared cache for owned offline dense comparison'}|ConvertTo-Json))
}
$benchGuards=@()
foreach($relative in @('project.godot','.godot/extension_list.cfg','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json')){
 $benchGuards+=@{relative=$relative;sha256=(Get-FileHash -LiteralPath (Join-Path $benchProject $relative)).Hash.ToLowerInvariant()}
}
$benchProtected=@(Get-Process -Id 7568,25060 -ErrorAction Stop|ForEach-Object{@{id=$_.Id;name=$_.ProcessName;start=$_.StartTime.ToUniversalTime().ToString('o')}})
$benchScreen=-1
if(-not$Headless){. (Join-Path $PSScriptRoot 'native-window-screen.ps1');$benchScreen=Get-NativeSecondaryScreen;if($benchScreen-lt0){throw 'No secondary monitor; preserve startup preference'}}
$benchArguments=@((Join-Path $PSScriptRoot 'replay-native-loading.mjs'),('--capture='+(Join-Path $benchProject '.cache/loading-benchmark-worlds/arelith-dense-hubint-2x2-v1')),('--source-project='+$benchSource),('--run='+$Run),('--profiling='+$Profiling),('--cache-directory='+$benchCache),'--native-lighting=enhanced','--native-light-history=1','--native-surface-output=true','--native-postprocess-mask=28','--native-postprocess-midpoint=0.4','--native-postprocess-intensity=0.15','--native-postprocess-vibrance=0.7')
if($SteadyMs-gt0){$benchArguments+=@('--settle-ms=1500',('--steady-ms='+$SteadyMs))}else{$benchArguments+=('--duration-ms='+$DurationMs)}
if($Headless){$benchArguments+='--headless'}else{$benchArguments+=('--screen='+$benchScreen)}
$benchStart=[Diagnostics.ProcessStartInfo]::new();$benchStart.FileName=(Get-Command node -ErrorAction Stop).Source;$benchStart.WorkingDirectory=$benchWorkspace;$benchStart.UseShellExecute=$false;$benchStart.CreateNoWindow=$true;$benchStart.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$benchStart.RedirectStandardOutput=$true;$benchStart.RedirectStandardError=$true
foreach($argument in $benchArguments){$benchStart.ArgumentList.Add($argument)}
$benchStart.Environment['APPDATA']=$benchApp;$benchStart.Environment['LOCALAPPDATA']=$benchLocal
$benchStart.Environment['NWN_PARTICLE_PRESENTATION']='shared';$benchStart.Environment['NWN_PARTICLE_LIGHTING']='pooled';$benchStart.Environment['NWN_PARTICLE_KERNEL']='compiled'
foreach($name in @('NWN_RECORD_LOADING','NWN_NATIVE_MENU_EXIT_CHECK','NWN_NATIVE_SOCKET_TRACE')){$benchStart.Environment.Remove($name)|Out-Null}
$benchOwned=[Diagnostics.Process]::Start($benchStart)
$benchOut=$benchOwned.StandardOutput.ReadToEndAsync();$benchErr=$benchOwned.StandardError.ReadToEndAsync()
$benchMetadata=@{schema=1;run=$Run;variant=$Variant;sourceProject=$benchSource;sourceReceipt=$benchReceipt;arguments=$benchArguments;profilingRequested=$Profiling-eq'true';controllerSha256=(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant();steadyRequestedMs=$SteadyMs;observationLimitMs=if($SteadyMs-gt0){$null}else{$DurationMs};privateAppData=$benchApp;privateLocalAppData=$benchLocal;cache=$benchCache;cacheRun=$benchCacheRun;headless=[bool]$Headless;screen=$benchScreen;driverPid=$benchOwned.Id;startedUtc=[DateTime]::UtcNow.ToString('o');guards=$benchGuards;protected=$benchProtected;declaredDeadlineSeconds=300;nativeBuilds=0;gameNetworkConnections=0;performanceAccepted=$false}
[IO.File]::WriteAllText($benchOwner,($benchMetadata|ConvertTo-Json -Depth 7))
@{started=$true;run=$Run;variant=$Variant;driverPid=$benchOwned.Id;screen=$benchScreen;headless=[bool]$Headless;owner=$benchOwner}|ConvertTo-Json -Compress
$benchTimedOut=$false;$benchDeadline=[DateTime]::UtcNow.AddSeconds(300)
while(-not$benchOwned.WaitForExit(500)){
 if([DateTime]::UtcNow-ge$benchDeadline){$benchTimedOut=$true;$benchOwned.Kill($true);$benchOwned.WaitForExit();break}
}
$benchOwned.WaitForExit();$benchOwned.Refresh()
[IO.File]::WriteAllText((Join-Path $benchStage ($Run+'.stdout.log')),$benchOut.GetAwaiter().GetResult())
[IO.File]::WriteAllText((Join-Path $benchStage ($Run+'.stderr.log')),$benchErr.GetAwaiter().GetResult())
$benchChanges=@($benchGuards|Where-Object{(Get-FileHash -LiteralPath (Join-Path $benchProject $_.relative)).Hash.ToLowerInvariant()-ne$_.sha256}|ForEach-Object relative)
$benchProcesses=@($benchProtected|ForEach-Object{$before=$_;$now=Get-Process -Id $before.id -ErrorAction SilentlyContinue;@{id=$before.id;unchanged=[bool]($now-and$now.ProcessName-eq$before.name-and$now.StartTime.ToUniversalTime().ToString('o')-eq$before.start)}})
$benchResult=if(Test-Path -LiteralPath $benchReport){Get-Content -LiteralPath $benchReport -Raw|ConvertFrom-Json}else{$null}
$benchMetadata.closed=$benchOwned.HasExited;$benchMetadata.exit=$benchOwned.ExitCode;$benchMetadata.timedOut=$benchTimedOut;$benchMetadata.report=$benchReport;$benchMetadata.changedGuards=$benchChanges;$benchMetadata.protectedProcesses=$benchProcesses;$benchMetadata.nativeResultWritten=$null-ne$benchResult
[IO.File]::WriteAllText($benchOwner,($benchMetadata|ConvertTo-Json -Depth 7))
@{run=$Run;driverExit=$benchOwned.ExitCode;closed=$benchOwned.HasExited;timedOut=$benchTimedOut;reportWritten=($null-ne$benchResult);nativeSuccess=if($benchResult){$benchResult.success}else{$false};failure=if($benchResult){$benchResult.failure}else{'Missing result'};changedGuards=$benchChanges;protectedUnchanged=-not($benchProcesses.unchanged-contains$false)}|ConvertTo-Json -Compress
if($benchTimedOut-or$benchOwned.ExitCode-ne0-or$benchChanges.Count-or($benchProcesses.unchanged-contains$false)){exit 1}
