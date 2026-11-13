// Read-only two-table companion for the render agent's native effect-ID trace.
// Base installed data only; no server override, effect execution or row-ID claim.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseKey} from '../../../../src/resource_archive.js';
import {parse2da} from '../../../../src/area.js';
const install=path.resolve('../FullDecomp/NwnRootInstall'),resources=new Map(),keys=[];
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
for(const name of ['data/nwn_retail.key','data/nwn_base.key']){
 const bytes=await fs.readFile(path.join(install,name)),key=parseKey(bytes);keys.push({name,sha256:hash(bytes)});
 for(const [id,row]of key.resources)if(!resources.has(id))resources.set(id,{...row,bif:key.bifNames[row.bifIndex]});
}
async function table(name){
 const row=resources.get(name+':2017');if(!row)throw Error('Missing base table '+name);
 const file=await fs.open(path.join(install,row.bif),'r');
 try{
  const header=Buffer.alloc(20);await file.read(header,0,20,0);
  const v11=header.toString('ascii',4,8)==='V1.1',stride=v11?20:16,p=v11?8:4,entry=Buffer.alloc(stride);
  await file.read(entry,0,stride,header.readUInt32LE(16)+row.resourceIndex*stride);
  if(entry.readUInt32LE(p+8)!==2017||entry.readUInt32LE(p+4)>8*1024*1024)throw Error('Bounded table record differs');
  const bytes=Buffer.alloc(entry.readUInt32LE(p+4));if((await file.read(bytes,0,bytes.length,entry.readUInt32LE(p))).bytesRead!==bytes.length)throw Error('Short table');
  return {source:{name,bif:row.bif,index:row.resourceIndex,sha256:hash(bytes),bytes:bytes.length},parsed:parse2da(bytes.toString('latin1'))};
 }finally{await file.close();}
}
const visual=await table('visualeffects'),prog=await table('progfx');
const rows=[0,1,2,3,4,5,6,7,8].map(index=>({index,value:visual.parsed.orderedRows[index]}));
const selected=visual.parsed.orderedRows[6],references=Object.entries(selected??{}).filter(([name,value])=>/prog/i.test(name)&&/^[0-9]+$/.test(String(value))).map(([field,value])=>({field,index:Number(value)}));
const indexes=[...new Set([6,...references.map(row=>row.index)])].filter(index=>index>=0&&index<prog.parsed.orderedRows.length).slice(0,8);
const result={version:1,scope:'Read-only base installed visualeffects row6 and possible referenced progfx data; native ID/table mapping and server overrides remain unproved',keys,visualeffects:{...visual.source,columns:visual.parsed.columns,rows},progfx:{...prog.source,columns:prog.parsed.columns,rows:indexes.map(index=>({index,value:prog.parsed.orderedRows[index]})),possibleReferences:references}};
for(const key of keys)if(hash(await fs.readFile(path.join(install,key.name)))!==key.sha256)throw Error('KEY changed');
const output=path.resolve('godot-client/tools/native_parity/doors/asset-source-visual6-v1.json');await fs.writeFile(output,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,visualeffects:result.visualeffects,progfx:result.progfx}));
