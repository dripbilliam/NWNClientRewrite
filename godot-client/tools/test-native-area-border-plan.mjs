import fs from 'node:fs';
import assert from 'node:assert/strict';
import {nativeAreaBorderPlan} from './area-border-reference.mjs';
const fixture=JSON.parse(fs.readFileSync(new URL('../reports/native-area-border-installed-v1.json',import.meta.url)));
const oracle=JSON.parse(fs.readFileSync(new URL('../reports/native-area-border-original-v2.json',import.meta.url)));
const bits=n=>{const b=Buffer.alloc(4);b.writeFloatLE(n);return b.toString('hex');};
let checks=0;
for(const row of oracle.rows){
 const sample=fixture.samples.find(s=>s.setName===row.setName),set={transition:Number(sample.general.Transition),tiles:sample.tiles},table=row.loaded?sample:null;
 const before=structuredClone({area:row.area,set,table}),actual=nativeAreaBorderPlan(row.area,set,table,{enabled:true,disabled:false});
 assert.deepEqual({area:row.area,set,table},before,row.name+' source immutability');checks++;
 assert.equal(actual.attempts.length,row.calls.length,row.name+' native SpawnTile call count');checks++;
 for(let n=0;n<row.calls.length;n++){
  const call=row.calls[n],plan=actual.attempts[n];
  assert.equal(plan.rawModel,call.model,row.name+'/'+n+' exact physical model choice');checks++;
  assert.deepEqual(plan.nativePosition.map(bits),call.positionBits,row.name+'/'+n+' source placement float bits');checks++;
  if(plan.rawModel){assert.equal(plan.orientation,call.orientation,row.name+'/'+n+' native quarter-turn');checks++;}
  assert.equal(plan.nativeSpawnFlags,call.nativeSpawnFlags);checks++;
 }
}
const sample=fixture.samples[0],area=oracle.rows[0].area,set={transition:Number(sample.general.Transition),tiles:sample.tiles};
for(const gate of [{enabled:false,disabled:false},{enabled:true,disabled:true}]){assert.equal(nativeAreaBorderPlan(area,set,sample,gate).attempts.length,0);checks++;}
console.log(JSON.stringify({clean:true,cases:oracle.rows.length,originalSpawnCalls:oracle.rows.reduce((n,r)=>n+r.calls.length,0),checks,scope:'Original whole-routine control/placement vs value reference; GDScript/render/active-data integration unrun.'}));
