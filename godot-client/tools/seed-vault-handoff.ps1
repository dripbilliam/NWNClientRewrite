param([Parameter(Mandatory=$true)][ValidatePattern('^vault-handoff-fixtures-v[0-9]+\.json$')][string]$Fixture)
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=Join-Path $root 'node_modules/electron/dist/electron.exe';$start.WorkingDirectory=$root;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
$start.ArgumentList.Add((Join-Path $PSScriptRoot 'seed-vault-handoff.cjs'));$start.ArgumentList.Add('--fixture='+$Fixture)
$process=[Diagnostics.Process]::Start($start);$process.WaitForExit();exit $process.ExitCode
