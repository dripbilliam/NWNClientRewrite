// Bounded READ-ONLY installed KEY/BIF door metadata extraction. No tests,
// renderer, engine, scene/model export, server, native build or resource writes.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseKey} from '../../../../src/resource_archive.js';
import {parse2da} from '../../../../src/area.js';
import {parseBinaryMdl} from '../../../../src/binary_mdl.js';
import {parseAsciiMdl} from '../../../../src/model_parser.js';
const [label,...selected]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(label??'')||selected.length>6||selected.some(name=>!/^[a-z0-9_]{1,32}$/.test(name)))throw Error('Explicit label and at most six door resource names required');
const install=path.resolve('../FullDecomp/NwnRootInstall'),resources=new Map(),keys=[];
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
for(const name of ['data/nwn_retail.key','data/nwn_base.key']){
 const bytes=await fs.readFile(path.join(install,name)),key=parseKey(bytes);keys.push({name,sha256:hash(bytes)});
 for(const [id,row]of key.resources)if(!resources.has(id))resources.set(id,{...row,bif:key.bifNames[row.bifIndex]});
}
async function read(name,type){
 const row=resources.get(name+':'+type);if(!row)throw Error('Missing installed resource '+name+':'+type);
 const file=await fs.open(path.join(install,row.bif),'r');
 try{
  const header=Buffer.alloc(20);if((await file.read(header,0,20,0)).bytesRead!==20)throw Error('Short BIF header');
  const v11=header.toString('ascii',4,8)==='V1.1',stride=v11?20:16,p=v11?8:4,entry=Buffer.alloc(stride);
  if((await file.read(entry,0,stride,header.readUInt32LE(16)+row.resourceIndex*stride)).bytesRead!==stride||entry.readUInt32LE(p+8)!==type)throw Error('BIF type/entry mismatch');
  const size=entry.readUInt32LE(p+4);if(size>8*1024*1024)throw Error('Door metadata resource exceeds bounded read');
  const bytes=Buffer.alloc(size);if((await file.read(bytes,0,size,entry.readUInt32LE(p))).bytesRead!==size)throw Error('Short BIF payload');
  return {bytes,source:{name,type,bif:row.bif,resourceIndex:row.resourceIndex,bytes:size,sha256:hash(bytes)}};
 }finally{await file.close();}
}
const tables=[];
for(const name of ['genericdoors','doortypes']){
 const resource=await read(name,2017),table=parse2da(resource.bytes.toString('latin1'));
 tables.push({...resource.source,columns:table.columns,rows:table.orderedRows});
}
const referenced=new Set(tables.flatMap(table=>table.rows.map(row=>String(row.ModelName??row.Model??'').toLowerCase())));
const models=[];
function annotate(records,animations){
 for(const record of records){
  const ancestors=[];for(let at=record.index;at>=0;at=records[at].parent)ancestors.push(records[at]);
  record.transformTracks=animations.flatMap(animation=>animation.tracks.filter(track=>['position','orientation','scale'].includes(track.property)&&ancestors.some(ancestor=>ancestor.name.toLowerCase()===track.node.toLowerCase())).map(track=>({animation:animation.name,...track})));
  record.opacityTracks=animations.flatMap(animation=>animation.tracks.filter(track=>track.property==='alpha'&&track.node.toLowerCase()===record.name.toLowerCase()).map(track=>({animation:animation.name,...track})));
  record.noAuthoredTrsTrackOnSelfOrAncestor=record.transformTracks.length===0;
  record.uniqueChainNames=ancestors.every(ancestor=>records.filter(other=>other.name.toLowerCase()===ancestor.name.toLowerCase()).length===1&&ancestor.parent!==-2);
 }
}
for(const name of selected){
 if(!referenced.has(name))throw Error('Selected model is not a current installed door table entry: '+name);
 const resource=await read(name,2002),bytes=resource.bytes;
 if(bytes.readUInt32LE(0)!==0){
  const text=bytes.toString('latin1'),model=parseAsciiMdl(text);if(model.nodes.length>256)throw Error('ASCII door node cap');
  const records=model.nodes.map((node,index)=>{
   const parents=model.nodes.map((other,i)=>({other,i})).filter(({other})=>other.name.toLowerCase()===node.parent.toLowerCase());
   const scalar=(key,fallback)=>Array.isArray(node.properties[key])?node.properties[key][0]:node.properties[key]??fallback;
   const mesh=['trimesh','skin','animmesh','aabb'].includes(node.type)?{authoredBounds:null,computedVertexBounds:node.verts.length?{min:[0,1,2].map(axis=>Math.min(...node.verts.map(vertex=>vertex[axis]))),max:[0,1,2].map(axis=>Math.max(...node.verts.map(vertex=>vertex[axis])))}:null,render:scalar('render',1),tilefadeRaw:scalar('tilefade',null),transparencyHint:scalar('transparencyhint',null),vertices:node.verts.length,faces:node.faces.length,boundsProvenance:'ASCII source has no serialized binary header; computed vertices are reported separately, not claimed native runtime bounds',rawBoundFields:Object.fromEntries(Object.entries(node.properties).filter(([key])=>/bound|bbox|bmin|bmax/i.test(key)))}:null;
   return {index,name:node.name,parent:node.parent.toUpperCase()==='NULL'?-1:parents.length===1?parents[0].i:-2,id:null,type:node.type,position:node.position,orientation:node.orientation,orientationFormat:node.orientationFormat,scale:scalar('scale',node.scale),alpha:scalar('alpha',1),bitmap:node.bitmap,mesh};
  });
  const animations=model.animations.map(animation=>({name:animation.name,length:animation.length,tracks:animation.tracks.filter(track=>['position','orientation','scale','alpha'].includes(track.property))}));
  annotate(records,animations);models.push({...resource.source,format:'ASCII MDL',supermodel:model.supermodel,unsupportedAnimations:model.unsupportedAnimations,records,animations});continue;
 }
 const array=bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),model=parseBinaryMdl(array);
 if(model.nodes.length>256)throw Error('Selected door exceeds bounded node count');
 const records=[];const visited=new Set();const modelEnd=12+bytes.readUInt32LE(4);
 const range=(at,size)=>{if(at<12||at+size>modelEnd)throw Error('Raw MDL metadata exceeds model section');};
 const vec=at=>[0,4,8].map(offset=>bytes.readFloatLE(at+offset));
 function walk(relative,parent=-1){
  const at=12+relative;range(at,112);if(visited.has(relative))throw Error('Raw MDL hierarchy cycle');visited.add(relative);
  const index=records.length,flags=bytes.readUInt32LE(at+108),node=model.nodes[index];
  const rawName=bytes.subarray(at+32,at+64).toString('ascii').split('\0')[0];
  if(node?.name!==rawName||node.parentIndex!==parent)throw Error('Raw/parsed node-order witness differs');
  let cursor=at+112;for(const [flag,size]of[[2,92],[4,216],[16,68]])if(flags&flag)cursor+=size;
  let mesh=null;
  if(flags&32){
   range(cursor,512);
   const computed=node.verts.length?{min:[0,1,2].map(axis=>Math.min(...node.verts.map(vertex=>vertex[axis]))),max:[0,1,2].map(axis=>Math.max(...node.verts.map(vertex=>vertex[axis])))}:null;
   mesh={extensionOffset:cursor-at,authoredBounds:{min:vec(cursor+0x14),max:vec(cursor+0x20)},computedVertexBounds:computed,
    render:bytes.readUInt32LE(cursor+0x6c),shadow:bytes.readUInt32LE(cursor+0x64),transparencyHint:bytes.readUInt32LE(cursor+0x70),tilefadeRaw:bytes.readUInt32LE(cursor+0x178),
    bboxSourceBytes:bytes.subarray(cursor+0x14,cursor+0x2c).toString('hex'),renderSourceBytes:bytes.subarray(cursor+0x6c,cursor+0x70).toString('hex'),tilefadeSourceBytes:bytes.subarray(cursor+0x178,cursor+0x17c).toString('hex'),
    vertices:node.verts.length,faces:node.faces.length};
  }
  records.push({index,name:node.name,parent,id:node.nativeNode.id34,relativeOffset:relative,flags,position:node.position,orientation:node.orientation,scale:node.scale,alpha:node.alpha,bitmap:node.bitmap,mesh});
  const childOffset=bytes.readUInt32LE(at+72),childCount=bytes.readUInt32LE(at+76);range(12+childOffset,childCount*4);
  for(let child=0;child<childCount;child++)walk(bytes.readUInt32LE(12+childOffset+child*4),index);
 }
 walk(bytes.readUInt32LE(84));
 const animations=model.animations.map(animation=>({name:animation.name,length:animation.length,tracks:animation.tracks.filter(track=>['position','orientation','scale','alpha'].includes(track.property)).map(track=>({node:track.node,property:track.property,interpolation:track.interpolation,frames:track.frames})),nativeNodes:[]}));
 for(let i=0;i<animations.length;i++){
  const pending=[model.animations[i].nativeRoot];
  while(pending.length){const node=pending.pop();if(!node)continue;animations[i].nativeNodes.push({name:node.name,id:node.id34,trsControllers:node.controllers78.filter(controller=>[16,40,44].includes(controller.displacement0)).map(controller=>({...controller,values:node.values88}))});pending.push(...node.children68);}
 }
 annotate(records,animations);
 models.push({...resource.source,format:model.format,supermodel:model.supermodel,unsupportedAnimations:model.unsupportedAnimations,records,animations});
}
for(const key of keys)if(hash(await fs.readFile(path.join(install,key.name)))!==key.sha256)throw Error('Installed KEY changed');
const output=path.resolve('godot-client/tools/native_parity/doors/asset-source-'+label+'.json');
await fs.writeFile(output,JSON.stringify({version:1,scope:'Read-only installed table/MDL static metadata and controller tracks; not runtime hit testing or renderer parity',keys,tables,models},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({output,tables:tables.map(table=>({name:table.name,rows:table.rows.length})),models:models.map(model=>({name:model.name,format:model.format,nodes:model.records.length,supermodel:model.supermodel,unsupported:model.unsupportedAnimations,stationaryMeshes:model.records.filter(record=>record.mesh&&record.noAuthoredTrsTrackOnSelfOrAncestor).map(record=>({name:record.name,position:record.position,orientation:record.orientation,alpha:record.alpha,opacityTracks:record.opacityTracks,bitmap:record.bitmap,render:record.mesh.render,tilefade:record.mesh.tilefadeRaw,bounds:record.mesh.authoredBounds,computedBounds:record.mesh.computedVertexBounds,uniqueChain:record.uniqueChainNames})),hidden:model.records.filter(record=>record.mesh&&record.mesh.render===0).map(record=>record.name)}))}));
