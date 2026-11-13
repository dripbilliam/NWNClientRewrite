[CmdletBinding()]
param([switch]$Fetch)
$ErrorActionPreference='Stop'
$tracyProject=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$tracyVendor=Join-Path $tracyProject '.cache/native-tracy/vendor'
$tracyArchive=Join-Path $tracyVendor 'windows-0.13.0.zip'
$tracyTools=Join-Path $tracyVendor 'windows-0.13.0'
$tracyReceipt=Join-Path $tracyVendor 'windows-0.13.0.tools.json'
$tracyUrl='https://github.com/wolfpld/tracy/releases/download/v0.13.0/windows-0.13.0.zip'
$tracyExpected='3872f4644c2d8f973076484314b189795e4b67d56b13778fe8ab9c2fea4024fb'
if(-not$Fetch){[pscustomobject]@{url=$tracyUrl;sha256=$tracyExpected;fetch=$false}|ConvertTo-Json -Compress;return}
if((Test-Path -LiteralPath $tracyArchive)-or(Test-Path -LiteralPath $tracyTools)-or(Test-Path -LiteralPath $tracyReceipt)){throw 'Existing tools/partial receipt retained; inspect before another fetch'}
New-Item -ItemType Directory -Path $tracyVendor -Force|Out-Null
Invoke-WebRequest -Uri $tracyUrl -OutFile $tracyArchive
if((Get-FileHash -LiteralPath $tracyArchive).Hash.ToLowerInvariant()-ne$tracyExpected){throw 'Official Tracy tools archive digest differs'}
Expand-Archive -LiteralPath $tracyArchive -DestinationPath $tracyTools
$tracyFiles=@(Get-ChildItem -LiteralPath $tracyTools -File -Recurse|ForEach-Object{@{relative=[IO.Path]::GetRelativePath($tracyTools,$_.FullName);bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
$tracyResult=@{version='0.13.0';protocol=76;url=$tracyUrl;archive=$tracyArchive;archiveSha256=$tracyExpected;directory=$tracyTools;files=$tracyFiles;fetchedUtc=[DateTime]::UtcNow.ToString('o');binariesExecuted=$false;scope='Official portable release tools only. No installation, PATH mutation or executable launch.'}
$tracyResult|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $tracyReceipt -Encoding utf8
[pscustomobject]@{file=$tracyReceipt;sha256=(Get-FileHash -LiteralPath $tracyReceipt).Hash.ToLowerInvariant();directory=$tracyTools;files=$tracyFiles.Count}|ConvertTo-Json -Compress
