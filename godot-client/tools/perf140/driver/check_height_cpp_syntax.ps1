param([Parameter(Mandatory=$true)][ValidatePattern('^height-native-syntax-[a-z0-9-]+$')][string]$Label)
# One translation-unit syntax check only: /Zs emits no object or linked DLL.
$ErrorActionPreference='Stop'
$heightSyntaxProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$heightSyntaxManifest=Join-Path $heightSyntaxProject '.cache/native-140fps/loading-agent/terrain-height-integration-v1/source-overlay.json'
if((Get-FileHash -LiteralPath $heightSyntaxManifest).Hash.ToLowerInvariant()-ne'a89f2889d7288c3225d9fff963bc6d5c9358be56e38044567f158663ba21d5a1'){throw 'Reviewed source overlay changed'}
$heightSyntaxSource=Get-Content -LiteralPath $heightSyntaxManifest -Raw|ConvertFrom-Json
$heightSyntaxOverlay=Join-Path (Split-Path $heightSyntaxManifest -Parent) 'overlay'
foreach($heightSyntaxPin in $heightSyntaxSource.outputs){if($heightSyntaxPin.relative.StartsWith('native/')){if((Get-FileHash -LiteralPath (Join-Path $heightSyntaxOverlay $heightSyntaxPin.relative)).Hash.ToLowerInvariant()-ne$heightSyntaxPin.sha256){throw 'Selected native source drift'}}}
$heightSyntaxOutput=Join-Path $heightSyntaxProject ('.cache/native-140fps/root/'+$Label)
if(Test-Path -LiteralPath $heightSyntaxOutput){throw 'Existing syntax evidence preserved'}
$heightSyntaxVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$heightSyntaxVs=@(& $heightSyntaxVsWhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')}|Select-Object -First 1
if(-not$heightSyntaxVs){throw 'MSVC unavailable'}
$heightSyntaxVersion=(Get-Content -LiteralPath (Join-Path $heightSyntaxVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt') -Raw).Trim()
$heightSyntaxTools=Join-Path $heightSyntaxVs ('VC/Tools/MSVC/'+$heightSyntaxVersion)
$heightSyntaxCompiler=Join-Path $heightSyntaxTools 'bin/Hostx64/x64/cl.exe'
$heightSyntaxSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/Include'
$heightSyntaxInclude=Get-ChildItem -LiteralPath $heightSyntaxSdk -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$heightSyntaxInclude){throw 'Windows SDK unavailable'}
$heightSyntaxPriorInclude=$env:INCLUDE
$env:INCLUDE=((Join-Path $heightSyntaxTools 'include'),(Join-Path $heightSyntaxInclude.FullName 'ucrt'),(Join-Path $heightSyntaxInclude.FullName 'shared'),(Join-Path $heightSyntaxInclude.FullName 'um'))-join';'
$heightSyntaxArgs=@('/nologo','/Zs','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD',('/I'+(Join-Path $heightSyntaxProject '.tools/extension-api')),('/I'+(Join-Path $heightSyntaxOverlay 'native')),('/I'+(Join-Path $heightSyntaxSource.parent.project 'native')),(Join-Path $heightSyntaxOverlay 'native/particle_kernel.cpp'))
New-Item -ItemType Directory -Path $heightSyntaxOutput | Out-Null
Push-Location $heightSyntaxOutput
try{$heightSyntaxLog=@(& $heightSyntaxCompiler @heightSyntaxArgs 2>&1);$heightSyntaxExit=$LASTEXITCODE}finally{Pop-Location;$env:INCLUDE=$heightSyntaxPriorInclude}
$heightSyntaxLog|Set-Content -LiteralPath (Join-Path $heightSyntaxOutput 'compiler.log') -Encoding utf8
$heightSyntaxUnexpected=@(Get-ChildItem -LiteralPath $heightSyntaxOutput -File|Where-Object{$_.Extension-in@('.obj','.dll','.lib','.pdb','.exe')})
$heightSyntaxResult=@{success=$heightSyntaxExit-eq0-and$heightSyntaxUnexpected.Count-eq0;exit=$heightSyntaxExit;compiler=$heightSyntaxVersion;arguments=$heightSyntaxArgs;sourceManifest=$heightSyntaxManifest;sourceManifestSha256=(Get-FileHash -LiteralPath $heightSyntaxManifest).Hash.ToLowerInvariant();unexpectedNativeOutputs=@($heightSyntaxUnexpected|ForEach-Object FullName);nativeDllBuilds=0;objectBuilds=0;worlds=0;gpuRuns=0;serverConnections=0;scope='Selected new native translation-unit syntax only. No code generation, linked library, runtime, numeric equivalence, performance or FPS acceptance.'}
$heightSyntaxResult|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $heightSyntaxOutput 'receipt.json') -Encoding utf8
$heightSyntaxResult|ConvertTo-Json -Compress -Depth 4
if(-not$heightSyntaxResult.success){exit 1}
