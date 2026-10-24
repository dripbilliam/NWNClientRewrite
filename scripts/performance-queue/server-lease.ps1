param(
    [Parameter(Mandatory=$true)][ValidateSet('Start','Ready','Stop')][string]$Action,
    [int]$ServerProcessId = 0,
    [string]$ServerCreated = ''
)
$ErrorActionPreference = 'Stop'
$queueRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$serverHome = [IO.Path]::GetFullPath((Join-Path $queueRoot 'runtime-logs/dense-performance-server'))
$serverExecutable = [IO.Path]::GetFullPath((Join-Path $queueRoot '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
if ($Action -eq 'Start') {
    $serverOutput = & (Join-Path $queueRoot 'scripts/dense-performance-server.ps1') -Action Start
    $serverMatch = [regex]::Match(($serverOutput -join "`n"), 'Started owned dense server PID (\d+), UDP 5123')
    if (-not $serverMatch.Success) { throw 'Could not obtain the newly started server PID.' }
    $startedProcessId = [int]$serverMatch.Groups[1].Value
    $startedProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $startedProcessId"
    if (-not $startedProcess) { throw 'New owned server exited before leasing it.' }
    @{ processId = $startedProcessId; created = $startedProcess.CreationDate.ToUniversalTime().ToString('o'); port = 5123 } | ConvertTo-Json -Compress
    exit
}
if ($ServerProcessId -le 0) { throw 'An explicit owned server PID is required.' }
$serverProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $ServerProcessId"
if (-not $serverProcess) {
    @{ processId = $ServerProcessId; ready = $false; exited = $true } | ConvertTo-Json -Compress
    exit
}
if ($serverProcess.ExecutablePath -ne $serverExecutable -or -not $serverProcess.CommandLine -or -not $serverProcess.CommandLine.Contains('"' + $serverHome + '"')) {
    throw 'Server PID ownership changed. Refusing to operate on it.'
}
if (-not $ServerCreated -or $serverProcess.CreationDate.ToUniversalTime().ToString('o') -ne $ServerCreated) {
    throw 'Server PID creation time changed. Refusing to operate on it.'
}
if ($Action -eq 'Stop') {
    Stop-Process -Id $ServerProcessId
    @{ processId = $ServerProcessId; stopped = $true } | ConvertTo-Json -Compress
} else {
    $serverEndpoint = @(Get-NetUDPEndpoint -OwningProcess $ServerProcessId -ErrorAction SilentlyContinue | Where-Object LocalPort -eq 5123)
    @{ processId = $ServerProcessId; ready = ($serverEndpoint.Count -gt 0) } | ConvertTo-Json -Compress
}
