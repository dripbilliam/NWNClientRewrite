param([string]$Scene='', [int]$Frames=0, [string]$Report='', [switch]$Headless, [switch]$SystemsSmoke)
$ErrorActionPreference='Stop'
$project=$PSScriptRoot
$engine=Join-Path $project '.tools/Godot_v4.7.2-stable_win64.exe'
if(-not (Test-Path -LiteralPath $engine)){throw 'Run tools/setup.ps1 first'}
. (Join-Path $project 'tools/local-test-guard.ps1')
Assert-NativeLocalTestAvailable $project
if($Frames-lt 0 -or $Frames-gt 1000000){throw 'Invalid frame count'}
if(-not $Scene){
 $reference=Join-Path $project '.cache/latest-room.json'
 if(-not (Test-Path -LiteralPath $reference)){throw 'No captured room is registered; pass -Scene with an external room.glb'}
 $Scene=(Get-Content -LiteralPath $reference -Raw | ConvertFrom-Json).scene
 if(-not (Test-Path -LiteralPath $Scene)){throw 'The external capture was removed; export the room again or pass -Scene'}
}
$arguments=@('--path',$project,'--rendering-method','forward_plus','--rendering-driver','vulkan')
if($Headless){$arguments+='--headless'}
$arguments+='--'
if($Scene){$arguments+='--scene='+[IO.Path]::GetFullPath($Scene)}
if($Frames){$arguments+='--frames='+$Frames}
if($Report){$arguments+='--report='+[IO.Path]::GetFullPath($Report)}
if($SystemsSmoke){$arguments+='--systems-smoke'}
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$engine
$start.WorkingDirectory=$project
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
$process=[Diagnostics.Process]::Start($start)
$process.WaitForExit()
exit $process.ExitCode
