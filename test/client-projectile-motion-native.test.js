import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {stepClientProjectileMotion} from '../src/client_projectile_motion.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-projectile-motion-observations.json',import.meta.url))),view=new DataView(new ArrayBuffer(4));
const bits=value=>{view.setFloat32(0,value,true);return view.getUint32(0,true);};
const canonical=value=>(value&0x7f800000)===0x7f800000&&(value&0x7fffff)!==0?'NaN':value;
const compare=(actual,expected,message)=>assert.deepEqual(actual.map(v=>canonical(bits(v))),expected.map(canonical),message);
for(const kind of ['basic','spiral'])test(`client projectile ${kind} matches original float32 steps, overshoot clamp, facing modes and multi-frame trajectories`,()=>{
 for(const row of native.rows.filter(r=>r.case.kind===kind)){
  let state=structuredClone(row.case);
  for(const [i,expected]of row.observations.entries()){
   const result=stepClientProjectileMotion(state,kind),label=JSON.stringify({case:row.case,step:i});
   compare(result.position,expected.position,label+' position');compare(result.velocity,expected.velocity,label+' velocity');
   assert.deepEqual(expected.calls.map(r=>r.kind),result.orientation?['orientation','position']:['position'],label+' callbacks');
   if(result.orientation)compare(result.orientation,expected.calls[0].bits,label+' orientation');
   compare(result.position,expected.calls.at(-1).bits,label+' position callback');
   state={...state,position:result.position,remaining:Math.max(0,state.remaining-state.elapsed)};
  }
 }
});
test('unknown motion and unavailable attachment remain explicit failures',()=>{
 const state=native.rows[0].case;
 assert.throws(()=>stepClientProjectileMotion(state,'unknown'),/unavailable/);
 assert.throws(()=>stepClientProjectileMotion({...state,facing:1,attachment:undefined},'basic'),/attachment/);
 assert.equal(native.rows.length,1318);
});
