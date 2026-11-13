# SOURCE-PREPARED ONLY. This builds a private DLL: root must grant a CPU/build
# lane before execution. AST inspection does not execute this file.
param([Parameter(Mandatory=$true)][string]$Label)
$ErrorActionPreference='Stop'
if($Label -notmatch '^terrain-height-build-[a-z0-9-]+$'){throw 'Owned terrain-height-build label required'}
$heightRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$heightStage=[IO.Path]::GetFullPath((Join-Path $heightRoot ('.cache/native-140fps/loading-agent/'+$Label)))
$heightProject=Join-Path $heightStage 'project'
$heightDraftFile=Join-Path $heightStage 'draft.json'
$heightDraft=Get-Content -Raw -LiteralPath $heightDraftFile | ConvertFrom-Json
$heightDraftSha=(Get-FileHash -LiteralPath $heightDraftFile -Algorithm SHA256).Hash.ToLowerInvariant()
$heightOverlaySha='a89f2889d7288c3225d9fff963bc6d5c9358be56e38044567f158663ba21d5a1'
if($heightDraft.kind-ne'unbuilt-height-native-candidate'-or$heightDraft.label-ne$Label-or[IO.Path]::GetFullPath($heightDraft.project)-ne$heightProject-or[IO.Path]::GetFullPath($heightDraft.stage)-ne$heightStage-or$heightDraft.sourceOverlay.sha256-ne$heightOverlaySha-or$heightDraft.launchable-ne$false-or-not$heightStage.StartsWith($heightRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Pinned draft/output ownership differs'}
$heightOutput=Join-Path $heightStage 'build-output'
if(Test-Path -LiteralPath $heightOutput){throw 'Existing build evidence preserved; use a fresh staged label'}
New-Item -ItemType Directory -Path $heightOutput | Out-Null
$heightProof=Join-Path $heightOutput 'build-proof.json'
$heightCompilerExit=$null;$heightCompilerInvoked=$false;$heightStarted=[DateTime]::UtcNow.ToString('o')
$heightPreviousInclude=$env:INCLUDE;$heightPreviousLib=$env:LIB
$heightDidPush=$false
try{
 $heightOverlayInput=Join-Path $heightStage 'source-overlay-input.json'
 if((Get-FileHash -LiteralPath $heightOverlayInput -Algorithm SHA256).Hash.ToLowerInvariant()-ne$heightOverlaySha-or$heightDraft.parent.sha256-ne'7a4a6a2728886b5d0de135e13e66ae829426414cac70289231fafd1974a7cb74'-or$heightDraft.baseBinary-ne'101efc79d3c2985d2267d05f9ffbd01578d2f14bbf52bad575ef921cd2412417'){throw 'Reviewed overlay/parent proof differs'}
 $heightOverlay=Get-Content -Raw -LiteralPath $heightOverlayInput | ConvertFrom-Json
 if($heightOverlay.outputs.Count-ne5){throw 'Exactly five reviewed height source outputs required'}
 foreach($heightOverlayPin in $heightOverlay.outputs){if((Get-FileHash -LiteralPath (Join-Path $heightProject $heightOverlayPin.relative) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$heightOverlayPin.sha256){throw ('Frozen height overlay changed '+$heightOverlayPin.relative)}}
 $heightBuilderSha=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
 [IO.File]::WriteAllBytes((Join-Path $heightOutput 'builder.input.ps1'),[IO.File]::ReadAllBytes($PSCommandPath))
 if(-not[string]::IsNullOrWhiteSpace($env:CL)-or-not[string]::IsNullOrWhiteSpace($env:_CL_)){throw 'Unreviewed implicit MSVC CL/_CL_ options are not permitted'}
 $heightExpected=@{}
 foreach($heightPin in $heightDraft.nativeSourcePins){
  if($heightPin.relative-notmatch'^native/[^:]+$'-or$heightPin.relative-match'(^|/)\.\.?(/|$)' -or $heightPin.relative.Contains('\') -or $heightExpected.ContainsKey($heightPin.relative)){throw 'Unsafe/duplicate native source pin'}
  $heightExpected[$heightPin.relative]=$heightPin.sha256
 }
 if($heightExpected.Count-lt5){throw 'Complete conservative native source inventory required'}
 $heightActual=@(Get-ChildItem -LiteralPath (Join-Path $heightProject 'native') -File -Recurse)
 if($heightActual.Count-ne$heightExpected.Count){throw 'Unpinned native file added or pinned source missing'}
 $heightSources=@()
 foreach($heightFile in $heightActual){
  if(($heightFile.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw 'Regular private native inputs required'}
  $heightRelative=$heightFile.FullName.Substring($heightProject.Length+1).Replace('\','/')
  $heightSha=(Get-FileHash -LiteralPath $heightFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  if(-not$heightExpected.ContainsKey($heightRelative)-or$heightSha-ne$heightExpected[$heightRelative]){throw ('Native source differs '+$heightRelative)}
  $heightSources+=@{relative=$heightRelative;sha256=$heightSha}
 }
 $heightApiRoot=Join-Path $heightRoot '.tools/extension-api'
 $heightHeader=Join-Path $heightApiRoot 'gdextension_interface.h';$heightApiFile=Join-Path $heightApiRoot 'extension_api.json'
 $heightHeaderSha=(Get-FileHash -LiteralPath $heightHeader -Algorithm SHA256).Hash.ToLowerInvariant();$heightApiSha=(Get-FileHash -LiteralPath $heightApiFile -Algorithm SHA256).Hash.ToLowerInvariant()
 if($heightHeaderSha-ne'640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'-or$heightApiSha-ne'd0e4c08c03b165156dabe6bfb6a906baf0069189f62035341230a246c86d6986'){throw 'Reviewed Godot API bytes differ'}
 $heightApi=Get-Content -Raw -LiteralPath $heightApiFile | ConvertFrom-Json
 if($heightApi.header.version_full_name-ne'Godot Engine v4.7.2.stable.official'-or$heightApi.header.precision-ne'single'){throw 'Pinned Godot single-precision ABI required'}
 $heightSizes=($heightApi.builtin_class_sizes | Where-Object build_configuration -eq float_64).sizes
 $heightSizeProof=@{}
 foreach($heightPair in @(@('Variant',24),@('StringName',8),@('String',8),@('Vector2',8),@('Vector3',12),@('Transform3D',48),@('Quaternion',16),@('PackedFloat64Array',16),@('PackedByteArray',16))){
  $heightRows=@($heightSizes | Where-Object name -eq $heightPair[0])
  if($heightRows.Count-ne1-or$heightRows[0].size-ne$heightPair[1]){throw ('GDExtension ABI size differs '+$heightPair[0])}
  $heightSizeProof[$heightPair[0]]=[int]$heightRows[0].size
 }
 $heightVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
 $heightVs=@(& $heightVsWhere -all -prerelease -products '*' -property installationPath) | Where-Object {Test-Path -LiteralPath (Join-Path $_ 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')} | Select-Object -First 1
 if(-not$heightVs){throw 'MSVC unavailable'}
 $heightVersion=(Get-Content -Raw -LiteralPath (Join-Path $heightVs 'VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt')).Trim()
 $heightTools=Join-Path $heightVs ('VC/Tools/MSVC/'+$heightVersion);$heightCompiler=Join-Path $heightTools 'bin/Hostx64/x64/cl.exe'
 $heightCompilerSha=(Get-FileHash -LiteralPath $heightCompiler -Algorithm SHA256).Hash.ToLowerInvariant()
 $heightSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
 $heightInclude=Get-ChildItem -LiteralPath (Join-Path $heightSdk 'Include') -Directory | Sort-Object Name -Descending | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')} | Select-Object -First 1
 if(-not$heightInclude){throw 'Windows SDK unavailable'}
 $env:INCLUDE=((Join-Path $heightTools 'include'),(Join-Path $heightInclude.FullName 'ucrt'),(Join-Path $heightInclude.FullName 'shared'),(Join-Path $heightInclude.FullName 'um')) -join ';'
 $env:LIB=((Join-Path $heightTools 'lib/x64'),(Join-Path $heightSdk ('Lib/'+$heightInclude.Name+'/ucrt/x64')),(Join-Path $heightSdk ('Lib/'+$heightInclude.Name+'/um/x64'))) -join ';'
 $heightBinary=Join-Path $heightOutput 'nwn-particle-kernel.dll'
 $heightArguments=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD','/I',$heightApiRoot,(Join-Path $heightProject 'native/particle_kernel.cpp'),('/Fe:'+$heightBinary),'/link','/INCREMENTAL:NO')
 Push-Location $heightOutput;$heightDidPush=$true
 $heightCompilerInvoked=$true
 & $heightCompiler @heightArguments *> (Join-Path $heightOutput 'compiler.log')
 $heightCompilerExit=$LASTEXITCODE
 if($heightCompilerExit-ne0){throw ('Private height native compiler exit '+$heightCompilerExit)}
 Pop-Location;$heightDidPush=$false
 if((Get-FileHash -LiteralPath $heightDraftFile -Algorithm SHA256).Hash.ToLowerInvariant()-ne$heightDraftSha){throw 'Draft changed during build'}
 foreach($heightPin in $heightSources){if((Get-FileHash -LiteralPath (Join-Path $heightProject $heightPin.relative) -Algorithm SHA256).Hash.ToLowerInvariant()-ne$heightPin.sha256){throw ('Native source changed during build '+$heightPin.relative)}}
 if(@(Get-ChildItem -LiteralPath (Join-Path $heightProject 'native') -File -Recurse).Count-ne$heightSources.Count){throw 'Native source inventory changed during build'}
 if((Get-FileHash -LiteralPath $heightHeader -Algorithm SHA256).Hash.ToLowerInvariant()-ne$heightHeaderSha-or(Get-FileHash -LiteralPath $heightApiFile -Algorithm SHA256).Hash.ToLowerInvariant()-ne$heightApiSha-or(Get-FileHash -LiteralPath $heightCompiler -Algorithm SHA256).Hash.ToLowerInvariant()-ne$heightCompilerSha-or(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()-ne$heightBuilderSha-or(Get-FileHash -LiteralPath (Join-Path $heightOutput 'builder.input.ps1') -Algorithm SHA256).Hash.ToLowerInvariant()-ne$heightBuilderSha){throw 'Compiler/API/builder bytes changed during build'}
 $heightReceipt=@{version=1;kind='isolated-terrain-height-native-build';success=$true;exit=0;testOnly=$false;label=$Label;sourceProject=$heightProject;compiledSourceRoot=$heightProject;translationUnit='native/particle_kernel.cpp';sourceInventory=$heightSources;sourceInventoryScope='Complete pinned native directory as conservative compiler-input superset; not a minimal include-graph claim';draftSha256=$heightDraftSha;sourceOverlaySha256=$heightOverlaySha;builder=@{file=$PSCommandPath;sha256=$heightBuilderSha;copiedInput='builder.input.ps1'};binary=$heightBinary;binarySha256=(Get-FileHash -LiteralPath $heightBinary -Algorithm SHA256).Hash.ToLowerInvariant();headerSha256=$heightHeaderSha;apiSha256=$heightApiSha;abi=@{version=$heightApi.header.version_full_name;precision=$heightApi.header.precision;buildConfiguration='float_64';sizes=$heightSizeProof};compiler=$heightVersion;compilerFile=$heightCompiler;compilerSha256=$heightCompilerSha;windowsSdk=$heightInclude.Name;flags='/O2 /fp:strict /EHsc /W4 /WX /std:c++17 /MD /LD';arguments=$heightArguments;startedAt=$heightStarted;endedAt=[DateTime]::UtcNow.ToString('o');nativeBuilds=1;engineStarts=0;sharedOutputWrites=0;pureGoldenRerun=$false;scope='Build provenance only. No new native/golden/caller/physical/authority/visual/performance test has run.'}
 $heightReceipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $heightProof -Encoding utf8
 Write-Output ('Private native height build recorded: '+$heightProof)
}catch{
 @{version=1;kind='isolated-terrain-height-native-build';success=$false;label=$Label;sourceProject=$heightProject;compiledSourceRoot=$heightProject;draftSha256=$heightDraftSha;sourceOverlaySha256=$heightOverlaySha;compilerInvoked=$heightCompilerInvoked;compilerExit=$heightCompilerExit;reason=$_.Exception.Message;startedAt=$heightStarted;endedAt=[DateTime]::UtcNow.ToString('o');engineStarts=0;sharedOutputWrites=0;scope='Failed private build/preflight evidence preserved; not an accepted DLL'} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $heightProof -Encoding utf8
 throw
}finally{
 if($heightDidPush){Pop-Location}
 $env:INCLUDE=$heightPreviousInclude;$env:LIB=$heightPreviousLib
}
