[CmdletBinding()]
param([ValidatePattern('^[a-z0-9-]+$')][string]$Stage='engine-build-tools-v1')
$ErrorActionPreference='Stop'
$renderProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$renderDirectory=Join-Path $renderProject ('.cache/native-140fps/render-agent/'+$Stage)
if(Test-Path -LiteralPath $renderDirectory){throw 'Existing build-tool evidence is preserved; use a fresh stage'}
New-Item -ItemType Directory -Path $renderDirectory|Out-Null
$renderPythonUrl='https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip'
$renderSconsUrl='https://files.pythonhosted.org/packages/8e/43/d6285848e893c19682c06e92679dc1a07d37ff7ea148747b1df681ec496c/scons-4.11.1-py3-none-any.whl'
$renderPythonArchive=Join-Path $renderDirectory 'python-3.12.10-embed-amd64.zip'
$renderSconsArchive=Join-Path $renderDirectory 'scons-4.11.1-py3-none-any.whl'
Invoke-WebRequest -Uri $renderPythonUrl -OutFile $renderPythonArchive
Invoke-WebRequest -Uri $renderSconsUrl -OutFile $renderSconsArchive
# The Python checksum is published on its exact official release page. The
# SCons SHA-256 is published by the exact-version PyPI metadata endpoint.
if((Get-FileHash -LiteralPath $renderPythonArchive -Algorithm MD5).Hash.ToLowerInvariant()-ne'fe8ef205f2e9c3ba44d0cf9954e1abd3'){throw 'Official Python archive checksum mismatch'}
if((Get-FileHash -LiteralPath $renderSconsArchive).Hash.ToLowerInvariant()-ne'454cef364348053422696e3d2ecb4fa593c96a624f955842eaaea64f95c8d11d'){throw 'Official SCons archive checksum mismatch'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$renderPythonDirectory=Join-Path $renderDirectory 'python'
$renderSconsDirectory=Join-Path $renderDirectory 'scons'
[IO.Compression.ZipFile]::ExtractToDirectory($renderPythonArchive,$renderPythonDirectory)
[IO.Compression.ZipFile]::ExtractToDirectory($renderSconsArchive,$renderSconsDirectory)
# The embedding package remains isolated from machine/user Python packages.
# Only its adjacent stdlib and this staged SCons wheel are available.
[IO.File]::WriteAllText((Join-Path $renderPythonDirectory 'python312._pth'),"python312.zip`n.`n../scons`n")
$renderPython=Join-Path $renderPythonDirectory 'python.exe'
$renderVersion=& $renderPython -m SCons --version 2>&1
if($LASTEXITCODE-ne0){throw ('Private SCons self-check failed: '+($renderVersion-join"`n"))}
$renderReceipt=@{version=1;directory=$renderDirectory;python=$renderPython;pythonSource=$renderPythonUrl;pythonArchiveSha256=(Get-FileHash -LiteralPath $renderPythonArchive).Hash.ToLowerInvariant();pythonExeSha256=(Get-FileHash -LiteralPath $renderPython).Hash.ToLowerInvariant();sconsSource=$renderSconsUrl;sconsArchiveSha256=(Get-FileHash -LiteralPath $renderSconsArchive).Hash.ToLowerInvariant();sconsVersion=$renderVersion;machineInstall=$false;machineEnvironmentChanged=$false;engineBuildStarted=$false}
[IO.File]::WriteAllText((Join-Path $renderDirectory 'manifest.json'),($renderReceipt|ConvertTo-Json -Depth 4))
$renderReceipt|ConvertTo-Json -Depth 4
