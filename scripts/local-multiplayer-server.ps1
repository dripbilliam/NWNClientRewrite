param(
    [ValidateSet('Start','Status','Stop')][string]$Action = 'Status',
    [ValidateRange(1024,65535)][int]$Port = 5121,
    [ValidatePattern('^[A-Za-z0-9 _-]+$')][string]$Module = 'Prelude',
    [string]$NWSyncUrl = '',
    [ValidatePattern('^$|^[a-f0-9]{40}$')][string]$NWSyncHash = ''
)
$ErrorActionPreference = 'Stop'
$serverWorkspace = Split-Path $PSScriptRoot -Parent
$serverHome = [IO.Path]::GetFullPath((Join-Path $serverWorkspace 'runtime-logs/local-multiplayer-server'))
$serverExecutable = [IO.Path]::GetFullPath((Join-Path $serverWorkspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
function Get-OwnedServer {
    Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" |
        Where-Object { $_.ExecutablePath -eq $serverExecutable -and $_.CommandLine -and $_.CommandLine.Contains('"' + $serverHome + '"') }
}
if ($Action -eq 'Start') {
    if (@(Get-OwnedServer).Count) { throw 'The local multiplayer server is already running; use Status.' }
    if (Get-NetUDPEndpoint -LocalPort $Port -ErrorAction SilentlyContinue) { throw "UDP port $Port is occupied." }
    if ((Get-FileHash -LiteralPath $serverExecutable -Algorithm SHA256).Hash -ne '98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6') { throw 'Unverified installed server build.' }
    New-Item -ItemType Directory -Path $serverHome -Force | Out-Null
    $serverSettings = Join-Path $serverHome 'settings.tml'
    if (-not (Test-Path -LiteralPath $serverSettings)) {
        @'
[server.identity]
name = "Replacement Client Compatibility"
public = false

[server.net]
accept-relayed-connections = false

[server.login.player-dm]
enabled = false
'@ | Set-Content -LiteralPath $serverSettings -Encoding utf8
    }
    $serverArguments = @('-userdirectory', ('"' + $serverHome + '"'), '-port', "$Port", '-publicserver', '0',
        '-servername', '"Replacement Client Compatibility"', '-maxclients', '2', '-servervault', '0',
        '-autosaveinterval', '0', '-module', ('"' + $Module + '"'))
    if($NWSyncUrl -or $NWSyncHash){
        $repository=[uri]$NWSyncUrl
        if($repository.Scheme-ne'http' -or $repository.Host-ne'127.0.0.1' -or $repository.UserInfo -or $repository.Query -or $repository.Fragment -or -not $NWSyncHash){throw 'Owned NWSync fixture must use an explicit loopback HTTP repository and manifest hash'}
        $serverArguments+=@('-nwsyncurl',$repository.AbsoluteUri,'-nwsynchash',$NWSyncHash,'-reloadwhenempty','0')
    }
    $serverPreviousNat = [Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', '1', 'Process')
        $serverProcess = Start-Process -FilePath $serverExecutable -WorkingDirectory (Split-Path $serverExecutable) -ArgumentList $serverArguments -WindowStyle Hidden -PassThru
    } finally {
        [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', $serverPreviousNat, 'Process')
    }
    Write-Output "Started installed NWN server PID $($serverProcess.Id); requested module $Module on UDP $Port."
    Write-Output "Profile: $serverHome"
} elseif ($Action -eq 'Stop') {
    foreach ($serverProcess in @(Get-OwnedServer)) { Stop-Process -Id $serverProcess.ProcessId }
    Write-Output 'Stopped only the server belonging to the local multiplayer test profile.'
} else {
    $serverProcesses = @(Get-OwnedServer)
    if (-not $serverProcesses.Count) { Write-Output 'Local multiplayer server is stopped.' }
    foreach ($serverProcess in $serverProcesses) {
        Write-Output "Local multiplayer server PID $($serverProcess.ProcessId)"
        Get-NetUDPEndpoint -OwningProcess $serverProcess.ProcessId -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess
    }
    $serverLogDirectory = Join-Path $serverHome 'logs'
    if (Test-Path -LiteralPath $serverLogDirectory) {
        Get-ChildItem -LiteralPath $serverLogDirectory -File | Select-Object Name,Length,LastWriteTime
    }
}
