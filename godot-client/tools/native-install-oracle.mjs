// Read-only original resources. Retain only paths, sizes and hashes, never art.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {parseKey} from '../../src/resource_archive.js';
import {parse2da} from '../../src/area.js';
import {parseGff,getGffStructType} from '../../src/gff.js';
import {parseBinaryMdl} from '../../src/binary_mdl.js';
const install=path.resolve('../FullDecomp/NwnRootInstall'),keys=[],resources=new Map();
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const floatHash=values=>hash(Buffer.from(new Float32Array(values).buffer));
const indexHash=values=>hash(Buffer.from(new Int32Array(values).buffer));
for(const relative of ['data/nwn_retail.key','data/nwn_base.key']){
 const filename=path.join(install,relative),bytes=await fs.readFile(filename),key=parseKey(bytes);keys.push({relative,sha256:hash(bytes),entries:key.resources.size});
 for(const[name,entry]of key.resources)if(!resources.has(name))resources.set(name,{...entry,bif:key.bifNames[entry.bifIndex]});
}
async function read(name,type){
 const entry=resources.get(name+':'+type);if(!entry)throw Error('Original installed sample unavailable: '+name);
 const file=await fs.open(path.join(install,entry.bif),'r');
 try{const h=Buffer.alloc(20);await file.read(h,0,20,0);if(h.toString('ascii',0,4)!=='BIFF'||h.readUInt32LE(12)!==0)throw Error('Unsupported original BIF');const v11=h.toString('ascii',4,8)==='V1.1',stride=v11?20:16,record=Buffer.alloc(stride);await file.read(record,0,stride,h.readUInt32LE(16)+entry.resourceIndex*stride);const p=v11?8:4;if(record.readUInt32LE(p+8)!==type)throw Error('Original BIF type mismatch');const size=record.readUInt32LE(p+4),bytes=Buffer.alloc(size);if((await file.read(bytes,0,size,record.readUInt32LE(p))).bytesRead!==size)throw Error('Original BIF payload truncated');return bytes;}finally{await file.close();}
}
const chosen=[['nwscript',2009],['visualeffects',2017],['c_golstone',2002]];
for(const type of [2033,2025]){const match=[...resources.values()].find(row=>row.resourceType===type);if(match)chosen.push([match.resref,type]);}
const samples=[];
for(const[name,type]of chosen){const bytes=await read(name,type),entry={name,type,bytes:bytes.length,sha256:hash(bytes)};if(type===2017)entry.tableRows=parse2da(bytes.toString('latin1')).orderedRows.length;if(type===2025){const doc=parseGff(bytes);entry.gff={type:doc.fileType,rootType:getGffStructType(doc.root),rootFields:Object.keys(doc.root).length};}if(type===2002){const model=parseBinaryMdl(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength));entry.model={name:model.modelName,nodes:model.nodes.map(n=>({name:n.name,parent:n.parentIndex,transformSha256:floatHash([...n.position,...n.orientation,n.scale,n.alpha,...(n.selfillumcolor??[0,0,0])]),...(n.type==='trimesh'?{mesh:{vertices:floatHash(n.verts.flat()),normals:floatHash(n.nativeVertexNormals??[]),uv:n.tvertsByLayer.map(layer=>floatHash(layer.flatMap(v=>v.slice(0,2)))),indices:indexHash(n.faces.flatMap(f=>f.slice(0,3))),collision_indices:indexHash((n.nativeCollisionFaces??[]).flatMap(f=>f.indices)),textures:n.textureLayers,render:n.render,shadow:n.shadow}}:{})}))};}samples.push(entry);}
const report={scope:'Read-only installed KEY/BIF resources; hash/count evidence only, no copied art',install,keys,samples};
const reportName=process.argv.find(arg=>arg.startsWith('--report='))?.slice(9)??'native-install-oracle-v1.json';
if(!/^[a-z0-9-]+\.json$/.test(reportName))throw Error('Invalid report basename');
await fs.writeFile(path.join('godot-client/reports',reportName),JSON.stringify(report,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({keys:keys.map(row=>({relative:row.relative,entries:row.entries})),samples:samples.map(({name,type,bytes})=>({name,type,bytes}))}));
