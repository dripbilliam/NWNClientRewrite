// Authored numeric particle art only; never reads/copies proprietary content.
import fs from 'node:fs/promises';
import path from 'node:path';
import * as T from 'three';
import {NativeParticleWorkers} from './particle-workers.mjs';

const output=process.argv.find(arg=>arg.startsWith('--output='))?.slice(9);
if(!output || !/^[a-z0-9-]+\.json$/.test(path.basename(output))) throw Error('Use --output=<unused path>.json');
try {await fs.access(output);throw Error('Fixture exists; preserved');}catch(error){if(error.code!=='ENOENT')throw error;}
const layout={vertexStride:12,attributeStride:12,colorOffset:0,uvOffset:4}, identity=new T.Matrix4().toArray();
const workers=new NativeParticleWorkers({count:2,layout,seed:12});
const properties={texture:'authored',update:'Fountain',render:'Normal',blend:'Normal',birthrate:20,lifeexp:.35,sizestart:1.2,sizeend:1.2,
 sizestart_y:1.2,sizeend_y:1.2,colorstart:[1,.4,.1],colorend:[.1,.3,1],alphastart:1,alphaend:1,xgrid:2,ygrid:2,
 framestart:0,frameend:3,fps:12,velocity:.2,randvel:0,spread:0,affectedbywind:0};
const rows=[1,2].map(id=>({id,model:'authored-fixture',node:'authored-'+id,properties,textureAvailable:true,rootMatrix:identity,matrix:identity}));
const frames=[], prefix=path.basename(output,'.json');
try {
 await workers.reset({epoch:1,emitters:rows});
 for(let index=0;index<18;index++) {
  const camera=new T.Matrix4().makeTranslation(0,0,4).toArray();
  const poses=rows.map(({id})=>{const matrix=new T.Matrix4().makeTranslation((id===1?-.9:.9)+Math.sin(index*.25)*.12,0,0).toArray();return{id,rootMatrix:matrix,matrix,properties:{birthrate:index<7?20:0}};});
  const result=await workers.frame({epoch:1,sequence:index,delta:.05,camera,poses});
  if(result.state.some(row=>row.failed))throw Error('Authored fixture simulation failed');
  const emitters=[];
  for(const row of result.emitters) {
   const base=prefix+'-f'+index+'-e'+row.id, positionFile=base+'-positions.bin', attributeFile=base+'-attributes.bin';
   await fs.writeFile(path.join(path.dirname(output),positionFile),new Uint8Array(row.positions),{flag:'wx'});
   await fs.writeFile(path.join(path.dirname(output),attributeFile),new Uint8Array(row.attributes),{flag:'wx'});
   const p=new Float32Array(row.positions), a=new DataView(row.attributes);
   const sample=[];for(let i=0;i<row.count;i++)sample.push({position:Array.from(p.slice(i*3,i*3+3)),color:Array.from(new Uint8Array(row.attributes,i*12,4)),uv:[a.getFloat32(i*12+4,true),a.getFloat32(i*12+8,true)]});
   emitters.push({id:row.id,count:row.count,capacity:row.capacity,bounds:row.bounds,positionFile,attributeFile,sample});
  }
  frames.push({sequence:index,emitters});
 }
 await fs.writeFile(output,JSON.stringify({scope:'Authored worker simulation and packed stream fixture; no game assets or performance acceptance',layout,epoch:1,frames},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({output,frames:frames.length,workers:2}));
}finally {await workers.close();}
