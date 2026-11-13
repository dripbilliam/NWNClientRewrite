[CmdletBinding()]
param([switch]$Fetch)
$ErrorActionPreference='Stop'
$tracyProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$tracyVendor=Join-Path $tracyProject '.cache/native-tracy/vendor'
$tracyVersion='0.13.0'
$tracyArchive=Join-Path $tracyVendor ('tracy-v'+$tracyVersion+'.zip')
$tracySource=Join-Path $tracyVendor ('tracy-'+$tracyVersion)
$tracyReceipt=Join-Path $tracyVendor ('tracy-v'+$tracyVersion+'.source.json')
if(-not$Fetch){
 [pscustomobject]@{version=$tracyVersion;archive=$tracyArchive;source=$tracySource;fetch=$false;scope='Source download only. No compiler, binary or installer execution.'}|ConvertTo-Json -Compress
 return
}
if(Test-Path -LiteralPath $tracyReceipt){throw 'Existing dependency receipt retained; review it instead of replacing it'}
if((Test-Path -LiteralPath $tracyArchive)-or(Test-Path -LiteralPath $tracySource)){throw 'Existing partial dependency retained; inspect before another fetch'}
New-Item -ItemType Directory -Path $tracyVendor -Force|Out-Null
$tracyRefUrl='https://api.github.com/repos/wolfpld/tracy/git/ref/tags/v'+$tracyVersion
$tracyRef=Invoke-RestMethod -Uri $tracyRefUrl -Headers @{'User-Agent'='NWN-Tracy-private-build'}
$tracyCommit=$tracyRef.object.sha
if($tracyRef.object.type-eq'tag'){
 $tracyTag=Invoke-RestMethod -Uri $tracyRef.object.url -Headers @{'User-Agent'='NWN-Tracy-private-build'}
 if($tracyTag.object.type-ne'commit'){throw 'Unexpected annotated tag target'}
 $tracyCommit=$tracyTag.object.sha
}
if($tracyCommit-ne'e6b9ea460993a6f093283055ef3c98025b19f909'){throw 'Official tag commit differs from reviewed Tracy0.13.0'}
$tracyUrl='https://github.com/wolfpld/tracy/archive/refs/tags/v'+$tracyVersion+'.zip'
Invoke-WebRequest -Uri $tracyUrl -OutFile $tracyArchive
$tracyArchiveSha=(Get-FileHash -LiteralPath $tracyArchive).Hash.ToLowerInvariant()
Expand-Archive -LiteralPath $tracyArchive -DestinationPath $tracyVendor
if(-not(Test-Path -LiteralPath (Join-Path $tracySource 'public/TracyClient.cpp'))){throw 'Official source archive lacks TracyClient.cpp'}
$tracyPins=@()
foreach($tracyRelative in @('LICENSE','public/TracyClient.cpp','public/tracy/Tracy.hpp','capture/src/capture.cpp','csvexport/src/csvexport.cpp')){
 $tracyFile=Join-Path $tracySource $tracyRelative
 if(Test-Path -LiteralPath $tracyFile){$tracyPins+=@{relative=$tracyRelative;sha256=(Get-FileHash -LiteralPath $tracyFile).Hash.ToLowerInvariant()}}
}
$tracyResult=@{version=$tracyVersion;commit=$tracyCommit;tagRef=$tracyRefUrl;sourceUrl=$tracyUrl;archive=$tracyArchive;archiveSha256=$tracyArchiveSha;source=$tracySource;pins=$tracyPins;fetchedUtc=[DateTime]::UtcNow.ToString('o');binariesExecuted=$false;scope='Official tag-pinned source. Client and capture/export tools must use this exact source revision. No normal client selection changed.'}
$tracyResult|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $tracyReceipt -Encoding utf8
[pscustomobject]@{file=$tracyReceipt;sha256=(Get-FileHash -LiteralPath $tracyReceipt).Hash.ToLowerInvariant();source=$tracySource;commit=$tracyCommit;archiveSha256=$tracyArchiveSha}|ConvertTo-Json -Compress
