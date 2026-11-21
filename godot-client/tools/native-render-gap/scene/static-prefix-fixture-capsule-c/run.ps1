param([Parameter(Mandatory=$true)][string]$Manifest,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$ManifestSha,[switch]$Run)
$ErrorActionPreference='Stop'
if(-not$Run){throw 'Prepared source only: -Run requires an authorized free-PC functional slot.'}
$fixtureManifest=[IO.Path]::GetFullPath($Manifest)
if((Get-FileHash -LiteralPath $fixtureManifest).Hash.ToLowerInvariant()-ne$ManifestSha){throw 'Explicit fixture manifest pin differs'}
$fixture=Get-Content -LiteralPath $fixtureManifest -Raw|ConvertFrom-Json
$fixtureRunner=@($fixture.pins|Where-Object file -EQ $PSCommandPath)
if($fixtureRunner.Count-ne1-or(Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()-ne$fixtureRunner[0].sha256){throw 'Frozen runner source differs'}
& node (Join-Path $PSScriptRoot 'verify.cjs') --phase=pre ('--manifest='+$fixtureManifest) ('--manifest-sha='+$ManifestSha)
if($LASTEXITCODE-ne0){throw 'Pre-execution frozen-input validation rejected'}
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
& node (Join-Path $PSScriptRoot 'verify.cjs') --phase=post ('--manifest='+$fixtureManifest) ('--manifest-sha='+$ManifestSha) ('--exit='+$fixtureProof.exit)
if($LASTEXITCODE-ne0){throw 'Actual full fixture acceptance rejected; outputs retained'}
