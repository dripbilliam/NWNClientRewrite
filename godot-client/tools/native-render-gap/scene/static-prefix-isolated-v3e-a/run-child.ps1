param([Parameter(Mandatory=$true)][string]$Suite,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$SuiteSha,[Parameter(Mandatory=$true)][int]$Index,[switch]$Run)
$ErrorActionPreference='Stop'
if(-not$Run){throw 'Source-only isolated runner; a new authorized native slot is required'}
$suiteFile=[IO.Path]::GetFullPath($Suite)
if((Get-FileHash -LiteralPath $suiteFile).Hash.ToLowerInvariant()-ne$SuiteSha){throw 'Isolated suite pin mismatch'}
$suiteData=Get-Content -LiteralPath $suiteFile -Raw|ConvertFrom-Json
if($Index-lt0-or$Index-ge$suiteData.jobs.Count){throw 'Isolated job index differs'}
$suiteRunner=@($suiteData.pins|Where-Object file -EQ $PSCommandPath)
if($suiteRunner.Count-ne1-or(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()-ne$suiteRunner[0].sha256){throw 'Frozen isolated runner changed'}
$job=$suiteData.jobs[$Index]
$fixture=[pscustomobject]@{engine=$suiteData.engine;out=$job.out;cli=$job.cli;environment=$job.environment;requiredModules=$suiteData.requiredModules;output=$job.output}
& node (Join-Path $PSScriptRoot 'verify-child.cjs') --phase=pre ('--suite='+$suiteFile) ('--suite-sha='+$SuiteSha) ('--index='+$Index)
if($LASTEXITCODE-ne0){throw 'Isolated child preparation rejected'}
$fixtureStart=[Diagnostics.ProcessStartInfo]::new();$fixtureStart.FileName=$fixture.engine.file;$fixtureStart.WorkingDirectory=$fixture.out;$fixtureStart.UseShellExecute=$false;$fixtureStart.CreateNoWindow=$true;$fixtureStart.WindowStyle='Hidden';$fixtureStart.RedirectStandardOutput=$true;$fixtureStart.RedirectStandardError=$true
foreach($fixtureArgument in $fixture.cli){$fixtureStart.ArgumentList.Add([string]$fixtureArgument)}
foreach($fixtureEnvironment in $fixture.environment.psobject.Properties){$fixtureStart.Environment[$fixtureEnvironment.Name]=[string]$fixtureEnvironment.Value}
$fixtureProcess=[Diagnostics.Process]::new();$fixtureProcess.StartInfo=$fixtureStart
$fixtureProof=@{version=1;pid=0;path=$fixture.engine.file;sha256=$fixture.engine.sha256;creationFileTimeUtc='';modules=@();stableLifetimeSamples=0;cleanExit=$false;forced=$false;exit=$null;startedUtc=[DateTime]::UtcNow.ToString('o');scope='Only this owned headless private fixture process; exact loaded engine and three native modules observed before startup barrier release.'}
$fixtureStdout=$null;$fixtureStderr=$null;$fixtureStarted=$false
try{
 if(-not$fixtureProcess.Start()){throw 'Owned fixture failed to start'}
 $fixtureStarted=$true
 $fixtureProof.pid=$fixtureProcess.Id;$fixtureProof.creationFileTimeUtc=$fixtureProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()
 $fixtureStdout=$fixtureProcess.StandardOutput.ReadToEndAsync();$fixtureStderr=$fixtureProcess.StandardError.ReadToEndAsync()
 $fixtureWatch=[Diagnostics.Stopwatch]::StartNew()
 $fixtureStartup=$null
 while(-not$fixtureStartup){
  if($fixtureProcess.HasExited){throw 'Engine exited before actual-module startup proof'}
  if($fixtureWatch.Elapsed.TotalSeconds-gt15){throw 'Actual fixture startup barrier exceeded15s'}
  if(Test-Path -LiteralPath $fixture.output.startup){try{$fixtureStartup=Get-Content -LiteralPath $fixture.output.startup -Raw|ConvertFrom-Json -ErrorAction Stop}catch{}}
  if(-not$fixtureStartup){Start-Sleep -Milliseconds 50}
 }
 if([int]$fixtureStartup.pid-ne$fixtureProcess.Id-or$fixtureStartup.engine_sha256-ne$fixture.engine.sha256){throw 'Native startup PID/engine scope differs'}
 $fixtureActual=$fixtureProcess.MainModule.FileName
 if(-not[IO.Path]::GetFullPath($fixtureActual).Equals([IO.Path]::GetFullPath($fixture.engine.file),[StringComparison]::OrdinalIgnoreCase)-or(Get-FileHash -LiteralPath $fixtureActual).Hash.ToLowerInvariant()-ne$fixture.engine.sha256){throw 'Actual loaded fixture engine differs'}
 foreach($fixtureRequired in $fixture.requiredModules){
  $fixtureLoaded=@($fixtureProcess.Modules|Where-Object ModuleName -EQ $fixtureRequired.name)
  if($fixtureLoaded.Count-ne1){throw ('Expected one actual loaded module: '+$fixtureRequired.name)}
  $fixtureModulePath=[IO.Path]::GetFullPath($fixtureLoaded[0].FileName)
  if(-not$fixtureModulePath.Equals([IO.Path]::GetFullPath($fixtureRequired.file),[StringComparison]::OrdinalIgnoreCase)){throw 'Actual loaded fixture module path differs'}
  $fixtureModuleHash=(Get-FileHash -LiteralPath $fixtureModulePath).Hash.ToLowerInvariant()
  if($fixtureModuleHash-ne$fixtureRequired.sha256){throw 'Actual loaded fixture module hash differs'}
  $fixtureProof.modules+=@{name=$fixtureRequired.name;path=$fixtureModulePath;sha256=$fixtureModuleHash}
 }
 if($fixtureProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-ne$fixtureProof.creationFileTimeUtc){throw 'Fixture PID lifetime changed'}
 $fixtureProof.stableLifetimeSamples+=1
 @{pid=$fixtureProcess.Id;engine_sha256=$fixture.engine.sha256;creationFileTimeUtc=$fixtureProof.creationFileTimeUtc;observedModules=$fixtureProof.modules;releasedUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $fixture.output.observerReady -Encoding utf8
 while(-not$fixtureProcess.WaitForExit(250)){
  if($fixtureWatch.Elapsed.TotalSeconds-gt120){throw 'Private full fixture exceeded120s'}
  if($fixtureProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-ne$fixtureProof.creationFileTimeUtc-or-not$fixtureProcess.MainModule.FileName.Equals($fixture.engine.file,[StringComparison]::OrdinalIgnoreCase)){throw 'Fixture actual PID/path/lifetime changed'}
  $fixtureProof.stableLifetimeSamples+=1
 }
 $fixtureProof.exit=$fixtureProcess.ExitCode;$fixtureProof.cleanExit=$fixtureProcess.ExitCode-eq0
}finally{
 if($fixtureStarted-and-not$fixtureProcess.HasExited){
  # Kill only the process object we started, after checking its exact lifetime.
  if($fixtureProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-eq$fixtureProof.creationFileTimeUtc){$fixtureProcess.Kill($true);[void]$fixtureProcess.WaitForExit(3000);$fixtureProof.forced=$true}
 }
 if($fixtureStdout){[IO.File]::WriteAllText($fixture.output.stdout,$fixtureStdout.GetAwaiter().GetResult())}
 if($fixtureStderr){[IO.File]::WriteAllText($fixture.output.stderr,$fixtureStderr.GetAwaiter().GetResult())}
 $fixtureProof.finishedUtc=[DateTime]::UtcNow.ToString('o');$fixtureProof|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $fixture.output.process -Encoding utf8
 $fixtureProcess.Dispose()
}
if(-not$fixtureProof.cleanExit-or$fixtureProof.forced){throw 'Private fixture did not close cleanly; retained outputs are not acceptance'}
& node (Join-Path $PSScriptRoot 'verify-child.cjs') --phase=post ('--suite='+$suiteFile) ('--suite-sha='+$SuiteSha) ('--index='+$Index)
if($LASTEXITCODE-ne0){throw 'Isolated child proof rejected; complete observations retained'}
