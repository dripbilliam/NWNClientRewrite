param(
    [ValidateSet('Start','Stop','Status')][string]$Action='Status',
    [Parameter(Mandatory)][string]$FixtureRoot,
    [string]$NWSyncUrl='',
    [ValidatePattern('^$|^[a-f0-9]{40}$')][string]$ManifestHash=''
)
$ErrorActionPreference='Stop'
$project=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$workspace=Split-Path $project -Parent
$cache=(Resolve-Path -LiteralPath (Join-Path $workspace '.cache')).Path
$root=(Resolve-Path -LiteralPath $FixtureRoot).Path
if(-not $root.StartsWith($cache+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'FixtureRoot must be below the workspace .cache'
}
for($path=$root;$path -ne $cache;$path=Split-Path $path -Parent){
    if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint){
        throw 'Fixture directories cannot be redirected'
    }
}
foreach($relativePath in @('server','server/modules','server/hak','server/servervault')){
    if((Get-Item -LiteralPath (Join-Path $root $relativePath)).Attributes -band [IO.FileAttributes]::ReparsePoint){
        throw 'Fixture directories cannot be redirected'
    }
}
$definition=Get-Content -LiteralPath (Join-Path $root 'world.json') -Raw | ConvertFrom-Json -AsHashtable
if($definition.format -cne 'nwn-dense-local-world-v1' -or $definition.module -cne 'DenseSync'){
    throw 'Fixture descriptor is invalid'
}
$module='DenseSync'
$port=[int]$definition.port
if($port -lt 1024 -or $port -gt 65535){throw 'Fixture UDP port is invalid'}
$profile=Join-Path $root 'server'
$logs=Join-Path $profile 'logs/nwengineLog.txt'
$binary=[IO.Path]::GetFullPath((Join-Path $workspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
function Get-WorldServer {
    Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'" | Where-Object {
        $_.ExecutablePath -eq $binary -and $_.CommandLine -and
        $_.CommandLine.Contains('"' + $profile + '"') -and
        $_.CommandLine -match "(?:^|\s)-port $port(?:\s|$)" -and
        $_.CommandLine -match '(?:^|\s)-module "?DenseSync"?(?:\s|$)'
    }
}
$owned=@(Get-WorldServer)
if($Action -eq 'Stop'){
    foreach($process in $owned){Stop-Process -Id $process.ProcessId}
    [ordered]@{stopped=$owned.Count;port=$port;module=$module} | ConvertTo-Json -Compress
    return
}
if($Action -eq 'Status'){
    [ordered]@{module=$module;port=$port;ownedPids=@($owned.ProcessId | Where-Object {$_});serverProfile=$profile;log=$logs} | ConvertTo-Json -Compress
    return
}
if($owned.Count -gt 0 -or @(Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue).Count -gt 0){
    throw 'The fixture port is occupied'
}
foreach($pair in @(@('server/modules/DenseSync.mod',$definition.moduleSha256),@('server/hak/ds_fixture.hak',$definition.hakSha256))){
    if((Get-FileHash -LiteralPath (Join-Path $root $pair[0]) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $pair[1]){
        throw ('Fixture resource changed: '+$pair[0])
    }
}
if((Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash -cne '98951511AE7D06A251355F12D4F3E4B96269A2414FA3058E641AFD70098690F6'){
    throw 'Installed NWN server binary differs from the pinned build'
}
if(-not $NWSyncUrl -or -not $ManifestHash){throw 'Start requires a loopback NWSync URL and a manifest hash'}
$url=[uri]$NWSyncUrl
if($url.Scheme -cne 'http' -or $url.Host -cne '127.0.0.1' -or $url.UserInfo -or $url.Query -or $url.Fragment){
    throw 'NWSync URL must be plain loopback HTTP'
}
if($definition.serverVault){
    $vault=Join-Path $profile 'servervault'
    $bics=@(Get-ChildItem -LiteralPath $vault -File -Recurse -Filter '*.bic')
    if($bics.Count -ne 1 -or -not $definition.seedSha256){throw 'ServerVault fixture must have one seeded character'}
    $seedVault=Join-Path $root 'seed-vault'
    if(Test-Path -LiteralPath $seedVault){
        $relative=[IO.Path]::GetRelativePath($vault,$bics[0].FullName)
        if($relative -notmatch '^[A-Za-z0-9_]+[\/\\][A-Za-z0-9_]+\.bic$'){throw 'Unexpected benchmark vault identifier'}
        $seed=Join-Path $seedVault $relative
        foreach($path in @($seedVault,(Split-Path $seed -Parent),$seed,$bics[0].DirectoryName,$bics[0].FullName)){
            if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint){
                throw 'Seeded vault files cannot be redirected'
            }
        }
        if((Get-FileHash -LiteralPath $seed -Algorithm SHA256).Hash.ToLowerInvariant() -cne $definition.seedSha256){
            throw 'Retained benchmark seed changed'
        }
        Copy-Item -LiteralPath $seed -Destination $bics[0].FullName -Force
    }
}
$settings=Join-Path $profile 'settings.tml'
if(-not (Test-Path -LiteralPath $settings)){
    @('[server.identity]','name = "Owned Dense NWSync Benchmark"','public = false','','[server.net]',
        'accept-relayed-connections = false','','[server.login.player-dm]','enabled = false') |
        Set-Content -LiteralPath $settings -Encoding utf8
}
$serverVault=if($definition.serverVault){'1'}else{'0'}
$arguments=@('-userdirectory',('"' + $profile + '"'),'-port',[string]$port,'-publicserver','0',
    '-servername','"Owned Dense NWSync Benchmark"','-maxclients','2','-servervault',$serverVault,
    '-autosaveinterval','0','-reloadwhenempty','0','-module',$module,
    '-nwsyncurl',$url.AbsoluteUri,'-nwsynchash',$ManifestHash)
$previousNat=[Environment]::GetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','Process')
try {
    [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH','1','Process')
    $process=Start-Process -FilePath $binary -WorkingDirectory (Split-Path $binary) -ArgumentList $arguments -WindowStyle Hidden -PassThru
} finally {
    [Environment]::SetEnvironmentVariable('NWN_DO_NOT_NAT_PUNCH',$previousNat,'Process')
}
try {
    $deadline=[DateTime]::UtcNow.AddSeconds(25)
    $readyAt=$null
    $serverLog=Join-Path $profile 'logs/nwserverLog1.txt'
    while ([DateTime]::UtcNow -lt $deadline -and -not $process.HasExited){
        $endpoint=Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue | Where-Object OwningProcess -eq $process.Id
        if($endpoint -and (Test-Path -LiteralPath $serverLog) -and (Select-String -LiteralPath $serverLog -SimpleMatch "Loading Module: $module" -Quiet) -and (Select-String -LiteralPath $serverLog -SimpleMatch 'End Server Options' -Quiet)){
            if($null -eq $readyAt){$readyAt=[DateTime]::UtcNow}
            if(([DateTime]::UtcNow-$readyAt).TotalMilliseconds -ge 1800){
                [ordered]@{module=$module;port=$port;pid=$process.Id;manifestHash=$ManifestHash;serverVault=[bool]$definition.serverVault;log=$logs} | ConvertTo-Json -Compress
                return
            }
        } else {
            $readyAt=$null
        }
        Start-Sleep -Milliseconds 200
    }
    if(-not $process.HasExited){$process.Kill();[void]$process.WaitForExit(5000)}
    throw "Owned server failed to load the benchmark world. See $logs"
} finally {
    $process.Dispose()
}
