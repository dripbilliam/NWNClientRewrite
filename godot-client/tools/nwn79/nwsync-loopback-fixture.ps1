param(
 [Parameter(Mandatory=$true)][string]$Directory,
 [ValidateRange(1024,65535)][int]$Port=31879,
 [switch]$VisualCohort,
 [switch]$Serve
)
$ErrorActionPreference='Stop'
$directory=[IO.Path]::GetFullPath($Directory)
$descriptorPath=Join-Path $directory 'descriptor.json'
if($Serve){
 $descriptor=Get-Content -LiteralPath $descriptorPath -Raw|ConvertFrom-Json
 $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port)
 $listener.Start()
 try{
  [IO.File]::WriteAllText((Join-Path $directory 'ready'),[string]$PID)
  while($true){
   $client=$listener.AcceptTcpClient()
   try{
    $stream=$client.GetStream()
    $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::ASCII,$false,1024,$true)
    $request=$reader.ReadLine()
    if(-not$request){continue}
    while($true){$line=$reader.ReadLine();if($null -eq $line -or $line -eq ''){break}}
    $route=($request -split ' ')[1]
    $name=if($route -eq ('/manifests/'+$descriptor.manifestHash)){'manifest.bin'}else{''}
    if(-not$name -and $descriptor.entries){
     foreach($entry in $descriptor.entries){
      $hash=[string]$entry.hash
      if($route -eq ('/data/sha1/'+$hash.Substring(0,2)+'/'+$hash.Substring(2,2)+'/'+$hash)){$name='blobs/'+$hash+'.bin';break}
     }
    }
    if(-not$name -and $descriptor.resourceHash -and $route -eq ('/data/sha1/'+$descriptor.resourceHash.Substring(0,2)+'/'+$descriptor.resourceHash.Substring(2,2)+'/'+$descriptor.resourceHash)){$name='blob.bin'}
    $controlPath=Join-Path $directory 'control.json'
    $control=if(Test-Path -LiteralPath $controlPath){Get-Content -LiteralPath $controlPath -Raw|ConvertFrom-Json}else{$null}
    if($name -ne 'manifest.bin' -and $control -and $control.failBlob){$name=''}
    $body=if($name){[IO.File]::ReadAllBytes((Join-Path $directory $name))}else{[byte[]]@()}
    $status=if($name){'200 OK'}else{'404 Not Found'}
    [IO.File]::AppendAllText((Join-Path $directory 'request-starts.log'),"$route started`n")
    if($control -and [int]$control.delayMilliseconds -gt 0){Start-Sleep -Milliseconds ([Math]::Min(10000,[int]$control.delayMilliseconds))}
    $header=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Length: $($body.Length)`r`nConnection: close`r`nContent-Type: application/octet-stream`r`n`r`n")
    try{
     $stream.Write($header,0,$header.Length)
     if($body.Length){$stream.Write($body,0,$body.Length)}
     [IO.File]::AppendAllText((Join-Path $directory 'requests.log'),"$route $status complete`n")
    }catch{[IO.File]::AppendAllText((Join-Path $directory 'requests.log'),"$route $status aborted`n")}
   }finally{$client.Dispose()}
  }
 }finally{$listener.Stop()}
}
if(Test-Path -LiteralPath $directory){throw 'NWSync fixture directory already exists'}
New-Item -ItemType Directory -Path $directory|Out-Null
if($VisualCohort){
 function Encode-VisualBlob([byte[]]$raw,[int]$algorithm){
  $payload=if($algorithm -eq 0){$raw}elseif($algorithm -eq 1){
   $compressed=[IO.MemoryStream]::new()
   $zlib=[IO.Compression.ZLibStream]::new($compressed,[IO.Compression.CompressionLevel]::Optimal,$true)
   try{$zlib.Write($raw,0,$raw.Length)}finally{$zlib.Dispose()}
   $bytes=$compressed.ToArray();$compressed.Dispose();$bytes
  }else{
   $hash=[Convert]::ToHexString([Security.Cryptography.SHA1]::HashData($raw)).ToLowerInvariant()
   [IO.File]::ReadAllBytes((Join-Path $visualCompressed ($hash+'.bin')))
  }
  $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream,[Text.Encoding]::ASCII,$true)
  $writer.Write([Text.Encoding]::ASCII.GetBytes('NSYC'))
  $writer.Write([uint32]3);$writer.Write([uint32]$algorithm);$writer.Write([uint32]$raw.Length)
  if($algorithm -gt 0){$writer.Write([uint32]1)}
  if($algorithm -eq 2){$writer.Write([uint32]0)}
  $writer.Write([byte[]]$payload);$writer.Flush()
  $result=$stream.ToArray();$writer.Dispose();$stream.Dispose();return ,$result
 }
 $resources=[Collections.Generic.List[object]]::new()
 for($i=0;$i -lt 12;$i++){
  $body="2DA V2.0`n`nVALUE`n0 GODOT_NWSYNC_$i`n"+("`n"*(1024+$i))
  $resources.Add([ordered]@{name=('gd_sync_'+$i);type=2017;data=[Text.Encoding]::ASCII.GetBytes($body);algorithm=($i%3)})
 }
 $tga=[byte[]]::new(18+16*16*4)
 $tga[2]=2;[BitConverter]::GetBytes([uint16]16).CopyTo($tga,12);[BitConverter]::GetBytes([uint16]16).CopyTo($tga,14)
 $tga[16]=32;$tga[17]=0x28
 for($offset=18;$offset -lt $tga.Length;$offset+=4){$tga[$offset]=20;$tga[$offset+1]=170;$tga[$offset+2]=240;$tga[$offset+3]=255}
 $resources.Add([ordered]@{name='gd_sync_icon';type=3;data=$tga;algorithm=2})
 $visualRaw=Join-Path $directory 'zstd-input';$visualCompressed=Join-Path $directory 'zstd-compressed'
 New-Item -ItemType Directory -Path $visualRaw|Out-Null
 foreach($resource in $resources){if($resource.algorithm -eq 2){$hash=[Convert]::ToHexString([Security.Cryptography.SHA1]::HashData([byte[]]$resource.data)).ToLowerInvariant();[IO.File]::WriteAllBytes((Join-Path $visualRaw ($hash+'.bin')),[byte[]]$resource.data)}}
 $godot=Join-Path $PSScriptRoot '../../.tools/Godot_v4.7.2-stable_win64_console.exe'
 if(-not(Test-Path -LiteralPath $godot -PathType Leaf)){throw 'Pinned Godot is required to author genuine Zstandard fixture blocks'}
 $visualUserData=Join-Path $directory 'godot-user-data';New-Item -ItemType Directory -Path $visualUserData|Out-Null
 $previousAppData=$env:APPDATA
 try{
  $env:APPDATA=$visualUserData
  & $godot --headless --path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))) --script 'res://tools/nwn79/nwsync-visual-zstd.gd' -- ('--input-dir='+$visualRaw) ('--output-dir='+$visualCompressed) | Out-Null
  if($LASTEXITCODE -ne 0){throw 'Godot could not author genuine Zstandard fixture blocks'}
 }finally{$env:APPDATA=$previousAppData}
 $blobs=Join-Path $directory 'blobs';New-Item -ItemType Directory -Path $blobs|Out-Null
 $manifestStream=[IO.MemoryStream]::new();$manifestWriter=[IO.BinaryWriter]::new($manifestStream,[Text.Encoding]::ASCII,$true)
 $manifestWriter.Write([Text.Encoding]::ASCII.GetBytes('NSYM'))
 $manifestWriter.Write([uint32]3);$manifestWriter.Write([uint32]$resources.Count);$manifestWriter.Write([uint32]0)
 $entries=[Collections.Generic.List[object]]::new()
 foreach($resource in $resources){
  $raw=[byte[]]$resource.data
  $hash=[Convert]::ToHexString([Security.Cryptography.SHA1]::HashData($raw)).ToLowerInvariant()
  $blob=Encode-VisualBlob $raw ([int]$resource.algorithm)
  [IO.File]::WriteAllBytes((Join-Path $blobs ($hash+'.bin')),$blob)
  $manifestWriter.Write([Convert]::FromHexString($hash));$manifestWriter.Write([uint32]$raw.Length)
  $name=[byte[]]::new(16);[Text.Encoding]::ASCII.GetBytes([string]$resource.name).CopyTo($name,0)
  $manifestWriter.Write($name);$manifestWriter.Write([uint16]$resource.type)
  $entries.Add([ordered]@{name=$resource.name;type=$resource.type;size=$raw.Length;hash=$hash;algorithm=$resource.algorithm;blobBytes=$blob.Length})
 }
 $manifestWriter.Flush();$manifest=$manifestStream.ToArray();$manifestWriter.Dispose();$manifestStream.Dispose()
 $manifestHash=[Convert]::ToHexString([Security.Cryptography.SHA1]::HashData($manifest)).ToLowerInvariant()
 [IO.File]::WriteAllBytes((Join-Path $directory 'manifest.bin'),$manifest)
 [ordered]@{format='nwn79-private-nwsync-visual-v1';url="http://127.0.0.1:$Port/";manifestHash=$manifestHash;manifestBytes=$manifest.Length;entries=@($entries);expectedColdRequests=14;expectedResourceCount=13;scope='Private authored multi-resource NWSync; no visual/client acceptance yet'}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $descriptorPath -Encoding utf8
 Write-Output $descriptorPath
 return
}
$data=[Text.Encoding]::ASCII.GetBytes("2DA V2.0`n`nVALUE`n0 NWN79_GODOT_ONLY`n")
$resourceHash=[Convert]::ToHexString([Security.Cryptography.SHA1]::HashData($data)).ToLowerInvariant()
$manifestStream=[IO.MemoryStream]::new()
$writer=[IO.BinaryWriter]::new($manifestStream,[Text.Encoding]::ASCII,$true)
$writer.Write([Text.Encoding]::ASCII.GetBytes('NSYM'))
$writer.Write([uint32]3)
$writer.Write([uint32]1)
$writer.Write([uint32]0)
$writer.Write([Convert]::FromHexString($resourceHash))
$writer.Write([uint32]$data.Length)
$name=[byte[]]::new(16);[Text.Encoding]::ASCII.GetBytes('nwn79_probe').CopyTo($name,0)
$writer.Write($name)
$writer.Write([uint16]2017)
$writer.Flush()
$manifest=$manifestStream.ToArray();$writer.Dispose();$manifestStream.Dispose()
$manifestHash=[Convert]::ToHexString([Security.Cryptography.SHA1]::HashData($manifest)).ToLowerInvariant()
$blobStream=[IO.MemoryStream]::new()
$writer=[IO.BinaryWriter]::new($blobStream,[Text.Encoding]::ASCII,$true)
$writer.Write([Text.Encoding]::ASCII.GetBytes('NSYC'))
$writer.Write([uint32]3)
$writer.Write([uint32]0)
$writer.Write([uint32]$data.Length)
$writer.Write($data)
$writer.Flush()
$blob=$blobStream.ToArray();$writer.Dispose();$blobStream.Dispose()
[IO.File]::WriteAllBytes((Join-Path $directory 'manifest.bin'),$manifest)
[IO.File]::WriteAllBytes((Join-Path $directory 'blob.bin'),$blob)
[ordered]@{format='nwn79-private-nwsync-v1';url="http://127.0.0.1:$Port/";manifestHash=$manifestHash;resourceHash=$resourceHash;resourceName='nwn79_probe';resourceType=2017;resourceBytes=$data.Length;manifestBytes=$manifest.Length;blobBytes=$blob.Length}|ConvertTo-Json|Set-Content -LiteralPath $descriptorPath -Encoding utf8
Write-Output $descriptorPath
