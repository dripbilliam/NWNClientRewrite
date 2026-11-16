param(
 [Parameter(Mandatory=$true)][string]$FixtureDirectory,
 [Parameter(Mandatory=$true)][string]$ReportRoot
)
$ErrorActionPreference='Stop'
$client=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$workspace=Split-Path -Path $client -Parent
$fixture=[IO.Path]::GetFullPath($FixtureDirectory)
$output=[IO.Path]::GetFullPath($ReportRoot)
if(-not$fixture.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $fixture.StartsWith($client+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Visual fixture must be an isolated workspace directory'}
if(-not$output.StartsWith($workspace+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($client+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)){throw 'Visual repository report root must be a fresh isolated workspace directory'}
$descriptor=Get-Content -LiteralPath (Join-Path $fixture 'descriptor.json') -Raw|ConvertFrom-Json
if($descriptor.format -ne 'nwn79-private-nwsync-visual-v1' -or @($descriptor.entries).Count -ne 13){throw 'Authored thirteen-resource fixture is unavailable'}
$uri=[uri]$descriptor.url
if($uri.Host -ne '127.0.0.1' -or $uri.Scheme -ne 'http'){throw 'Visual repository fixture must be loopback HTTP'}
$engine=Join-Path $client '.tools/Godot_v4.7.2-stable_win64_console.exe'
if(-not(Test-Path -LiteralPath $engine -PathType Leaf)){throw 'Pinned Godot console is unavailable'}
New-Item -ItemType Directory -Path $output -Force|Out-Null
$cache=Join-Path $output 'cache';$userData=Join-Path $output 'user-data'
New-Item -ItemType Directory -Path $cache,$userData -Force|Out-Null
$process=$null;$previousAppData=$env:APPDATA
try{
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=(Get-Command pwsh -ErrorAction Stop).Source
 $start.WorkingDirectory=$workspace
 $start.UseShellExecute=$false;$start.CreateNoWindow=$true
 foreach($argument in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'nwsync-loopback-fixture.ps1'),'-Directory',$fixture,'-Port',([string]$uri.Port),'-Serve')){$start.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($start)
 if($process -eq $null){throw 'PowerShell loopback fixture did not start'}
 $ready=Join-Path $fixture 'ready';$deadline=[DateTime]::UtcNow.AddSeconds(10)
 while([DateTime]::UtcNow -lt $deadline){if((Test-Path -LiteralPath $ready) -and (Get-Content -LiteralPath $ready -Raw).Trim() -eq [string]$process.Id){break};if($process.HasExited){throw 'PowerShell loopback fixture exited before readiness'};Start-Sleep -Milliseconds 100}
 if(-not(Test-Path -LiteralPath $ready) -or (Get-Content -LiteralPath $ready -Raw).Trim() -ne [string]$process.Id){throw 'Owned PowerShell loopback fixture did not become ready'}
 $rows=@();$requestsPath=Join-Path $fixture 'requests.log';$firstHash=[string]$descriptor.entries[0].hash
 foreach($phase in @('cold','warm','repair')){
  if($phase -eq 'repair'){
   $corrupt=Join-Path $cache ('objects/'+$firstHash)
   if(-not(Test-Path -LiteralPath $corrupt -PathType Leaf)){throw 'First authored blob was not cached before repair'}
   [IO.File]::WriteAllText($corrupt,'corrupt authored visual cache fixture')
  }
  $before=if(Test-Path -LiteralPath $requestsPath){@(Get-Content -LiteralPath $requestsPath).Count}else{0}
  $report=Join-Path $output ($phase+'.json')
  $env:APPDATA=$userData
  & $engine --headless --path $client --script 'res://tools/nwn79/nwsync-visual-repository-check.gd' -- ('--descriptor='+(Join-Path $fixture 'descriptor.json')) ('--cache='+$cache) ('--report='+$report) ('--phase='+$phase)
  if($LASTEXITCODE -ne 0){throw ('Godot visual repository '+$phase+' phase failed')}
  $receipt=Get-Content -LiteralPath $report -Raw|ConvertFrom-Json
  if($receipt.success -ne $true -or @($receipt.entries).Count -ne 13 -or $receipt.iconPixel -ne $true){throw ('Godot visual repository '+$phase+' receipt is incomplete')}
  $all=if(Test-Path -LiteralPath $requestsPath){@(Get-Content -LiteralPath $requestsPath)}else{@()}
  $seen=@($all|Select-Object -Skip $before)
  $expected=if($phase -eq 'cold'){14}elseif($phase -eq 'warm'){0}else{1}
  if($seen.Count -ne $expected -or @($seen|Where-Object {$_ -notmatch '200 OK complete$'}).Count){throw ('Visual repository '+$phase+' HTTP count/status differs')}
  if($phase -eq 'cold' -and @($seen|Where-Object {$_ -match '^/manifests/'}).Count -ne 1){throw 'Cold visual repository omitted manifest fetch'}
  if($phase -eq 'repair' -and $seen[0] -notmatch [regex]::Escape($firstHash)){throw 'Visual cache repair fetched a different blob'}
  $rows+=@{phase=$phase;status='pass';requests=$seen.Count;report=$report;reportSha256=(Get-FileHash -LiteralPath $report -Algorithm SHA256).Hash.ToLowerInvariant()}
 }
 $summary=[ordered]@{format='nwn79-nwsync-visual-repository-matrix-v1';success=$true;scope='Private PowerShell HTTP plus Godot repository/store decoding only; world/lobby visual acceptance pending';fixture=$fixture;manifestHash=$descriptor.manifestHash;entries=13;rows=$rows;nodeElectronInvoked=$false}
 $summary|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $output 'summary.json') -Encoding utf8
 Write-Output ('Godot multi-resource NWSync repository PASS: '+(Join-Path $output 'summary.json'))
}finally{
 $env:APPDATA=$previousAppData
 if($process){if(-not$process.HasExited){$process.Kill($true);$process.WaitForExit(5000)|Out-Null};$process.Dispose()}
}
