[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('control','candidate')][string]$Mode)
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$scope=Join-Path $project '.cache/nwn74'
$source=Join-Path $scope 'engine-source-f-control'
$output=Join-Path $scope "engine-build-f-$Mode"
$dryLog=Join-Path $scope $(if($Mode -eq 'control'){'control-f-dryrun.log'}else{'candidate-f-dryrun.log'})
$forward=Join-Path $source 'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp'
$binary=Join-Path $source 'bin/godot.windows.template_release.x86_64.exe'
$accepted=Join-Path $project '.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe'
$acceptedForward=Join-Path $project '.cache/native-tracy/engine-msvc-a/source/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp'
$control=Join-Path $scope 'engine-build-f-control/Godot_nwn74_accepted_source_control_f_win64.exe'
$python=Join-Path $project '.cache/native-140fps/render-agent/engine-build-tools-v1/python/python.exe'
$tracy=Join-Path $project '.cache/native-tracy/vendor/tracy-0.13.0'
function Hash([string]$file){(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
if(Test-Path -LiteralPath $output){throw 'Preserve existing private build output'}
if((Get-PSDrive C).Free -lt 21GB){throw 'Preflight disk floor is below 21 GiB'}
if((Hash $accepted) -ne '0a2710bd80c0a2cbfeca8ac28338a071561ba741c52a01857df233d69efe02d1'){throw 'Accepted binary changed'}
if((Hash $acceptedForward) -ne 'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd'){throw 'Accepted source patch changed'}
$expectedForward=if($Mode -eq 'control'){'49fc6ca310573c5a0704e5a6d9dfa4cf769b37d756239f7e49aa9502d1d97705'}else{'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd'}
if((Hash $forward) -ne $expectedForward){throw 'Private Forward+ source differs'}
if($Mode -eq 'candidate'){
 $controlReceipt=Get-Content -LiteralPath (Join-Path $scope 'engine-build-f-control/receipt.json') -Raw | ConvertFrom-Json
 if(-not $controlReceipt.success -or (Hash $control) -ne $controlReceipt.binary.sha256){throw 'Private control differs'}
}
$planned=@([regex]::Matches((Get-Content -LiteralPath $dryLog -Raw).Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$') | ForEach-Object {$_.Groups[1].Value.Trim()})
$expectedCount=if($Mode -eq 'control'){25}else{1}
if($planned.Count -ne $expectedCount -or -not ($planned -contains 'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp')){throw 'Dry-run compile scope differs'}
if($Mode -eq 'candidate' -and $planned[0] -ne 'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp'){throw 'Candidate must recompile only Forward+'}
New-Item -ItemType Directory -Path $output | Out-Null
$sourcePins=@();foreach($relative in $planned){$sourcePins += [ordered]@{relative=$relative;sha256=Hash (Join-Path $source $relative)}}
$args=@('-m','SCons','platform=windows','target=template_release','arch=x86_64','use_mingw=no','msvc_version=14.5','disable_path_overrides=no','d3d12=no','debug_symbols=yes','optimize=speed','lto=none','profiler=tracy',"profiler_path=$tracy",'profiler_sample_callstack=no','profiler_track_memory=no','profiler_record_on_demand=yes','-j','2','bin/godot.windows.template_release.x86_64.exe')
$receipt=[ordered]@{issue='NWN-74';mode=$Mode;scope='Private same-source engine pair; accepted executable untouched';startUtc=[DateTime]::UtcNow.ToString('o');source=$source;output=$output;arguments=$args;plannedCompiles=$planned;dryRunSha256=Hash $dryLog;forwardSha256=$expectedForward;sourcePins=$sourcePins;acceptedBefore=Hash $accepted;acceptedSourceBefore=Hash $acceptedForward;cloneBinaryBefore=Hash $binary;controlBefore=if($Mode -eq 'candidate'){Hash $control}else{$null};peakPrivateBytes=0L;peakWorkingSetBytes=0L;minFreeBytes=[long](Get-PSDrive C).Free;success=$false}
$start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$python;$start.WorkingDirectory=$source;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.Environment.Remove('NODE_OPTIONS') | Out-Null
foreach($arg in $args){[void]$start.ArgumentList.Add($arg)}
$process=[Diagnostics.Process]::new();$process.StartInfo=$start;$stdout=$null;$stderr=$null
try{
 if(-not $process.Start()){throw 'SCons did not start'}
 $receipt.pid=$process.Id;$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();$watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $process.WaitForExit(3000)){
  if($watch.Elapsed.TotalSeconds -gt 1200){throw 'Build exceeded 20-minute watchdog'}
  $rows=@(Get-Process -Name python,cl,c1xx,c2,link,lib -ErrorAction SilentlyContinue)
  if(-not @($rows | Where-Object {$_.Id -eq $process.Id}).Count){throw 'SCons process disappeared'}
  $private=0L;$working=0L;foreach($row in $rows){$private += [long]$row.PrivateMemorySize64;$working += [long]$row.WorkingSet64}
  $receipt.peakPrivateBytes=[Math]::Max($receipt.peakPrivateBytes,$private);$receipt.peakWorkingSetBytes=[Math]::Max($receipt.peakWorkingSetBytes,$working)
  if($private -gt 8GB -or $working -gt 8GB){throw 'Compiler memory exceeded 8 GiB'}
  $free=[long](Get-PSDrive C).Free;$receipt.minFreeBytes=[Math]::Min($receipt.minFreeBytes,$free)
  if($free -lt 20GB){throw 'Disk free below 20 GiB'}
 }
 $receipt.exit=$process.ExitCode;if($receipt.exit -ne 0){throw "SCons exited $($receipt.exit)"}
 $actual=@([regex]::Matches($stdout.GetAwaiter().GetResult().Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$') | ForEach-Object {$_.Groups[1].Value.Trim()})
 $receipt.actualCompiles=$actual;if($actual.Count -ne $planned.Count -or @(Compare-Object $planned $actual).Count -ne 0){throw 'Actual compile set differs from dry run'}
 $saved=Join-Path $output $(if($Mode -eq 'control'){'Godot_nwn74_accepted_source_control_f_win64.exe'}else{'Godot_nwn74_accepted_source_candidate_f_win64.exe'})
 Copy-Item -LiteralPath $binary -Destination $saved
 $receipt.binary=[ordered]@{file=$saved;sha256=Hash $saved;bytes=(Get-Item -LiteralPath $saved).Length}
 $receipt.success=$true
}catch{$receipt.failure=$_.Exception.Message}
finally{
 if($receipt.pid -and -not $process.HasExited){$process.Kill($true);[void]$process.WaitForExit(10000);$receipt.forced=$true}
 if($stdout){[IO.File]::WriteAllText((Join-Path $output 'build.stdout.log'),$stdout.GetAwaiter().GetResult())}
 if($stderr){[IO.File]::WriteAllText((Join-Path $output 'build.stderr.log'),$stderr.GetAwaiter().GetResult())}
 $receipt.acceptedAfter=Hash $accepted;$receipt.acceptedSourceAfter=Hash $acceptedForward;$receipt.forwardAfter=Hash $forward
 $receipt.controlAfter=if($Mode -eq 'candidate'){Hash $control}else{$null}
 $receipt.sourcePinsUnchanged=@($sourcePins | Where-Object {$_.sha256 -ne (Hash (Join-Path $source $_.relative))}).Count -eq 0
 $receipt.success=$receipt.success -and $receipt.acceptedBefore -eq $receipt.acceptedAfter -and $receipt.acceptedSourceBefore -eq $receipt.acceptedSourceAfter -and $receipt.forwardSha256 -eq $receipt.forwardAfter -and $receipt.sourcePinsUnchanged -and ($Mode -eq 'control' -or $receipt.controlBefore -eq $receipt.controlAfter)
 $receipt.freeAfterBytes=[long](Get-PSDrive C).Free;$receipt.endUtc=[DateTime]::UtcNow.ToString('o')
 $receipt | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $output 'receipt.json') -Encoding utf8;$process.Dispose()
}
$receipt | ConvertTo-Json -Depth 4
if(-not $receipt.success){exit 1}
