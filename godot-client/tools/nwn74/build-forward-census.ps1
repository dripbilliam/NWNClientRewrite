[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$scope = Join-Path $project '.cache/nwn74'
$source = Join-Path $scope 'engine-source-b'
$output = Join-Path $scope 'engine-build-d'
$dryLog = Join-Path $scope 'forward-census-b-dryrun.log'
$python = Join-Path $project '.cache/native-140fps/render-agent/engine-build-tools-v1/python/python.exe'
$tracy = Join-Path $project '.cache/native-tracy/vendor/tracy-0.13.0'
$binary = Join-Path $source 'bin/godot.windows.template_release.x86_64.exe'
$accepted = Join-Path $project '.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe'
$prior = Join-Path $scope 'engine-build-c/Godot_nwn74_pair_index_c_win64.exe'
function Hash([string]$file) { (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() }
$expected = @(
 'modules/nwn_frame_probe/frame_probe.cpp',
 'modules/nwn_frame_probe/register_types.cpp',
 'scene/3d/skeleton_3d.cpp',
 'servers/rendering/renderer_scene_cull.cpp',
 'servers/rendering/rendering_light_culler.cpp',
 'servers/rendering/rendering_server_default.cpp',
 'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp',
 'servers/rendering/renderer_rd/storage_rd/light_storage.cpp',
 'servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp',
 'servers/rendering/renderer_rd/storage_rd/utilities.cpp'
)
$dry = Get-Content -LiteralPath $dryLog -Raw
$planned = @([regex]::Matches($dry.Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$') | ForEach-Object { $_.Groups[1].Value.Trim() })
if ($planned.Count -ne $expected.Count -or @(Compare-Object $expected $planned).Count -ne 0) { throw 'Dry-run compile scope changed' }
if ((Get-PSDrive C).Free -lt 22GB) { throw 'Disk headroom below 22 GiB preflight' }
if (Test-Path -LiteralPath $output) { throw 'Private build output already exists' }
New-Item -ItemType Directory -Path $output | Out-Null
$pins = [ordered]@{
 accepted = Hash $accepted
 prior = Hash $prior
 forward = Hash (Join-Path $source 'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp')
 header = Hash (Join-Path $source 'modules/nwn_frame_probe/frame_probe.h')
 probe = Hash (Join-Path $source 'modules/nwn_frame_probe/frame_probe.cpp')
 originalForward = Hash (Join-Path $scope 'engine-source-a/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp')
}
$arguments = @('-m','SCons','platform=windows','target=template_release','arch=x86_64','use_mingw=no','msvc_version=14.5','disable_path_overrides=no','d3d12=no','debug_symbols=yes','optimize=speed','lto=none','profiler=tracy',"profiler_path=$tracy",'profiler_sample_callstack=no','profiler_track_memory=no','profiler_record_on_demand=yes','-j','2','bin/godot.windows.template_release.x86_64.exe')
$receipt = [ordered]@{ issue='NWN-74'; scope='Isolated Forward+ draw census; no accepted engine/source edit'; startUtc=[DateTime]::UtcNow.ToString('o'); source=$source; output=$output; arguments=$arguments; plannedCompiles=$planned; dryRunSha256=Hash $dryLog; pins=$pins; peakPrivateBytes=0L; peakWorkingSetBytes=0L; minFreeBytes=[long](Get-PSDrive C).Free; success=$false }
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName=$python; $start.WorkingDirectory=$source; $start.UseShellExecute=$false; $start.CreateNoWindow=$true
$start.RedirectStandardOutput=$true; $start.RedirectStandardError=$true
$start.Environment.Remove('NODE_OPTIONS') | Out-Null
foreach ($arg in $arguments) { [void]$start.ArgumentList.Add($arg) }
$process=[Diagnostics.Process]::new();$process.StartInfo=$start
$stdout=$null;$stderr=$null
try {
 if (-not $process.Start()) { throw 'SCons did not start' }
 $receipt.pid=$process.Id
 $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while (-not $process.WaitForExit(3000)) {
  if ($watch.Elapsed.TotalSeconds -gt 1200) { throw 'Build exceeded 20-minute watchdog' }
  $rows=@(Get-Process -Name python,cl,c1xx,c2,link,lib -ErrorAction SilentlyContinue)
  if (-not @($rows | Where-Object { $_.Id -eq $process.Id }).Count) { throw 'SCons process disappeared' }
  $private=0L;$working=0L
  foreach($row in $rows){$private += [long]$row.PrivateMemorySize64;$working += [long]$row.WorkingSet64}
  $receipt.peakPrivateBytes=[Math]::Max($receipt.peakPrivateBytes,$private)
  $receipt.peakWorkingSetBytes=[Math]::Max($receipt.peakWorkingSetBytes,$working)
  if ($private -gt 8GB -or $working -gt 8GB) { throw 'Compiler memory exceeded 8 GiB' }
  $free=[long](Get-PSDrive C).Free;$receipt.minFreeBytes=[Math]::Min($receipt.minFreeBytes,$free)
  if ($free -lt 20GB) { throw 'Disk free below 20 GiB' }
 }
 $receipt.exit=$process.ExitCode
 if ($receipt.exit -ne 0) { throw "SCons exited $($receipt.exit)" }
 $actual=@([regex]::Matches($stdout.GetAwaiter().GetResult().Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$') | ForEach-Object {$_.Groups[1].Value.Trim()})
 $receipt.actualCompiles=$actual
 if ($actual.Count -ne $expected.Count -or @(Compare-Object $expected $actual).Count -ne 0) { throw 'Actual compile set differs from dry run' }
 $saved=Join-Path $output 'Godot_nwn74_forward_census_d_win64.exe'
 Copy-Item -LiteralPath $binary -Destination $saved
 $receipt.binary=[ordered]@{file=$saved;sha256=Hash $saved;bytes=(Get-Item -LiteralPath $saved).Length}
 $receipt.success=$true
} catch { $receipt.failure=$_.Exception.Message }
finally {
 if ($receipt.pid -and -not $process.HasExited) { $process.Kill($true);[void]$process.WaitForExit(10000);$receipt.forced=$true }
 if ($stdout) { [IO.File]::WriteAllText((Join-Path $output 'build.stdout.log'),$stdout.GetAwaiter().GetResult()) }
 if ($stderr) { [IO.File]::WriteAllText((Join-Path $output 'build.stderr.log'),$stderr.GetAwaiter().GetResult()) }
 $receipt.acceptedUnchanged=$pins.accepted -eq (Hash $accepted)
 $receipt.priorUnchanged=$pins.prior -eq (Hash $prior)
 $receipt.originalSourceUnchanged=$pins.originalForward -eq (Hash (Join-Path $scope 'engine-source-a/servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp'))
 $receipt.sourceUnchanged=$pins.forward -eq (Hash (Join-Path $source 'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp')) -and $pins.header -eq (Hash (Join-Path $source 'modules/nwn_frame_probe/frame_probe.h')) -and $pins.probe -eq (Hash (Join-Path $source 'modules/nwn_frame_probe/frame_probe.cpp'))
 $receipt.success=$receipt.success -and $receipt.acceptedUnchanged -and $receipt.priorUnchanged -and $receipt.originalSourceUnchanged -and $receipt.sourceUnchanged
 $receipt.freeAfterBytes=[long](Get-PSDrive C).Free
 $receipt.endUtc=[DateTime]::UtcNow.ToString('o')
 $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'receipt.json') -Encoding utf8
 $process.Dispose()
}
$receipt | ConvertTo-Json -Depth 5
if (-not $receipt.success) { exit 1 }
