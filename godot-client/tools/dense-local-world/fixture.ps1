param(
    [Parameter(Mandatory)][ValidateSet('Prepare','Run')][string]$Action,
    [Parameter(Mandatory)][string]$FixtureRoot,
    [ValidateSet('smoke','dense')][string]$Scale='dense',
    [ValidateRange(1,4)][int]$DensityMultiplier=1,
    [ValidateRange(1024,65535)][int]$UdpPort=5127,
    [ValidateRange(1024,65535)][int]$HttpPort=5137,
    [string]$SeedVault='',
    [string]$SettingsSource='',
    [ValidateSet('cold','pair')][string]$Phase='pair',
    [ValidateSet('validate','frame','profile')][string]$Mode='validate',
    [ValidateRange(2,30)][int]$IdleSeconds=6,
    [ValidateRange(1,12)][int]$RouteLaps=1,
    [ValidateRange(45,600)][int]$TimeoutSeconds=180,
    [ValidateSet('reference','cpu-compiled','gpu-skin','gpu-skin-pick')][string]$Variant='reference',
    [switch]$PointerProbe,
    [switch]$JoinDiagnostics,
    [switch]$ForegroundModelCompletion,
    [switch]$PrefetchLookahead,
    [switch]$DriveObstaclePrefix,
    [switch]$DriveObstacleSparse,
    [switch]$CpuSkinPicking,
    [ValidateSet('safe','separate')][string]$RenderThread='safe'
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath($FixtureRoot)
$worldBuilder=Join-Path $PSScriptRoot 'world/build-world.ps1'
$repositoryBuilder=Join-Path $PSScriptRoot 'nwsync/new-repository.ps1'
$repositoryHost=Join-Path $PSScriptRoot 'nwsync/serve-repository.ps1'
$serverController=Join-Path $PSScriptRoot 'world/world-server.ps1'
$repository=Join-Path $root 'repository'
$descriptor=Join-Path $repository 'descriptor.json'

if($Action -eq 'Prepare'){
    $worldOptions=@{FixtureRoot=$root;Scale=$Scale;Port=$UdpPort;DensityMultiplier=$DensityMultiplier}
    if($SeedVault){$worldOptions.SeedVault=$SeedVault}
    & $worldBuilder @worldOptions
    & $repositoryBuilder -ResourceDirectory (Join-Path $root 'resources') -Archive (Join-Path $root 'server/hak/ds_fixture.hak') -Repository $repository -Port $HttpPort
    return
}

if(-not $SettingsSource){throw 'Run requires the isolated client settings seed'}
if($ForegroundModelCompletion -and -not $JoinDiagnostics){throw 'Foreground model completion comparison requires JoinDiagnostics'}
if($DriveObstacleSparse -and -not $DriveObstaclePrefix){throw 'Sparse obstacle reuse requires DriveObstaclePrefix'}
if($RouteLaps -gt 1 -and $Mode -ne 'validate'){throw 'Repeated route laps require headless validate mode'}
$world=Join-Path $root 'world.json'
$runner=Join-Path $PSScriptRoot 'client/run-client.ps1'
foreach($path in @($world,$runner,$serverController,$descriptor)){
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "Missing fixture input: $path"}
}
$manifest=Get-Content -LiteralPath $descriptor -Raw | ConvertFrom-Json
$runs=Join-Path $root 'runs'
if(-not (Test-Path -LiteralPath $runs)){New-Item -ItemType Directory -Path $runs | Out-Null}
$routeSuffix=if($RouteLaps -gt 1){"-laps$RouteLaps"}else{''}
$pointerSuffix=if($PointerProbe){'-pointer'}else{''}
$skinPickSuffix=if($CpuSkinPicking){'-cpupick'}else{''}
$completionSuffix=if($ForegroundModelCompletion){'-model-completion'}else{''}
$phaseSuffix=if($Phase -eq 'cold'){'-cold'}else{''}
$prefixSuffix=if($DriveObstacleSparse){'-obstacle-sparse'}elseif($DriveObstaclePrefix){'-obstacle-prefix'}else{''}
$lookaheadSuffix=if($PrefetchLookahead){'-lookahead'}else{''}
$run=Join-Path $runs ((Get-Date -Format 'yyyyMMdd-HHmmssfff')+"-$Mode-$Variant$routeSuffix$pointerSuffix$skinPickSuffix$completionSuffix$phaseSuffix$prefixSuffix$lookaheadSuffix")
New-Item -ItemType Directory -Path $run | Out-Null
$httpLogs=Join-Path $run 'http'
$httpStart=[Diagnostics.ProcessStartInfo]::new()
$httpStart.FileName=(Get-Command pwsh -ErrorAction Stop).Source
$httpStart.UseShellExecute=$false
$httpStart.CreateNoWindow=$true
$httpStart.RedirectStandardOutput=$true
$httpStart.RedirectStandardError=$true
foreach($argument in @('-NoProfile','-File',$repositoryHost,'-Repository',$repository,'-LogDirectory',$httpLogs)){
    $httpStart.ArgumentList.Add($argument)
}

$http=$null
$worldProcess=$null
try{
    $http=[Diagnostics.Process]::Start($httpStart)
    $stdout=$http.StandardOutput.ReadToEndAsync()
    $stderr=$http.StandardError.ReadToEndAsync()
    $readyPath=Join-Path $httpLogs 'ready.json'
    $deadline=[DateTime]::UtcNow.AddSeconds(15)
    while(-not (Test-Path -LiteralPath $readyPath -PathType Leaf)){
        if($http.HasExited){throw "NWSync HTTP process exited with code $($http.ExitCode)"}
        if([DateTime]::UtcNow -ge $deadline){throw 'NWSync HTTP process did not become ready'}
        Start-Sleep -Milliseconds 100
    }
    $ready=Get-Content -LiteralPath $readyPath -Raw | ConvertFrom-Json
    if($http.HasExited -or $ready.pid -ne $http.Id -or $ready.port -ne ([uri]$manifest.url).Port){throw 'The expected NWSync HTTP process is not ready on the fixture port'}

    $worldStart=& $serverController -Action Start -FixtureRoot $root -NWSyncUrl $manifest.url -ManifestHash $manifest.manifestHash
    $ownedServer=$worldStart | ConvertFrom-Json
    $worldProcess=[Diagnostics.Process]::GetProcessById([int]$ownedServer.pid)
    $null=$worldProcess.Handle
    $worldStart | Set-Content -LiteralPath (Join-Path $run 'server-start.json') -Encoding utf8
    if($ownedServer.manifestHash -cne $manifest.manifestHash){throw 'The owned server advertised a different fixture manifest'}
    $runnerOptions=@{
        World=$world
        Repository=$repository
        RepositoryLogs=$httpLogs
        SettingsSource=$SettingsSource
        OutputRoot=Join-Path $run 'client'
        Phase=$Phase
        Mode=$Mode
        IdleSeconds=$IdleSeconds
        RouteLaps=$RouteLaps
        TimeoutSeconds=$TimeoutSeconds
        Variant=$Variant
        PointerProbe=[bool]$PointerProbe
        JoinDiagnostics=[bool]$JoinDiagnostics
        ForegroundModelCompletion=[bool]$ForegroundModelCompletion
        PrefetchLookahead=[bool]$PrefetchLookahead
        DriveObstaclePrefix=[bool]$DriveObstaclePrefix
        DriveObstacleSparse=[bool]$DriveObstacleSparse
        CpuSkinPicking=[bool]$CpuSkinPicking
        RenderThread=$RenderThread
    }
    $null=& $runner @runnerOptions
    $summaryPath=Join-Path $run "client/summary-$Phase.json"
    $summary=Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    $expectedPhases=if($Phase -eq 'cold'){'cold'}else{'cold,warm'}
    if($summary.success -ne $true -or $summary.format -cne 'dense-local-client-pair-v1' -or
        $summary.manifestHash -cne $manifest.manifestHash -or $summary.mode -cne $Mode -or
        $summary.variant -cne $Variant -or $summary.routeLaps -ne $RouteLaps -or $summary.phase -cne $Phase -or
        [bool]$summary.cpuSkinPicking -ne [bool]$CpuSkinPicking -or [bool]$summary.joinDiagnostics -ne [bool]$JoinDiagnostics -or
        [bool]$summary.foregroundModelCompletion -ne [bool]$ForegroundModelCompletion -or
        [bool]$summary.prefetchLookahead -ne [bool]$PrefetchLookahead -or
        [bool]$summary.driveObstaclePrefix -ne [bool]$DriveObstaclePrefix -or [bool]$summary.driveObstacleSparse -ne [bool]$DriveObstacleSparse -or
        [bool]$summary.pointerProbe -ne [bool]$PointerProbe -or ($summary.runs.phase -join ',') -cne $expectedPhases){
        throw 'The client did not record the requested fixture phases and configuration'
    }
}finally{
    try{
        if($worldProcess){
            try{
                if(-not $worldProcess.HasExited){$worldProcess.Kill()}
                if(-not $worldProcess.WaitForExit(5000)){throw 'The owned fixture server did not stop'}
            }finally{$worldProcess.Dispose()}
        }
    }finally{
        if($http){
            if(-not $http.HasExited){$http.Kill(); [void]$http.WaitForExit(5000)}
            if($stdout.IsCompletedSuccessfully){[IO.File]::WriteAllText((Join-Path $run 'http.stdout.log'),$stdout.Result)}
            if($stderr.IsCompletedSuccessfully){[IO.File]::WriteAllText((Join-Path $run 'http.stderr.log'),$stderr.Result)}
            $http.Dispose()
        }
    }
}
Write-Output $summaryPath
