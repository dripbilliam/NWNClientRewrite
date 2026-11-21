// Owned, non-executed PE64 analysis fixture. No game code/assets are embedded.
// Function at140001000 computes (x + 2*y) XOR 0x13579bdf modulo2^32.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const directory=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../backups/rea-trial');
const b=Buffer.alloc(0x400),u16=(p,v)=>b.writeUInt16LE(v,p),u32=(p,v)=>b.writeUInt32LE(v,p),u64=(p,v)=>b.writeBigUInt64LE(BigInt(v),p);
b.write('MZ');u32(0x3c,0x80);b.write('PE\0\0',0x80);const coff=0x84,optional=coff+20,section=optional+240;
u16(coff,0x8664);u16(coff+2,1);u16(coff+16,240);u16(coff+18,0x22);
u16(optional,0x20b);u32(optional+4,0x200);u32(optional+16,0x1000);u32(optional+20,0x1000);u64(optional+24,0x140000000);
u32(optional+32,0x1000);u32(optional+36,0x200);u16(optional+40,6);u16(optional+48,6);u32(optional+56,0x2000);u32(optional+60,0x200);u16(optional+68,3);u16(optional+70,0x8160);
u64(optional+72,0x100000);u64(optional+80,0x1000);u64(optional+88,0x100000);u64(optional+96,0x1000);u32(optional+108,16);
const code=Buffer.from('8d045135df9b5713c3','hex');b.write('.text',section);u32(section+8,code.length);u32(section+12,0x1000);u32(section+16,0x200);u32(section+20,0x200);u32(section+36,0x60000020);b.set(code,0x200);
await fs.writeFile(path.join(directory,'owned-arithmetic-fixture.exe'),b);
await fs.writeFile(path.join(directory,'owned-fixture-expectation.json'),JSON.stringify({source:'scripts/rea-trial-fixture.mjs',entry:'0x140001000',bytes:code.toString('hex'),instructions:['LEA EAX,[RCX+RDX*2]','XOR EAX,0x13579bdf','RET'],formula:'(x + 2*y) XOR 0x13579bdf modulo2^32',executed:false},null,2)+'\n');
console.log('Owned static PE fixture written; never executed.');
