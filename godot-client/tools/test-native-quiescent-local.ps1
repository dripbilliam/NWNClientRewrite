[CmdletBinding()]
param(
 [Parameter(Mandatory)][ValidatePattern('^native-world-quiescent-local-[a-z0-9-]+$')][string]$Run,
 [Parameter(Mandatory)][string]$ProtectedKeyFile,
 [ValidateSet('baseline','candidate')][string]$Variant='candidate',
 [string]$RenderOverlay=''
)
$ErrorActionPreference='Stop'
$localProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$localWorkspace=Split-Path -Parent $localProject
. (Join-Path $PSScriptRoot 'native-level-up-no-build.ps1')
Assert-NativeLevelUpNoBuild -Root $localProject
$localExpected=if($Variant-eq'candidate'){'const World=preload("res://systems/native_render/live_world_quiescent_candidate.gd")'}else{'const World=preload("res://systems/native_render/live_world.gd")'}
if(-not [IO.File]::ReadAllText((Join-Path $localProject 'native_live_world.gd')).Contains($localExpected)){throw 'Expected planning variant is not selected'}
$localBootstrap=Join-Path $PSScriptRoot 'native-session-bootstrap.cjs'
$localOverlay=$null
if($RenderOverlay){
 $localOverlayPath=[IO.Path]::GetFullPath($RenderOverlay)
 $localOverlayRoot=[IO.Path]::GetFullPath((Join-Path $localProject '.cache/native-particle-pose-local'))+[IO.Path]::DirectorySeparatorChar
 if(-not$localOverlayPath.StartsWith($localOverlayRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Local overlay escapes its private root'}
 $localOverlay=Get-Content -LiteralPath $localOverlayPath -Raw|ConvertFrom-Json
 if($localOverlay.version-ne1-or$localOverlay.kind-ne'private-particle-pose-local-overlay'-or$localOverlay.run-ne$Run-or$localOverlay.server-ne'127.0.0.1:5121'-or$localOverlay.publicConnections-ne0){throw 'Local renderer overlay identity differs'}
 foreach($pin in $localOverlay.sourcePins){if((Get-FileHash -LiteralPath (Join-Path $localOverlay.rendererProject $pin.relative)).Hash.ToLowerInvariant()-ne$pin.finalSha256){throw 'Copied local renderer source differs'}}
 foreach($pin in $localOverlay.wrappers){if((Get-FileHash -LiteralPath $pin.file).Hash.ToLowerInvariant()-ne$pin.sha256-or(Get-FileHash -LiteralPath $pin.original).Hash.ToLowerInvariant()-ne$pin.originalSha256){throw 'Local wrapper/original differs'}}
 $localBootstrap=$localOverlay.bootstrapWrapper
}
$localProtected=@(Get-Process -Id 7568,25060 -ErrorAction Stop|ForEach-Object{@{id=$_.Id;name=$_.ProcessName;start=$_.StartTime.ToUniversalTime().ToString('o')}})
$localEndpoint=Get-NetUDPEndpoint -LocalPort 5121 -ErrorAction Stop
if(-not @($localEndpoint|Where-Object OwningProcess -eq 7568).Count){throw 'Existing original local server does not own UDP5121'}
$localOwner=Join-Path $localProject ('reports/'+$Run+'.owner.json')
$localHostReport=Join-Path $localProject ('reports/'+$Run+'.json')
if((Test-Path -LiteralPath $localOwner)-or(Test-Path -LiteralPath $localHostReport)){throw 'Existing local evidence is preserved'}
$localGuards=@()
foreach($relative in @('native_live_world.gd','native_session_world.gd','systems/native_render/live_world.gd','systems/native_render/live_world_quiescent_candidate.gd','project.godot','.godot/extension_list.cfg','.cache/native-window/nwn-window-modes.exe','.cache/native-window/build-manifest.json','.cache/native-kernel/nwn-particle-kernel.dll','.cache/native-kernel/build-manifest.json','.cache/native-resource-index/nwn-resource-index.dll','.cache/native-resource-index/build-manifest.json')){
 $localGuards+=@{relative=$relative;sha256=(Get-FileHash -LiteralPath (Join-Path $localProject $relative)).Hash.ToLowerInvariant()}
}
$localPipeName='nwn-private-login-'+[Guid]::NewGuid().ToString('N')
$localPipe=[IO.Pipes.NamedPipeServerStream]::new($localPipeName,[IO.Pipes.PipeDirection]::Out,1,[IO.Pipes.PipeTransmissionMode]::Byte,([IO.Pipes.PipeOptions]::Asynchronous -bor [IO.Pipes.PipeOptions]::CurrentUserOnly))
$localSecure=$null
try{
 $localSecure=Get-Content -LiteralPath $ProtectedKeyFile -Raw|ConvertTo-SecureString
 $localPayload=@{cdKey=[Net.NetworkCredential]::new('',$localSecure).Password}|ConvertTo-Json -Compress
}finally{if($localSecure){$localSecure.Dispose()}}
$localArgs=@($localBootstrap,('--run='+$Run),'--native-runtime=editor','--local-check','--local-cycles=2','--native-headless','--render-profile=gameplay','--particle-presentation=shared','--particle-lighting=pooled',('--private-login-pipe='+$localPipeName))
$localStart=[Diagnostics.ProcessStartInfo]::new()
$localStart.FileName=Join-Path $localWorkspace 'node_modules/electron/dist/electron.exe'
$localStart.WorkingDirectory=$localWorkspace;$localStart.UseShellExecute=$false;$localStart.CreateNoWindow=$true;$localStart.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$localStart.RedirectStandardOutput=$true;$localStart.RedirectStandardError=$true
foreach($argument in $localArgs){$localStart.ArgumentList.Add($argument)}
$localStart.Environment.Remove('ELECTRON_RUN_AS_NODE')|Out-Null
$localStart.Environment['NWN_PARTICLE_KERNEL']='compiled'
foreach($name in @('NWN_RECORD_LOADING','NWN_NATIVE_SOCKET_TRACE')){$localStart.Environment.Remove($name)|Out-Null}
$localChild=[Diagnostics.Process]::Start($localStart)
$localOut=$localChild.StandardOutput.ReadToEndAsync();$localErr=$localChild.StandardError.ReadToEndAsync()
$localMetadata=@{run=$Run;variant=$Variant;pid=$localChild.Id;server='127.0.0.1:5121';cycles=2;headless=$true;nativeBuilds=0;publicConnections=0;protected=$localProtected;guards=$localGuards;declaredDeadlineSeconds=300;closed=$false;startedUtc=[DateTime]::UtcNow.ToString('o')}
if($localOverlay){$localMetadata.renderOverlay=@{file=$localOverlayPath;sha256=(Get-FileHash -LiteralPath $localOverlayPath).Hash.ToLowerInvariant();rendererProject=$localOverlay.rendererProject;wrappers=$localOverlay.wrappers}}
[IO.File]::WriteAllText($localOwner,($localMetadata|ConvertTo-Json -Depth 6))
@{started=$true;run=$Run;pid=$localChild.Id;server='127.0.0.1:5121';nativeBuilds=0;publicConnections=0}|ConvertTo-Json -Compress
try{
 $localTimeout=[Threading.CancellationTokenSource]::new(20000)
 $localPipe.WaitForConnectionAsync($localTimeout.Token).GetAwaiter().GetResult()
 $localBytes=[Text.Encoding]::UTF8.GetBytes($localPayload);$localPayload=''
 $localPipe.Write($localBytes,0,$localBytes.Length)
}finally{$localPayload='';if($localBytes){[Array]::Clear($localBytes,0,$localBytes.Length)};$localPipe.Dispose();if($localTimeout){$localTimeout.Dispose()}}
$localDeadline=[DateTime]::UtcNow.AddSeconds(300);$localTimedOut=$false
while(-not $localChild.WaitForExit(500)){
 if([DateTime]::UtcNow-ge$localDeadline){$localTimedOut=$true;$localChild.Kill($true);$localChild.WaitForExit();break}
}
$localChild.WaitForExit()
[IO.File]::WriteAllText((Join-Path $localProject ('reports/'+$Run+'.stdout.log')),$localOut.GetAwaiter().GetResult())
[IO.File]::WriteAllText((Join-Path $localProject ('reports/'+$Run+'.stderr.log')),$localErr.GetAwaiter().GetResult())
$localChanged=@($localGuards|Where-Object{(Get-FileHash -LiteralPath (Join-Path $localProject $_.relative)).Hash.ToLowerInvariant()-ne$_.sha256}|ForEach-Object relative)
$localProcessProof=@($localProtected|ForEach-Object{$pin=$_;$now=Get-Process -Id $pin.id -ErrorAction SilentlyContinue;@{id=$pin.id;unchanged=[bool]($now-and$now.ProcessName-eq$pin.name-and$now.StartTime.ToUniversalTime().ToString('o')-eq$pin.start)}})
$localResult=if(Test-Path -LiteralPath $localHostReport){Get-Content -LiteralPath $localHostReport -Raw|ConvertFrom-Json}else{$null}
$localOverlayChanged=@();$localOverlayBound=$true
if($localOverlay){
 foreach($pin in $localOverlay.sourcePins){if($pin.relative-ne'benchmark-options.cfg'-and(Get-FileHash -LiteralPath (Join-Path $localOverlay.rendererProject $pin.relative)).Hash.ToLowerInvariant()-ne$pin.finalSha256){$localOverlayChanged+=$pin.relative}}
 $localOverlayBound=$localResult.nativeRenderProjectOverlay.project-eq$localOverlay.rendererProject-and$localResult.nativeRenderProjectOverlay.run-eq$Run
 $localMetadata.renderOverlay.changedSources=$localOverlayChanged;$localMetadata.renderOverlay.bound=[bool]$localOverlayBound
}
$localMetadata.closed=$localChild.HasExited;$localMetadata.exit=$localChild.ExitCode;$localMetadata.timedOut=$localTimedOut;$localMetadata.changedGuards=$localChanged;$localMetadata.protectedProcesses=$localProcessProof;$localMetadata.hostReportPresent=$null-ne$localResult
[IO.File]::WriteAllText($localOwner,($localMetadata|ConvertTo-Json -Depth 6))
$localSuccess=$localResult-and$localResult.success-and$localChild.ExitCode-eq0-and-not$localTimedOut-and-not$localChanged.Count-and-not$localOverlayChanged.Count-and$localOverlayBound-and-not($localProcessProof.unchanged-contains$false)
@{success=[bool]$localSuccess;run=$Run;closed=$localChild.HasExited;exit=$localChild.ExitCode;failure=if($localResult){$localResult.failure}else{'Missing report'};cycles=@($localResult.localCycles).Count;nativeDistance=$localResult.localWalkDistance;serverDistance=$localResult.authoritativeDistance;changedGuards=$localChanged;protectedUnchanged=-not($localProcessProof.unchanged-contains$false)}|ConvertTo-Json -Compress
if(-not$localSuccess){exit 1}
