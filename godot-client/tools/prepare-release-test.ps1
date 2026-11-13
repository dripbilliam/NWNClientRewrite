$ErrorActionPreference='Stop'
$releaseProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$releaseWorkspace=[IO.Path]::GetFullPath((Join-Path $releaseProject '..'))
& (Join-Path $PSScriptRoot 'ensure-release-runtime.ps1')|Out-Host
& (Join-Path $PSScriptRoot 'build-window-modes.ps1')|Out-Host
$releaseInputs=@(& rg --files $releaseProject -g '*.gd' -g '*.gdshader' -g '*.gdshaderinc' -g '*.tscn' -g '*.tres' -g '*.svg' -g '*.json' -g '*.gdextension' -g '!reports/**' -g '!backups/**' -g '!.cache/**' -g '!.tools/**' -g '!.godot/**')|Where-Object {([IO.Path]::GetRelativePath($releaseProject,$_).Replace('\','/').Split('/')[0])-notin@('.cache','.godot','.tools','reports','backups')}
$releaseInputs+=@((Join-Path $releaseProject 'project.godot'),$PSCommandPath)
$releaseInputs+=@((Join-Path $releaseProject 'native/window_modes.c'),(Join-Path $PSScriptRoot 'build-window-modes.ps1'),(Join-Path $releaseProject '.cache/native-window/build-manifest.json'),(Join-Path $releaseProject '.cache/native-window/nwn-window-modes.exe'))
foreach($name in @('global_script_class_cache.cfg','uid_cache.bin')){$file=Join-Path $releaseProject ('.godot/'+$name);if(Test-Path -LiteralPath $file){$releaseInputs+=$file}}
$releaseHash=[Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
try{
 foreach($file in @($releaseInputs|Sort-Object -Unique)){$relative=[IO.Path]::GetFullPath($file).Substring($releaseProject.Length+1).Replace('\','/');$releaseHash.AppendData([Text.Encoding]::UTF8.GetBytes($relative));$releaseHash.AppendData([IO.File]::ReadAllBytes($file))}
 $releaseSignature=[Convert]::ToHexString($releaseHash.GetHashAndReset()).ToLowerInvariant()
}finally{$releaseHash.Dispose()}
$releaseStage=[IO.Path]::GetFullPath((Join-Path $releaseProject ('.cache/release-tests/'+$releaseSignature.Substring(0,16))))
if(-not$releaseStage.StartsWith((Join-Path $releaseProject '.cache')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Release test stage escaped its cache root'}
$releaseDirectory=Join-Path $releaseStage 'project'
New-Item -ItemType Directory -Path $releaseDirectory -Force|Out-Null
$releaseFixtureLink=Join-Path $releaseStage 'backups'
$releaseFixtureSource=Join-Path $releaseWorkspace 'backups'
if(Test-Path -LiteralPath $releaseFixtureLink){
 $existingLink=Get-Item -LiteralPath $releaseFixtureLink
 if(-not($existingLink.Attributes-band[IO.FileAttributes]::ReparsePoint)-or$existingLink.Target-ne$releaseFixtureSource){throw 'Unexpected existing original-evidence link'}
}else{New-Item -ItemType Junction -Path $releaseFixtureLink -Target $releaseFixtureSource|Out-Null}
$releaseExecutable=Join-Path $releaseDirectory 'NwnReleaseTest.exe'
$releaseBinary=Join-Path $releaseProject '.tools/windows_release_x86_64.exe'
if(-not(Test-Path -LiteralPath $releaseExecutable)){New-Item -ItemType HardLink -Path $releaseExecutable -Target $releaseBinary|Out-Null}
if((Get-FileHash -LiteralPath $releaseExecutable -Algorithm SHA256).Hash-ne(Get-FileHash -LiteralPath $releaseBinary -Algorithm SHA256).Hash){throw 'Packaged test executable differs from the verified release runtime'}
$releaseModeDirectory=Join-Path $releaseDirectory '.cache/native-window'
New-Item -ItemType Directory -Path $releaseModeDirectory -Force|Out-Null
$releaseModeSource=Join-Path $releaseProject '.cache/native-window/nwn-window-modes.exe'
$releaseModeBinary=Join-Path $releaseModeDirectory 'nwn-window-modes.exe'
if(-not(Test-Path -LiteralPath $releaseModeBinary)){New-Item -ItemType HardLink -Path $releaseModeBinary -Target $releaseModeSource|Out-Null}
if((Get-FileHash -LiteralPath $releaseModeBinary -Algorithm SHA256).Hash-ne(Get-FileHash -LiteralPath $releaseModeSource -Algorithm SHA256).Hash){throw 'Packaged display mode helper differs from its source build'}
$releaseReport=Join-Path $releaseDirectory 'pack.json'
if(-not(Test-Path -LiteralPath $releaseReport)){
 $releaseEditor=Join-Path $releaseProject '.tools/Godot_v4.7.2-stable_win64.exe'
 & $releaseEditor --headless --path $releaseProject --log-file (Join-Path $releaseDirectory 'pack.engine.log') --script res://tools/prepare-release-pack.gd -- ('--directory='+$releaseDirectory) ('--report='+$releaseReport)|Out-Host
 if($LASTEXITCODE-ne0){throw 'Release test pack preparation failed'}
}
$releaseReceipt=Get-Content -LiteralPath $releaseReport -Raw|ConvertFrom-Json
$releasePack=Join-Path $releaseDirectory 'NwnReleaseTest.pck'
if(-not$releaseReceipt.success-or(Get-FileHash -LiteralPath $releasePack -Algorithm SHA256).Hash.ToLowerInvariant()-ne$releaseReceipt.pack_sha256){throw 'Release test pack is incomplete or changed'}
$releaseSelection=Join-Path $releaseDirectory 'runtime.json'
$releasePackage=[ordered]@{kind='native-release-package';executable=$releaseExecutable;pack=$releasePack;receipt=$releaseReport;directory=$releaseDirectory;sourceSignature=$releaseSignature;packSha256=$releaseReceipt.pack_sha256;originalGameAssetsPacked=$false;selection=$releaseSelection}
if(-not(Test-Path -LiteralPath $releaseSelection)){[IO.File]::WriteAllText($releaseSelection,($releasePackage|ConvertTo-Json -Depth 4)+[Environment]::NewLine)}
[pscustomobject]$releasePackage
