import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';

const target='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a';
// These ABI locations apply only to the verified original image. New game builds
// must be researched explicitly rather than sending this build's identity.
const platformKeyRva=0x140bab8;
export async function installedNetworkBuild(install){
 const bytes=await fs.readFile(path.join(install,'bin/win32/nwmain.exe'));
 if(createHash('sha256').update(bytes).digest('hex')!==target)throw new Error('Unsupported native network client build');
 const pe=bytes.readUInt32LE(0x3c),sections=bytes.readUInt16LE(pe+6),table=pe+24+bytes.readUInt16LE(pe+20);
 let key=null;
 for(let i=0;i<sections;i++){
  const at=table+i*40,virtualSize=bytes.readUInt32LE(at+8),rva=bytes.readUInt32LE(at+12),size=bytes.readUInt32LE(at+16),offset=bytes.readUInt32LE(at+20);
  if(platformKeyRva<rva||platformKeyRva+32>rva+Math.max(virtualSize,size))continue;
  key=Buffer.alloc(32);const delta=platformKeyRva-rva,count=Math.min(32,Math.max(0,size-delta));
  if(count)key.set(bytes.subarray(offset+delta,offset+delta+count));break;
 }
 if(!key)throw new Error('Native platform key storage is unavailable');
 const signature=Buffer.from([0xbd,0x04,0xef,0xfe]),versionAt=bytes.indexOf(signature);
 if(versionAt<0||bytes.indexOf(signature,versionAt+1)!==-1)throw new Error('Native file version is ambiguous');
 const ms=bytes.readUInt32LE(versionAt+8),ls=bytes.readUInt32LE(versionAt+12);
 const commit=(await fs.readFile(path.join(install,'bin/win32/build.txt'),'utf8')).trim().split(/\s+/)[0];
 if(!/^[0-9a-f]{40}$/.test(commit))throw new Error('Native build commit is unavailable');
 const build=Object.freeze({number:ms&65535,revision:ls>>>16,postfix:ls&65535,commit:commit.slice(0,8)});
 let disposed=false;
 return Object.freeze({target,platformId:2,build,
  async platformIdentifier(crypto){if(disposed)throw new Error('Native build identity is disposed');return crypto.platformIdentity(2,key);},
  dispose(){key.fill(0);disposed=true;}
 });
}
