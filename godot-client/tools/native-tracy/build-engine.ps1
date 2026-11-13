[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Plan,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$PlanSha,[switch]$Build)
$ErrorActionPreference='Stop'
$tracyPlanFile=[IO.Path]::GetFullPath($Plan)
if((Get-FileHash -LiteralPath $tracyPlanFile).Hash.ToLowerInvariant()-ne$PlanSha){throw 'Private build plan changed'}
$tracyPlan=Get-Content -LiteralPath $tracyPlanFile -Raw|ConvertFrom-Json
if($tracyPlan.kind-ne'private-source-equivalent-d-tracy-build'){throw 'Unexpected private plan'}
$tracyExpectedRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../.cache/native-tracy'))+[IO.Path]::DirectorySeparatorChar
if(-not$tracyPlan.source.StartsWith($tracyExpectedRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Build source outside private Tracy workspace'}
function Assert-TracyInputs{
 foreach($tracyPin in @($tracyPlan.engineTrackedSources)+@($tracyPlan.python)){
  if((Get-FileHash -LiteralPath $tracyPin.file).Hash.ToLowerInvariant()-ne$tracyPin.sha256){throw ('Changed private input '+$tracyPin.file)}
 }
}
Assert-TracyInputs
if(-not$Build){[pscustomobject]@{ready=$true;arguments=$tracyPlan.engineArguments;compiled=$false}|ConvertTo-Json -Depth 4;return}
if(Test-Path -LiteralPath $tracyPlan.output){throw 'Preserve previous compiler output'}
New-Item -ItemType Directory -Path $tracyPlan.output|Out-Null
$tracyOut=$tracyPlan.output
$tracyStart=[Diagnostics.ProcessStartInfo]::new();$tracyStart.FileName=$tracyPlan.python.file;$tracyStart.WorkingDirectory=$tracyPlan.source;$tracyStart.UseShellExecute=$false;$tracyStart.CreateNoWindow=$true;$tracyStart.WindowStyle='Hidden';$tracyStart.RedirectStandardOutput=$true;$tracyStart.RedirectStandardError=$true
foreach($tracyArgument in $tracyPlan.engineArguments){$tracyStart.ArgumentList.Add([string]$tracyArgument)}
$tracyStart.Environment.Remove('NODE_OPTIONS')|Out-Null
$tracyProcess=[Diagnostics.Process]::new();$tracyProcess.StartInfo=$tracyStart
$tracyProof=@{version=1;plan=$tracyPlanFile;planSha256=$PlanSha;arguments=$tracyPlan.engineArguments;startedUtc=[DateTime]::UtcNow.ToString('o');pid=0;exit=$null;success=$false;forced=$false;normalRuntimeChanged=$false;scope=$tracyPlan.scope}
$tracyStdout=$null;$tracyStderr=$null
try{
 if(-not$tracyProcess.Start()){throw 'Private compiler driver failed to start'}
 $tracyProof.pid=$tracyProcess.Id;$tracyProof.creationFileTimeUtc=$tracyProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()
 $tracyStdout=$tracyProcess.StandardOutput.ReadToEndAsync();$tracyStderr=$tracyProcess.StandardError.ReadToEndAsync()
 $tracyProof|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $tracyOut 'process.json') -Encoding utf8
 $tracyWatch=[Diagnostics.Stopwatch]::StartNew()
 while(-not$tracyProcess.WaitForExit(1000)){
  if($tracyWatch.Elapsed.TotalMinutes-gt60){throw 'Private engine build exceeded60minutes'}
  @{pid=$tracyProcess.Id;elapsedSeconds=[Math]::Round($tracyWatch.Elapsed.TotalSeconds,1);updatedUtc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $tracyOut 'progress.json') -Encoding utf8
 }
 $tracyProof.exit=$tracyProcess.ExitCode
 if($tracyProof.exit-ne0){throw ('Private engine compilation failed '+$tracyProof.exit)}
 Assert-TracyInputs
 $tracyBinary=Join-Path $tracyPlan.source 'bin/godot.windows.template_release.x86_64.exe'
 if(-not(Test-Path -LiteralPath $tracyBinary)){throw 'Compiler did not emit expected release engine'}
 $tracySavedBinary=Join-Path $tracyOut 'Godot_native_d_tracy_win64.exe';Copy-Item -LiteralPath $tracyBinary -Destination $tracySavedBinary
 $tracyPdbs=@(Get-ChildItem -LiteralPath (Join-Path $tracyPlan.source 'bin') -Filter '*.pdb' -File)
 if($tracyPdbs.Count-lt1){throw 'Diagnostic engine lacks expected Windows symbols'}
 $tracyProof.symbols=@();foreach($tracyPdb in $tracyPdbs){$tracySavedPdb=Join-Path $tracyOut $tracyPdb.Name;Copy-Item -LiteralPath $tracyPdb.FullName -Destination $tracySavedPdb;$tracyProof.symbols+=@{file=$tracySavedPdb;sha256=(Get-FileHash -LiteralPath $tracySavedPdb).Hash.ToLowerInvariant();bytes=$tracyPdb.Length}}
 $tracyProof.binary=@{file=$tracySavedBinary;sha256=(Get-FileHash -LiteralPath $tracySavedBinary).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $tracySavedBinary).Length};$tracyProof.success=$true
}catch{$tracyProof.failure=$_.Exception.Message;throw}finally{
 if($tracyProof.pid-and-not$tracyProcess.HasExited){if($tracyProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString()-eq$tracyProof.creationFileTimeUtc){$tracyProcess.Kill($true);[void]$tracyProcess.WaitForExit(5000);$tracyProof.forced=$true}}
 foreach($tracyPair in @(@($tracyStdout,'stdout.log'),@($tracyStderr,'stderr.log'))){$tracyTask=$tracyPair[0];if($tracyTask-and$tracyTask.Wait(5000)){[IO.File]::WriteAllText((Join-Path $tracyOut $tracyPair[1]),$tracyTask.GetAwaiter().GetResult())}}
 $tracyProof.finishedUtc=[DateTime]::UtcNow.ToString('o');$tracyProof|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $tracyOut 'receipt.json') -Encoding utf8;$tracyProcess.Dispose()
}
$tracyProof|ConvertTo-Json -Depth 6
