param([ValidatePattern('^[a-z0-9-]+$')][string]$Label='a')
$ErrorActionPreference='Stop'
$ripProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$ripOut=Join-Path $ripProject ('.cache/native-render-gap/original/frame-pacing/rip-sampler-'+$Label)
if(Test-Path -LiteralPath $ripOut){throw 'Preserve prior sampler build'}
New-Item -ItemType Directory -Path $ripOut|Out-Null
$ripSource=Join-Path $ripOut 'sample-rip.cpp';Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'sample-rip.cpp') -Destination $ripSource
$ripVsWhere=Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$ripVs=@(& $ripVsWhere -all -prerelease -products '*' -property installationPath)|Where-Object{Test-Path -LiteralPath (Join-Path $_ 'VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64/cl.exe')}|Select-Object -First 1
if(-not$ripVs){throw 'Pinned MSVC unavailable'}
$ripTools=Join-Path $ripVs 'VC/Tools/MSVC/14.50.35717';$ripCompiler=Join-Path $ripTools 'bin/Hostx64/x64/cl.exe'
$ripSdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10';$ripInclude=Get-ChildItem -LiteralPath (Join-Path $ripSdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
$ripOldInclude=$env:INCLUDE;$ripOldLib=$env:LIB
$ripArguments=@('/nologo','/O2','/EHsc','/std:c++17','/MD','/W4','/D_WIN32_WINNT=0x0A00',('/Fo'+(Join-Path $ripOut 'sample-rip.obj')),('/Fe'+(Join-Path $ripOut 'sample-rip.exe')),$ripSource,'/link','/INCREMENTAL:NO')
try{
 $env:INCLUDE=((Join-Path $ripTools 'include'),(Join-Path $ripInclude.FullName 'ucrt'),(Join-Path $ripInclude.FullName 'shared'),(Join-Path $ripInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $ripTools 'lib/x64'),(Join-Path $ripSdk ('Lib/'+$ripInclude.Name+'/ucrt/x64')),(Join-Path $ripSdk ('Lib/'+$ripInclude.Name+'/um/x64')))-join';'
 & $ripCompiler @ripArguments *> (Join-Path $ripOut 'compiler.log');$ripExit=$LASTEXITCODE
 if($ripExit-ne0){Get-Content -LiteralPath (Join-Path $ripOut 'compiler.log') -Tail 24;throw ('Sampler compiler failed '+$ripExit)}
 @{version=1;source=$ripSource;sourceSha256=(Get-FileHash -LiteralPath $ripSource).Hash.ToLowerInvariant();compiler=$ripCompiler;compilerSha256=(Get-FileHash -LiteralPath $ripCompiler).Hash.ToLowerInvariant();sdk=$ripInclude.Name;contextHeaderSha256=(Get-FileHash -LiteralPath (Join-Path $ripInclude.FullName 'um/winnt.h')).Hash.ToLowerInvariant();arguments=$ripArguments;exit=$ripExit;exe=Join-Path $ripOut 'sample-rip.exe';exeSha256=(Get-FileHash -LiteralPath (Join-Path $ripOut 'sample-rip.exe')).Hash.ToLowerInvariant();scope='Private diagnostic build only. No real client sampled; root review required before capture. SDK CONTEXT alignas16, deterministic2-5ms private timer jitter, fixed sample storage, RAII resume.'}|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $ripOut 'build.json') -Encoding utf8
 Write-Output ('Built private sampler '+$ripOut)
}finally{$env:INCLUDE=$ripOldInclude;$env:LIB=$ripOldLib}
