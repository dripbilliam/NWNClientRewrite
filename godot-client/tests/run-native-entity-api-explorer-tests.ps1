param([string]$Godot='',[string]$Electron='')
$ErrorActionPreference='Stop'
$explorerProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$explorerWorkspace=[IO.Path]::GetFullPath((Join-Path $explorerProject '..'))
if(-not$Godot){$Godot=Join-Path $explorerProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not$Electron){$Electron=Join-Path $explorerWorkspace 'node_modules/electron/dist/electron.exe'}
if(-not(Test-Path -LiteralPath $Godot)-or-not(Test-Path -LiteralPath $Electron)){throw 'Explorer test requires the existing Godot and Electron executables; this runner never builds/downloads them'}
$explorerRun=Join-Path $explorerProject ('.cache/entity-api-explorer-tests/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$explorerIsolated=Join-Path $explorerRun 'project'
$explorerState=Join-Path $explorerRun 'state'
[IO.Directory]::CreateDirectory($explorerIsolated)|Out-Null
[IO.Directory]::CreateDirectory($explorerState)|Out-Null
$explorerInputs=@(& rg --files (Join-Path $explorerProject 'systems/client_api') -g '*.gd' | ForEach-Object {[IO.Path]::GetRelativePath($explorerProject,$_).Replace('\','/')})
$explorerInputs+=@('tests/native_entity_api_explorer_fixture.gd','tests/native_entity_api_explorer_browser.cjs','tests/run-native-entity-api-explorer-tests.ps1')
$explorerHashes=@()
foreach($relative in $explorerInputs){
 $source=Join-Path $explorerProject $relative
 $destination=Join-Path $explorerIsolated $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))|Out-Null
 Copy-Item -LiteralPath $source -Destination $destination
 $sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
 if((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$sourceHash){throw ('Explorer input changed while copying: '+$relative)}
 $explorerHashes+=@{path=$relative;sha256=$sourceHash}
}
[IO.File]::WriteAllText((Join-Path $explorerIsolated 'project.godot'),"config_version=5`n[application]`nconfig/name=""Isolated Entity Explorer""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
function Start-ExplorerOwned([string]$Executable,[string[]]$Arguments,[string]$Label){
 $info=[Diagnostics.ProcessStartInfo]::new()
 $info.FileName=$Executable;$info.WorkingDirectory=$explorerWorkspace;$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
 $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $info.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
 foreach($argument in $Arguments){$info.ArgumentList.Add($argument)}
 $process=[Diagnostics.Process]::Start($info)
 return [pscustomobject]@{process=$process;stdout=$process.StandardOutput.ReadToEndAsync();stderr=$process.StandardError.ReadToEndAsync();label=$Label;logged=$false}
}
function Save-ExplorerOwned($Owned){
 if($Owned.logged){return}
 [IO.File]::WriteAllText((Join-Path $explorerRun ($Owned.label+'.stdout.log')),$Owned.stdout.GetAwaiter().GetResult())
 [IO.File]::WriteAllText((Join-Path $explorerRun ($Owned.label+'.stderr.log')),$Owned.stderr.GetAwaiter().GetResult())
 $Owned.logged=$true
}
function Wait-ExplorerOwned($Owned,[int]$Seconds){
 $until=[DateTime]::UtcNow.AddSeconds($Seconds)
 while(-not$Owned.process.WaitForExit(1000)){if([DateTime]::UtcNow-ge$until){$Owned.process.Kill($true);$Owned.process.WaitForExit();Save-ExplorerOwned $Owned;throw ('Stopped only timed-out owned explorer test: '+$Owned.label)}}
 $Owned.process.Refresh();Save-ExplorerOwned $Owned
 return $Owned.process.ExitCode
}
$fixture=$null;$browser=$null
$explorerDiscovery=Join-Path $explorerState 'discovery.private.json'
$explorerBrowserReport=Join-Path $explorerState 'browser-report.json'
try{
 $fixture=Start-ExplorerOwned $Godot @('--headless','--max-fps','60','--path',$explorerIsolated,'--log-file',(Join-Path $explorerRun 'fixture.engine.log'),'--script','res://tests/native_entity_api_explorer_fixture.gd','--','--entity-api-rest=true','--entity-api-rest-port=0',('--entity-api-rest-discovery='+$explorerDiscovery),('--fixture-directory='+$explorerState)) 'fixture'
 $ready=Join-Path $explorerState 'ready.json';$readyDeadline=[DateTime]::UtcNow.AddSeconds(20)
 while(-not(Test-Path -LiteralPath $ready)-and[DateTime]::UtcNow-lt$readyDeadline-and-not$fixture.process.HasExited){Start-Sleep -Milliseconds 100}
 if(-not(Test-Path -LiteralPath $ready)){throw 'Owned Godot explorer fixture did not become ready'}
 $readyState=Get-Content -LiteralPath $ready -Raw|ConvertFrom-Json
 if(-not$readyState.listening){throw 'Owned Godot explorer fixture could not start its listener'}
 $browser=Start-ExplorerOwned $Electron @((Join-Path $explorerIsolated 'tests/native_entity_api_explorer_browser.cjs'),('--fixture-directory='+$explorerState),('--report='+$explorerBrowserReport)) 'browser'
 $browserCode=Wait-ExplorerOwned $browser 80
 $fixtureCode=Wait-ExplorerOwned $fixture 10
 if(-not(Test-Path -LiteralPath $explorerBrowserReport)){throw 'Browser test produced no result'}
 $browserResult=Get-Content -LiteralPath $explorerBrowserReport -Raw|ConvertFrom-Json
 $fixtureResult=Get-Content -LiteralPath (Join-Path $explorerState 'fixture-report.json') -Raw|ConvertFrom-Json
 if($browserCode-ne0-or-not$browserResult.success){throw ('Explorer browser test failed: '+($browserResult.failures -join ', '))}
 if($fixtureCode-ne0-or-not$fixtureResult.success){throw 'Explorer native fixture cleanup failed'}
 if([IO.File]::ReadAllText((Join-Path $explorerRun 'fixture.engine.log'))-match '(?m)^ERROR:|SCRIPT ERROR|WARNING:|ObjectDB instances leaked|still in use at exit'){throw 'Explorer native fixture engine error/leak'}
 foreach($input in $explorerHashes){if((Get-FileHash -LiteralPath (Join-Path $explorerProject $input.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$input.sha256){throw ('Explorer input changed during tests: '+$input.path)}}
 $receipt=[ordered]@{success=$true;testedAtUtc=[DateTime]::UtcNow.ToString('o');directory=$explorerRun;godotSha256=(Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash.ToLowerInvariant();electronSha256=(Get-FileHash -LiteralPath $Electron -Algorithm SHA256).Hash.ToLowerInvariant();inputs=$explorerHashes;browserChecks=$browserResult.checks;fixtureChecks=$fixtureResult.checks;browserReport=$explorerBrowserReport;fixtureReport=(Join-Path $explorerState 'fixture-report.json');screenshot=(Join-Path $explorerState 'explorer-authenticated.png');presentationScreenshot=(Join-Path $explorerState 'explorer-presentation.png');finalScreenshot=(Join-Path $explorerState 'explorer-final.png');gameServerConnections=0;publicConnections=0;nativeBuilds=0;userWindowsLaunched=$false;scope='Actual hidden isolated Chromium external explorer over owned native Godot loopback HTTP; authored entity owners, no running game client or product Electron renderer integration'}
 [IO.File]::WriteAllText((Join-Path $explorerProject 'reports/native-entity-api-explorer-v1-receipt.json'),($receipt|ConvertTo-Json -Depth 7)+[Environment]::NewLine)
 $receipt|ConvertTo-Json -Depth 7
}finally{
 [IO.File]::WriteAllText((Join-Path $explorerState 'stop.json'),'{}')
 foreach($owned in @($browser,$fixture)){
  if($null-eq$owned){continue}
  if(-not$owned.process.HasExited){if(-not$owned.process.WaitForExit(5000)){$owned.process.Kill($true);$owned.process.WaitForExit()}}
  Save-ExplorerOwned $owned
 }
 foreach($name in @('discovery.private.json','malformed.private.json','foreign.private.json','wrong-token.private.json')){$privatePath=Join-Path $explorerState $name;if(Test-Path -LiteralPath $privatePath){Remove-Item -LiteralPath $privatePath}}
}
