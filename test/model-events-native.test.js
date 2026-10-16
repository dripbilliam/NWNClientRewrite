import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {animateModelEvents,ModelEventDispatcher} from '../src/model_events.js';
test('model event range/dispatch/detonate match304 coupled original executions',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-events-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,304);
 for(const row of oracle.rows){
  const c=row.case,calls=[],owner={},bus=new ModelEventDispatcher(owner),targets=Array.from({length:6},(_,id)=>({id,detonate108:0}));
  for(const [i,pattern]of ['Detonate','','*tail','detonate','Sound'].entries())bus.add(pattern,(_owner,name,target)=>{calls.push([i===0||i===3?'detonate':'listener',name,target.id]);if(i===0||i===3)target.detonate108=1;else if(c.destroy)bus.destroy();},targets[i]);
  if(c.direct)bus.dispatch('dEtOnAtE',c.data?targets[5]:null);
  else animateModelEvents({events:structuredClone(c.events)},c.fromTime,c.toTime,c.flags,(name,data)=>bus.dispatch(name,data));
  assert.deepEqual({calls,detonated:targets.map(t=>t.detonate108),activeHandles:bus.handles.length,capacity:bus.capacity,allocated:Number(bus.capacity!==0)},{calls:row.calls,detonated:row.detonated,activeHandles:row.activeHandles,capacity:row.capacity,allocated:row.allocated},JSON.stringify(c));
 }
});
