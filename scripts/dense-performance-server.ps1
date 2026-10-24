param([ValidateSet('Start','Status','Stop')][string]$Action = 'Status')
$ErrorActionPreference = 'Stop'
$denseRoot = Split-Path $PSScriptRoot -Parent
$denseHome = [IO.Path]::GetFullPath((Join-Path $denseRoot 'runtime-logs/dense-performance-server'))
$denseExecutable = [IO.Path]::GetFullPath((Join-Path $denseRoot '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
function Get-DenseOwnedServer {
    Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" | Where-Object { $_.ExecutablePath -eq $denseExecutable -and $_.CommandLine -and $_.CommandLine.Contains('"' + $denseHome + '"') }
}
if ($Action -eq 'Start') {
    if (@(Get-DenseOwnedServer).Count) { throw 'The dense test server is already running.' }
    if (Get-NetUDPEndpoint -LocalPort 5123 -ErrorAction SilentlyContinue) { throw 'UDP 5123 is occupied.' }
    if ((Get-FileHash -LiteralPath $denseExecutable -Algorithm SHA256).Hash -ne '98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6') { throw 'Unverified installed server build.' }
    if (-not (Test-Path -LiteralPath (Join-Path $denseHome 'modules/DensePerf.mod'))) { throw 'Create the authored fixture first.' }
    @'
[server.identity]
name = "Owned Dense Performance Fixture"
public = false
[server.net]
accept-relayed-connections = false
[server.login.player-dm]
enabled = false
'@ | Set-Content -LiteralPath (Join-Path $denseHome 'settings.tml') -Encoding utf8
    $densePreviousNat = [Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', '1', 'Process')
        $denseProcess = Start-Process -FilePath $denseExecutable -WorkingDirectory (Split-Path $denseExecutable) -ArgumentList @('-userdirectory', ('"' + $denseHome + '"'), '-port', '5123', '-publicserver', '0', '-servername', '"Owned Dense Performance Fixture"', '-maxclients', '2', '-servervault', '0', '-autosaveinterval', '0', '-module', 'DensePerf') -WindowStyle Hidden -PassThru
    } finally { [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', $densePreviousNat, 'Process') }
    Write-Output "Started owned dense server PID $($denseProcess.Id), UDP 5123."
} elseif ($Action -eq 'Stop') {
    foreach ($denseProcess in @(Get-DenseOwnedServer)) { Stop-Process -Id $denseProcess.ProcessId }
    Write-Output 'Stopped only the authored dense test server.'
} else {
    foreach ($denseProcess in @(Get-DenseOwnedServer)) { Get-NetUDPEndpoint -OwningProcess $denseProcess.ProcessId -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess }
    if (Test-Path -LiteralPath (Join-Path $denseHome 'logs/nwengineLog.txt')) { Get-Content -LiteralPath (Join-Path $denseHome 'logs/nwengineLog.txt') -Tail 12 }
}
