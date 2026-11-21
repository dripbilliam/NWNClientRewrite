import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {playClientProjectileAnimation,setClientProjectileStage} from '../src/client_projectile_animation.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-projectile-animation-observations.json',import.meta.url))),view=new DataView(new ArrayBuffer(4));
const bits=v=>{view.setFloat32(0,v,true);return view.getUint32(0,true);};
for(const mode of ['play','set'])test(`native projectile animation ${mode}: WORD stage, zero speed, impact flags, clear and unconditional handle success`,()=>{
 for(const row of native.rows.filter(r=>r.case.mode===mode)){
  const c=row.case,calls=[],model={},state={model:c.hasModel?model:null,stage:123},p={playAnimation:(m,name,speed,flags,start)=>{assert.equal(m,model);calls.push({name,speed:bits(speed),flags:flags>>>0,start:bits(start)});return c.playResult;}};
  const result=mode==='play'?playClientProjectileAnimation(model,c.stage,c.speed,c.flags,c.start,p):setClientProjectileStage(state,c.stage,p);
  assert.equal(result,row.result,JSON.stringify(c));assert.equal(state.stage,row.stage,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
