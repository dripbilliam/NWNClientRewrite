[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$stage=Join-Path $project '.cache/nwn74/trait-hoist-a'
$fixture=Join-Path $project 'tools/nwn74/trait-draw-fixture.gd'
$control=Join-Path $project '.cache/nwn74/engine-source-f-control/bin/godot.windows.template_release.x86_64.exe'
$candidate=Join-Path $stage 'Godot_nwn74_trait_hoist_win64.exe'
function Hash([string]$file){(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()}
if((Hash $control) -ne '3d0e9e6ed669c0c936405332b6e576031a3b65adfaec10494308edc71c05fca7'){throw 'Control engine changed'}
if((Hash $candidate) -ne '20ec8409fe00bc96ff1789ce950887a07b752c9fb6ecaa7565256f2c351abb73'){throw 'Candidate engine changed'}
$fixtureSha=Hash $fixture
$rows=@()
foreach($leg in @(@('control',$control),@('candidate',$candidate))){
 $label=$leg[0];$engine=$leg[1];$reportRelative=".cache/nwn74/trait-hoist-a/final-$label.json";$report=Join-Path $project $reportRelative
 if(Test-Path -LiteralPath $report){throw "Preserve prior $report"}
 $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$engine;$start.WorkingDirectory=$project;$start.UseShellExecute=$false;$start.CreateNoWindow=$false;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Normal;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
 foreach($arg in @('--path',$project,'--rendering-method','forward_plus','--rendering-driver','vulkan','--windowed','--position','2500,100','--resolution','320x240','--script','res://tools/nwn74/trait-draw-fixture.gd','--',"--report=$reportRelative")){[void]$start.ArgumentList.Add($arg)}
 $proc=[Diagnostics.Process]::new();$proc.StartInfo=$start
 try{
  if(-not $proc.Start()){throw "Could not start $label"}
  $stdout=$proc.StandardOutput.ReadToEndAsync();$stderr=$proc.StandardError.ReadToEndAsync()
  if(-not $proc.WaitForExit(90000)){throw "$label exceeded 90-second watchdog"}
  [IO.File]::WriteAllText((Join-Path $stage "final-$label.stdout.log"),$stdout.GetAwaiter().GetResult())
  [IO.File]::WriteAllText((Join-Path $stage "final-$label.stderr.log"),$stderr.GetAwaiter().GetResult())
  if($proc.ExitCode -ne 0){throw "$label exited $($proc.ExitCode)"}
 }finally{if($proc.Id -and -not $proc.HasExited){$proc.Kill($true);[void]$proc.WaitForExit(10000)};$proc.Dispose()}
 if(-not (Test-Path -LiteralPath $report)){throw "Missing $label report"}
 $data=Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
 if(-not $data.passed -or $data.draws.Count -ne 24 -or $data.max_draws -le 0){throw "$label fixture did not exercise Forward+"}
 $rows+=@{label=$label;engineSha256=Hash $engine;report=$report;reportSha256=Hash $report;passed=$data.passed;draws=$data.draws;maxDraws=$data.max_draws;pixelSha256=$data.pixel_sha256}
}
if($rows[0].pixelSha256 -ne $rows[1].pixelSha256){throw 'Control/candidate pixels differ'}
if(($rows[0].draws -join ',') -ne ($rows[1].draws -join ',')){throw 'Control/candidate draw counts differ'}
$receipt=[ordered]@{issue='NWN-74';scope='24-frame secondary-position Vulkan Forward+ correctness, no FPS measurement';fixture=$fixture;fixtureSha256=$fixtureSha;sourceControlSha256='cb319128c2650189dc3ebff5aad7e70ac73b0bd4c4d0c58993f06d4d002ddc62';sourceCandidateSha256='9de657dbbe6a2d020b0775a9401806b051004f92c48123a1a382267e2d712e45';rows=$rows;pixelParity=$true;countParity=$true;acceptedSourceUnchanged=((Hash (Join-Path $project '.cache/native-tracy/engine-msvc-a/source/servers/rendering/rendering_device.cpp')) -eq 'cb319128c2650189dc3ebff5aad7e70ac73b0bd4c4d0c58993f06d4d002ddc62')}
$receiptFile=Join-Path $stage 'final-receipt.json'
$receipt|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $receiptFile -Encoding utf8
$receipt|ConvertTo-Json -Depth 5
if(-not $receipt.acceptedSourceUnchanged){exit 1}
