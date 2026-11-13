param([Parameter(Mandatory=$true)][string]$ModuleProof,[Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label,[ValidateRange(0,180)][int]$StartAgeSeconds=105,[ValidateRange(100,30000)][int]$DurationMs=30000)
$ErrorActionPreference='Stop'
$ripProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$ripOut=Join-Path $ripProject ('.cache/native-render-gap/original/frame-pacing/rip-'+$Label)
if(Test-Path -LiteralPath $ripOut){throw 'Preserve prior capture'}
$ripProof=Get-Content -LiteralPath $ModuleProof -Raw|ConvertFrom-Json
if(-not$ripProof.success){throw 'Input module proof rejected'}
$ripExe=Join-Path $ripProject '.cache/native-render-gap/original/frame-pacing/rip-sampler-c/sample-rip.exe'
if((Get-FileHash -LiteralPath $ripExe).Hash.ToLowerInvariant()-ne'610e626eb733737905d45c0c5de79bbaaf92637a9e52101a4386e8ebc63c6e95'){throw 'Frozen sampler drift'}
function Get-RipTarget {
 $ripTarget=Get-Process -Id $ripProof.processId
 if($ripTarget.StartTime.ToFileTimeUtc()-ne$ripProof.createdFileTimeUtc-or-not[string]::Equals($ripTarget.MainModule.FileName,$ripProof.engine,[StringComparison]::OrdinalIgnoreCase)){throw 'Target process lifetime/path drift'}
 return $ripTarget
}
$ripInitial=Get-RipTarget
New-Item -ItemType Directory -Path $ripOut|Out-Null
@{moduleProof=[IO.Path]::GetFullPath($ModuleProof);moduleProofSha256=(Get-FileHash -LiteralPath $ModuleProof).Hash.ToLowerInvariant();targetPid=$ripProof.processId;targetCreation=$ripProof.createdFileTimeUtc.ToString();waitUntilAgeSeconds=$StartAgeSeconds;durationMs=$DurationMs;scope='Waits only for the exact owned target. No sampler attachment before age gate.'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $ripOut 'schedule.json') -Encoding utf8
Write-Output ('Waiting for exact owned target '+$ripProof.processId+' age '+$StartAgeSeconds+' seconds')
while($true){$ripTarget=Get-RipTarget;$ripAge=([DateTime]::UtcNow-$ripTarget.StartTime.ToUniversalTime()).TotalSeconds;if($ripAge-ge$StartAgeSeconds){break};Start-Sleep -Milliseconds ([int][Math]::Min(3000,[Math]::Max(1,($StartAgeSeconds-$ripAge)*1000)))}
$ripMain=$ripTarget.MainModule;$ripKernel=@($ripTarget.Modules|Where-Object{[string]::Equals($_.FileName,$ripProof.module,[StringComparison]::OrdinalIgnoreCase)})
if($ripKernel.Count-ne1){throw 'Exact pinned kernel not loaded'}
$ripEngineHash=(Get-FileHash -LiteralPath $ripMain.FileName).Hash.ToLowerInvariant();$ripKernelHash=(Get-FileHash -LiteralPath $ripKernel[0].FileName).Hash.ToLowerInvariant()
if($ripEngineHash-ne'a4fbea1d8122498abc3ee6b7c7cae284863690875dde7c02c1bdf189d0c3c438'-or$ripKernelHash-ne$ripProof.sha256){throw 'Pinned module hash changed'}
$ripThreads=@($ripTarget.Threads|Sort-Object TotalProcessorTime -Descending|Select-Object -First 3|ForEach-Object{@{id=$_.Id;cpuMs=$_.TotalProcessorTime.TotalMilliseconds}})
$ripTid=[int]$ripThreads[0].id
@{pid=$ripTarget.Id;creationFileTimeUtc=$ripTarget.StartTime.ToFileTimeUtc().ToString();mainTid=$ripTid;observedUtc=[DateTime]::UtcNow.ToString('o');ageSeconds=$ripAge;targetCpuThreads=$ripThreads;engine=@{file=$ripMain.FileName;base=('0x{0:x}'-f$ripMain.BaseAddress.ToInt64());size=$ripMain.ModuleMemorySize;sha256=$ripEngineHash};kernel=@{file=$ripKernel[0].FileName;base=('0x{0:x}'-f$ripKernel[0].BaseAddress.ToInt64());size=$ripKernel[0].ModuleMemorySize;sha256=$ripKernelHash}}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $ripOut 'preflight.json') -Encoding utf8
$ripReport=Join-Path $ripOut 'native.json'
# Parenthesize each concatenation: PowerShell otherwise joins the entire comma
# expression into one string. ProcessStartInfo preserves each option separately.
$ripArguments=@(('--pid='+$ripTarget.Id),('--tid='+$ripTid),('--creation='+$ripTarget.StartTime.ToFileTimeUtc().ToString()),('--engine='+$ripMain.FileName),('--sha='+$ripEngineHash),('--kernel='+$ripKernel[0].FileName),('--kernel-sha='+$ripKernelHash),('--duration-ms='+$DurationMs),('--out='+$ripReport))
if($ripArguments.Count-ne9-or@($ripArguments|Where-Object{$_-notmatch'^--[a-z-]+='}).Count){throw 'Structured sampler argument assertion failed'}
$ripStart=[Diagnostics.ProcessStartInfo]::new();$ripStart.FileName=$ripExe;$ripStart.UseShellExecute=$false;$ripStart.CreateNoWindow=$true;$ripStart.RedirectStandardOutput=$true;$ripStart.RedirectStandardError=$true
foreach($ripArgument in $ripArguments){$ripStart.ArgumentList.Add($ripArgument)}
$ripChild=[Diagnostics.Process]::new();$ripChild.StartInfo=$ripStart;[void]$ripChild.Start()
@{pid=$ripChild.Id;targetPid=$ripTarget.Id;targetTid=$ripTid;exe=$ripExe;exeSha256='610e626eb733737905d45c0c5de79bbaaf92637a9e52101a4386e8ebc63c6e95';arguments=$ripArguments;startedUtc=[DateTime]::UtcNow.ToString('o');scope='Authorized RIP diagnostic only; do not terminate sampler while it may own a suspend increment.'}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $ripOut 'process.json') -Encoding utf8
Write-Output ('Started owned RIP sampler PID '+$ripChild.Id+' target '+$ripTarget.Id+' TID '+$ripTid)
$ripStdout=$ripChild.StandardOutput.ReadToEndAsync();$ripStderr=$ripChild.StandardError.ReadToEndAsync()
# Do not forcibly kill this native helper on an outer timer: it owns guaranteed
# RAII resumes. Native collection has its own thirty-second QPC deadline.
$ripChild.WaitForExit();$ripCode=$ripChild.ExitCode
[IO.File]::WriteAllText((Join-Path $ripOut 'stdout.log'),$ripStdout.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $ripOut 'stderr.log'),$ripStderr.GetAwaiter().GetResult());$ripChild.Dispose()
@{exit=$ripCode;finishedUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $ripOut 'exit.json') -Encoding utf8
if($ripCode-ne0){Get-Content -LiteralPath (Join-Path $ripOut 'stderr.log');throw 'Sampler preflight/capture rejected'}
$ripNumeric=Get-Content -LiteralPath $ripReport -Raw|ConvertFrom-Json
$ripInvalid=@($ripNumeric.samples|Where-Object{$_[6]-ne0-or$_[7]-ne0-or$_[8]-ne0-or$_[9]-ne1})
if(-not$ripNumeric.success-or$ripInvalid.Count){throw 'Outer status/suspend/resume interference acceptance failed; preserve raw data'}
Write-Output ('Owned RIP sampler exited0; '+$ripNumeric.samples.Count+' valid captures. Final role/pacing and symbol-map attribution still required.')
