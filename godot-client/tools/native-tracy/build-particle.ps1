[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Plan,[Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{64}$')][string]$PlanSha,[switch]$Build)
$ErrorActionPreference='Stop'
$tracyPlanFile=[IO.Path]::GetFullPath($Plan)
if((Get-FileHash -LiteralPath $tracyPlanFile).Hash.ToLowerInvariant()-ne$PlanSha){throw 'Private source plan changed'}
$tracyPlan=Get-Content -LiteralPath $tracyPlanFile -Raw|ConvertFrom-Json
$tracyProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if(-not$tracyPlan.particle.StartsWith((Join-Path $tracyProject '.cache/native-tracy/'),[StringComparison]::OrdinalIgnoreCase)){throw 'Private particle source escaped workspace'}
foreach($tracyPin in $tracyPlan.particlePins){if((Get-FileHash -LiteralPath $tracyPin.file).Hash.ToLowerInvariant()-ne$tracyPin.sha256){throw 'Particle source changed'}}
$tracyApi=Join-Path $tracyProject '.tools/extension-api'
if((Get-FileHash -LiteralPath (Join-Path $tracyApi 'gdextension_interface.h')).Hash.ToLowerInvariant()-ne'640b48188708ba0016f8d7ace9e0e1d3279a41fa1226c59ff3193b15538bd254'){throw 'Extension interface changed'}
$tracyOriginal=Get-Content -LiteralPath (Join-Path $tracyProject '.cache/native-render-gap/particles/combined-b/kernel-build/build-receipt.json') -Raw|ConvertFrom-Json
$tracyCompiler=$tracyOriginal.compiler
if((Get-FileHash -LiteralPath $tracyCompiler).Hash.ToLowerInvariant()-ne$tracyOriginal.compilerSha256){throw 'Accepted MSVC compiler changed'}
$tracyCompilerRoot=[IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $tracyCompiler) '../../..'))
$tracySdk=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10'
$tracySdkInclude=Get-ChildItem -LiteralPath (Join-Path $tracySdk 'Include') -Directory|Sort-Object Name -Descending|Where-Object{Test-Path -LiteralPath (Join-Path $_.FullName 'um/Windows.h')}|Select-Object -First 1
if(-not$Build){[pscustomobject]@{ready=$true;compiler=$tracyCompiler;source=$tracyPlan.particle;compiled=$false}|ConvertTo-Json -Compress;return}
$tracyOut=Join-Path $tracyPlan.stage 'particle-build'
if(Test-Path -LiteralPath $tracyOut){throw 'Preserve prior particle build'}
New-Item -ItemType Directory -Path $tracyOut|Out-Null
$tracyBinary=Join-Path $tracyOut 'nwn-particle-kernel.dll'
$tracyArgs=@('/nologo','/O2','/fp:strict','/EHsc','/W4','/WX','/std:c++17','/MD','/LD','/Zi',('/Fd'+(Join-Path $tracyOut 'compiler.pdb')),('/I'+$tracyApi),('/Fo'+(Join-Path $tracyOut 'particle-kernel.obj')),('/Fe'+$tracyBinary),(Join-Path $tracyPlan.particle 'particle_kernel.cpp'),'/link','/DEBUG:FULL','/INCREMENTAL:NO',('/PDB:'+(Join-Path $tracyOut 'nwn-particle-kernel.pdb')),('/IMPLIB:'+(Join-Path $tracyOut 'particle-kernel.lib')))
$tracyOldInclude=$env:INCLUDE;$tracyOldLib=$env:LIB
$tracyProof=@{version=1;success=$false;startedUtc=[DateTime]::UtcNow.ToString('o');compiler=$tracyCompiler;compilerSha256=$tracyOriginal.compilerSha256;arguments=$tracyArgs;plan=$tracyPlanFile;planSha256=$PlanSha;normalRuntimeChanged=$false;scope='Private accepted45-file particle source plus tracing bridge. Same MSVC/O2/strict-FP/MD with PDBs. No FPS or visual acceptance.'}
try{
 $env:INCLUDE=((Join-Path $tracyCompilerRoot 'include'),(Join-Path $tracySdkInclude.FullName 'ucrt'),(Join-Path $tracySdkInclude.FullName 'shared'),(Join-Path $tracySdkInclude.FullName 'um'))-join';'
 $env:LIB=((Join-Path $tracyCompilerRoot 'lib/x64'),(Join-Path $tracySdk ('Lib/'+$tracySdkInclude.Name+'/ucrt/x64')),(Join-Path $tracySdk ('Lib/'+$tracySdkInclude.Name+'/um/x64')))-join';'
 & $tracyCompiler @tracyArgs 2>&1|Tee-Object -FilePath (Join-Path $tracyOut 'compiler.log')
 $tracyProof.exit=$LASTEXITCODE;if($LASTEXITCODE-ne0){throw 'Private traced particle compilation failed'}
 foreach($tracyPin in $tracyPlan.particlePins){if((Get-FileHash -LiteralPath $tracyPin.file).Hash.ToLowerInvariant()-ne$tracyPin.sha256){throw 'Particle source changed during build'}}
 $tracyProof.binary=@{file=$tracyBinary;sha256=(Get-FileHash -LiteralPath $tracyBinary).Hash.ToLowerInvariant()};$tracyProof.symbols=@{file=(Join-Path $tracyOut 'nwn-particle-kernel.pdb');sha256=(Get-FileHash -LiteralPath (Join-Path $tracyOut 'nwn-particle-kernel.pdb')).Hash.ToLowerInvariant()};$tracyProof.success=$true
}catch{$tracyProof.failure=$_.Exception.Message;throw}finally{$env:INCLUDE=$tracyOldInclude;$env:LIB=$tracyOldLib;$tracyProof.finishedUtc=[DateTime]::UtcNow.ToString('o');$tracyProof|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $tracyOut 'receipt.json') -Encoding utf8}
$tracyProof|ConvertTo-Json -Depth 6
