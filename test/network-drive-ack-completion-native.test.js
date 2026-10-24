import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NetworkMotion} from '../src/network_motion.js';

test('short matching acknowledgements and stale replies agree with isolated original path acceptance/completion',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-drive-ack-completion-v1.json',import.meta.url)));
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,4);
 for(const row of oracle.cases){
  const actor={id:1,replicated:{position:row.before.slice(),orientation:[.9245460629463196,.3810702860355377,0],animation:79,walkRate:2200,runRate:4400}},canonical=structuredClone(actor),motion=new NetworkMotion(),s=motion.ensure(actor);
  s.script=1;s.active=true;s.factor=1;s.path=structuredClone(row.priorPath);s.driveSequence=row.lastSequence;
  motion.observe(actor,{actionFlag:row.sequence,path:row.acknowledged,animation:79,field8F4:1,field8EC:1});
  assert.equal(row.installed.length,row.sequence===0||row.sequence===row.lastSequence?1:0);
  for(const frame of row.frames){
   motion.update(.008);for(const key of ['position','render'])for(let i=0;i<3;i++)assert.ok(Math.abs(s[key][i]-frame[key][i])<2e-5,JSON.stringify({sequence:row.sequence,ms:frame.ms,key,i,actual:s[key],native:frame[key]}));
   assert.equal(s.script,frame.script);assert.equal(s.active,frame.animation===79);assert.equal(s.finished?0:s.animation,frame.animation);s.finished=false;if(!s.active)s.animation=0;
  }
  assert.deepEqual(actor,canonical,'Presentation replay must not alter server-owned state');
 }
});
