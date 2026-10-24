import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {presentScriptFloatingFeedback} from '../src/network_script_feedback.js';
import {NetworkFeedbackView} from '../src/network_feedback_view.js';
import {NetworkWorld} from '../src/network_world.js';

test('script floating text matches64 original formatter traces, including independent chat flag and white unshadowed floats',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-nui-script-feedback-v1.json',import.meta.url)));
 assert.equal(oracle.cases.length,64);
 for(const row of oracle.cases){
  assert.equal(row.error,null);const data={integers:{},strings:{},objects:{0:0x80000063}},floats=[],outputs=[];
  for(const c of row.calls){if(c[0]==='integer')data.integers[c[1]]=c[2];else if(c[0]==='string')data.strings[c[1]]={text:'String'+c[1]};}
  await presentScriptFloatingFeedback({type:row.type,data},{parse:(ref,options)=>{assert.deepEqual(options,{nativeB8:0,nativeBC:0});return 'P'+ref+'{"1": "old1", "2": "old2"}';},string:v=>v.text,creature:()=>row.world,display:(raw,flags)=>outputs.push({raw,flags}),floating:e=>floats.push(['floaty',e.raw,e.rgb,e.flags])});
  assert.deepEqual(outputs,row.outputs);assert.deepEqual(floats,row.calls.filter(c=>c[0]==='floaty'));
 }
});

test('server assignment prompt targets canonical character ID, ignores combat toggle, and rejects stale/removed/noncreature targets',async()=>{
 let world=new NetworkWorld(),release;const actor={objectType:5};world.registry.addObjectAtPos(0xfffffffe,actor);world.localObjectId=0xfffffffe;
 const rows=[],floats=[],reports=[],text={raw:async v=>v.text,resolve:async()=>new Promise(r=>release=r)};
 const view=new NetworkFeedbackView({world:()=>world,text:()=>text,tables:()=>null,display:r=>rows.push(r),floating:e=>floats.push(e),options:()=>({enabled:false}),report:(...args)=>reports.push(args)});
 const message={kind:'combat-feedback',type:94,data:{objects:{0:0xfffffffe},strings:{0:{text:'Select a slot'}},integers:{0:1}}};
 await view.receive(message);assert.equal(floats.length,1);assert.equal(floats[0].objectId,0xfffffffe);assert.equal(floats[0].raw,'Select a slot');assert.equal(floats[0].font,'fnt_galahad14');assert.equal(rows[0].text,'Select a slot');assert.equal(rows[0].category,'script-feedback');
 actor.replicationRemoved=true;await view.receive(message);assert.equal(floats.length,1);assert.equal(rows.length,2);
 actor.replicationRemoved=false;actor.objectType=9;await view.receive({...message,data:{...message.data,integers:{0:0}}});assert.equal(floats.length,1);assert.equal(rows.length,2);
 actor.objectType=5;const pending=view.receive({kind:'combat-feedback',type:93,data:{objects:{0:0xfffffffe},integers:{0:123,1:1}}});while(!release)await Promise.resolve();view.reset();world=new NetworkWorld();release('Old prompt');await pending;assert.equal(floats.length,1);assert.equal(rows.length,2);assert.deepEqual(reports,[]);
});
