[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Plan,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$PlanSha,[ValidateSet('DryRun','Build')][string]$Phase='DryRun')
$ErrorActionPreference='Stop'
$nwnPlanFile=[IO.Path]::GetFullPath($Plan)
function Get-NwnHash([string]$File){return (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()}
if((Get-NwnHash $nwnPlanFile)-ne$PlanSha){throw 'Private build plan differs'}
$nwnPlan=Get-Content -LiteralPath $nwnPlanFile -Raw|ConvertFrom-Json
if($nwnPlan.schema-ne'nwn71-incremental-private-tracy-v1'){throw 'Wrong build plan'}
$nwnRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$nwnExpected=[IO.Path]::GetFullPath((Join-Path $nwnRoot '.cache/native-tracy/engine-msvc-a/source'))
if($nwnPlan.source-ne$nwnExpected){throw 'Only owned private Tracy scratch tree permitted'}
if(-not([IO.Path]::GetFullPath($nwnPlan.output).StartsWith((Join-Path $nwnRoot '.cache/nwn71')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase))){throw 'Output escaped private NWN71 area'}
foreach($nwnPin in @($nwnPlan.basePlan,$nwnPlan.python,$nwnPlan.runner)+@($nwnPlan.engineTrackedSources)+@($nwnPlan.protectedInputs)){if((Get-NwnHash $nwnPin.file)-ne$nwnPin.sha256){throw ('Pinned input differs: '+$nwnPin.file)}}
foreach($nwnPin in $nwnPlan.headerClosure){if((Get-NwnHash $nwnPin.file)-ne$nwnPin.sha256){throw ('Current header closure differs: '+$nwnPin.file)}}
foreach($nwnPin in $nwnPlan.generatedRestore){if((Get-NwnHash $nwnPin.file)-ne$nwnPin.sha256-or(Get-NwnHash $nwnPin.snapshot)-ne$nwnPin.sha256){throw 'Generated input snapshot differs'}}
foreach($nwnPin in $nwnPlan.profilingPrepopulate){if($nwnPin.file-ne(Join-Path $nwnPlan.source 'core/profiling/profiling.gen.h')-or(Get-NwnHash $nwnPin.file)-ne$nwnPin.beforeSha256-or(Get-NwnHash $nwnPin.reconstructedFile)-ne$nwnPin.sha256){throw 'Private profiling prepopulation pin differs'}}
$nwnMode=$Phase.ToLowerInvariant();$nwnReceiptFile=Join-Path $nwnPlan.output ($nwnMode+'-receipt.json')
if(Test-Path -LiteralPath $nwnReceiptFile){throw 'Preserve prior dry-run/build evidence'}
if($Phase-eq'Build'){
 $nwnDryFile=Join-Path $nwnPlan.output 'dryrun-receipt.json'
 $nwnDry=Get-Content -LiteralPath $nwnDryFile -Raw|ConvertFrom-Json
 if(-not$nwnDry.success-or$nwnDry.planSha256-ne$PlanSha-or-not$nwnDry.expectedOnly){throw 'Build requires accepted exact planned-TU dry-run'}
 if((Get-NwnHash (Join-Path $nwnPlan.output 'dryrun.stdout.log'))-ne$nwnDry.stdoutSha256){throw 'Dry-run log differs'}
}
$nwnSaved=@();foreach($nwnChange in $nwnPlan.changes){
 if((Get-NwnHash $nwnChange.file)-ne$nwnChange.beforeSha256-or(Get-NwnHash $nwnChange.afterFile)-ne$nwnChange.afterSha256){throw 'CPP overlay input differs'}
 $nwnSaved+=@{change=$nwnChange;bytes=[IO.File]::ReadAllBytes($nwnChange.file)}
}
$nwnEnvFile=Join-Path $nwnPlan.source '.scons_env.json';$nwnEnvBytes=if(Test-Path -LiteralPath $nwnEnvFile){[IO.File]::ReadAllBytes($nwnEnvFile)}else{$null}
$nwnArguments=[Collections.Generic.List[string]]::new();foreach($nwnArg in $nwnPlan.engineArguments){$nwnArguments.Add([string]$nwnArg)}
if($Phase-eq'DryRun'){$nwnArguments.Add('-n');$nwnArguments.Add('--debug=explain')}
$nwnStart=[Diagnostics.ProcessStartInfo]::new();$nwnStart.FileName=$nwnPlan.python.file;$nwnStart.WorkingDirectory=$nwnPlan.source;$nwnStart.UseShellExecute=$false;$nwnStart.CreateNoWindow=$true;$nwnStart.WindowStyle='Hidden';$nwnStart.RedirectStandardOutput=$true;$nwnStart.RedirectStandardError=$true;$nwnStart.Environment.Remove('NODE_OPTIONS')|Out-Null
foreach($nwnArg in $nwnArguments){$nwnStart.ArgumentList.Add($nwnArg)}
$nwnProcess=[Diagnostics.Process]::new();$nwnProcess.StartInfo=$nwnStart
$nwnProof=@{schema=$nwnPlan.schema;phase=$Phase;startedUtc=[DateTime]::UtcNow.ToString('o');planSha256=$PlanSha;arguments=@($nwnArguments);success=$false;expectedOnly=$false;exit=$null;pid=0;sourceRestored=$false;protectedUnchanged=$false;peakPrivateBytes=0L;peakWorkingSetBytes=0L;scope='Private diagnostic only; accepted/selected binary directories untouched. No clean/full rebuild permitted.'}
$nwnStdout=$null;$nwnStderr=$null
try{
 foreach($nwnRow in $nwnSaved){[IO.File]::WriteAllBytes($nwnRow.change.file,[IO.File]::ReadAllBytes($nwnRow.change.afterFile))}
 foreach($nwnPin in $nwnPlan.profilingPrepopulate){[IO.File]::WriteAllBytes($nwnPin.file,[IO.File]::ReadAllBytes($nwnPin.reconstructedFile))}
 if(-not$nwnProcess.Start()){throw 'Compiler driver failed to start'}
 $nwnProof.pid=$nwnProcess.Id;$nwnProof.creationUtc=$nwnProcess.StartTime.ToUniversalTime().ToString('o');$nwnStdout=$nwnProcess.StandardOutput.ReadToEndAsync();$nwnStderr=$nwnProcess.StandardError.ReadToEndAsync();$nwnWatch=[Diagnostics.Stopwatch]::StartNew()
 while(-not$nwnProcess.WaitForExit(1500)){
  if($nwnWatch.Elapsed.TotalSeconds-gt$nwnPlan.maxSeconds){throw 'Incremental build timeout; reject broad rebuild'}
  $nwnSnapshot=@(Get-CimInstance Win32_Process -Property ProcessId,ParentProcessId,PrivatePageCount,WorkingSetSize)
  $nwnOwned=[Collections.Generic.HashSet[uint32]]::new();[void]$nwnOwned.Add([uint32]$nwnProcess.Id)
  do{$nwnAdded=$false;foreach($nwnRecord in $nwnSnapshot){if($nwnOwned.Contains([uint32]$nwnRecord.ParentProcessId)-and$nwnOwned.Add([uint32]$nwnRecord.ProcessId)){$nwnAdded=$true}}}while($nwnAdded)
  $nwnPrivate=0L;$nwnWorking=0L;foreach($nwnRecord in $nwnSnapshot){if($nwnOwned.Contains([uint32]$nwnRecord.ProcessId)){$nwnPrivate+=[long]$nwnRecord.PrivatePageCount;$nwnWorking+=[long]$nwnRecord.WorkingSetSize}}
  $nwnProof.peakPrivateBytes=[Math]::Max($nwnProof.peakPrivateBytes,$nwnPrivate);$nwnProof.peakWorkingSetBytes=[Math]::Max($nwnProof.peakWorkingSetBytes,$nwnWorking)
  if($nwnPrivate-gt$nwnPlan.maxPrivateBytes-or$nwnWorking-gt$nwnPlan.maxWorkingSetBytes){throw 'Owned compiler tree exceeded8GB memory cap'}
 }
 $nwnProof.exit=$nwnProcess.ExitCode
 if($nwnProof.exit-ne0){throw ('SCons failed '+$nwnProof.exit)}
 $nwnText=$nwnStdout.GetAwaiter().GetResult();$nwnNormalized=$nwnText.Replace('\','/')
 $nwnCompiles=@([regex]::Matches($nwnNormalized,'(?m)^Compiling (.+?) \.\.\.\s*$')|ForEach-Object{$_.Groups[1].Value.Trim()})
 $nwnProof.compiles=$nwnCompiles
 $nwnExpectedCompiles=@($nwnPlan.expectedCompiles|Sort-Object);$nwnActualCompiles=@($nwnCompiles|Sort-Object)
 $nwnProof.expectedOnly=$nwnExpectedCompiles.Count-eq$nwnActualCompiles.Count-and@(Compare-Object $nwnExpectedCompiles $nwnActualCompiles).Count-eq0
 if(-not$nwnProof.expectedOnly){throw 'Unexpected compilation set; review dry-run before any build'}
 $nwnHeaderSnapshot=@();foreach($nwnPin in $nwnPlan.headerClosure){$nwnHeaderSnapshot+=@{file=$nwnPin.file;sha256=(Get-NwnHash $nwnPin.file)}}
 $nwnHeaderFile=Join-Path $nwnPlan.output ($nwnMode+'.header-inputs.json');$nwnHeaderSnapshot|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $nwnHeaderFile -Encoding utf8;$nwnProof.headerInputs=@{file=$nwnHeaderFile;sha256=(Get-NwnHash $nwnHeaderFile);count=$nwnHeaderSnapshot.Count;scope=$nwnPlan.headerScope}
 if($Phase-eq'Build'){
  $nwnBinary=Join-Path $nwnPlan.source $nwnPlan.target;$nwnSavedBinary=Join-Path $nwnPlan.output 'Godot_nwn71_group_labels_win64.exe';if(Test-Path -LiteralPath $nwnSavedBinary){throw 'Preserve existing private EXE'};Copy-Item -LiteralPath $nwnBinary -Destination $nwnSavedBinary
  $nwnPdb=Join-Path $nwnPlan.source 'bin/godot.windows.template_release.x86_64.pdb';$nwnSavedPdb=Join-Path $nwnPlan.output 'godot.windows.template_release.x86_64.pdb';if(Test-Path -LiteralPath $nwnSavedPdb){throw 'Preserve existing private PDB'};Copy-Item -LiteralPath $nwnPdb -Destination $nwnSavedPdb
  $nwnProof.binary=@{file=$nwnSavedBinary;sha256=(Get-NwnHash $nwnSavedBinary);bytes=(Get-Item -LiteralPath $nwnSavedBinary).Length};$nwnProof.symbols=@{file=$nwnSavedPdb;sha256=(Get-NwnHash $nwnSavedPdb);bytes=(Get-Item -LiteralPath $nwnSavedPdb).Length}
 }
 $nwnProof.success=$true
}catch{$nwnProof.failure=$_.Exception.Message;throw}finally{
 if($nwnProof.pid-and-not$nwnProcess.HasExited){$nwnProcess.Kill($true);[void]$nwnProcess.WaitForExit(10000);$nwnProof.forced=$true}
 $nwnRestore=$true;foreach($nwnRow in $nwnSaved){$nwnCurrent=Get-NwnHash $nwnRow.change.file;if($nwnCurrent-ne$nwnRow.change.afterSha256-and$nwnCurrent-ne$nwnRow.change.beforeSha256){$nwnRestore=$false;$nwnProof.restoreConflict=$nwnRow.change.file;continue};[IO.File]::WriteAllBytes($nwnRow.change.file,$nwnRow.bytes);if((Get-NwnHash $nwnRow.change.file)-ne$nwnRow.change.beforeSha256){$nwnRestore=$false}}
 foreach($nwnPin in $nwnPlan.generatedRestore){if((Get-NwnHash $nwnPin.snapshot)-ne$nwnPin.sha256){$nwnRestore=$false;continue};[IO.File]::WriteAllBytes($nwnPin.file,[IO.File]::ReadAllBytes($nwnPin.snapshot));if((Get-NwnHash $nwnPin.file)-ne$nwnPin.sha256){$nwnRestore=$false}}
 if($null-ne$nwnEnvBytes){[IO.File]::WriteAllBytes($nwnEnvFile,$nwnEnvBytes)}
 $nwnProof.sourceRestored=$nwnRestore;$nwnProof.protectedUnchanged=$true
 foreach($nwnPin in $nwnPlan.protectedInputs){if((Get-NwnHash $nwnPin.file)-ne$nwnPin.sha256){$nwnProof.protectedUnchanged=$false}}
 foreach($nwnPair in @(@($nwnStdout,'stdout.log'),@($nwnStderr,'stderr.log'))){if($nwnPair[0]-and$nwnPair[0].Wait(10000)){[IO.File]::WriteAllText((Join-Path $nwnPlan.output ($nwnMode+'.'+$nwnPair[1])),$nwnPair[0].GetAwaiter().GetResult())}}
 $nwnLog=Join-Path $nwnPlan.output ($nwnMode+'.stdout.log');if(Test-Path -LiteralPath $nwnLog){$nwnProof.stdoutSha256=Get-NwnHash $nwnLog}
 $nwnProof.success=$nwnProof.success-and$nwnRestore-and$nwnProof.protectedUnchanged;$nwnProof.finishedUtc=[DateTime]::UtcNow.ToString('o');$nwnProof|ConvertTo-Json -Depth 9|Set-Content -LiteralPath $nwnReceiptFile -Encoding utf8;$nwnProcess.Dispose()
}
$nwnProof|ConvertTo-Json -Depth 6
