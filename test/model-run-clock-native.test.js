import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import {advanceModelRuns} from '../src/model_run_clock.js';
import {animateModelEvents} from '../src/model_events.js';
test('model run clock matches474 complete original Animate profiles with actual authored-event scheduling',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-model-run-clock-observations.json',import.meta.url)));
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,474);
 for(const row of oracle.rows){
  const c=row.case,calls=[],gob={root90:c.root?{}:null,period188:c.period,runsE0:c.initial.map((r,id)=>({id,clip0:{id,name:`clip${id}`,length90:Math.fround(r.length),events:[0,.25,.5,1].map((time,j)=>({time,name:`e${id}_${j}`}))},speed8:Math.fround(r.speed),flagsC:r.flags,previous10:Math.fround(r.previous),time14:Math.fround(r.time),weight18:Math.fround(r.weight),transition1c:Math.fround(r.transition),scale20:Math.fround(r.scale),done24:r.done}))};
  const p={event:(...args)=>calls.push(['event',...args]),destroyRun:(run,bytes)=>calls.push(['destroyRun',run.id,bytes]),applyClip:(clip,previous,time,weight,scale,context,reverse)=>calls.push(['applyClip',clip.id,previous,time,weight,scale,context?.id??null,context?reverse:0]),animateEvents:(clip,previous,time,reverse)=>animateModelEvents(clip,previous,time,reverse,name=>calls.push(['event',name,0])),updateRoot:(_root,delta)=>calls.push(['updateRoot',delta]),periodicUpdate:()=>calls.push(['periodicUpdate'])};
  const frames=c.deltas.map(delta=>{advanceModelRuns(gob,delta,p);return{runs:gob.runsE0.map(({clip0,...r})=>({id:r.id,clip:clip0.id,...Object.fromEntries(Object.entries(r).filter(([key])=>key!=='id'))})),period:gob.period188};});
  assert.deepEqual({calls,frames},{calls:row.calls,frames:row.frames},JSON.stringify(c));
 }
});
