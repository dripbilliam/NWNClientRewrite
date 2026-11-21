import fs from 'node:fs/promises';import crypto from 'node:crypto';import assert from 'node:assert/strict';import * as T from 'three';
import {manageLocalMatrix,commitLocalMatrix,setManagedMatrixReuse,managedMatrixReuseSnapshot} from '../src/managed_local_matrix.js';
const median=a=>[...a].sort((x,y)=>x-y)[Math.floor(a.length/2)],p95=a=>[...a].sort((x,y)=>x-y)[Math.ceil(a.length*.95)-1];
function fixture(){const scene=manageLocalMatrix(new T.Scene()),models=[];for(let i=0;i<100;i++){const root=new T.Group(),nodes=[];root.position.set(i%10*4,0,Math.floor(i/10)*4);if(i<80)manageLocalMatrix(root);scene.add(root);for(let j=0;j<64;j++){const node=manageLocalMatrix(new T.Group());node.position.set(j*.01,j*.02,j*.03);commitLocalMatrix(node);(j?nodes[Math.floor((j-1)/2)]:root).add(node);nodes.push(node);}models.push({root,nodes});}scene.updateMatrixWorld(true);return{scene,models};}
function step(f,frame,dynamicFraction){for(const [i,{root,nodes}]of f.models.entries()){if(i>=80)root.position.y=Math.sin(frame*.013+i)*.1;for(const[j,node]of nodes.entries()){node.position.x=j*.01+((j%64)/64<dynamicFraction?Math.sin(frame*.017+i+j)*.2:0);commitLocalMatrix(node);}root.updateWorldMatrix(true,true);}f.scene.updateMatrixWorld();}
function checksum(f){const values=[];f.scene.traverse(n=>values.push(...n.matrix.elements,...n.matrixWorld.elements));return crypto.createHash('sha256').update(new Uint8Array(new Float64Array(values).buffer)).digest('hex');}
const runs=[];
try{
 for(const dynamicFraction of [0,.125,1])for(let round=0;round<4;round++)for(const enabled of round%2?[true,false]:[false,true]){
  setManagedMatrixReuse(enabled);const f=fixture();for(let i=0;i<40;i++)step(f,i,dynamicFraction);const before=managedMatrixReuseSnapshot(),frames=[];
  for(let i=40;i<160;i++){const at=performance.now();step(f,i,dynamicFraction);frames.push(performance.now()-at);}
  const after=managedMatrixReuseSnapshot();runs.push({dynamicFraction,round,enabled,medianMs:median(frames),p95Ms:p95(frames),frames,checksum:checksum(f),reused:after.reused-before.reused,composed:after.composed-before.composed});
 }
 for(const row of runs){const pair=runs.find(r=>r.dynamicFraction===row.dynamicFraction&&r.round===row.round&&r.enabled!==row.enabled);assert.equal(row.checksum,pair.checksum);}
 const groups=[0,.125,1].map(fraction=>({dynamicFraction:fraction,ordinaryMedianMs:median(runs.filter(r=>r.dynamicFraction===fraction&&!r.enabled).map(r=>r.medianMs)),reuseMedianMs:median(runs.filter(r=>r.dynamicFraction===fraction&&r.enabled).map(r=>r.medianMs))}));
 const source=await fs.readFile('src/managed_local_matrix.js');await fs.writeFile('backups/animations/managed-matrix-reuse-cpu-v1.json',JSON.stringify({success:true,scope:'Pure CPU authored transform workload, 100 models x64 parts; immediate producer queries then frame world pass. Not whole-client FPS.',sourceSha256:crypto.createHash('sha256').update(source).digest('hex'),groups,runs},null,2)+'\n');console.log(JSON.stringify({success:true,groups}));
}finally{setManagedMatrixReuse(false);}
