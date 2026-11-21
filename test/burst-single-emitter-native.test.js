import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {updateExplosionEmitter,updateSingleEmitter} from '../src/burst_single_emitter.js';
const f=Math.fround;
test('Explosion and Single updates match647 complete original executions with explicit lower boundaries',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-burst-single-update-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,647);
 for(const row of oracle.rows){
  const c=row.case,calls=[],all=new Map();let nextid=c.ages.length+c.freeCount;
  const make=(id,age=0)=>{const p={id,age:f(age),field48:100+id,rotation1c:id%2===0?7:-7,position10:[.5,1,1.5].map(v=>f(v+id)),trail64:[-1,-2,-3],chunk78:id%2===0?{id}:null};all.set(id,p);return p;};
  const e={lifeExp:f(c.life),loop:c.loop,chunkName:c.chunk?'synthetic_chunk':'',birthRate:f(c.rate),source50:c.source?{}:null,renderMode1a8:c.renderMode,blurLength:f(.3),particleRot:f(2.25),position1e0:[1.25,-.5,.75],blastRadius:f(c.blastRadius),blastLength:f(.5),blastLatch1c8:f(c.latch),detonate108:c.detonate,active188:{records:c.ages.map((age,id)=>make(id,age)),capacity:c.ages.length?16:0},free130:{records:Array.from({length:c.freeCount},(_,i)=>make(c.ages.length+i)),capacity:c.freeCount?16:0}};
  const providers={sourceFactor:()=>{calls.push(['source',c.factor]);return c.factor;},reserveFree:n=>calls.push(['reserveFree',n]),reserveActive:n=>calls.push(['reserveActive',n]),detachChunk:(chunk,flag)=>calls.push(['detach',chunk.id,flag]),moveParticles:(_e,delta)=>{calls.push(['move',delta,e.active188.records.map(p=>p.id)]);if(c.moveDetonate!==undefined)e.detonate108=c.moveDetonate;},
   createParticle:(chunk,delta)=>{const particle=make(nextid++);calls.push(['construct',particle.id,Number(chunk),delta]);return particle;},
   initializeParticle:(particle,delta,factor)=>{calls.push(['initialize',particle.id,delta,factor]);particle.age=0;particle.rotation1c=0;particle.position10=[1,2,3].map(v=>f(v*factor));},
   randomizeParticle:(_e,particle)=>calls.push(['randomize',particle.id]),destroyParticle:(particle,flag)=>calls.push(['destroy',particle.id,flag]),addPointSourceWind:(...args)=>calls.push(['wind',...args])};
  (c.kind==='Explosion'?updateExplosionEmitter:updateSingleEmitter)(e,c.delta,providers);
  const out={calls,active:e.active188.records.map(p=>p.id),free:e.free130.records.map(p=>p.id),activeCapacity:e.active188.capacity,freeCapacity:e.free130.capacity,latch:e.blastLatch1c8,detonate:e.detonate108,particles:[...all.values()].sort((a,b)=>a.id-b.id).map(p=>({id:p.id,age:p.age,field48:p.field48,rotation:p.rotation1c,position:p.position10,trail:p.trail64}))};
  const {case:_case,...expected}=row;assert.deepEqual(out,expected,JSON.stringify(c));
 }
});
