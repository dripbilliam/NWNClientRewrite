import test from 'node:test';import assert from 'node:assert/strict';import * as T from 'three';
import {createModelEmitter} from '../../src/model_particles.js';import {prepareParticleTransfer} from './export-particles.mjs';import {prepareGodotRoom} from './export-room.mjs';
import {NativeParticleSimulation} from './particle-simulation.mjs';import {NativeParticleWorkers} from './particle-workers.mjs';import {ParticleDelivery} from './particle-delivery.mjs';
import wireModule from './particle-wire.cjs';import {sampleTrack} from '../../src/model_animation.js';
const {particlePackets,MAX_BINARY}=wireModule,layout={vertexStride:12,attributeStride:12,colorOffset:0,uvOffset:4},identity=new T.Matrix4().toArray();
const descriptor=id=>({id,objectId:id,matrix:identity,rootMatrix:identity,textureAvailable:true,properties:{texture:'authored',update:'Fountain',render:'Normal',blend:'Normal',birthrate:20,lifeexp:1,sizestart:1,sizeend:1,colorstart:[1,1,1],colorend:[1,1,1],alphastart:1,alphaend:1,xgrid:1,ygrid:1,velocity:1,affectedbywind:0}});
const frame=(sequence,poses=[])=>({epoch:1,sequence,delta:.1,camera:identity,poses});

test('tinted emitters require an explicit native engine-lighting material; other missing light providers remain failures',()=>{
 for(const enabled of [false,true]){const simulation=new NativeParticleSimulation({layout}),row=descriptor(7);row.properties.tinted=1;row.engineLighting=enabled;
 try{simulation.reset({epoch:1,emitters:[row]});const result=simulation.frame(frame(0));assert.equal(result.state[0].failed,!enabled);assert.equal(result.emitters[0].count>0,enabled);assert.equal(simulation.nodes.get(7).mesh.userData.mdlEmitter.properties.tinted,1,'original flags are preserved');}
 finally{simulation.close();}}
});

test('new private emitters wait for their first actual native pose without drawing random numbers at the resource origin',()=>{
 const simulation=new NativeParticleSimulation({layout}),row={...descriptor(11),awaitPose:true};
 try{simulation.reset({epoch:1,emitters:[row]});const waiting=simulation.frame(frame(0));assert.equal(waiting.emitters[0].count,0);assert.equal(waiting.randomDraws,0);
  const position=new T.Matrix4().makeTranslation(54,2,-42).toArray(),active=simulation.frame(frame(1,[{id:11,matrix:position,rootMatrix:position}]));assert.ok(active.emitters[0].count>0);const values=new Float32Array(active.emitters[0].positions);assert.ok(values[0]>50);assert.ok(values[2]<-35);
 }finally{simulation.close();}
});

test('initially hidden/empty emitter exports its actual texture and physical binding with stable IDs',()=>{
 const scene=new T.Scene(),camera=new T.PerspectiveCamera(),root=new T.Group(),part=new T.Group();root.userData.mdlRoot=true;root.userData.networkObjectId=1;root.add(part);scene.add(root);
 const texture=new T.DataTexture(new Uint8Array([12,34,56,255]),1,1),row=descriptor(1),emitter=createModelEmitter({name:'authored',properties:row.properties},new Map([['authored',texture]]),'authored');part.add(emitter);
 const source={instances:new Set([{root,model:{animations:[{name:'default',length:1,tracks:[{node:'authored',property:'emitter.birthrate',frames:[{time:0,value:[0]}]}]}]}}])},rigTransfer={nodeBinding:()=>({objectId:1,rigNode:3,modelIndex:0})};
 const transfer=prepareParticleTransfer({scene,camera,presentation:source,rigTransfer}),again=prepareParticleTransfer({scene,camera,presentation:source,rigTransfer});
 assert.equal(emitter.visible,false);assert.equal(emitter.geometry.attributes.position,undefined);assert.equal(transfer.data.emitters.length,1);assert.equal(transfer.data.emitters[0].id,again.data.emitters[0].id);assert.deepEqual(transfer.data.emitters[0].nativeParent,{objectId:1,rigNode:3,modelIndex:0});
 const prepared=prepareGodotRoom({scene,camera,inventory:[{id:1}],buffer:[800,600],particleTransfer:transfer});
 try{assert.equal(prepared.manifest.meshes.length,1);assert.equal(prepared.manifest.meshes[0].liveParticle,true);assert.equal(prepared.manifest.particles.emitters[0].textureMesh,prepared.scene.children[0].name);assert.deepEqual([...prepared.scene.children[0].material.map.image.data],[12,34,56,255]);assert.ok([...prepared.scene.children[0].geometry.attributes.color.array].every(byte=>byte===0));assert.equal(emitter.visible,false);assert.equal(transfer.data.collision.length,0);}finally{prepared.dispose();texture.dispose();emitter.geometry.dispose();emitter.material.dispose();}
});

test('delta emitter discovery respects selected object IDs and keeps false-string bounce flags out of static collision exports',()=>{
 const scene=new T.Scene(),camera=new T.PerspectiveCamera();for(const id of [1,2]){const root=new T.Group();root.userData.mdlRoot=true;root.userData.networkObjectId=id;scene.add(root);const row=descriptor(id);root.add(createModelEmitter({name:'authored',properties:{...row.properties,bounce:'false'}},new Map(),'authored'));}
 const result=prepareParticleTransfer({scene,camera,objectIds:new Set([2])});assert.equal(result.data.emitters.length,1);assert.equal(result.data.emitters[0].objectId,2);assert.equal(result.data.collision.length,0);
});

test('sampled original linear/Bezier emitter controllers reset to defaults on clip change',()=>{
 const row=descriptor(1),track={property:'emitter.birthrate',interpolation:'bezier',frames:[{time:0,value:[0],in:[0],out:[5]},{time:1,value:[40],in:[-4],out:[0]}]};row.clips={authored:{tracks:[track]}};
 const native=new NativeParticleSimulation({layout});native.reset({epoch:1,emitters:[row]});
 try{native.frame(frame(0,[{id:1,matrix:identity,rootMatrix:identity,animation:{clip:'authored',time:.4}}]));const entry=native.simulation.entries.get(native.nodes.get(1).mesh);assert.equal(entry.e.birthRate,Math.fround(sampleTrack(track,.4)[0]));native.frame(frame(1,[{id:1,matrix:identity,rootMatrix:identity,animation:{clip:'other',time:.2}}]));assert.equal(entry.e.birthRate,20);}finally{native.close();}
});

test('same-area worker patches retain untouched particles/RNG and retire removed emitter storage',async()=>{
 const workers=new NativeParticleWorkers({count:2,layout});try{await workers.reset({epoch:1,emitters:[descriptor(1),descriptor(2)]});const first=await workers.frame(frame(0));await workers.patch({epoch:1,remove:[2],add:[descriptor(3)]});const second=await workers.frame(frame(1));assert.deepEqual(second.emitters.map(row=>row.id),[1,3]);assert.ok(second.state.find(row=>row.frames===2));assert.ok(second.emitters.find(row=>row.id===1).count>first.emitters.find(row=>row.id===1).count);assert.equal(workers.pending.size,0);await assert.rejects(workers.patch({epoch:1,add:[descriptor(1)]}),/reuses/);assert.equal(workers.ready,true);}finally{await workers.close();}
});

test('binary packets contain bounded metadata and exact uninterpreted bytes, split large batches, and reject duplicate/invalid streams',()=>{
 const simulation=new NativeParticleSimulation({layout});simulation.reset({epoch:1,emitters:[descriptor(1)]});try{const result=simulation.frame(frame(0)),scope={connection:1,areaId:2147483649,generation:1,transferId:1},packets=particlePackets(scope,result),packet=packets[0],size=packet.readUInt32LE(8);assert.equal(packet.subarray(0,4).toString('hex'),'89504152');assert.equal(packet.readUInt32LE(4),packet.length-8);const metadata=JSON.parse(packet.subarray(12,12+size));assert.equal(metadata.areaId,2147483649);assert.deepEqual(packet.subarray(12+size,12+size+result.emitters[0].positions.byteLength),Buffer.from(result.emitters[0].positions));assert.ok(packet.length<=MAX_BINARY+8);assert.throws(()=>particlePackets(scope,{...result,emitters:[...result.emitters,...result.emitters]}),/Duplicate/);assert.throws(()=>particlePackets({...scope,connection:-1},result),/scope/);assert.throws(()=>particlePackets(scope,{...result,emitters:[{...result.emitters[0],capacity:196614}]}),/Invalid/);
 const many=Array.from({length:257},(_,id)=>({...result.emitters[0],id}));assert.equal(particlePackets(scope,{...result,emitters:many}).length,3);}finally{simulation.close();}
});

test('delivery uses actual workers, scopes output to current owner, and shuts down pending resources',async()=>{
 const messages=[],packets=[],report={epochs:[]};let current=true;
 const delivery=new ParticleDelivery({scope:{connection:1,areaId:2,generation:1,transferId:1},data:{epoch:1,emitters:[descriptor(1)],collision:[]},wire:{sendParticles:(scope,result)=>packets.push(...particlePackets(scope,result))},send:message=>messages.push(message),current:()=>current,diagnose:()=>{},report});
 try{await delivery.start(layout);assert.equal(messages[0].kind,'particles-ready');await delivery.frame(frame(0));assert.equal(packets.length,1);assert.equal(messages.at(-1).kind,'particle-complete');assert.equal(report.epochs[0].frames,1);current=false;await delivery.frame(frame(1));assert.equal(packets.length,1);}finally{await delivery.close();}assert.equal(delivery.workers.pending.size,0);
});

test('model additions during initial worker setup are applied without losing emitters, and retirement cannot publish late readiness',async()=>{
 const messages=[],report={epochs:[]},delivery=new ParticleDelivery({scope:{connection:1,areaId:2,generation:1,transferId:1},data:{epoch:1,emitters:[descriptor(1)]},wire:{sendParticles:()=>{}},send:message=>messages.push(message),current:()=>true,diagnose:()=>{},report});
 try{const start=delivery.start(layout),patch=delivery.patch({removeObjects:[],add:[descriptor(2)]});await Promise.all([start,patch]);const result=await delivery.workers.frame(frame(0));assert.deepEqual(result.emitters.map(row=>row.id),[1,2]);}finally{await delivery.close();}
 const late=[],retired=new ParticleDelivery({scope:{connection:1,areaId:2,generation:1,transferId:1},data:{epoch:1,emitters:[descriptor(1)]},wire:{sendParticles:()=>{}},send:message=>late.push(message),current:()=>true,diagnose:()=>{},report:{epochs:[]}});
 const start=retired.start(layout);await retired.close();await start;assert.equal(late.length,0);assert.equal(retired.stats.remainingThreads,0);assert.equal(retired.stats.pendingJobs,0);
});
