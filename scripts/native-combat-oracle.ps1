param([ValidateSet('Start','Status','Stop')][string]$Action = 'Status', [int]$Port = 5131,
    [ValidateSet('combat','perception')][string]$Fixture = 'combat')
$ErrorActionPreference = 'Stop'
$oracleWorkspace = Split-Path $PSScriptRoot -Parent
$oracleModule = 'codex_' + $Fixture + '_oracle'
$oracleHome = [IO.Path]::GetFullPath((Join-Path $oracleWorkspace ('backups\native-' + $Fixture + '-oracle\home')))
$oracleExecutable = [IO.Path]::GetFullPath((Join-Path $oracleWorkspace '..\FullDecomp\NwnRootInstall\bin\win32\nwserver.exe'))
function Get-OracleProcess {
    Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" |
        Where-Object { $_.ExecutablePath -eq $oracleExecutable -and $_.CommandLine -and $_.CommandLine.Contains($oracleHome) }
}
if ($Action -eq 'Start') {
    if (@(Get-OracleProcess).Count) { throw 'Owned oracle is already running.' }
    if (Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue) { throw 'Oracle port is occupied.' }
    if ((Get-FileHash -LiteralPath $oracleExecutable -Algorithm SHA256).Hash -ne '98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6') { throw 'Unverified original server build.' }
    if (-not (Test-Path -LiteralPath (Join-Path $oracleHome ('modules\' + $oracleModule + '.mod')))) { throw 'Build authored fixture first.' }
    @'
[server.identity]
name = "Owned Combat Oracle"
public = false

[server.net]
accept-relayed-connections = false

[server.login.player-dm]
enabled = false
'@ | Set-Content -LiteralPath (Join-Path $oracleHome 'settings.tml') -Encoding utf8
    $oracleArguments = @('-userdirectory', "`"$oracleHome`"", '-port', "$Port", '-publicserver', '0', '-servername', '"Owned Combat Oracle"',
        '-maxclients', '1', '-servervault', '0', '-playerpassword', [Guid]::NewGuid().ToString('N'),
        '-dmpassword', [Guid]::NewGuid().ToString('N'), '-adminpassword', [Guid]::NewGuid().ToString('N'),
        '-autosaveinterval', '0', '-module', $oracleModule)
    $oraclePreviousNat = [Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', '1', 'Process')
        $oracleProcess = Start-Process -FilePath $oracleExecutable -WorkingDirectory (Split-Path $oracleExecutable) -ArgumentList $oracleArguments -WindowStyle Hidden -PassThru
    } finally { [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', $oraclePreviousNat, 'Process') }
    Write-Output "Owned native oracle PID $($oracleProcess.Id), unlisted, log directory $oracleHome\logs"
} elseif ($Action -eq 'Stop') {
    foreach ($oracleProcess in @(Get-OracleProcess)) { Stop-Process -Id $oracleProcess.ProcessId }
    Write-Output 'Stopped only processes belonging to the authored oracle directory.'
} else {
    $oracleProcesses = @(Get-OracleProcess)
    if (-not $oracleProcesses.Count) { Write-Output 'Owned oracle stopped.' }
    foreach ($oracleProcess in $oracleProcesses) {
        Write-Output "Owned oracle PID $($oracleProcess.ProcessId)"
        Get-NetUDPEndpoint -OwningProcess $oracleProcess.ProcessId -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
    }
    if (Test-Path -LiteralPath (Join-Path $oracleHome 'logs')) {
        Get-ChildItem -LiteralPath (Join-Path $oracleHome 'logs') -File | ForEach-Object { Write-Output $_.Name; Get-Content -LiteralPath $_.FullName -Tail 40 }
    }
}
