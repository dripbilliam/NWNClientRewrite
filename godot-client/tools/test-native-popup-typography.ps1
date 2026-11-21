[CmdletBinding()]
param(
 [ValidatePattern('^native-popup-typography-[a-z0-9-]+$')][string]$Run='native-popup-typography-v1',
 [string]$Godot='',
 [string]$Install=''
)
$ErrorActionPreference='Stop'
$popupProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$popupWorkspace=Split-Path $popupProject
if(-not $Godot){$Godot=Join-Path $popupProject '.tools/Godot_v4.7.2-stable_win64.exe'}
if(-not $Install){$Install=[IO.Path]::GetFullPath((Join-Path $popupWorkspace '../FullDecomp/NwnRootInstall'))}
$popupDirectory=Join-Path $popupProject ('.cache/popup-typography/'+$Run)
$popupCopy=Join-Path $popupDirectory 'project'
if(Test-Path -LiteralPath $popupDirectory){throw 'Existing popup typography evidence is preserved; use a fresh label'}
if(-not(Test-Path -LiteralPath $Godot)-or-not(Test-Path -LiteralPath (Join-Path $Install 'lang/en/data/dialog.tlk'))){throw 'Existing pinned Godot and original install are required; no download/build fallback'}
function PopupHash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function PopupSharedText([string]$Path){
 if(-not(Test-Path -LiteralPath $Path)){return ''}
 $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
 $reader=[IO.StreamReader]::new($stream)
 try{return $reader.ReadToEnd()}finally{$reader.Dispose()}
}
$popupEngineHash=PopupHash $Godot
if($popupEngineHash-ne'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'){throw 'Unexpected existing Godot engine identity'}
$popupGuardNames=@('.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json','project.godot','.godot/extension_list.cfg')
$popupGuards=@($popupGuardNames|ForEach-Object{$file=Join-Path $popupProject $_;@{path=$file;sha256=if(Test-Path -LiteralPath $file){PopupHash $file}else{$null}}})
$popupProtected=@(Get-CimInstance Win32_Process|Where-Object{$_.Name-in@('nwmain.exe','nwserver.exe','Godot_v4.7.2-stable_win64.exe','Godot_v4.7.2-stable_win64_console.exe','electron.exe')}|Select-Object ProcessId,Name,ExecutablePath,CreationDate)
[IO.Directory]::CreateDirectory($popupCopy)|Out-Null
$popupFiles=@(Get-ChildItem -LiteralPath (Join-Path $popupProject 'systems') -Recurse -File|Where-Object{$_.Extension-in@('.gd','.gdshader','.glsl','.json')})+@(Get-ChildItem -LiteralPath $popupProject -File -Filter '*.gd')
$popupFiles+=@(Get-Item -LiteralPath (Join-Path $popupProject 'tests/native_popup_typography_test.gd'),$PSCommandPath)
# SessionWorld has guarded probe preloads even when no probe is instantiated.
# Copy their real static closure; never rewrite or stub a copied source file.
$popupSeen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$popupQueue=[Collections.Generic.Queue[string]]::new()
foreach($file in $popupFiles){if($file.Extension-eq'.gd'){$popupQueue.Enqueue($file.FullName)};$popupSeen.Add($file.FullName)|Out-Null}
$popupReferencePattern=@'
(?:(?:preload|load)\s*\(\s*|extends\s+)["']res://([^"']+)["']
'@
while($popupQueue.Count-gt0){
 $popupFile=$popupQueue.Dequeue();$popupBody=[IO.File]::ReadAllText($popupFile)
 foreach($match in [regex]::Matches($popupBody,$popupReferencePattern)){
  $dependency=[IO.Path]::GetFullPath((Join-Path $popupProject $match.Groups[1].Value))
  if(-not$dependency.StartsWith($popupProject+[IO.Path]::DirectorySeparatorChar)){throw 'Popup dependency escaped project'}
  if(-not(Test-Path -LiteralPath $dependency -PathType Leaf)){continue}
  if($popupSeen.Add($dependency)){$popupFiles+=Get-Item -LiteralPath $dependency;if([IO.Path]::GetExtension($dependency)-eq'.gd'){$popupQueue.Enqueue($dependency)}}
 }
}
foreach($relative in @('native/particle_kernel.gdextension','native/resource_index.gdextension','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-resource-index/nwn-resource-index.dll')){
 $file=Join-Path $popupProject $relative
 if(Test-Path -LiteralPath $file){$popupFiles+=Get-Item -LiteralPath $file}
}
$popupPins=@();$popupBytes=0
foreach($file in $popupFiles|Sort-Object FullName -Unique){
 $relative=[IO.Path]::GetRelativePath($popupProject,$file.FullName)
 if($relative.StartsWith('..')){throw 'Popup source copy escapes project'}
 $bytes=[IO.File]::ReadAllBytes($file.FullName);$popupBytes+=$bytes.Length
 if($popupPins.Count-ge2000-or$popupBytes-gt64MB){throw 'Popup copied source bound exceeded'}
 $target=Join-Path $popupCopy $relative;[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))|Out-Null
 [IO.File]::WriteAllBytes($target,$bytes);$hash=PopupHash $file.FullName
 if((PopupHash $target)-ne$hash){throw 'Popup source changed during copied snapshot'}
 $popupPins+=@{source=$file.FullName;copy=$target;relative=$relative;sha256=$hash}
}
$popupProjectText="config_version=5`n[application]`nconfig/name=`"Owned $Run`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n"
[IO.File]::WriteAllText((Join-Path $popupCopy 'project.godot'),$popupProjectText,[Text.UTF8Encoding]::new($false))
$popupReport=Join-Path $popupDirectory 'result.json';$popupLog=Join-Path $popupDirectory 'engine.log';$popupOut=Join-Path $popupDirectory 'stdout.log';$popupErr=Join-Path $popupDirectory 'stderr.log'
$popupArgs=@('--headless','--max-fps','60','--path',('"'+$popupCopy+'"'),'--log-file',('"'+$popupLog+'"'),'--script','res://tests/native_popup_typography_test.gd','--',('"--report='+$popupReport+'"'),('"--install='+$Install+'"'))
[IO.File]::WriteAllText((Join-Path $popupDirectory 'inventory.json'),(@{inputs=$popupPins;guards=$popupGuards;engine=@{path=$Godot;sha256=$popupEngineHash};arguments=$popupArgs;deadlineMilliseconds=60000;outputBytes=2MB;sourceBytes=$popupBytes;scope='Headless actual font/control correctness; no framebuffer, network or build'}|ConvertTo-Json -Depth 7))
$popupOwned=$null;$popupFailure=$null;$popupResult=$null;$popupTimedOut=$false;$popupKilled=$false;$popupExit=$null
try{
 $popupOwned=Start-Process -FilePath $Godot -ArgumentList $popupArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $popupOut -RedirectStandardError $popupErr
 $popupDeadline=[DateTime]::UtcNow.AddMilliseconds(60000)
 while(-not$popupOwned.WaitForExit(200)){
  $total=0;foreach($file in @($popupOut,$popupErr,$popupLog)){if(Test-Path -LiteralPath $file){$total+=(Get-Item -LiteralPath $file).Length}}
  if($total-gt2MB){$popupFailure='Owned output exceeded2MiB';break}
  if([DateTime]::UtcNow-ge$popupDeadline){$popupTimedOut=$true;$popupFailure='Owned headless deadline exceeded60s';break}
  if(((PopupSharedText $popupErr)+(PopupSharedText $popupOut))-match'SCRIPT ERROR|Parse Error|(?m)^ERROR:'){$popupFailure='Owned engine reported an error';break}
 }
 if(-not$popupOwned.HasExited){$popupKilled=$true;$popupOwned.Kill($true);$popupOwned.WaitForExit()}
 $popupOwned.WaitForExit();$popupOwned.Refresh();$popupExit=$popupOwned.ExitCode
 if(Test-Path -LiteralPath $popupReport){$popupResult=Get-Content -LiteralPath $popupReport -Raw|ConvertFrom-Json}else{$popupFailure??='No popup result receipt'}
}catch{$popupFailure=$_.Exception.Message}
finally{
 if($null-ne$popupOwned-and-not$popupOwned.HasExited){$popupKilled=$true;$popupOwned.Kill($true);$popupOwned.WaitForExit()}
 $popupChangedSources=@($popupPins|Where-Object{(PopupHash $_.source)-ne$_.sha256}|ForEach-Object relative)
 $popupChangedCopies=@($popupPins|Where-Object{(PopupHash $_.copy)-ne$_.sha256}|ForEach-Object relative)
 $popupChangedGuards=@($popupGuards|Where-Object{$now=if(Test-Path -LiteralPath $_.path){PopupHash $_.path}else{$null};$now-ne$_.sha256}|ForEach-Object path)
 $popupProcesses=@($popupProtected|ForEach-Object{$before=$_;$now=Get-CimInstance Win32_Process -Filter ('ProcessId='+$before.ProcessId);@{processId=$before.ProcessId;name=$before.Name;unchanged=[bool]($now-and$now.Name-eq$before.Name-and$now.ExecutablePath-eq$before.ExecutablePath-and$now.CreationDate-eq$before.CreationDate)}})
 $popupText=(PopupSharedText $popupLog)+"`n"+(PopupSharedText $popupErr)+"`n"+(PopupSharedText $popupOut)
 $popupClean=$popupText-notmatch'(?m)^ERROR:|^WARNING:|SCRIPT ERROR|Parse Error|ObjectDB.*leak|resources still in use|Unicode parsing error'
 $popupClosed=$null-ne$popupOwned-and$popupOwned.HasExited
 $popupEngineSame=(PopupHash $Godot)-eq$popupEngineHash
 $popupSuccess=$popupClosed-and$popupExit-eq0-and-not$popupFailure-and$popupClean-and$popupResult.success-and-not$popupChangedSources.Count-and-not$popupChangedCopies.Count-and-not$popupChangedGuards.Count-and-not($popupProcesses.unchanged-contains$false)-and$popupEngineSame
 $popupProof=@{success=[bool]$popupSuccess;run=$Run;failure=$popupFailure;checks=if($popupResult){$popupResult.checks}else{0};failures=if($popupResult){@($popupResult.failures)}else{@()};engineClean=$popupClean;ownedPid=if($popupOwned){$popupOwned.Id}else{$null};ownedClosed=$popupClosed;exitCode=$popupExit;timedOut=$popupTimedOut;killRequested=$popupKilled;deadlineMilliseconds=60000;outputBytes=2MB;inputs=$popupPins;changedSources=$popupChangedSources;changedCopies=$popupChangedCopies;guards=$popupGuards;changedGuards=$popupChangedGuards;protectedProcesses=$popupProcesses;engineSha256=$popupEngineHash;engineUnchanged=$popupEngineSame;report=$popupReport;headless=$true;gpu=$false;framebuffer=$false;nativeBuilds=0;serverConnections=0;profileOrKeyReads=0;mainExtensionListWritten=$false;originalPixelsAccepted=$false;scope='Installed native fonts/models and actual popup controls/fitting/style/lifecycle; actual HUD borrowing with authored projection/received rows, SessionWorld graph compilation; no renderer/server/complete pixel parity'}
 [IO.File]::WriteAllText((Join-Path $popupDirectory 'proof.json'),($popupProof|ConvertTo-Json -Depth 9))
 @{success=[bool]$popupSuccess;run=$Run;checks=$popupProof.checks;failures=$popupProof.failures;failure=$popupFailure;ownedPid=$popupProof.ownedPid;ownedClosed=$popupClosed;engineClean=$popupClean;sourcePins=$popupPins.Count;changedSources=$popupChangedSources;changedCopies=$popupChangedCopies;changedGuards=$popupChangedGuards;proof=(Join-Path $popupDirectory 'proof.json')}|ConvertTo-Json -Depth 6
}
if(-not$popupSuccess){exit 1}
