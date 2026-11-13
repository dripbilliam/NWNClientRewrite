// Read installed KEY/BIF metadata only. No game, renderer, network or art export.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseKey} from '../../src/resource_archive.js';
import {parseBinaryMdl} from '../../src/binary_mdl.js';
const install=path.resolve('../FullDecomp/NwnRootInstall'),resources=new Map(),keys=[];
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
for(const name of ['data/nwn_retail.key','data/nwn_base.key']) {
 const bytes=await fs.readFile(path.join(install,name)),key=parseKey(bytes);
 keys.push({name,sha256:sha(bytes)});
 for(const [id,row] of key.resources) if(!resources.has(id)) resources.set(id,{...row,bif:key.bifNames[row.bifIndex]});
}
async function read(name,type) {
 const row=resources.get(`${name}:${type}`);if(!row)throw Error(`Missing installed resource ${name}:${type}`);
 const file=await fs.open(path.join(install,row.bif),'r');
 try {
  const header=Buffer.alloc(20);await file.read(header,0,20,0);
  const v11=header.toString('ascii',4,8)==='V1.1',stride=v11?20:16,p=v11?8:4,entry=Buffer.alloc(stride);
  await file.read(entry,0,stride,header.readUInt32LE(16)+row.resourceIndex*stride);
  if(entry.readUInt32LE(p+8)!==type)throw Error('BIF type mismatch');
  const bytes=Buffer.alloc(entry.readUInt32LE(p+4));
  if((await file.read(bytes,0,bytes.length,entry.readUInt32LE(p))).bytesRead!==bytes.length)throw Error('Truncated BIF entry');
  return {bytes,source:{name,type,bif:row.bif,resourceIndex:row.resourceIndex,sha256:sha(bytes),length:bytes.length}};
 }finally {await file.close();}
}
const resource=await read('pnl_floatytext',2002),mdl=parseBinaryMdl(resource.bytes.buffer.slice(resource.bytes.byteOffset,resource.bytes.byteOffset+resource.bytes.byteLength));
const nodes=mdl.nodes.map(n=>({name:n.name,parent:n.parent,parentIndex:n.parentIndex,type:n.type,position:n.position,orientation:n.orientation,scale:n.scale,vertices:n.verts,bitmap:n.bitmap,render:n.render,faces:n.faces.length,properties:n.properties}));
const font=await read('fnt_maintext',2074);
const bitmap=resources.has('fnt_galahad14:2022')?await read('fnt_galahad14',2022):null;
for(const key of keys)if(sha(await fs.readFile(path.join(install,key.name)))!==key.sha256)throw Error('KEY changed');
const report={schema:'native-script-floating-installed-v1',scope:'Read-only installed original model hook geometry and font identity; no rendered-pixel acceptance',keys,model:{...resource.source,nodes},font:{...font.source,signature:font.bytes.subarray(0,4).toString('hex'),nativeRequestedName:'fnt_galahad14',nativeRemappedName:'ttf fnt_maintext 17'},unusedBitmapMetadata:bitmap?{...bitmap.source,text:bitmap.bytes.toString('latin1')}:null};
const output=path.resolve('godot-client/reports/native-script-floating-installed-v1.json');
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,model:report.model,font:report.font}));
