// Bounded installed-placeable metadata only. Candidate names select records;
// they do not establish a runtime visibility policy. No engine/server/test.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseKey} from '../../../../src/resource_archive.js';
import {parse2da} from '../../../../src/area.js';
import {parseBinaryMdl} from '../../../../src/binary_mdl.js';
import {parseAsciiMdl} from '../../../../src/model_parser.js';
const [label,...selected]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||selected.length>8||selected.some(n=>!/^[a-z0-9_]{1,32}$/.test(n)))throw Error('Fresh label and at most eight explicit placeable resrefs required');
const install=path.resolve('../FullDecomp/NwnRootInstall'),rows=new Map(),keys=[];
const hash=b=>createHash('sha256').update(b).digest('hex');
for(const name of ['data/nwn_retail.key','data/nwn_base.key']){
 const bytes=await fs.readFile(path.join(install,name)),key=parseKey(bytes);keys.push({name,sha256:hash(bytes)});
 for(const [id,row]of key.resources)if(!rows.has(id))rows.set(id,{...row,bif:key.bifNames[row.bifIndex]});
}
async function read(name,type){
 const row=rows.get(name+':'+type);if(!row)throw Error('Missing installed '+name+':'+type);
 const file=await fs.open(path.join(install,row.bif),'r');
 try{
  const h=Buffer.alloc(20);if((await file.read(h,0,20,0)).bytesRead!==20)throw Error('Short BIF header');
  const v11=h.toString('ascii',4,8)==='V1.1',stride=v11?20:16,p=v11?8:4,e=Buffer.alloc(stride);
  if((await file.read(e,0,stride,h.readUInt32LE(16)+row.resourceIndex*stride)).bytesRead!==stride||e.readUInt32LE(p+8)!==type)throw Error('BIF entry/type mismatch');
  const n=e.readUInt32LE(p+4);if(n>8*1024*1024)throw Error('Bounded resource limit');
  const b=Buffer.alloc(n);if((await file.read(b,0,n,e.readUInt32LE(p))).bytesRead!==n)throw Error('Short resource');
  return {bytes:b,source:{name,type,bif:row.bif,resourceIndex:row.resourceIndex,bytes:n,sha256:hash(b)}};
 }finally{await file.close();}
}
const tableSource=await read('placeables',2017),table=parse2da(tableSource.bytes.toString('latin1'));
const referenced=new Map();table.orderedRows.forEach((row,index)=>{const name=String(row.ModelName??'').toLowerCase();if(!referenced.has(name))referenced.set(name,[]);referenced.get(name).push({index,...row});});
const candidates=table.orderedRows.map((row,index)=>({index,...row})).filter(row=>/invis|bound|block|walkmesh|collision|helper/i.test(String(row.Label)+' '+String(row.ModelName)));
if(candidates.length>64)throw Error('Candidate table output exceeds64rows; narrow explicit source selection');
const models=[];
for(const name of selected){
 if(!referenced.has(name))throw Error('Not referenced by installed base placeables table: '+name);
 const resource=await read(name,2002),b=resource.bytes;
 const binary=b.readUInt32LE(0)===0,model=binary?parseBinaryMdl(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)):parseAsciiMdl(b.toString('latin1'));
 if(model.nodes.length>512)throw Error('Bounded model node cap');
 const animations=model.animations.map(a=>({name:a.name,length:a.length,transition:a.transition,tracks:a.tracks.filter(t=>['alpha','render','tilefade','position','orientation','scale','selfillumcolor'].includes(t.property))}));
 const records=[];
 if(binary){
  const end=12+b.readUInt32LE(4),visited=new Set(),vec=at=>[0,4,8].map(o=>b.readFloatLE(at+o));
  const range=(at,n)=>{if(at<12||at+n>end)throw Error('Raw node outside model section');};
  function walk(relative,parent=-1){
   const at=12+relative;range(at,112);if(visited.has(relative))throw Error('Raw hierarchy cycle');visited.add(relative);
   const index=records.length,node=model.nodes[index],rawName=b.subarray(at+32,at+64).toString('ascii').split('\0')[0],flags=b.readUInt32LE(at+108);
   if(node?.name!==rawName||node.parentIndex!==parent)throw Error('Raw/parsed physical-order mismatch');
   let c=at+112;for(const [flag,size]of[[2,92],[4,216],[16,68]])if(flags&flag)c+=size;
   let mesh=null;if(flags&32){range(c,512);mesh={renderRaw:b.readUInt32LE(c+0x6c),shadowRaw:b.readUInt32LE(c+0x64),tilefadeRaw:b.readUInt32LE(c+0x178),transparencyHint:b.readUInt32LE(c+0x70),bounds:{min:vec(c+0x14),max:vec(c+0x20)},bitmap:node.bitmap,textures:node.textureLayers,vertices:node.verts.length,faces:node.faces.length,sourceOffsets:{render:c+0x6c,tilefade:c+0x178,bounds:c+0x14}};}
   records.push({index,name:node.name,parent,flags,position:node.position,orientation:node.orientation,scale:node.scale,staticAlpha:node.alpha,mesh});
   const offset=b.readUInt32LE(at+72),count=b.readUInt32LE(at+76);range(12+offset,count*4);for(let i=0;i<count;i++)walk(b.readUInt32LE(12+offset+i*4),index);
  }walk(b.readUInt32LE(84));
 }else{
  for(const [index,node]of model.nodes.entries()){
   const scalar=(key,fallback)=>Array.isArray(node.properties[key])?node.properties[key][0]:node.properties[key]??fallback;
   records.push({index,name:node.name,parent:node.parent,kind:node.type,position:node.position,orientation:node.orientation,scale:scalar('scale',node.scale),staticAlpha:scalar('alpha',1),mesh:['trimesh','skin','animmesh','aabb','danglymesh'].includes(node.type)?{renderRaw:scalar('render',1),tilefadeRaw:scalar('tilefade',null),tilefadeDefaultIfAbsent:0,transparencyHint:scalar('transparencyhint',null),bitmap:node.bitmap,vertices:node.verts.length,faces:node.faces.length,rawProperties:node.properties}:null});
  }
 }
 for(const record of records)record.alphaTracks=animations.flatMap(a=>a.tracks.filter(t=>t.property==='alpha'&&t.node.toLowerCase()===record.name.toLowerCase()).map(t=>({animation:a.name,...t})));
 models.push({...resource.source,tableRows:referenced.get(name),format:binary?'Binary MDL':'ASCII MDL',classificationFlags:binary?b.readUInt8(12+0x72):null,supermodel:model.supermodel,unsupportedAnimations:model.unsupportedAnimations,records,animations});
}
for(const key of keys)if(hash(await fs.readFile(path.join(install,key.name)))!==key.sha256)throw Error('Installed KEY changed');
const output=path.resolve('godot-client/tools/native_parity/visibility/blocker-asset-'+label+'.json');
await fs.writeFile(output,JSON.stringify({version:1,scope:'Installed base placeable static/controller metadata; selection labels are not visibility classification; no runtime draw/hit test',keys,table:{...tableSource.source,columns:table.columns,rowCount:table.orderedRows.length,candidates},models},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,table:{rows:table.orderedRows.length,candidates},models:models.map(m=>({name:m.name,format:m.format,supermodel:m.supermodel,unsupported:m.unsupportedAnimations,clips:m.animations.map(a=>a.name),meshes:m.records.filter(r=>r.mesh).map(r=>({name:r.name,alpha:r.staticAlpha,render:r.mesh.renderRaw,tilefade:r.mesh.tilefadeRaw,bitmap:r.mesh.bitmap,faces:r.mesh.faces,alphaTracks:r.alphaTracks}))}))}));
