param([string]$PlayerName='ReplacementTest')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(-not(Test-Path -LiteralPath (Join-Path $PSScriptRoot '.cache/local-bridge/latest.json'))){throw 'Build the native resource bridge first.'}
$report='public-browser-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()+'.json'
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=Join-Path $root 'node_modules/electron/dist/electron.exe'
$start.WorkingDirectory=$root
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$start.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
foreach($argument in @((Join-Path $PSScriptRoot 'tools/local-host.cjs'),'--public-servers',('--player-name='+$PlayerName),('--report='+$report),'--native-verbose')){$start.ArgumentList.Add($argument)}
Write-Output 'Opening native Godot server browser; choose your server and character.'
Write-Output ('Connection status: '+(Join-Path $PSScriptRoot ('reports/'+$report.Replace('.json','.status.json'))))
$process=[Diagnostics.Process]::Start($start)
$process.WaitForExit()
exit $process.ExitCode
