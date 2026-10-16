import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {moveStandardParticles} from '../src/particle_movement.js';
const f=Math.fround;

test('standard movement and quaternion helpers match384 original wind/intersection/inheritance/bounce profiles',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-particle-movement-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,384);
 for(const row of oracle.rows){
  const c=row.case,calls=[],particles=Array.from({length:c.count},(_,i)=>({position10:[.5+i,.75-i,1+i].map(f),velocity58:[.3,-.2,.1].map(f),inheritedSpeed20:f(.4),inheritedDirection24:[.25,.5,.75],quaternion34:[1,0,0,0],trail64:[-1,-2,-3],direction4c:[0,0,1],stopped70:Number(i===2),chunk78:i%2===0?{id:i}:null}));
  const e={flags:c.flags,source50:c.source?{position:[4.5,-3.5,2.5],quaternion:[1,0,0,0]}:null,position1e0:[4,-3,2],previous19c:[3,-2,1],reference10c:[2,-1,.5],referenceQuaternion118:[.5,.5,.5,.5],quaternion1d0:c.quaternion.map(f),previousQuaternion178:[1,0,0,0],mass:f(.2),bounceCoefficient:f(c.bounce),sizeStart:f(.3),chunkName:c.chunk?'synthetic_chunk':'',active188:{records:particles},hit1f0:{normal:[0,0,0]}};
  moveStandardParticles(e,c.delta,{wind:(position,delta)=>{calls.push(['wind',position,delta]);return[.01,-.02,.03].map(f);},clearHit:hit=>{calls.push(['clearHit']);hit.normal=[0,0,0];},resetIgnoredHits:()=>calls.push(['resetIgnored']),addIgnoredHit:(_hit,chunk)=>calls.push(['ignore',chunk.id]),collide:(old,goal,out,hit)=>{calls.push(['collide',old,goal]);hit.normal=c.normal.map(f);if(c.collision)out.splice(0,3,.5,.75,1);return c.collision;}});
  const out={calls,reference:e.reference10c,referenceQuaternion:e.referenceQuaternion118,particles:particles.map(p=>({position:p.position10,velocity:p.velocity58,inheritedSpeed:p.inheritedSpeed20,quaternion:p.quaternion34,trail:p.trail64,direction:p.direction4c,stopped:p.stopped70}))};
  const {case:_case,...expected}=row;assert.deepEqual(out,expected,JSON.stringify(c));
 }
});
