[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$Plan,
 [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$ReviewedPlanSha,
 [Parameter(Mandatory)][ValidateSet('control','candidate')][string]$Variant,
 [Parameter(Mandatory)][ValidatePattern('^native-production-local-[a-z0-9-]{1,48}$')][string]$Run,
 [ValidateRange(60,600)][int]$TimeoutSeconds=300,
 [switch]$Execute
)
$ErrorActionPreference='Stop'
if(-not $Execute){throw 'Preparation only. Root must review the plan/server identity and authorize -Execute; no client or server was started.'}
$planFile=[IO.Path]::GetFullPath($Plan)
if((Get-FileHash -LiteralPath $planFile -Algorithm SHA256).Hash.ToLowerInvariant()-cne$ReviewedPlanSha){throw 'Reviewed plan SHA differs; nothing launched'}
$inputPlan=Get-Content -LiteralPath $planFile -Raw|ConvertFrom-Json -AsHashtable
$checker=Join-Path $PSScriptRoot 'check_production_local.cjs'
$node=$inputPlan.runtimes.node.file
if((Get-FileHash -LiteralPath $node -Algorithm SHA256).Hash.ToLowerInvariant()-cne$inputPlan.runtimes.node.sha256){throw 'Pinned Node differs'}
& $node $checker verify ('--plan='+$planFile) ('--plan-sha='+$ReviewedPlanSha)
if($LASTEXITCODE-ne0){throw 'Source/runtime preflight failed; nothing launched'}
function Assert-ExistingServer {
 $facts=$inputPlan.server
 $process=Get-CimInstance Win32_Process -Filter ('ProcessId = '+$facts.pid)
 if(-not$process-or$process.Name-ne'nwserver.exe'-or[IO.Path]::GetFullPath($process.ExecutablePath)-ne[IO.Path]::GetFullPath($facts.executable)){throw 'Original local server identity differs; preserved'}
 $created=([DateTimeOffset]$process.CreationDate).ToUniversalTime()
 if($created.Ticks-ne[long]$facts.creationUtcTicks){throw 'Original local server creation ticks differ; preserved'}
 if(-not$process.CommandLine-or$process.CommandLine.IndexOf([string]$facts.home,[StringComparison]::OrdinalIgnoreCase)-lt0-or$process.CommandLine-notmatch'(?i)-publicserver\s+0(?:\s|$)'){throw 'Original local home/nonpublic command-line binding differs; preserved'}
 $endpoints=Get-NetUDPEndpoint -LocalPort 5122 -ErrorAction Stop
 if(-not@($endpoints|Where-Object OwningProcess -eq $facts.pid).Count){throw 'Original local server does not own UDP5122; preserved'}
 foreach($row in @(@{file=$facts.executable;sha256=$facts.sha256},@{file=$facts.moduleFile;sha256=$facts.moduleSha256},$inputPlan.serverSettings)){
  if((Get-FileHash -LiteralPath $row.file -Algorithm SHA256).Hash.ToLowerInvariant()-cne$row.sha256){throw 'Existing original server/module/settings bytes changed; preserved'}
 }
 $stream=[IO.File]::Open((Join-Path $facts.home 'logs/nwengineLog.txt'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
 try{$reader=[IO.StreamReader]::new($stream);$text=$reader.ReadToEnd();if(-not$text.Contains('Loading Module: BaseReuse2')){throw 'Existing server loaded module differs'}}finally{if($reader){$reader.Dispose()}else{$stream.Dispose()};$text=$null}
 return @{pid=$facts.pid;port=5122;creationUtcTicks=[string]$facts.creationUtcTicks;executableMatch=$true;homeMatch=$true;nonpublic=$true;udpOwnerMatch=$true;moduleMatch=$true;settingsMatch=$true}
}
$before=Assert-ExistingServer
$runDirectory=[IO.Path]::GetFullPath((Join-Path $inputPlan.stage ('runs/'+$Run)))
if(-not$runDirectory.StartsWith([IO.Path]::GetFullPath($inputPlan.stage)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-or(Test-Path -LiteralPath $runDirectory)){throw 'Fresh run directory inside reviewed stage required'}
foreach($relative in @('client','host-settings','godot-appdata','godot-localappdata','prepared','reports')){New-Item -ItemType Directory -Path (Join-Path $runDirectory $relative)|Out-Null}
@{version=1;planSha256=$ReviewedPlanSha;variant=$Variant;run=$Run;authentication='saved-protected-broker';serverPid=$inputPlan.server.pid;headless=$true}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $runDirectory 'intent.json') -Encoding utf8
$owner=@{version=1;planSha256=$ReviewedPlanSha;variant=$Variant;run=$Run;authentication='saved-protected-broker';headless=$true;serverStarts=0;processesStopped=0;builds=0;sourceUnchanged=$false;serverPreserved=$false;beforeServer=$before;closed=$false;timedOut=$false;performanceAccepted=$false;visualAccepted=$false}
$child=$null;$outputStream=$null;$errorStream=$null;$phase='broker-start'
try{
 $bootstrap=($inputPlan.wrappers|Where-Object kind -eq 'bootstrap').wrapper.file
 $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$inputPlan.runtimes.electron.file;$start.WorkingDirectory=$inputPlan.workspace;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
 $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 foreach($argument in @($bootstrap,('--run='+$Run))+@($inputPlan.variants[$Variant])){$start.ArgumentList.Add([string]$argument)}
 $start.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
 foreach($name in @($start.Environment.Keys|Where-Object{$_-like'NWN_*'})){$start.Environment.Remove($name)|Out-Null}
 # Original Electron APPDATA/safeStorage context remains unchanged. Only the
 # native child receives isolated APPDATA through the reviewed host wrapper.
 $start.Environment['NWN_LOCAL_HARNESS_PLAN_SHA']=$ReviewedPlanSha
 $start.Environment['NWN_LOCAL_HARNESS_VARIANT']=$Variant
 $start.Environment['NWN_LOCAL_HARNESS_RUN']=$Run
 $start.Environment['NWN_DO_NOT_NAT_PUNCH']='1'
 $start.Environment['NWN_PARTICLE_KERNEL']='compiled'
 $outputStream=[IO.File]::Open((Join-Path $runDirectory 'broker.stdout.log'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
 $errorStream=[IO.File]::Open((Join-Path $runDirectory 'broker.stderr.log'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
 $child=[Diagnostics.Process]::Start($start);$owner.brokerPid=$child.Id;$owner.started=$true
 $stdout=$child.StandardOutput.BaseStream.CopyToAsync($outputStream);$stderr=$child.StandardError.BaseStream.CopyToAsync($errorStream)
 $phase='bounded-original-local-session';$deadline=[DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
 while(-not$child.HasExited-and[DateTime]::UtcNow-lt$deadline){Start-Sleep -Milliseconds 250}
 $owner.closed=$child.HasExited;$owner.timedOut=-not$child.HasExited
 if($child.HasExited){$stdout.GetAwaiter().GetResult();$stderr.GetAwaiter().GetResult();$owner.exit=$child.ExitCode}else{$owner.failure='Owned client exceeded the bound; no process was stopped'}
 $phase='source-after-fence'
 & $node $checker verify ('--plan='+$planFile) ('--plan-sha='+$ReviewedPlanSha)
 $owner.sourceUnchanged=$LASTEXITCODE-eq0
 $phase='server-after-fence';$owner.afterServer=Assert-ExistingServer;$owner.serverPreserved=$true
}catch{$owner.failure='Authoritative local phase failed: '+$phase;$owner.failureType=$_.Exception.GetType().Name}
finally{
 if($child-and$child.HasExited){if($outputStream){$outputStream.Dispose()};if($errorStream){$errorStream.Dispose()}}
 $owner|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $runDirectory 'owner.json') -Encoding utf8
}
if(-not$owner.closed-or$owner.timedOut-or$owner.exit-ne0-or-not$owner.sourceUnchanged-or-not$owner.serverPreserved){throw 'Owned authoritative local run did not pass; receipts/processes preserved'}
& $node $checker analyze ('--plan='+$planFile) ('--plan-sha='+$ReviewedPlanSha) ('--run='+$Run)
if($LASTEXITCODE-ne0){throw 'Original local functional/owner analysis did not pass'}
