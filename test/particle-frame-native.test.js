import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {animateEmitterParticles} from '../src/particle_frame.js';
const f=Math.fround;
test('outer particle frame gates, history, basis and time match800 complete original executions',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-particle-frame-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,800);
 for(const row of oracle.rows){
  const c=row.case,calls=[],e={flags:c.flags,initialized208:c.initialized,source50:c.source?{position:[7,8,9],quaternion:[.5,.5,.5,-.5],instance:c.sourceInstance?{fade:f(c.sourceFade)}:null}:null,instance100:c.instance?{fade:f(c.fade)}:null,position1e0:[1,2,3],quaternion1d0:[1,0,0,0],previous19c:[-1,-2,-3],previousQuaternion178:[0,1,0,0],reference10c:[4,5,6],referenceQuaternion118:[0,0,1,0],basis140:[0,1,2,3,4,5,6,7,8]};
  const state=()=>({position:e.position1e0,quaternion:e.quaternion1d0,previous:e.previous19c,previousQuaternion:e.previousQuaternion178,reference:e.reference10c,referenceQuaternion:e.referenceQuaternion118,basis:e.basis140,initialized:e.initialized208});
  const providers={globalTransform:()=>{const index=calls.filter(v=>v[0]==='transform').length,position=[[10,20,30],[-2,4,1]][index],quaternion=[[.5,.25,-.5,.75],[.5,-.5,.5,.5]][index];calls.push(['transform',position,quaternion]);return{position,quaternion};},updateEmitter:(_e,delta)=>calls.push(['update',delta,structuredClone(state())])};
  animateEmitterParticles(e,c.delta,providers);assert.deepEqual({calls,state:state()},{calls:row.calls,state:row.state},JSON.stringify(c));
 }
});
