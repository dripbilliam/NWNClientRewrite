// Enumerate MSVC RTTI primary vtables whose inheritance graph contains Part.
// A vtable entry is a possible dispatch target, not proof of construction or reachability.
const fs = require('node:fs');
const crypto = require('node:crypto');
const file = process.argv[2];
if (!file) throw new Error('Usage: node audit-part-draw-vtables.cjs <pinned nwmain.exe>');
const b = fs.readFileSync(file);
const hash = crypto.createHash('sha256').update(b).digest('hex');
if (hash !== '3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a') throw new Error(`Wrong binary: ${hash}`);
const pe = b.readUInt32LE(0x3c), opt = pe + 24, base = b.readBigUInt64LE(opt + 24);
const sect = opt + b.readUInt16LE(pe + 20), sections = [];
for (let i = 0; i < b.readUInt16LE(pe + 6); i++) {
  const p = sect + 40 * i;
  sections.push({name:b.toString('ascii',p,p+8).replace(/\0.*$/,''), rva:b.readUInt32LE(p+12),raw:b.readUInt32LE(p+20),size:b.readUInt32LE(p+16),flags:b.readUInt32LE(p+36)});
}
function off(address, length=1) {
  const rva = Number(BigInt(address)-base);
  const s=sections.find(x=>rva>=x.rva&&rva+length<=x.rva+x.size);
  return s? s.raw+rva-s.rva : null;
}
function qword(address) { const p=off(address,8); return p===null?null:b.readBigUInt64LE(p); }
function nameAt(address) {
  const p=off(address,96); if(p===null)return null;
  const end=b.indexOf(0,p); if(end<p || end>p+95)return null;
  return b.toString('ascii',p,end);
}
function baseNames(chdRva) {
  const p=off(base+BigInt(chdRva),16);
  if(p===null)return [];
  const count=b.readUInt32LE(p+8), array=base+BigInt(b.readUInt32LE(p+12));
  if(count<1||count>64)return [];
  const a=off(array,count*4);
  if(a===null)return [];
  const result=[];
  for(let i=0;i<count;i++){
    const d=off(base+BigInt(b.readUInt32LE(a+4*i)),4);
    if(d===null)return [];
    const n=nameAt(base+BigInt(b.readUInt32LE(d))+16n);
    if(!n)return [];
    result.push(n);
  }
  return result;
}
const rdata=sections.find(x=>x.name==='.rdata');
const found=[];
for(let p=rdata.raw;p+8<=rdata.raw+rdata.size;p+=8){
  const col=b.readBigUInt64LE(p), cp=off(col,24);
  if(cp===null || b.readUInt32LE(cp)!==1) continue;
  const colRva=Number(col-base);
  if(b.readUInt32LE(cp+20)!==colRva) continue;
  const type=base+BigInt(b.readUInt32LE(cp+12));
  const name=nameAt(type+16n);
  if(!name)continue;
  const bases=baseNames(b.readUInt32LE(cp+16));
  if(!bases.includes('.?AVPart@@'))continue;
  const vtable=base+BigInt(rdata.rva+p+8-rdata.raw);
  const target=qword(vtable+0xc8n);
  const targetRva=target===null?null:Number(target-base);
  const executable=sections.some(s=>(s.flags&0x20000000)&&targetRva>=s.rva&&targetRva<s.rva+s.size);
  found.push({type:name,bases,vtable:`0x${vtable.toString(16)}`,col:`0x${col.toString(16)}`,colOffset:b.readUInt32LE(cp+4),draw:target===null?null:`0x${target.toString(16)}`,executable});
}
process.stdout.write(JSON.stringify({binary_sha256:hash,count:found.length,vtables:found},null,2)+'\n');
