// Bounded installed original shader include closure, source evidence only.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {parseKey} from '../../../../src/resource_archive.js';
const root=process.cwd(),output=path.resolve(process.argv[2]??''),boundary=path.join(root,'godot-client/.cache/native-presentation-parity/render-agent')+path.sep;
if(!output.startsWith(boundary))throw Error('Owned output required');
const install=path.resolve('../FullDecomp/NwnRootInstall'),rows=new Map(),keys=[];
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
for(const name of ['data/nwn_retail.key','data/nwn_base.key']){
 const bytes=await fs.readFile(path.join(install,name)),key=parseKey(bytes);keys.push({name,sha256:sha(bytes)});
 for(const [id,row]of key.resources)if(!rows.has(id))rows.set(id,{...row,bif:key.bifNames[row.bifIndex]});
}
async function read(name,type){
 const row=rows.get(name+':'+type);if(!row)return null;
 const file=await fs.open(path.join(install,row.bif),'r');
 try{
  const header=Buffer.alloc(20);if((await file.read(header,0,20,0)).bytesRead!==20)throw Error('BIF header');
  const v11=header.toString('ascii',4,8)==='V1.1',stride=v11?20:16,p=v11?8:4,entry=Buffer.alloc(stride);
  if((await file.read(entry,0,stride,header.readUInt32LE(16)+row.resourceIndex*stride)).bytesRead!==stride||entry.readUInt32LE(p+8)!==type)throw Error('BIF entry');
  const size=entry.readUInt32LE(p+4);if(size>256*1024)throw Error('Bounded shader size');
  const bytes=Buffer.alloc(size);if((await file.read(bytes,0,size,entry.readUInt32LE(p))).bytesRead!==size)throw Error('Short shader');
  return {name,type,bif:row.bif,resource_index:row.resourceIndex,bytes:size,sha256:sha(bytes),text:bytes.toString('latin1')};
 }finally{await file.close();}
}
const shaders=[],seen=new Set(),queue=['vsvtc','fstc'];
while(queue.length){
 const name=queue.shift();if(seen.has(name))continue;
 if(seen.size>=32||!/^[a-z0-9_]{1,32}$/i.test(name))throw Error('Bounded shader include closure');seen.add(name);
 const entry=await read(name,2069);if(!entry)throw Error('Missing original shader '+name);shaders.push(entry);
 for(const match of entry.text.matchAll(/^\s*#include\s+["<]?([a-z0-9_]+)(?:\.shd)?[">]?/gmi))queue.push(match[1]);
}
const texture_entries=[3,2022,2033,2073].map(type=>{const row=rows.get('fxpa_dot02:'+type);return row?{type,bif:row.bif,resource_index:row.resourceIndex}:null;}).filter(Boolean);
for(const key of keys)if(sha(await fs.readFile(path.join(install,key.name)))!==key.sha256)throw Error('KEY changed');
await fs.mkdir(path.dirname(output),{recursive:true});await fs.writeFile(output,JSON.stringify({scope:'Installed base shader source evidence; no rendering, no active server override claim',keys,texture_entries,shaders},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,shader_count:shaders.length,texture_entries,shaders:shaders.map(s=>({name:s.name,bytes:s.bytes,sha256:s.sha256}))}));
