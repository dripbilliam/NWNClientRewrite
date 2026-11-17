param([string]$OutputRoot='')
$ErrorActionPreference='Stop'
$project=Split-Path -Parent $PSScriptRoot
$workspace=Split-Path -Parent $project
if([string]::IsNullOrWhiteSpace($OutputRoot)){
 $OutputRoot=Join-Path $workspace ('.cache/nwn79-reader-pipe-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
}
if(Test-Path -LiteralPath $OutputRoot){throw 'Reader pipe output directory must be fresh'}
$null=New-Item -ItemType Directory -Path $OutputRoot
$compiler='C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$godot=Join-Path $project '.tools/Godot_v4.7.2-stable_win64_console.exe'
$source=Join-Path $PSScriptRoot 'fixtures/nwn79_nwsync_pipe_reply.cs'
$helper=Join-Path $OutputRoot 'nwn79_nwsync_pipe_reply.exe'
if(-not (Test-Path -LiteralPath $compiler) -or -not (Test-Path -LiteralPath $godot)){throw 'Reader pipe compiler or Godot console executable is missing'}
& $compiler '/nologo' '/target:exe' ('/out:'+$helper) $source
if($LASTEXITCODE -ne 0){throw 'Test-only native pipe helper compilation failed'}
& $godot '--headless' '--path' $project '--script' 'res://tests/nwn79_native_nwsync_real_pipe_test.gd' '--' ('--helper='+$helper) ('--scratch='+(Join-Path $OutputRoot 'test')) 2>&1 | Tee-Object -FilePath (Join-Path $OutputRoot 'real-pipe.stdout.log')
if($LASTEXITCODE -ne 0){throw 'Godot real process-pipe frame test failed'}
