param([Parameter(Mandatory=$true)][string]$Plan)
$ErrorActionPreference='Stop'
$vmPlan=Get-Content -LiteralPath $Plan -Raw|ConvertFrom-Json
foreach($vmPin in @(@{file=$vmPlan.invocationFile;sha=$vmPlan.invocationSha256},@{file=$vmPlan.compiler;sha=$vmPlan.compilerSha256},@{file=$vmPlan.python;sha=$vmPlan.pythonSha256},@{file=$vmPlan.profile;sha=$vmPlan.profileSha256},@{file=$vmPlan.object;sha=$vmPlan.objectSha256},@{file=$vmPlan.archive;sha=$vmPlan.archiveSha256},@{file=$vmPlan.sourceFile;sha=$vmPlan.sourceSha256})){if((Get-FileHash -LiteralPath $vmPin.file).Hash.ToLowerInvariant()-ne$vmPin.sha){throw 'VM capture input drift'}}
if(Test-Path -LiteralPath $vmPlan.commandFile){throw 'Preserve captured command'}
$vmStart=[Diagnostics.ProcessStartInfo]::new();$vmStart.FileName=$vmPlan.python;$vmStart.WorkingDirectory=$vmPlan.source;$vmStart.UseShellExecute=$false;$vmStart.CreateNoWindow=$true;$vmStart.RedirectStandardOutput=$true;$vmStart.RedirectStandardError=$true
$vmStart.Environment['PATH']=(Split-Path -Parent $vmPlan.compiler)+';'+$env:PATH
foreach($vmArgument in $vmPlan.arguments){$vmStart.ArgumentList.Add($vmArgument)}
$vmChild=[Diagnostics.Process]::new();$vmChild.StartInfo=$vmStart;[void]$vmChild.Start();$vmPid=$vmChild.Id;$vmOut=$vmChild.StandardOutput.ReadToEndAsync();$vmError=$vmChild.StandardError.ReadToEndAsync();Write-Output ('Started metadata-only SCons executor capture PID '+$vmPid)
if(-not$vmChild.WaitForExit(30000)){$vmChild.Kill($true);[void]$vmChild.WaitForExit(1000);throw 'Metadata capture timeout'}
$vmCode=$vmChild.ExitCode;$vmText=$vmOut.GetAwaiter().GetResult();$vmStderr=$vmError.GetAwaiter().GetResult();$vmChild.Dispose()
[IO.File]::WriteAllText((Join-Path $vmPlan.out 'capture.stdout.log'),$vmText);[IO.File]::WriteAllText((Join-Path $vmPlan.out 'capture.stderr.log'),$vmStderr)
if($vmCode-ne0){throw ('Metadata capture failed '+$vmStderr)}
if(-not(Test-Path -LiteralPath $vmPlan.commandFile)){throw 'No executor capture produced'}
foreach($vmPin in @(@{file=$vmPlan.object;sha=$vmPlan.objectSha256},@{file=$vmPlan.archive;sha=$vmPlan.archiveSha256},@{file=$vmPlan.sourceFile;sha=$vmPlan.sourceSha256})){if((Get-FileHash -LiteralPath $vmPin.file).Hash.ToLowerInvariant()-ne$vmPin.sha){throw 'Original VM object/archive/source changed during metadata capture'}}
@{version=1;success=$true;exit=$vmCode;pid=$vmPid;planSha256=(Get-FileHash -LiteralPath $Plan).Hash.ToLowerInvariant();commandSha256=(Get-FileHash -LiteralPath $vmPlan.commandFile).Hash.ToLowerInvariant();originalInputsUnchanged=$true;scope='Metadata-only SCons --dry-run plus post-read executor expansion. No compile, archive or link action executed.'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $vmPlan.out 'capture-receipt.json') -Encoding utf8
Write-Output 'Exact VM compiler argument capture closed.'
