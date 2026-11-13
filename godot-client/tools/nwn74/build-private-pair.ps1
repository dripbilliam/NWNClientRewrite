[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$scope = [IO.Path]::GetFullPath((Join-Path $project '.cache/nwn74'))
$source = [IO.Path]::GetFullPath((Join-Path $scope 'engine-source-a'))
$output = [IO.Path]::GetFullPath((Join-Path $scope 'engine-build-c'))
$original = [IO.Path]::GetFullPath((Join-Path $project '.cache/native-tracy/engine-msvc-a/source/bin/godot.windows.template_release.x86_64.exe'))
$priorCandidate = [IO.Path]::GetFullPath((Join-Path $scope 'engine-build-b/Godot_nwn74_render_probe_b_win64.exe'))
$binary = Join-Path $source 'bin/godot.windows.template_release.x86_64.exe'
$savedBinary = Join-Path $output 'Godot_nwn74_pair_index_c_win64.exe'
$savedPdb = Join-Path $output 'godot.windows.template_release.x86_64.pdb'
$dryLog = Join-Path $scope 'pair-index-a/dryrun.log'
$python = [IO.Path]::GetFullPath((Join-Path $project '.cache/native-140fps/render-agent/engine-build-tools-v1/python/python.exe'))
$profilerPath = [IO.Path]::GetFullPath((Join-Path $project '.cache/native-tracy/vendor/tracy-0.13.0'))
$arguments = @('-m','SCons','platform=windows','target=template_release','arch=x86_64','use_mingw=no','msvc_version=14.5','disable_path_overrides=no','d3d12=no','debug_symbols=yes','optimize=speed','lto=none','profiler=tracy',"profiler_path=$profilerPath",'profiler_sample_callstack=no','profiler_track_memory=no','profiler_record_on_demand=yes','-j','2','bin/godot.windows.template_release.x86_64.exe')
function Hash([string]$file) { (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() }
if (-not $source.StartsWith($scope+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not $output.StartsWith($scope+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Private build path escaped NWN-74 scope' }
if (Test-Path -LiteralPath $output) {
  if (@(Get-ChildItem -LiteralPath $output -Force).Count -ne 0) { throw 'Preserve existing private build result' }
} else {
  New-Item -ItemType Directory -Path $output | Out-Null
}
if ((Hash $dryLog) -ne '56d3daa90d37a86e2d1f1b6388065d6c75223f20cfdd6d01d3e537cebd7ee54d') { throw 'Dry-run proof differs' }
$expected = @([regex]::Matches((Get-Content -LiteralPath $dryLog -Raw).Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$') | ForEach-Object { $_.Groups[1].Value.Trim() } | Sort-Object)
if ($expected.Count -ne 3 -or @(Compare-Object $expected @('servers/rendering/renderer_scene_cull.cpp','servers/rendering/rendering_light_culler.cpp','servers/rendering/rendering_server_default.cpp')).Count -ne 0) { throw 'Pair candidate compile set changed' }
if ((Hash (Join-Path $source 'servers/rendering/renderer_scene_cull.cpp')) -ne '9208fd79912b5d00250ba4320c3282045ce3194f4122bb07d95547c156ca9236' -or
    (Hash (Join-Path $source 'servers/rendering/renderer_scene_cull.h')) -ne 'f04744119ec2a2d74c2fbe6ffae2a26cb5b3749b2d4a26231c71dab155a94ae0') { throw 'Private pair source changed' }
$originalBefore = Hash $original
$cloneBefore = Hash $binary
if ($originalBefore -ne '0a2710bd80c0a2cbfeca8ac28338a071561ba741c52a01857df233d69efe02d1' -or (Hash $priorCandidate) -ne '35e47e75fb71dac4ae91140026d1b333988c1546e8033f86a8624702b12da64f' -or $cloneBefore -ne (Hash $priorCandidate)) { throw 'Accepted/prior private control differs' }
$receipt = [ordered]@{ scope='Private NWN-74 opt-in pair-index build; accepted engine and prior diagnostic binary untouched'; startedUtc=[DateTime]::UtcNow.ToString('o'); source=$source; output=$output; python=$python; arguments=$arguments; dryRunSha256=(Hash $dryLog); expectedCompiles=$expected; sourceCppSha256=(Hash (Join-Path $source 'servers/rendering/renderer_scene_cull.cpp')); sourceHeaderSha256=(Hash (Join-Path $source 'servers/rendering/renderer_scene_cull.h')); originalBefore=$originalBefore; priorCandidateBefore=(Hash $priorCandidate); cloneBefore=$cloneBefore; maxSeconds=900; maxMemoryBytes=8GB; pid=0; exit=$null; peakPrivateBytes=0L; peakWorkingSetBytes=0L; success=$false }
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = $python
$start.WorkingDirectory = $source
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.Environment.Remove('NODE_OPTIONS') | Out-Null
foreach ($arg in $arguments) { [void]$start.ArgumentList.Add($arg) }
$process = [Diagnostics.Process]::new()
$process.StartInfo = $start
$stdout = $null
$stderr = $null
try {
  if (-not $process.Start()) { throw 'SCons did not start' }
  $receipt.pid = $process.Id
  $stdout = $process.StandardOutput.ReadToEndAsync()
  $stderr = $process.StandardError.ReadToEndAsync()
  $watch = [Diagnostics.Stopwatch]::StartNew()
  while (-not $process.WaitForExit(3000)) {
    if ($watch.Elapsed.TotalSeconds -gt $receipt.maxSeconds) { throw 'Private build watchdog expired' }
    # CIM process enumeration is denied in this sandbox. The coordinated
    # exclusive build slot has no other compilers, so account for SCons and
    # all compiler/linker processes by name. This conservatively overcounts.
    $snapshot = @(Get-Process -Name python,cl,link,c1xx,c2,lib -ErrorAction SilentlyContinue)
    if (-not @($snapshot | Where-Object { $_.Id -eq $process.Id }).Count) { throw 'Private SCons process disappeared before completion' }
    $private=0L; $working=0L
    foreach ($row in $snapshot) { $private += [long]$row.PrivateMemorySize64; $working += [long]$row.WorkingSet64 }
    $receipt.peakPrivateBytes=[Math]::Max($receipt.peakPrivateBytes,$private)
    $receipt.peakWorkingSetBytes=[Math]::Max($receipt.peakWorkingSetBytes,$working)
    if ($private -gt $receipt.maxMemoryBytes -or $working -gt $receipt.maxMemoryBytes) { throw 'Private compiler tree exceeded 8 GiB cap' }
  }
  $receipt.exit = $process.ExitCode
  if ($receipt.exit -ne 0) { throw "SCons exited $($receipt.exit)" }
  $actual = @([regex]::Matches($stdout.GetAwaiter().GetResult().Replace('\','/'),'(?m)^Compiling (.+?) \.\.\.\s*$') | ForEach-Object { $_.Groups[1].Value.Trim() } | Sort-Object)
  $receipt.actualCompiles = $actual
  if ($actual.Count -ne $expected.Count -or @(Compare-Object $expected $actual).Count -ne 0) { throw 'Actual compile set differed from bounded dry run' }
  Copy-Item -LiteralPath $binary -Destination $savedBinary
  Copy-Item -LiteralPath (Join-Path $source 'bin/godot.windows.template_release.x86_64.pdb') -Destination $savedPdb
  $receipt.binary = @{ file=$savedBinary; sha256=(Hash $savedBinary); bytes=(Get-Item -LiteralPath $savedBinary).Length }
  $receipt.symbols = @{ file=$savedPdb; sha256=(Hash $savedPdb); bytes=(Get-Item -LiteralPath $savedPdb).Length }
  $receipt.success = $true
} catch {
  $receipt.failure = $_.Exception.Message
} finally {
  if ($receipt.pid -and -not $process.HasExited) { $process.Kill($true); [void]$process.WaitForExit(10000); $receipt.forced = $true }
  if ($stdout) { [IO.File]::WriteAllText((Join-Path $output 'build.stdout.log'),$stdout.GetAwaiter().GetResult()) }
  if ($stderr) { [IO.File]::WriteAllText((Join-Path $output 'build.stderr.log'),$stderr.GetAwaiter().GetResult()) }
  $receipt.originalAfter = Hash $original
  $receipt.originalUntouched = $receipt.originalBefore -eq $receipt.originalAfter
  $receipt.priorCandidateAfter = Hash $priorCandidate
  $receipt.priorCandidateUntouched = $receipt.priorCandidateBefore -eq $receipt.priorCandidateAfter
  $receipt.sourceUntouched = $receipt.sourceCppSha256 -eq (Hash (Join-Path $source 'servers/rendering/renderer_scene_cull.cpp')) -and $receipt.sourceHeaderSha256 -eq (Hash (Join-Path $source 'servers/rendering/renderer_scene_cull.h'))
  $receipt.success = $receipt.success -and $receipt.originalUntouched -and $receipt.priorCandidateUntouched -and $receipt.sourceUntouched
  $receipt.finishedUtc = [DateTime]::UtcNow.ToString('o')
  $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'receipt.json') -Encoding utf8
  $process.Dispose()
}
$receipt | ConvertTo-Json -Depth 5
if (-not $receipt.success) { exit 1 }
