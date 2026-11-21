param([Parameter(Mandatory=$true)][string]$Config,[Parameter(Mandatory=$true)][int]$ServerPid)
$ErrorActionPreference='Stop'
$frontConfig=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
$frontOut=[IO.Path]::GetFullPath($frontConfig.out)
if(Test-Path -LiteralPath (Join-Path $frontOut 'launcher.json')){throw 'Preserve prior launch'}
foreach($frontPin in $frontConfig.pins){if((Get-FileHash -LiteralPath $frontPin.file).Hash.ToLowerInvariant()-ne$frontPin.sha256){throw 'Frozen harness drift'}}
if((Get-FileHash -LiteralPath $frontConfig.host).Hash.ToLowerInvariant()-ne$frontConfig.hostSha256-or(Get-FileHash -LiteralPath $frontConfig.bootstrap).Hash.ToLowerInvariant()-ne$frontConfig.bootstrapSha256){throw 'Ordinary host/bootstrap source drift'}
$frontServer=Get-Process -Id $ServerPid
$frontUdp=@(Get-NetUDPEndpoint -LocalPort 5121)
if($frontUdp.Count-lt1-or@($frontUdp|Where-Object OwningProcess -NE $ServerPid).Count-ne0){throw 'UDP5121 endpoint is not exclusively owned by supplied server PID'}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NormalFrontendPresentation {
 [StructLayout(LayoutKind.Sequential)] struct Point { public int X,Y; }
 [StructLayout(LayoutKind.Sequential)] struct Cursor {public int Size;public uint Flags;public IntPtr Handle;public Point Position;}
 [StructLayout(LayoutKind.Sequential)] struct Rect {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)] struct Info {public int Size;public Rect Monitor,Work;public uint Flags;}
 [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll",EntryPoint="GetWindowLongPtrW")] static extern IntPtr GetWindowLongPtr(IntPtr window,int index);
 [DllImport("user32.dll")] static extern bool GetCursorInfo(ref Cursor cursor);
 [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr window,uint flags);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern bool GetMonitorInfoW(IntPtr monitor,ref Info info);
 public static object Read(IntPtr window){if(window==IntPtr.Zero)return null;var c=new Cursor{Size=Marshal.SizeOf<Cursor>()};var i=new Info{Size=Marshal.SizeOf<Info>()};if(!GetCursorInfo(ref c)||!GetMonitorInfoW(MonitorFromWindow(window,2),ref i))return null;long style=GetWindowLongPtr(window,-20).ToInt64();return new{unfocusableNoActivate=(style&0x08000000)!=0,focused=GetForegroundWindow()==window,nonPrimary=(i.Flags&1)==0,cursorVisible=(c.Flags&1)!=0};}
}
'@
$frontStart=[Diagnostics.ProcessStartInfo]::new();$frontStart.FileName=(Get-Command pwsh).Source;$frontStart.WorkingDirectory=Split-Path -Parent $frontConfig.project;$frontStart.UseShellExecute=$false;$frontStart.CreateNoWindow=$true;$frontStart.RedirectStandardOutput=$true;$frontStart.RedirectStandardError=$true
$frontArguments=@('-NoProfile','-File',(Join-Path $frontConfig.project 'join-native.ps1'),'-LocalOnly','-Server','127.0.0.1:5121','-Run',$frontConfig.run)
foreach($frontArg in $frontArguments){$frontStart.ArgumentList.Add($frontArg)}
$frontPreload=(Join-Path $frontOut 'source/bootstrap-preload.cjs').Replace('\','/')
$frontStart.Environment['NWN_NORMAL_FRONTEND_CONFIG']=[IO.Path]::GetFullPath($Config)
$frontStart.Environment['NODE_OPTIONS']=(($env:NODE_OPTIONS+' --require="'+$frontPreload+'"').Trim())
$frontChild=[Diagnostics.Process]::new();$frontChild.StartInfo=$frontStart;[void]$frontChild.Start();$frontStdout=$frontChild.StandardOutput.ReadToEndAsync();$frontStderr=$frontChild.StandardError.ReadToEndAsync()
@{version=1;pid=$frontChild.Id;arguments=$frontArguments;configSha256=(Get-FileHash -LiteralPath $Config).Hash.ToLowerInvariant();server=@{pid=$ServerPid;path=$frontServer.Path;creationFileTimeUtc=$frontServer.StartTime.ToUniversalTime().ToFileTimeUtc().ToString();localPort=5121};startedUtc=[DateTime]::UtcNow.ToString('o');scope='Owned normal LocalOnly client, private frontend IPC and read-only API. No explicit runtime/check switches. Server owned separately by root.'}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $frontOut 'launcher.json') -Encoding utf8
Write-Output ('Started ordinary LocalOnly launcher PID '+$frontChild.Id)
$frontNativeProof=$null;$frontPresentations=[Collections.Generic.List[object]]::new();$frontWatch=[Diagnostics.Stopwatch]::StartNew();$frontProgressFile=Join-Path $frontOut 'frontend-progress.json'
try {
while(-not$frontChild.WaitForExit(500)){
 if($frontWatch.Elapsed.TotalSeconds-gt230){$frontChild.Kill($true);[void]$frontChild.WaitForExit(2000);throw 'Owned normal local test exceeded230s; forced tree closure is not clean acceptance'}
 if(Test-Path -LiteralPath $frontProgressFile){try{
  $frontProgress=Get-Content -LiteralPath $frontProgressFile -Raw|ConvertFrom-Json
  if($frontProgress.native.pid){
   $frontNative=Get-Process -Id ([int]$frontProgress.native.pid)
   $frontExe=$frontNative.MainModule.FileName;$frontCreation=$frontNative.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()
   if(-not[IO.Path]::GetFullPath($frontExe).Equals([IO.Path]::GetFullPath($frontConfig.engine),[StringComparison]::OrdinalIgnoreCase)){throw 'Actual loaded normal engine path mismatch'}
   if(-not$frontNativeProof){if((Get-FileHash -LiteralPath $frontExe).Hash.ToLowerInvariant()-ne$frontConfig.engineSha256){throw 'Actual loaded normal engine mismatch'};$frontNativeProof=@{pid=$frontNative.Id;hostPid=$frontProgress.hostPid;path=$frontExe;sha256=$frontConfig.engineSha256;creationFileTimeUtc=$frontCreation}}
   elseif($frontCreation-ne$frontNativeProof.creationFileTimeUtc-or-not$frontExe.Equals($frontNativeProof.path,[StringComparison]::OrdinalIgnoreCase)){throw 'Native PID lifetime/path mismatch'}
   if(-not$frontNativeProof.kernel){$frontKernel=@($frontNative.Modules|Where-Object ModuleName -EQ 'nwn-particle-kernel.dll');if($frontKernel.Count-eq1){$frontHash=(Get-FileHash -LiteralPath $frontKernel[0].FileName).Hash.ToLowerInvariant();if($frontHash-ne$frontConfig.expectedKernelSha256){throw 'Actual loaded normal kernel mismatch'};$frontNativeProof.kernel=@{file=$frontKernel[0].FileName;sha256=$frontHash}}}
   if(-not$frontNativeProof.resource){$frontResource=@($frontNative.Modules|Where-Object ModuleName -EQ 'nwn-resource-index.dll');if($frontResource.Count-eq1){$frontResourcePath=$frontResource[0].FileName;if(-not[IO.Path]::GetFullPath($frontResourcePath).Equals([IO.Path]::GetFullPath($frontConfig.expectedResourcePath),[StringComparison]::OrdinalIgnoreCase)){throw 'Actual loaded normal resource path mismatch'};$frontHash=(Get-FileHash -LiteralPath $frontResourcePath).Hash.ToLowerInvariant();if($frontHash-ne$frontConfig.expectedResourceSha256){throw 'Actual loaded normal resource mismatch'};$frontNativeProof.resource=@{file=$frontResourcePath;sha256=$frontHash}}}
   $frontWindow=[NormalFrontendPresentation]::Read($frontNative.MainWindowHandle);if($null-ne$frontWindow-and$frontPresentations.Count-lt500){$frontPresentations.Add(@{at=[DateTime]::UtcNow.ToString('o');state=$frontWindow})}
   $frontNative.Dispose()
  }
 }catch{if($_.Exception.Message-match'mismatch'){throw}}}
}
$frontExit=$frontChild.ExitCode;$frontText=$frontStdout.GetAwaiter().GetResult();$frontError=$frontStderr.GetAwaiter().GetResult();[IO.File]::WriteAllText((Join-Path $frontOut 'stdout.log'),$frontText);[IO.File]::WriteAllText((Join-Path $frontOut 'stderr.log'),$frontError)
$frontProgress=Get-Content -LiteralPath $frontProgressFile -Raw|ConvertFrom-Json
$frontHostFile=Join-Path $frontConfig.project ('reports/'+$frontConfig.run+'.json');$frontNativeFile=Join-Path $frontConfig.project ('reports/'+$frontConfig.run+'.native.json');$frontHost=Get-Content -LiteralPath $frontHostFile -Raw|ConvertFrom-Json;$frontNativeReport=Get-Content -LiteralPath $frontNativeFile -Raw|ConvertFrom-Json
$frontCopies=Get-Content -LiteralPath (Join-Path $frontOut 'settings-copies.json') -Raw|ConvertFrom-Json;foreach($frontCopy in $frontCopies.copies){if((Get-FileHash -LiteralPath $frontCopy.source).Hash.ToLowerInvariant()-ne$frontCopy.sha256){throw 'Original protected settings/preference source changed'}}
& node (Join-Path $PSScriptRoot 'verify-policy.cjs') $Config
if($LASTEXITCODE-ne0){throw 'Formal normal policy/native/world proof rejected'}
$frontPolicyFile=Join-Path $frontOut 'normal-policy-proof.json';$frontPolicy=Get-Content -LiteralPath $frontPolicyFile -Raw|ConvertFrom-Json
$frontWindowPass=$frontPresentations.Count-gt0-and@($frontPresentations|Where-Object{-not$_.state.unfocusableNoActivate-or$_.state.focused-or-not$_.state.nonPrimary-or-not$_.state.cursorVisible}).Count-eq0
$frontSuccess=$frontExit-eq0-and$frontProgress.success-and$frontProgress.nativeFinished.success-and$frontProgress.nativeExit.code-eq0-and$frontHost.success-and$frontHost.sourceUnchanged-and$frontHost.publicConnections-eq0-and$frontNativeReport.clean_exit-and$frontNativeProof.kernel-and$frontNativeProof.resource-and$frontWindowPass-and$frontPolicy.success
$frontReceipt=@{version=1;success=[bool]$frontSuccess;exit=$frontExit;native=$frontNativeProof;movement=$frontProgress.proof;frontendEvents=$frontProgress.events;originalSettingsUnchanged=$true;presentationPass=$frontWindowPass;presentations=$frontPresentations;normalPolicy=@{file=$frontPolicyFile;sha256=(Get-FileHash -LiteralPath $frontPolicyFile).Hash.ToLowerInvariant()};hostReport=@{file=$frontHostFile;sha256=(Get-FileHash -LiteralPath $frontHostFile).Hash.ToLowerInvariant()};nativeReport=@{file=$frontNativeFile;sha256=(Get-FileHash -LiteralPath $frontNativeFile).Hash.ToLowerInvariant()};finishedUtc=[DateTime]::UtcNow.ToString('o');scope='Ordinary production policy LocalOnly frontend IPC integration with actual original-server received movement and native presentation, clean finish/ack and process-scoped no-focus working-copy diagnostics. No FPS or physical chooser/Exit-control claim.'}
$frontReceipt|ConvertTo-Json -Depth 18|Set-Content -LiteralPath (Join-Path $frontOut 'acceptance.json') -Encoding utf8
if(-not$frontSuccess){throw 'Normal local frontend acceptance rejected; retained reports explain actual outcome'}
Write-Output 'Normal local frontend/authority acceptance PASS; owned client tree closed.'
} finally {
 if(-not$frontChild.HasExited){[IO.File]::WriteAllText((Join-Path $frontOut 'request-clean-finish.json'),'{"kind":"request-clean-finish"}');if(-not$frontChild.WaitForExit(30000)){$frontChild.Kill($true);[void]$frontChild.WaitForExit(2000);@{forced=$true;scope='Exceptional owned-tree cleanup; never clean-exit acceptance'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $frontOut 'forced-cleanup.json') -Encoding utf8}}
 $frontChild.Dispose()
}
