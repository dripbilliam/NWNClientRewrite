param([Parameter(Mandatory)][string]$Directory)
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $Directory){throw 'Existing shared log test evidence retained'}
New-Item -ItemType Directory -Path $Directory|Out-Null
. (Join-Path $PSScriptRoot '../tools/native-creation-shared-log.ps1')
$path=Join-Path $Directory 'owned-log.txt'
$writer=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
$checks=0
try{
 $bytes=[Text.Encoding]::UTF8.GetBytes('owned public identity only');$writer.Write($bytes);$writer.Flush()
 if((Read-OwnedCreationLog -Path $path)-ne'owned public identity only'){throw 'Shared writer read differs'};$checks++
 $bytes=[Text.Encoding]::UTF8.GetBytes(' appended');$writer.Write($bytes);$writer.Flush()
 if((Read-OwnedCreationLog -Path $path)-ne'owned public identity only appended'){throw 'Reader disposed original writer or missed append'};$checks++
}finally{$writer.Dispose()}
if((Read-OwnedCreationLog -Path $path)-ne'owned public identity only appended'){throw 'Closed writer read differs'};$checks++
$large=Join-Path $Directory 'oversize.bin';$s=[IO.File]::Open($large,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try{$s.SetLength(16MB+1)}finally{$s.Dispose()}
$rejected=$false;try{Read-OwnedCreationLog -Path $large|Out-Null}catch{$rejected=$_.Exception.Message-contains'Owned creation log exceeds16MiB'}
if(-not$rejected){throw 'Oversize log accepted'};$checks++
$exclusive=[IO.File]::Open($large,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$exclusive.Dispose();$checks++
Add-Type -TypeDefinition @'
using System;
using System.IO;
public sealed class GrowingCreationLogStream : Stream {
 public long BytesReturned=0;
 public override bool CanRead {get{return true;}}
 public override bool CanSeek {get{return false;}}
 public override bool CanWrite {get{return false;}}
 public override long Length {get{return 0;}}
 public override long Position {get{return BytesReturned;}set{throw new NotSupportedException();}}
 public override void Flush(){}
 public override int Read(byte[] buffer,int offset,int count){
  int n=(int)Math.Min(count,32L*1024*1024-BytesReturned);
  for(int i=0;i<n;i++)buffer[offset+i]=88;
  BytesReturned+=n;return n;
 }
 public override long Seek(long offset,SeekOrigin origin){throw new NotSupportedException();}
 public override void SetLength(long value){throw new NotSupportedException();}
 public override void Write(byte[] buffer,int offset,int count){throw new NotSupportedException();}
}
'@
$growing=[GrowingCreationLogStream]::new();$growthRejected=$false
try{try{Read-BoundedCreationLogStream -Stream $growing|Out-Null}catch{$growthRejected=$_.Exception.Message-eq'Owned creation log grew beyond16MiB'}
 if(-not$growthRejected-or$growing.BytesReturned-ne16MB+1){throw 'Growth cap exceeded one sentinel byte'};$checks++
}finally{$growing.Dispose()}
$result=@{success=$true;checks=$checks;scope='Bounded shared-reader only: open append writer, continued writer use, closed writer, oversize rejection/exclusive reopen cleanup, and zero-initial-length growth stream stopped at16MiB+one discarded sentinel. No server/private-key/native process.'}
[IO.File]::WriteAllText((Join-Path $Directory 'proof.json'),($result|ConvertTo-Json)+[Environment]::NewLine)
$result|ConvertTo-Json -Compress
