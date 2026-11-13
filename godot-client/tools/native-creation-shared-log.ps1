function Read-BoundedCreationLogStream {
 param([Parameter(Mandatory)][IO.Stream]$Stream)
 $maximum=16MB
 if($Stream.Length-gt$maximum){throw 'Owned creation log exceeds16MiB'}
 $buffer=[byte[]]::new(4096);$memory=[IO.MemoryStream]::new();$total=0
 try{
  while($true){
   # One extra sentinel byte detects growth, without appending or decoding it.
   $count=$Stream.Read($buffer,0,[Math]::Min($buffer.Length,$maximum-$total+1))
   if($count-eq0){break}
   if($total+$count-gt$maximum){throw 'Owned creation log grew beyond16MiB'}
   $memory.Write($buffer,0,$count);$total+=$count
  }
  return [Text.Encoding]::UTF8.GetString($memory.ToArray())
 }finally{$memory.Dispose()}
}
function Read-OwnedCreationLog {
 param([Parameter(Mandatory)][string]$Path)
 $stream=$null
 try{
  $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite-bor[IO.FileShare]::Delete))
  return Read-BoundedCreationLogStream -Stream $stream
 }finally{if($stream){$stream.Dispose()}}
}
