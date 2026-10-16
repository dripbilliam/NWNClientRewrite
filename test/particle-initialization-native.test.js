import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import { NativeRandom } from '../src/native_random.js';
import { createParticle, initializeParticle, randomizeParticleFrame } from '../src/particle_initialization.js';
const f=Math.fround;

test('particle construction/initialization matches876 original executions including real direction/inheritance and CRT math',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-particle-initialization-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,876);
 assert.ok(oracle.coverage.correctionCases>0);assert.ok(oracle.coverage.correctionIterations>oracle.coverage.correctionCases);
 for(const row of oracle.rows){
  const c=row.case,rng=new NativeRandom(c.seed),draws=[],e={flags:c.flags,deadspace:f(c.deadspace),position1e0:[4,-3,2],previous19c:[3,-2,1],previousQuaternion178:[1,0,0,0],quaternion1d0:c.quaternion.map(f),basis140:c.basis.map(f),frameStart:f(.5),frameEnd:f(3.75),randomVelocity:f(c.randomVelocity),velocity:2,xSize:f(c.size[0]),ySize:f(c.size[1]),spread:f(c.spread)};
  const p={random:()=>{const v=rng.next();draws.push(v);return v;},cameraPosition:()=>[10,20,30],cosineDouble:Math.cos};
  let particle={emitter8:e};
  if(c.mode==='constructor'||c.mode==='both')particle=createParticle(e,c.delta,p);
  if(c.mode==='initialize'||c.mode==='both')initializeParticle(particle,c.delta,c.factor,p);
  randomizeParticleFrame(e,particle,p);
  const out={draws,rng:rng.state,position:particle.position10,rotation:particle.rotation1c,inheritedSpeed:particle.inheritedSpeed20,inheritedDirection:particle.inheritedDirection24,quaternion:particle.quaternion34,frame:particle.frame44,field48:particle.field48,direction:particle.direction4c,velocity:particle.velocity58,trail:particle.trail64,stopped:particle.stopped70,age:particle.age};
  const {case:_case,...expected}=row;assert.deepEqual(out,expected,JSON.stringify(c));
 }
});
