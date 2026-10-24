import test from 'node:test';
import assert from 'node:assert/strict';
import {ParticleDelivery} from './particle-delivery.mjs';
const turn=()=>new Promise(resolve=>setImmediate(resolve));
test('canonical and private mutations serialize across worker acknowledgments without losing either namespace',async()=>{
 const report={epochs:[]},calls=[];let acknowledge;
 const service=new ParticleDelivery({scope:{},data:{epoch:1,emitters:[{id:1,objectId:7}]},current:()=>true,report});
 service.workers={patch:async value=>{calls.push(value);if(calls.length===1)await new Promise(resolve=>acknowledge=resolve);},close:async()=>{},pending:new Map(),slots:[]};
 const canonical=service.patch({removeObjects:[7],add:[{id:2,objectId:7}]}),privateAdd=service.patch({removeObjects:[],add:[{id:2**40+1,objectId:-11}]}),privateRemove=service.patch({removeObjects:[-11],add:[]});
 await turn();assert.equal(calls.length,1);assert.equal(service.changing,true);assert.deepEqual([...service.rows.keys()],[2]);
 acknowledge();await Promise.all([canonical,privateAdd,privateRemove]);
 assert.deepEqual(calls.map(row=>({remove:row.remove,ids:row.add.map(item=>item.id)})),[{remove:[1],ids:[2]},{remove:[],ids:[2**40+1]},{remove:[2**40+1],ids:[]}]);
 assert.deepEqual([...service.rows.keys()],[2]);assert.deepEqual([...service.activeIds],[2]);assert.equal(service.changing,false);await service.close();assert.equal(report.epochs[0].pendingJobs,0);
});

test('retiring an in-flight frame closes workers without publishing failure into the next world',async()=>{
 let reject;const sent=[],diagnostics=[],report={epochs:[]},service=new ParticleDelivery({scope:{connection:1},data:{epoch:1,emitters:[]},current:()=>true,send:v=>sent.push(v),diagnose:(...v)=>diagnostics.push(v),report});
 service.workers={frame:()=>new Promise((_r,e)=>reject=e),close:async()=>reject(Error('Particle workers closed')),pending:new Map(),slots:[]};
 const frame=service.frame({epoch:1,sequence:1,poses:[]});await service.close();await frame;
 assert.equal(sent.length,0);assert.equal(diagnostics.length,0);assert.equal(service.stats.retiredFrames,1);assert.equal(service.stats.remainingThreads,0);assert.equal(service.busy,false);
});
test('a current-world worker failure remains visible and completes the failed frame',async()=>{
 const sent=[],diagnostics=[],service=new ParticleDelivery({scope:{connection:1},data:{epoch:1,emitters:[]},current:()=>true,send:v=>sent.push(v),diagnose:(...v)=>diagnostics.push(v),report:{epochs:[]}});
 service.workers={frame:async()=>{throw Error('actual current failure');}};await service.frame({epoch:1,sequence:3,poses:[]});assert.equal(sent[0].failed,true);assert.equal(sent[0].sequence,3);assert.equal(diagnostics[0][0],'godot.particle-frame-failed');assert.equal(service.stats.retiredFrames,undefined);
});
