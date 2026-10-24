import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import inspector from 'node:inspector';
import {performance} from 'node:perf_hooks';
import * as THREE from 'three';
import {createModelEmitter,ModelParticlePresentation} from '../src/model_particles.js';

// Authored offline load fixture. No installed resources, connection, gameplay
// state, or proprietary asset data. Same seed/trajectory makes output comparable.
const version=process.argv[2]??'baseline';if(!/^[a-z0-9-]+$/.test(version))throw Error('Invalid benchmark version');
const output=new URL(`../backups/animations/particle-presentation-${version}.json`,import.meta.url);
const profile=new inspector.Session();profile.connect();const command=(name,args={})=>new Promise((resolve,reject)=>profile.post(name,args,(error,result)=>error?reject(error):resolve(result)));
const root=new THREE.Group(),camera=new THREE.PerspectiveCamera(),texture=new THREE.Texture(),diagnostics=[];
const presentation=new ModelParticlePresentation({camera,seed:17,report:(...args)=>diagnostics.push(args)});
const emitters=80,models=20;
for(let i=0;i<models;i++){
 const model=new THREE.Group();model.userData.mdlRoot='authored-particle-benchmark';model.position.set((i%5)*10,0,-Math.floor(i/5)*10);root.add(model);
 for(let j=0;j<emitters/models;j++){
  let parent=model;for(let depth=0;depth<5;depth++){const child=new THREE.Group();child.position.set(.02,.03,-.01);parent.add(child);parent=child;}
  const node={name:`emitter-${i}-${j}`,properties:{texture:'fixture',update:'Fountain',render:['Normal','Billboard_to_World_Z','Motion_Blur','Aligned_to_Particle_Dir'][j],blend:'Lighten',birthrate:80,lifeexp:2,sizestart:.3,sizeend:.6,colorstart:[1,.5,.25],colorend:[.2,.2,.1],alphastart:.6,alphaend:0,xgrid:1,ygrid:1,velocity:1,randvel:.5,affectedbywind:'false'}};
  parent.add(createModelEmitter(node,new Map([['fixture',texture]]),'authored-particle-benchmark'));
 }
}
const phases={simulationAndVertices:[],upload:[]},times=[];
const upload=presentation.upload.bind(presentation);presentation.upload=(...args)=>{const start=performance.now();const result=upload(...args);phases.upload.push(performance.now()-start);return result;};
const step=(frame)=>{camera.position.set(Math.sin(frame*.01)*15,8,Math.cos(frame*.01)*15);camera.lookAt(15,1,-15);root.children[0].rotation.y=frame*.002;const started=performance.now(),before=phases.upload.length;presentation.update(root,1/60);const ms=performance.now()-started,uploadMs=phases.upload.slice(before).reduce((n,v)=>n+v,0);times.push(ms);phases.simulationAndVertices.push(ms-uploadMs);};
for(let frame=0;frame<150;frame++)step(frame);
times.length=0;phases.upload.length=0;phases.simulationAndVertices.length=0;
await command('Profiler.enable');await command('Profiler.setSamplingInterval',{interval:1000});await command('Profiler.start');
for(let frame=150;frame<270;frame++)step(frame);
const {profile:cpu}=await command('Profiler.stop');profile.disconnect();
const hash=crypto.createHash('sha256');for(const entry of presentation.entries.values()){
 for(const key of ['position','uv','particleColor']){const attr=entry.mesh.geometry.getAttribute(key);hash.update(Buffer.from(attr.array.buffer,attr.array.byteOffset,entry.drawCount*attr.itemSize*attr.array.BYTES_PER_ELEMENT));}
 hash.update(JSON.stringify(entry.e.active188.records,(key,value)=>key==='emitter8'?undefined:value));
}
const percentile=(a,p)=>a.toSorted((a,b)=>a-b)[Math.min(a.length-1,Math.floor(a.length*p))],summary=a=>({meanMs:a.reduce((n,v)=>n+v,0)/a.length,p50Ms:percentile(a,.5),p95Ms:percentile(a,.95),maxMs:Math.max(...a)});
const hits=new Map();for(const id of cpu.samples??[])hits.set(id,(hits.get(id)??0)+1);
const report={version,scope:'Deterministic authored CPU particle fixture; not GPU or whole-game FPS',emitters,models,frames:times.length,active:[...presentation.entries.values()].reduce((n,e)=>n+e.e.active188.records.length,0),vertices:[...presentation.entries.values()].reduce((n,e)=>n+e.drawCount,0),total:summary(times),upload:summary(phases.upload),simulationAndVertices:summary(phases.simulationAndVertices),hash:hash.digest('hex'),failed:[...presentation.entries.values()].filter(e=>e.failed).length,diagnostics:diagnostics.map(d=>d[0]),profileTop:cpu.nodes.filter(n=>hits.has(n.id)).toSorted((a,b)=>hits.get(b.id)-hits.get(a.id)).slice(0,14).map(n=>({function:n.callFrame.functionName,url:n.callFrame.url,line:n.callFrame.lineNumber,samples:hits.get(n.id)})),sourceSha256:crypto.createHash('sha256').update(await fs.readFile(new URL('../src/model_particles.js',import.meta.url))).digest('hex')};
report.sourceHashes={};for(const name of ['model_particles','particle_vertices','particle_math','path_grid_storage'])report.sourceHashes[name]=crypto.createHash('sha256').update(await fs.readFile(new URL(`../src/${name}.js`,import.meta.url))).digest('hex');
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');await fs.writeFile(new URL(`../backups/animations/particle-presentation-${version}.cpuprofile`,import.meta.url),JSON.stringify(cpu)+'\n');presentation.dispose();texture.dispose();console.log(JSON.stringify(report,null,2));
if(report.failed)process.exitCode=1;
