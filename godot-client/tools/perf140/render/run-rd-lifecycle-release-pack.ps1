[CmdletBinding()]
param(
 [ValidatePattern('^[a-z0-9-]+$')][string]$Stage='rd-lifecycle-release-pack-v1',
 [Parameter(Mandatory)][ValidateSet('safe','separate')][string]$ThreadMode,
 [ValidatePattern('^[a-z0-9-]+$')][string]$Run=('probe-'+[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
)
$ErrorActionPreference='Stop'
$renderProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$renderStage=Join-Path $renderProject ('.cache/native-140fps/render-agent/'+$Stage)
$renderManifest=Get-Content -LiteralPath (Join-Path $renderStage 'manifest.json') -Raw|ConvertFrom-Json
foreach($renderPin in $renderManifest.pins){if((Get-FileHash -LiteralPath (Join-Path $renderStage $renderPin.relative)).Hash.ToLowerInvariant()-ne$renderPin.sha256){throw ('Probe source drift: '+$renderPin.relative)}}
$renderBinary=Join-Path $renderStage ($ThreadMode+'/probe.exe')
$renderHash=(Get-FileHash -LiteralPath $renderBinary).Hash.ToLowerInvariant()
if($renderHash-ne'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'){throw 'Verified release runtime drifted'}
. (Join-Path $renderProject 'tools/native-window-screen.ps1')
$renderScreen=Get-NativeSecondaryScreen
if($renderScreen-lt0){throw 'A nonprimary screen is required for the visual probe'}
$renderDirectory=Join-Path $renderStage ($ThreadMode+'-'+$Run)
if(Test-Path -LiteralPath $renderDirectory){throw 'Existing engine evidence is preserved'}
New-Item -ItemType Directory -Path $renderDirectory|Out-Null
$renderStdout=Join-Path $renderDirectory 'stdout.log'
$renderStderr=Join-Path $renderDirectory 'stderr.log'
$renderArguments=@('--rendering-method','forward_plus','--rendering-driver','vulkan','--screen',[string]$renderScreen,'--resolution','400x240','--verbose')
$renderInvocation=@{engine='release';binary=$renderBinary;sha256=$renderHash;arguments=$renderArguments;screen=$renderScreen;normalQuit=$true;appExtensions=0;serverConnections=0;graphical=$true;automaticSiblingPck=$true}
[IO.File]::WriteAllText((Join-Path $renderDirectory 'invocation.json'),($renderInvocation|ConvertTo-Json -Depth 4))
$renderProcess=Start-Process -FilePath $renderBinary -ArgumentList $renderArguments -WorkingDirectory (Split-Path -Parent $renderBinary) -WindowStyle Hidden -RedirectStandardOutput $renderStdout -RedirectStandardError $renderStderr -PassThru
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
$renderReceipt=@{completedNormally=($renderProcess.ExitCode-eq0-and$renderQuit.Count-eq1);clean=($renderProcess.ExitCode-eq0-and$renderQuit.Count-eq1-and-not$renderUnexpected-and-not$renderLeaked);threadMode=$ThreadMode;engine='release';exitCode=$renderProcess.ExitCode;rows=$renderRows;finalizeWrongThread=$renderLifecycleError;objectLeaks=$renderLeaked;sourceUnchanged=$renderSourcesUnchanged;directory=$renderDirectory;applicationExtensions=0;serverConnections=0;graphical=$true;automaticSiblingPck=$true}
[IO.File]::WriteAllText((Join-Path $renderDirectory 'receipt.json'),($renderReceipt|ConvertTo-Json -Depth 6))
$renderReceipt|ConvertTo-Json -Depth 6
if(-not$renderReceipt.completedNormally-or-not$renderSourcesUnchanged){exit 1}
