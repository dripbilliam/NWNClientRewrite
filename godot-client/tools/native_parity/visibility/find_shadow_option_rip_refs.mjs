// Read-only original PE scan for TWO already-observed exact data addresses.
// No disassembly job, runtime attach, engine, GPU, archive or server activity.
import fs from 'node:fs';
import crypto from 'node:crypto';
const file='C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall/bin/win32/nwmain.exe';
const bytes=fs.readFileSync(file);
const sha256=crypto.createHash('sha256').update(bytes).digest('hex');
if(sha256!=='3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a')throw Error('Original identity mismatch');
const pe=bytes.readUInt32LE(0x3c);
if(bytes.toString('ascii',pe,pe+4)!=='PE\0\0'||bytes.readUInt16LE(pe+24)!==0x20b)throw Error('Expected PE32+');
const base=bytes.readBigUInt64LE(pe+24+24),sectionCount=bytes.readUInt16LE(pe+6),table=pe+24+bytes.readUInt16LE(pe+20);
const targets=new Set([0x140e291b8n,0x140e2b2a0n]);
const matches=[];let scanned=0;
for(let section=0;section<sectionCount;section++){
 const at=table+section*40,flags=bytes.readUInt32LE(at+36);
 if(!(flags&0x20000000))continue;
 const rva=bytes.readUInt32LE(at+12),size=bytes.readUInt32LE(at+16),offset=bytes.readUInt32LE(at+20);
 scanned+=size;if(scanned>20*1024*1024||offset+size>bytes.length)throw Error('Explicit executable section bound exceeded');
 // RIP-relative LEA r64,[disp32], any destination register. False decoded
 // candidates remain evidence only and must be verified by REA Listing.
 for(let index=0;index+7<=size;index++){
  const cursor=offset+index;
  if((bytes[cursor]!==0x48&&bytes[cursor]!==0x4c)||bytes[cursor+1]!==0x8d||(bytes[cursor+2]&0xc7)!==0x05)continue;
  const instruction=base+BigInt(rva+index),target=instruction+7n+BigInt(bytes.readInt32LE(cursor+3));
  if(targets.has(target))matches.push({instruction:'0x'+instruction.toString(16),target:'0x'+target.toString(16),sourceBytes:bytes.subarray(cursor,cursor+7).toString('hex')});
 }
}
if(matches.length>32)throw Error('Exact reference count exceeded bound');
console.log(JSON.stringify({subject:{file,sha256},scope:'Two exact observed data addresses, bounded original executable-section LEA candidate search; REA Listing confirmation required',scanned,matches}));
