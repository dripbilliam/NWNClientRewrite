param(
    [Parameter(Mandatory)][string]$ResourceDirectory,
    [Parameter(Mandatory)][string]$Repository,
    [string[]]$Archive=@(),
    [ValidateRange(1024,65535)][int]$Port=5137
)
$ErrorActionPreference='Stop'
$client=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
$source=(Resolve-Path -LiteralPath $ResourceDirectory).Path
$repositoryPath=[IO.Path]::GetFullPath($Repository)
if(Test-Path -LiteralPath $repositoryPath){throw 'Repository output already exists'}
$resources=@(Get-ChildItem -LiteralPath $source)
foreach($path in $Archive){
    $file=Get-Item -LiteralPath $path
    if($file.Extension -notin @('.hak','.nwm')){throw 'Named archives must be HAK or NWM files'}
    $resources+=$file
}
if($resources.Count -eq 0 -or $resources.Count -gt 65536){throw 'Expected 1–65536 benchmark resource files'}

# Read resource type IDs from the same table used by the client resolver.
$typeTable=Get-Content -LiteralPath (Join-Path $client 'systems/native_data/resource_extensions.gd') -Raw
$types=@{}
foreach($definition in [regex]::Matches($typeTable,'(?m)^[ \t]*"([0-9a-z]+)":([0-9]+),\r?$')){
    $types[$definition.Groups[1].Value]=[uint16]$definition.Groups[2].Value
}
$rows=[Collections.Generic.SortedDictionary[string,object]]::new([StringComparer]::Ordinal)
foreach($resource in $resources){
    if($resource.PSIsContainer -or ($resource.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Expected a flat directory of authored files'}
    $name=$resource.BaseName.ToLowerInvariant()
    $extension=$resource.Extension.TrimStart('.').ToLowerInvariant()
    if($name -notmatch '^[a-z0-9_]{1,16}$' -or -not $types.ContainsKey($extension) -or $extension -in @('mod','erf','key','bif')){throw "Invalid benchmark resource: $($resource.Name)"}
    if($resource.Length -lt 1 -or $resource.Length -gt 256MB){throw "Resource is empty or exceeds the NWSync reader limit: $($resource.Name)"}
    $type=$types[$extension]
    $key='{0}:{1:D5}' -f $name,$type
    if($rows.ContainsKey($key)){throw "Duplicate benchmark resource: $key"}
    $rows.Add($key,@{name=$name;type=$type;path=$resource.FullName})
}

New-Item -ItemType Directory -Path $repositoryPath | Out-Null
$blobDirectory=Join-Path $repositoryPath 'blobs'
New-Item -ItemType Directory -Path $blobDirectory | Out-Null
$rawDirectory=Join-Path $repositoryPath 'zstd-input'
$compressedDirectory=Join-Path $repositoryPath 'zstd-output'
New-Item -ItemType Directory -Path $rawDirectory | Out-Null
$unique=@{}
$manifestStream=[IO.MemoryStream]::new()
$manifestWriter=[IO.BinaryWriter]::new($manifestStream)
try{
    $manifestWriter.Write([Text.Encoding]::ASCII.GetBytes('NSYM'))
    $manifestWriter.Write([uint32]3)
    $manifestWriter.Write([uint32]$rows.Count)
    $manifestWriter.Write([uint32]0)
    foreach($row in $rows.Values){
        $bytes=[IO.File]::ReadAllBytes($row.path)
        $digest=[Security.Cryptography.SHA1]::HashData($bytes)
        $row.hash=[Convert]::ToHexString($digest).ToLowerInvariant()
        $row.size=$bytes.Length
        if(-not $unique.ContainsKey($row.hash)){
            $unique[$row.hash]=$row
            [IO.File]::WriteAllBytes((Join-Path $rawDirectory ($row.hash+'.bin')),$bytes)
        }
        $manifestWriter.Write([byte[]]$digest)
        $manifestWriter.Write([uint32]$row.size)
        $nameField=[byte[]]::new(16)
        [Text.Encoding]::ASCII.GetBytes($row.name).CopyTo($nameField,0)
        $manifestWriter.Write($nameField)
        $manifestWriter.Write([uint16]$row.type)
    }
    $manifest=$manifestStream.ToArray()
}finally{$manifestWriter.Dispose()}

# Use the same fixture encoder verified by the production NWSync reader tests.
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=Join-Path $client '.tools/Godot_v4.7.2-stable_win64.exe'
$start.WorkingDirectory=$client
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$start.Environment['APPDATA']=Join-Path $repositoryPath 'author-user-data'
foreach($argument in @('--headless','--path',$client,'--log-file',(Join-Path $repositoryPath 'author.log'),'--script','res://tools/nwn79/nwsync-visual-zstd.gd','--',('--input-dir='+$rawDirectory),('--output-dir='+$compressedDirectory))){$start.ArgumentList.Add($argument)}
$encoder=[Diagnostics.Process]::Start($start)
try{
    if(-not $encoder.WaitForExit(120000)){$encoder.Kill(); $encoder.WaitForExit(); throw 'Zstandard authoring timed out'}
    if($encoder.ExitCode -ne 0){throw "Zstandard authoring failed with code $($encoder.ExitCode)"}
}finally{$encoder.Dispose()}

foreach($row in $unique.Values){
    $blobPath=Join-Path $blobDirectory ($row.hash+'.bin')
    $file=[IO.File]::Create($blobPath)
    $writer=[IO.BinaryWriter]::new($file)
    try{
        $writer.Write([Text.Encoding]::ASCII.GetBytes('NSYC'))
        $writer.Write([uint32]3)
        $writer.Write([uint32]2)
        $writer.Write([uint32]$row.size)
        $writer.Write([uint32]1)
        $writer.Write([uint32]0)
        $writer.Write([IO.File]::ReadAllBytes((Join-Path $compressedDirectory ($row.hash+'.bin'))))
        $writer.Flush()
        $row.blobBytes=$file.Length
        if($row.blobBytes -gt 256MB){throw "Encoded NWSync blob exceeds the reader limit: $($row.name)"}
    }finally{$writer.Dispose()}
    # Reclaim exact staging files produced by this pack operation.
    [IO.File]::Delete((Join-Path $rawDirectory ($row.hash+'.bin')))
    [IO.File]::Delete((Join-Path $compressedDirectory ($row.hash+'.bin')))
}

$manifestHash=[Convert]::ToHexString([Security.Cryptography.SHA1]::HashData($manifest)).ToLowerInvariant()
[IO.File]::WriteAllBytes((Join-Path $repositoryPath 'manifest.bin'),$manifest)
$entries=@(foreach($row in $rows.Values){
    [ordered]@{name=$row.name;type=$row.type;size=$row.size;hash=$row.hash;algorithm=2;blobBytes=$unique[$row.hash].blobBytes}
})
$descriptorPath=Join-Path $repositoryPath 'descriptor.json'
[ordered]@{
    format='dense-local-nwsync-v1'
    url="http://127.0.0.1:$Port/"
    manifestHash=$manifestHash
    manifestBytes=$manifest.Length
    entries=$entries
    uniqueBlobCount=$unique.Count
    expectedColdRequests=1+$unique.Count
    rawBytes=[long]($unique.Values | ForEach-Object { $_.size } | Measure-Object -Sum).Sum
    httpBlobBytes=[long]($unique.Values | ForEach-Object { $_.blobBytes } | Measure-Object -Sum).Sum
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $descriptorPath -Encoding utf8
Write-Output $descriptorPath
