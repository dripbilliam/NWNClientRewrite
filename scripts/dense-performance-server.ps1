param(
    [ValidateSet('Start','Status','Stop')][string]$Action = 'Status',
    [switch]$Showcase
)
$ErrorActionPreference = 'Stop'
$denseRoot = Split-Path $PSScriptRoot -Parent
$denseProfile = if ($Showcase) { 'dense-performance-cx-server' } else { 'dense-performance-server' }
$denseModule = if ($Showcase) { 'DensePerfCx' } else { 'DensePerf' }
$densePort = if ($Showcase) { 5133 } else { 5123 }
$denseName = if ($Showcase) { 'Dense Performance CX Showcase' } else { 'Owned Dense Performance Fixture' }
$denseHome = [IO.Path]::GetFullPath((Join-Path $denseRoot "runtime-logs/$denseProfile"))
$denseExecutable = [IO.Path]::GetFullPath((Join-Path $denseRoot '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
$denseReceipt = Join-Path $denseHome 'launch.json'
function Get-ShowcaseEndpoint {
    foreach ($line in (netstat.exe -ano -p udp)) {
        if ($line -match "^\s*UDP\s+(\S+):$densePort\s+\S+\s+(\d+)\s*$") {
            [pscustomobject]@{ LocalAddress = $Matches[1]; LocalPort = $densePort; OwningProcess = [int]$Matches[2] }
        }
    }
}
function Get-DenseOwnedServer {
    if ($Showcase) {
        if (-not (Test-Path -LiteralPath $denseReceipt -PathType Leaf)) { return }
        $launch = Get-Content -LiteralPath $denseReceipt -Raw | ConvertFrom-Json
        $process = Get-Process -Id $launch.processId -ErrorAction SilentlyContinue
        if ($process -and $process.Path -eq $denseExecutable -and $process.StartTime.ToUniversalTime().Ticks -eq [long]$launch.startedUtcTicks) {
            [pscustomobject]@{ ProcessId = $process.Id }
        }
        return
    }
    Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" | Where-Object { $_.ExecutablePath -eq $denseExecutable -and $_.CommandLine -and $_.CommandLine.Contains('"' + $denseHome + '"') }
}
if ($Action -eq 'Start') {
    if (@(Get-DenseOwnedServer).Count) { throw 'The dense test server is already running.' }
    $denseEndpoint = if ($Showcase) { Get-ShowcaseEndpoint } else { Get-NetUDPEndpoint -LocalPort $densePort -ErrorAction SilentlyContinue }
    if ($denseEndpoint) { throw "UDP $densePort is occupied." }
    if ((Get-FileHash -LiteralPath $denseExecutable -Algorithm SHA256).Hash -ne '98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6') { throw 'Unverified installed server build.' }
    if (-not (Test-Path -LiteralPath (Join-Path $denseHome "modules/$denseModule.mod"))) { throw "Create $denseModule with the authored fixture generator first." }
    @"
[server.identity]
name = "$denseName"
public = false
[server.net]
accept-relayed-connections = false
[server.login.player-dm]
enabled = false
"@ | Set-Content -LiteralPath (Join-Path $denseHome 'settings.tml') -Encoding utf8
    $densePreviousNat = [Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', '1', 'Process')
        $denseProcess = Start-Process -FilePath $denseExecutable -WorkingDirectory (Split-Path $denseExecutable) -ArgumentList @('-userdirectory', ('"' + $denseHome + '"'), '-port', "$densePort", '-publicserver', '0', '-servername', ('"' + $denseName + '"'), '-maxclients', '2', '-servervault', '0', '-autosaveinterval', '0', '-module', $denseModule) -WindowStyle Hidden -PassThru
    } finally { [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH', $densePreviousNat, 'Process') }
    if ($Showcase) {
        @{ processId = $denseProcess.Id; startedUtcTicks = [string]$denseProcess.StartTime.ToUniversalTime().Ticks } |
            ConvertTo-Json | Set-Content -LiteralPath $denseReceipt -Encoding utf8
    }
    Write-Output "Started $denseModule server PID $($denseProcess.Id), connect at 127.0.0.1:$densePort."
} elseif ($Action -eq 'Stop') {
    foreach ($denseProcess in @(Get-DenseOwnedServer)) { Stop-Process -Id $denseProcess.ProcessId }
    Write-Output "Stopped only the $denseModule test server."
} else {
    foreach ($denseProcess in @(Get-DenseOwnedServer)) {
        if ($Showcase) { Get-ShowcaseEndpoint | Where-Object OwningProcess -eq $denseProcess.ProcessId }
        else { Get-NetUDPEndpoint -OwningProcess $denseProcess.ProcessId -ErrorAction SilentlyContinue | Select-Object LocalAddress,LocalPort,OwningProcess }
    }
    if (Test-Path -LiteralPath (Join-Path $denseHome 'logs/nwengineLog.txt')) { Get-Content -LiteralPath (Join-Path $denseHome 'logs/nwengineLog.txt') -Tail 12 }
}
