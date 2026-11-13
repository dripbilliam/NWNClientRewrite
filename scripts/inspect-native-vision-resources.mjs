// Offline base-game vision table oracle, not an active server resolver/renderer.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseKey} from '../src/resource_archive.js';
import {parse2da} from '../src/area.js';
const [root,output]=process.argv.slice(2);
if(!root||!output)throw Error('Supply original install root and new output path');
const keys=[];
for(const name of ['nwn_retail.key','nwn_base.key'])keys.push(parseKey(await fs.readFile(path.join(root,'data',name))));
const hashes={};
async function read(name){
 for(const key of keys){
  const entry=[...key.resources.values()].find(r=>r.resref===name&&r.resourceType===2017);if(!entry)continue;
  const archive=key.bifNames[entry.bifIndex].replaceAll('\\','/'),handle=await fs.open(path.join(root,archive),'r');
  try{
   const readAt=async(at,count)=>{if(count>8e6)throw Error('Bounded read exceeded');const bytes=Buffer.alloc(count);if((await handle.read(bytes,0,count,at)).bytesRead!==count)throw Error('Truncated');return bytes;};
   const head=await readAt(0,24),stride=head.toString('ascii',4,8)==='V1.1'?20:16;
   const row=await readAt(head.readUInt32LE(16)+entry.resourceIndex*stride,stride),at=stride===20?8:4;
   const bytes=await readAt(row.readUInt32LE(at),row.readUInt32LE(at+4));
   hashes[name]={archive,sha256:createHash('sha256').update(bytes).digest('hex')};return parse2da(bytes.toString('latin1'));
  }finally{await handle.close();}
 }
 throw Error('Missing original resource '+name);
}
const visual=await read('visualeffects'),programs=await read('progfx');
const effects=[182,242,243,244,247].map(id=>{const row=visual.rows.get(id)??visual.rows.get(String(id));return {id,label:row.Label,duration:Number(row.ProgFX_Duration),cessation:Number(row.ProgFX_Cessation)};});
const ids=[...new Set(effects.flatMap(row=>[row.duration,row.cessation]))];
const rows=ids.map(id=>({id,row:programs.rows.get(id)??programs.rows.get(String(id))}));
const result={scope:'Installed base table vision mappings only. Does not establish active server/override precedence or live renderer parity.',network_connections:0,hashes,effects,programs:rows};
await fs.writeFile(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify(result));
