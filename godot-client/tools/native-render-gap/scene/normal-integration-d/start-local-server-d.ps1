param([Parameter(Mandatory=$true)][string]$Config)
$ErrorActionPreference='Stop'
$localDConfig=Get-Content -LiteralPath $Config -Raw|ConvertFrom-Json
$localDProject=[IO.Path]::GetFullPath([string]$localDConfig.project)
$localDWorkspace=Split-Path -Parent $localDProject
$localDCase=[IO.Path]::GetFullPath([string]$localDConfig.out)
$localDAllowed=Join-Path $localDProject '.cache/native-render-gap/original/local-authority'
if(-not$localDCase.StartsWith($localDAllowed+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Owned local D receipt directory differs'}
$localDReceipt=Join-Path $localDCase 'server-start-receipt.json'
if(Test-Path -LiteralPath $localDReceipt){throw 'Preserve prior local server start receipt'}
$localDHelper=Join-Path $localDWorkspace 'scripts/local-multiplayer-server.ps1'
$localDStarted=[DateTime]::UtcNow
$localDOutput=@(& $localDHelper -Action Start -Module Prelude)
$localDProfile=[IO.Path]::GetFullPath((Join-Path $localDWorkspace 'runtime-logs/local-multiplayer-server'))
$localDExe=[IO.Path]::GetFullPath((Join-Path $localDWorkspace '../FullDecomp/NwnRootInstall/bin/win32/nwserver.exe'))
$localDProcesses=@(Get-CimInstance Win32_Process -Filter "Name = 'nwserver.exe'"|Where-Object{$_.ExecutablePath-eq$localDExe-and$_.CommandLine-and$_.CommandLine.Contains('"'+$localDProfile+'"')})
if($localDProcesses.Count-ne1){throw 'Owned Prelude server identity differs'}
$localDProcess=[Diagnostics.Process]::GetProcessById([int]$localDProcesses[0].ProcessId)
$localDEndpoint=@();$localDWatch=[Diagnostics.Stopwatch]::StartNew()
while($localDWatch.Elapsed.TotalSeconds-lt30-and-not$localDEndpoint){$localDEndpoint=@(Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction SilentlyContinue|Where-Object OwningProcess -EQ $localDProcess.Id);if(-not$localDEndpoint){Start-Sleep -Milliseconds 200}}
if(-not$localDEndpoint){throw 'Owned Prelude UDP5121 did not become ready'}
$localDResult=@{version=1;success=$true;pid=$localDProcess.Id;path=$localDProcess.MainModule.FileName;sha256=(Get-FileHash -LiteralPath $localDProcess.MainModule.FileName).Hash.ToLowerInvariant();creationFileTimeUtc=$localDProcess.StartTime.ToUniversalTime().ToFileTimeUtc().ToString();profile=$localDProfile;port=5121;module='Prelude';publicServer=$false;helper=@{file=$localDHelper;sha256=(Get-FileHash -LiteralPath $localDHelper).Hash.ToLowerInvariant()};config=@{file=[IO.Path]::GetFullPath($Config);sha256=(Get-FileHash -LiteralPath $Config).Hash.ToLowerInvariant()};stdout=$localDOutput;startedUtc=$localDStarted.ToString('o');readyUtc=[DateTime]::UtcNow.ToString('o');scope='Only existing owned private Prelude helper/profile with no public listing; no native frontend launched by this script. Root owns eventual server Stop.'}
$localDResult|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $localDReceipt -Encoding utf8
$localDProcess.Dispose()
Write-Output ($localDResult|ConvertTo-Json -Compress -Depth 8)
