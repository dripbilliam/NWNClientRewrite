param([ValidatePattern('^[a-z0-9-]{3,80}$')][string]$Run='native-alternate-inventory-source-v1',[string]$Godot='',[string]$Install='')
$ErrorActionPreference='Stop'
$altProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$altWorkspace=[IO.Path]::GetFullPath((Join-Path $altProject '..'))
if(-not$Godot){$Godot=Join-Path $altProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not$Install){$Install=[IO.Path]::GetFullPath((Join-Path $altWorkspace '../FullDecomp/NwnRootInstall'))}
if((Get-FileHash -LiteralPath $Godot -Algorithm SHA256).Hash-ne'AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424'){throw 'Unexpected existing Godot executable'}
$altDirectory=Join-Path $altProject ('.cache/alternate-inventory-tests/'+$Run)
if(Test-Path -LiteralPath $altDirectory){throw 'Owned evidence directory already exists'}
$altCopy=Join-Path $altDirectory 'project';[IO.Directory]::CreateDirectory($altCopy)|Out-Null
$altFiles=@(& rg --files (Join-Path $altProject 'systems') -g '*.gd' -g '*.gdshader' -g '*.json'|ForEach-Object{[IO.Path]::GetRelativePath($altProject,$_).Replace('\','/')})
$altFiles+=@('tests/native_alternate_inventory_source_test.gd','tests/native_skill_description_source_test.gd','tests/native_inventory_window_owner_test.gd','tests/native_quickbar_item_test.gd','tests/native_quickbar_associate_test.gd','tests/native_quickbar_polymorph_test.gd','tests/native_quickbar_context_test.gd','../backups/animations/native-inventory-window-observations-v1.json','tools/test-native-alternate-inventory.ps1')
$altHashes=@()
foreach($altRelative in ($altFiles|Sort-Object -Unique)){
 $altSource=Join-Path $altProject $altRelative;$altDestination=Join-Path $altCopy $altRelative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($altDestination))|Out-Null
 $altHash=(Get-FileHash -LiteralPath $altSource -Algorithm SHA256).Hash.ToLowerInvariant();Copy-Item -LiteralPath $altSource -Destination $altDestination
 if((Get-FileHash -LiteralPath $altDestination -Algorithm SHA256).Hash.ToLowerInvariant()-ne$altHash){throw ('Changed during copy: '+$altRelative)}
 $altHashes+=@{path=$altRelative;sha256=$altHash}
}
[IO.File]::WriteAllText((Join-Path $altCopy 'project.godot'),"config_version=5`n[application]`nconfig/name=""Owned Alternate Inventory CPU Tests""`n[rendering]`nrenderer/rendering_method=""gl_compatibility""`n")
$altCases=@(@('native_inventory_window_owner_test.gd','policy'),@('native_alternate_inventory_source_test.gd','source'),@('native_quickbar_item_test.gd','item'),@('native_quickbar_associate_test.gd','associate'),@('native_quickbar_polymorph_test.gd','polymorph'))
$altResults=@()
foreach($altCase in $altCases){
 $altOutput=Join-Path $altDirectory ($altCase[1]+'.json');$altEngine=Join-Path $altDirectory ($altCase[1]+'.engine.log')
 $altInfo=[Diagnostics.ProcessStartInfo]::new();$altInfo.FileName=$Godot;$altInfo.WorkingDirectory=$altWorkspace;$altInfo.UseShellExecute=$false;$altInfo.CreateNoWindow=$true;$altInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$altInfo.RedirectStandardOutput=$true;$altInfo.RedirectStandardError=$true
 foreach($altArgument in @('--headless','--max-fps','60','--path',$altCopy,'--log-file',$altEngine,'--script',('res://tests/'+$altCase[0]),'--',('--report='+$altOutput),('--install='+$Install),('--oracle='+(Join-Path $altCopy '../backups/animations/native-inventory-window-observations-v1.json')),'--entity-api-rest=false')){$altInfo.ArgumentList.Add($altArgument)}
 $altProcess=[Diagnostics.Process]::Start($altInfo);$altStdout=$altProcess.StandardOutput.ReadToEndAsync();$altStderr=$altProcess.StandardError.ReadToEndAsync();$altTimedOut=$false;$altDeadline=[DateTime]::UtcNow.AddSeconds(35)
 while(-not$altProcess.WaitForExit(500)){if([DateTime]::UtcNow-ge$altDeadline){$altTimedOut=$true;$altProcess.Kill($true);$altProcess.WaitForExit();break}}
 $altProcess.Refresh();[IO.File]::WriteAllText((Join-Path $altDirectory ($altCase[1]+'.stdout.log')),$altStdout.GetAwaiter().GetResult());[IO.File]::WriteAllText((Join-Path $altDirectory ($altCase[1]+'.stderr.log')),$altStderr.GetAwaiter().GetResult())
 $altData=if(Test-Path -LiteralPath $altOutput){Get-Content -LiteralPath $altOutput -Raw|ConvertFrom-Json}else{$null}
 $altClean=(Test-Path -LiteralPath $altEngine)-and([IO.File]::ReadAllText($altEngine)-notmatch '(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB instances leaked|Leaked instance|still in use at exit')
 $altResults+=@{name=$altCase[1];success=[bool]($altData-and$altData.success-and$altClean-and-not$altTimedOut-and$altProcess.ExitCode-eq0);checks=if($altData){$altData.checks}else{0};exitCode=$altProcess.ExitCode;timedOut=$altTimedOut;cleanEngine=$altClean;report=$altOutput;engineLog=$altEngine}
 if(-not$altResults[-1].success){break}
}
$altChanged=@($altHashes|Where-Object{(Get-FileHash -LiteralPath (Join-Path $altProject $_.path) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$_.sha256})
$altReceipt=[ordered]@{success=[bool]($altResults.Count-eq$altCases.Count-and-not($altResults|Where-Object{-not$_.success})-and$altChanged.Count-eq0);directory=$altDirectory;results=$altResults;inputs=$altHashes;changedInputs=$altChanged;nativeBuilds=0;gameServerConnections=0;publicConnections=0;gpu=$false;scope='Copied current native source-window owner policy and installed original frame/physical alternate page/close input; controlled raster/font/icon publication, plus bound39/43/item regressions. No authoritative game-server outcome or pixels.'}
[IO.File]::WriteAllText((Join-Path $altDirectory 'runner.json'),($altReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)
if($altReceipt.success){[IO.File]::WriteAllText((Join-Path $altProject ('reports/'+$Run+'.proof.json')),($altReceipt|ConvertTo-Json -Depth 8)+[Environment]::NewLine)}
[pscustomobject]@{success=$altReceipt.success;directory=$altDirectory;results=$altResults;changedInputs=$altChanged.Count}|ConvertTo-Json -Depth 5
if(-not$altReceipt.success){throw ('Owned alternate inventory checks rejected; exact inputs/logs retained: '+$altDirectory)}
