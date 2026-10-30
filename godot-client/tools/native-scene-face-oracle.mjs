// Hash only original MaxFace plane/material metadata; no model payload output.
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';import {parseBinaryMdl} from '../../src/binary_mdl.js';
const hash=b=>createHash('sha256').update(b).digest('hex'),context=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),models=[];
for(const name of ['plc_a08','pmh0_chest001','c_ydrowiz','pfa0_robe003']){
 const bytes=Buffer.from(await context.getResource(name,2002)),model=parseBinaryMdl(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength));
 models.push({name,sha256:hash(bytes),nodes:model.nodes.map(node=>{const faces=node.nativeCollisionFaces??[],meta=Buffer.alloc(faces.length*20);for(const [i,face]of faces.entries()){for(let a=0;a<3;a++)meta.writeFloatLE(face.normal[a],i*20+a*4);meta.writeFloatLE(face.constant,i*20+12);meta.writeUInt32LE(face.surfaceType>>>0,i*20+16);}return{name:node.name,faces:faces.length,sha256:hash(meta)};})});
}
await fs.writeFile('godot-client/reports/native-scene-face-oracle-v1.json',JSON.stringify({scope:'Independent original binary collision-plane/surface metadata hashes only; no geometry/art copied',models})+'\n',{flag:'wx'});console.log(JSON.stringify({models:models.map(m=>({name:m.name,parts:m.nodes.length,faces:m.nodes.reduce((n,p)=>n+p.faces,0)}))}));
