[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$scope=Join-Path $project '.cache/nwn74'
$source=Join-Path $scope 'engine-source-f-control'
$output=Join-Path $scope 'engine-build-i-cache'
$dryLog=Join-Path $scope 'vertex-cache-i-dryrun.log'
$forward=Join-Path $source 'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp'
$binary=Join-Path $source 'bin/godot.windows.template_release.x86_64.exe'
$accepted=Join-Path $project '.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe'
$guard=Join-Path $scope 'engine-build-f-candidate/Godot_nwn74_accepted_source_candidate_f_win64.exe'
$python=Join-Path $project '.cache/native-140fps/render-agent/engine-build-tools-v1/python/python.exe'
$tracy=Join-Path $project '.cache/native-tracy/vendor/tracy-0.13.0'
function Hash([string]$file){(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
if(Test-Path -LiteralPath $output){throw 'Preserve prior private output'}
if((Get-PSDrive C).Free -lt 20.5GB){throw 'Disk headroom too low'}
$planned=@([regex]::Matches((Get-Content -LiteralPath $dryLog -Raw).Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$') | ForEach-Object {$_.Groups[1].Value.Trim()})
if($planned.Count -ne 1 -or $planned[0] -ne 'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp'){throw 'Dry-run scope differs'}
$pins=[ordered]@{source=Hash $forward;accepted=Hash $accepted;guard=Hash $guard;guardSource=Hash (Join-Path $scope 'engine-build-f-candidate/source-forward.cpp')}
if($pins.source -ne '05b7e8379000b331fbb26dedc9577b594eca7d09d7ea7872cbc54078b3837e74' -or $pins.accepted -ne '0a2710bd80c0a2cbfeca8ac28338a071561ba741c52a01857df233d69efe02d1' -or $pins.guard -ne '52d8c4f85e126c28de5d321119b3a67310ec121a307a9c6e83802a529a6a7af3' -or $pins.guardSource -ne 'fe8b102c6742d12f8a51a7312bfa8b72596277ee7d2f429fce5c97d6e03846dd'){throw 'Private/accepted identity differs'}
New-Item -ItemType Directory -Path $output | Out-Null
$args=@('-m','SCons','platform=windows','target=template_release','arch=x86_64','use_mingw=no','msvc_version=14.5','disable_path_overrides=no','d3d12=no','debug_symbols=yes','optimize=speed','lto=none','profiler=tracy',"profiler_path=$tracy",'profiler_sample_callstack=no','profiler_track_memory=no','profiler_record_on_demand=yes','-j','2','bin/godot.windows.template_release.x86_64.exe')
$receipt=[ordered]@{issue='NWN-74';scope='Private opt-in per-frame static vertex-array cache; dynamic meshes unchanged';startUtc=[DateTime]::UtcNow.ToString('o');source=$source;output=$output;arguments=$args;plannedCompiles=$planned;dryRunSha256=Hash $dryLog;pins=$pins;peakPrivateBytes=0L;peakWorkingSetBytes=0L;minFreeBytes=[long](Get-PSDrive C).Free;success=$false}
$start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$python;$start.WorkingDirectory=$source;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.Environment.Remove('NODE_OPTIONS') | Out-Null
foreach($arg in $args){[void]$start.ArgumentList.Add($arg)}
$process=[Diagnostics.Process]::new();$process.StartInfo=$start;$stdout=$null;$stderr=$null
try{
 if(-not $process.Start()){throw 'SCons did not start'}
 $receipt.pid=$process.Id;$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();$watch=[Diagnostics.Stopwatch]::StartNew()
 while(-not $process.WaitForExit(3000)){
  if($watch.Elapsed.TotalSeconds -gt 900){throw 'Build exceeded 15-minute watchdog'}
  $rows=@(Get-Process -Name python,cl,c1xx,c2,link,lib -ErrorAction SilentlyContinue)
  if(-not @($rows | Where-Object {$_.Id -eq $process.Id}).Count){throw 'SCons disappeared'}
  $private=0L;$working=0L;foreach($row in $rows){$private += [long]$row.PrivateMemorySize64;$working += [long]$row.WorkingSet64}
  $receipt.peakPrivateBytes=[Math]::Max($receipt.peakPrivateBytes,$private);$receipt.peakWorkingSetBytes=[Math]::Max($receipt.peakWorkingSetBytes,$working)
  if($private -gt 8GB -or $working -gt 8GB){throw 'Compiler memory exceeded 8 GiB'}
  $free=[long](Get-PSDrive C).Free;$receipt.minFreeBytes=[Math]::Min($receipt.minFreeBytes,$free)
  if($free -lt 20GB){throw 'Disk free below 20 GiB'}
 }
 $receipt.exit=$process.ExitCode;if($receipt.exit -ne 0){throw "SCons exited $($receipt.exit)"}
 $actual=@([regex]::Matches($stdout.GetAwaiter().GetResult().Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$') | ForEach-Object {$_.Groups[1].Value.Trim()})
 $receipt.actualCompiles=$actual;if($actual.Count -ne 1 -or $actual[0] -ne $planned[0]){throw 'Actual compile set differs'}
 $saved=Join-Path $output 'Godot_nwn74_vertex_cache_i_win64.exe';Copy-Item -LiteralPath $binary -Destination $saved
 $receipt.binary=[ordered]@{file=$saved;sha256=Hash $saved;bytes=(Get-Item -LiteralPath $saved).Length};$receipt.success=$true
}catch{$receipt.failure=$_.Exception.Message}
finally{
 if($receipt.pid -and -not $process.HasExited){$process.Kill($true);[void]$process.WaitForExit(10000);$receipt.forced=$true}
 if($stdout){[IO.File]::WriteAllText((Join-Path $output 'build.stdout.log'),$stdout.GetAwaiter().GetResult())}
 if($stderr){[IO.File]::WriteAllText((Join-Path $output 'build.stderr.log'),$stderr.GetAwaiter().GetResult())}
 $receipt.sourceUnchanged=$pins.source -eq (Hash $forward);$receipt.acceptedUnchanged=$pins.accepted -eq (Hash $accepted);$receipt.guardUnchanged=$pins.guard -eq (Hash $guard)
 $receipt.success=$receipt.success -and $receipt.sourceUnchanged -and $receipt.acceptedUnchanged -and $receipt.guardUnchanged
 $receipt.freeAfterBytes=[long](Get-PSDrive C).Free;$receipt.endUtc=[DateTime]::UtcNow.ToString('o')
 $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'receipt.json') -Encoding utf8;$process.Dispose()
}
$receipt | ConvertTo-Json -Depth 4
if(-not $receipt.success){exit 1}


