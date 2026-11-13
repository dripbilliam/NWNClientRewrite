[CmdletBinding()]
param(
 [ValidatePattern('^[a-z0-9-]+$')][string]$Stage='rd-lifecycle-probe-v1',
 [Parameter(Mandatory)][ValidateSet('safe','separate')][string]$ThreadMode,
 [ValidateSet('debug','release','custom')][string]$Engine='debug',
 [string]$EngineFile,
 [ValidatePattern('^[a-f0-9]{64}$')][string]$EngineSha256,
 [ValidatePattern('^[a-z0-9-]+$')][string]$Run=('probe-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
)
$ErrorActionPreference='Stop'
$renderProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$renderStage=Join-Path $renderProject ('.cache/native-140fps/render-agent/'+$Stage)
$renderManifestFile=Join-Path $renderStage 'manifest.json'
$renderManifest=Get-Content -LiteralPath $renderManifestFile -Raw|ConvertFrom-Json
foreach($renderPin in $renderManifest.pins){if((Get-FileHash -LiteralPath (Join-Path $renderStage $renderPin.relative)).Hash.ToLowerInvariant()-ne$renderPin.sha256){throw ('Probe source drift: '+$renderPin.relative)}}
if($Engine-eq'custom'){
 if(-not$EngineFile-or-not$EngineSha256){throw 'A private custom engine and its recorded SHA-256 are required'}
 $renderBinary=[IO.Path]::GetFullPath($EngineFile)
 $renderPrivateRoot=[IO.Path]::GetFullPath((Join-Path $renderProject '.cache/native-140fps/render-agent'))+[IO.Path]::DirectorySeparatorChar
 if(-not$renderBinary.StartsWith($renderPrivateRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Custom lifecycle engines must remain in the private rendering stage'}
}else{
 if($EngineFile-or$EngineSha256){throw 'Engine overrides are only supported for the private custom mode'}
 $renderBinary=Join-Path $renderProject $(if($Engine-eq'release'){'.tools/windows_release_x86_64.exe'}else{'.tools/Godot_v4.7.2-stable_win64.exe'})
}
$renderHash=(Get-FileHash -LiteralPath $renderBinary).Hash.ToLowerInvariant()
if($Engine-eq'release'-and$renderHash-ne'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'){throw 'Verified release runtime drifted'}
if($Engine-eq'custom'-and$renderHash-ne$EngineSha256){throw 'Pinned custom engine drifted'}
. (Join-Path $renderProject 'tools/native-window-screen.ps1')
$renderScreen=Get-NativeSecondaryScreen
if($renderScreen-lt0){throw 'A nonprimary screen is required for the visual probe'}
$renderDirectory=Join-Path $renderStage ($Engine+'-'+$ThreadMode+'-'+$Run)
if(Test-Path -LiteralPath $renderDirectory){throw 'Existing engine evidence is preserved'}
New-Item -ItemType Directory -Path $renderDirectory|Out-Null
$renderStdout=Join-Path $renderDirectory 'stdout.log'
$renderStderr=Join-Path $renderDirectory 'stderr.log'
$renderArguments=@('--path',('"'+(Join-Path $renderStage $ThreadMode)+'"'),'--script','res://probe.gd','--rendering-method','forward_plus','--rendering-driver','vulkan','--screen',[string]$renderScreen,'--resolution','400x240','--verbose')
$renderInvocation=@{engine=$Engine;binary=$renderBinary;sha256=$renderHash;arguments=$renderArguments;screen=$renderScreen;normalQuit=$true;appExtensions=0;serverConnections=0;graphical=$true}
[IO.File]::WriteAllText((Join-Path $renderDirectory 'invocation.json'),($renderInvocation|ConvertTo-Json -Depth 4))
$renderProcess=Start-Process -FilePath $renderBinary -ArgumentList $renderArguments -WindowStyle Hidden -RedirectStandardOutput $renderStdout -RedirectStandardError $renderStderr -PassThru
$renderExited=$renderProcess.WaitForExit(15000)
if(-not$renderExited){throw ('Probe did not quit normally; process preserved for root inspection: '+$renderProcess.Id)}
$renderProcess.Refresh()
$renderOutput=Get-Content -LiteralPath $renderStdout -Raw
$renderErrors=Get-Content -LiteralPath $renderStderr -Raw
$renderRows=@()
foreach($renderLine in ($renderOutput-split'\r?\n')){if($renderLine.StartsWith('NATIVE_RD_LIFECYCLE ')){$renderRows+=($renderLine.Substring(20)|ConvertFrom-Json)}}
$renderLifecycleError=([string]$renderErrors)-match'This function \(finalize\) can only be called from the render thread'
$renderLeaked=([string]$renderErrors)-match'ObjectDB instances were leaked'
$renderUnexpected=([string]$renderErrors)-match'SCRIPT ERROR|ERROR:'
$renderQuit=@($renderRows|Where-Object kind -eq normal_quit)
$renderSourcesUnchanged=$true
foreach($renderPin in $renderManifest.pins){if((Get-FileHash -LiteralPath (Join-Path $renderStage $renderPin.relative)).Hash.ToLowerInvariant()-ne$renderPin.sha256){$renderSourcesUnchanged=$false}}
$renderReceipt=@{completedNormally=($renderProcess.ExitCode-eq0-and$renderQuit.Count-eq1);clean=($renderProcess.ExitCode-eq0-and$renderQuit.Count-eq1-and-not$renderUnexpected-and-not$renderLeaked);threadMode=$ThreadMode;engine=$Engine;exitCode=$renderProcess.ExitCode;rows=$renderRows;finalizeWrongThread=$renderLifecycleError;objectLeaks=$renderLeaked;sourceUnchanged=$renderSourcesUnchanged;directory=$renderDirectory;applicationExtensions=0;serverConnections=0;graphical=$true}
[IO.File]::WriteAllText((Join-Path $renderDirectory 'receipt.json'),($renderReceipt|ConvertTo-Json -Depth 6))
$renderReceipt|ConvertTo-Json -Depth 6
# A reproduced engine defect is evidence, not acceptance of a clean lifecycle.
if(-not$renderReceipt.completedNormally-or-not$renderSourcesUnchanged){exit 1}
