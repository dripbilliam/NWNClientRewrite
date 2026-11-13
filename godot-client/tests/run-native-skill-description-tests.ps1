param([string]$Godot='', [string]$Install='')
$ErrorActionPreference='Stop'
$skillProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$skillWorkspace=[IO.Path]::GetFullPath((Join-Path $skillProject '..'))
if(-not $Godot){$Godot=Join-Path $skillProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not $Install){$Install=[IO.Path]::GetFullPath((Join-Path $skillWorkspace '../FullDecomp/NwnRootInstall'))}
if(-not(Test-Path -LiteralPath $Godot)-or-not(Test-Path -LiteralPath (Join-Path $Install 'lang/en/data/dialog.tlk'))){throw 'Existing native runtime and installed game data are required; this runner never builds or downloads'}
$skillRun=Join-Path $skillProject ('.cache/skill-description-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $skillRun|Out-Null
$skillInputs=@(& rg --files (Join-Path $skillProject 'systems') (Join-Path $skillProject 'tests') -g '*.gd')
$skillInputs+=@((Join-Path $skillProject 'project.godot'),$PSCommandPath)
$skillInputs+=@('src/network_hud_input.js','electron/network_game_session.mjs','test/native-skill-description-protocol.test.js','test/network-game-session.test.js')|ForEach-Object{Join-Path $skillWorkspace $_}
$skillHashes=@{}
foreach($skillSource in $skillInputs){$skillHashes[$skillSource]=(Get-FileHash -LiteralPath $skillSource -Algorithm SHA256).Hash.ToLowerInvariant()}
$skillReport=Join-Path $skillRun 'result.json'; $skillLog=Join-Path $skillRun 'engine.log'
$skillArguments=@('--headless','--path',('"'+$skillProject+'"'),'--log-file',('"'+$skillLog+'"'),'--script','res://tests/native_skill_description_test.gd','--',('"--report='+$skillReport+'"'),('"--install='+$Install+'"'))
$skillOwned=Start-Process -FilePath $Godot -ArgumentList $skillArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $skillRun 'stdout.log') -RedirectStandardError (Join-Path $skillRun 'stderr.log')
$skillTimedOut=-not $skillOwned.WaitForExit(30000)
if($skillTimedOut){$skillOwned.Kill();$skillOwned.WaitForExit()}
$skillOwned.Refresh()
$skillResult=if(Test-Path -LiteralPath $skillReport){Get-Content -LiteralPath $skillReport -Raw|ConvertFrom-Json}else{$null}
$skillEngine=if(Test-Path -LiteralPath $skillLog){[IO.File]::ReadAllText($skillLog)}else{''}
$skillTap=Join-Path $skillRun 'protocol.tap'; $skillProtocolError=Join-Path $skillRun 'protocol.stderr.log'
$skillNode=(Get-Command node -CommandType Application).Source
$skillProtocol=Start-Process -FilePath $skillNode -WorkingDirectory $skillWorkspace -ArgumentList @('--test','test/native-skill-description-protocol.test.js','test/network-game-session.test.js') -WindowStyle Hidden -PassThru -RedirectStandardOutput $skillTap -RedirectStandardError $skillProtocolError
$skillProtocolTimeout=-not $skillProtocol.WaitForExit(30000)
if($skillProtocolTimeout){$skillProtocol.Kill();$skillProtocol.WaitForExit()}
$skillProtocol.Refresh()
$skillProtocolText=[IO.File]::ReadAllText($skillTap)
$skillProtocolChecks=if($skillProtocolText-match '(?m)^# tests (\d+)\r?$'){[int]$Matches[1]}else{0}
$skillChanged=@()
foreach($skillSource in $skillInputs){if((Get-FileHash -LiteralPath $skillSource -Algorithm SHA256).Hash.ToLowerInvariant()-ne$skillHashes[$skillSource]){$skillChanged+=$skillSource}}
$skillClean=$skillEngine-notmatch '(?m)SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB.*leak|resources still in use|Unicode parsing error'
$skillReceipt=[ordered]@{
 success=($null-ne$skillResult-and$skillResult.success-and$skillOwned.ExitCode-eq0-and-not$skillTimedOut-and$skillClean-and$skillProtocol.ExitCode-eq0-and-not$skillProtocolTimeout-and$skillProtocolChecks-gt0-and$skillProtocolText-match '(?m)^# fail 0\r?$'-and$skillChanged.Count-eq0)
 testedAtUtc=[DateTime]::UtcNow.ToString('o'); checks=$skillResult.checks; failures=$skillResult.failures; protocolChecks=$skillProtocolChecks
 headless=$true; rendering='dummy'; gameServerConnections=0; publicConnections=0; nativeBuilds=0; userProcessesTouched=0
 exitCode=$skillOwned.ExitCode; timedOut=$skillTimedOut; protocolExitCode=$skillProtocol.ExitCode; protocolTimedOut=$skillProtocolTimeout; engineClean=$skillClean
 sourceUnchanged=($skillChanged.Count-eq0); changed=$skillChanged; inputs=$skillHashes
 engineSha256=(Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash.ToLowerInvariant(); report=$skillReport; engineLog=$skillLog; protocolTap=$skillTap
 details=$skillResult.diagnostic.additional; sourceSkinArtworkValidated=$false; liveServerValidated=$false
}
$skillReceiptPath=Join-Path $skillRun 'receipt.json'
[IO.File]::WriteAllText($skillReceiptPath,($skillReceipt|ConvertTo-Json -Depth 7)+[Environment]::NewLine)
if($skillReceipt.success){Copy-Item -LiteralPath $skillReceiptPath -Destination (Join-Path $skillProject 'reports/native-skill-description-v1-receipt.json')}
[pscustomobject]@{success=$skillReceipt.success;checks=$skillReceipt.checks;protocolChecks=$skillProtocolChecks;engineClean=$skillClean;sourceUnchanged=$skillReceipt.sourceUnchanged;receipt=$skillReceiptPath;details=$skillReceipt.details}|ConvertTo-Json -Depth 5
if(-not $skillReceipt.success){Get-Content -LiteralPath $skillLog -Tail 20 -ErrorAction SilentlyContinue|Out-Host;exit 1}
