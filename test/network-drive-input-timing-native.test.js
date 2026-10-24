import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {NetworkKeyboardInput} from '../src/network_keyboard_input.js';
test('192 unchanged original UI schedules match preview/send timing and input sequence advancement',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-drive-input-timing-v1.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,192);
 for(const row of oracle.cases){
  const c=row.case,context={sessionId:'fixture',areaGeneration:1,areaId:1,actorId:1,position:[10,20,0],orientation:[1,0,0]},sent=[],previews=[],now=10000;let sequence=c.lastSequence;
  const input=new NetworkKeyboardInput({events:new EventTarget(),document:new EventTarget(),context:()=>context,enabled:()=>true,now:()=>now,send:async(_c,r)=>{sequence=(sequence+1)&255;sent.push(r);return{sequence};},preview:(_c,flags)=>previews.push(flags)});
  input.owner=context;input.lastFlags=c.dirty?0:c.flags;input.lastAt=now-c.wireAgo/1000;input.previewAt=now-c.previewAgo/1000;input.keys=new Set(c.flags===3?['KeyW']:c.flags===4?['KeyQ']:c.flags===8?['KeyE']:['KeyQ','KeyA']);
  input.update();await input.queue;
  assert.deepEqual(previews,row.calls.filter(r=>r.kind==='preview').map(r=>r.flags),JSON.stringify(c));assert.equal(sent.filter(r=>r.transmit).length,row.calls.filter(r=>r.kind==='drive').length,JSON.stringify(c));assert.equal(sequence,row.sequence,JSON.stringify(c));
  assert.equal(Math.round(input.lastAt*1000),row.lastWire,JSON.stringify(c));assert.equal(Math.round(input.previewAt*1000),row.lastPreview,JSON.stringify(c));
 }
});
test('native repeated key-down admission refreshes an already held direction immediately',async()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-drive-input-timing-v1.json',import.meta.url)));assert.equal(oracle.repeatedEvents.length,2);
 for(const row of oracle.repeatedEvents){
  assert.deepEqual(row.queued,[{kind:'queued',inputClass:0,key:10,value:1}]);assert.equal(row.dirtyAfterEvent,1);
  const context={sessionId:'s',areaGeneration:1,areaId:1,actorId:1,position:[1,2,0],orientation:[1,0,0]},events=new EventTarget(),requests=[],previews=[];
  const input=new NetworkKeyboardInput({context:()=>context,enabled:()=>true,events,document:new EventTarget(),now:()=>10000,send:async(_c,r)=>requests.push(r),preview:(_c,flags)=>previews.push(flags)});
  input.owner=context;input.keys.add('KeyQ');input.lastFlags=4;input.lastAt=input.previewAt=10000;
  const event=new Event('keydown',{cancelable:true});Object.assign(event,{code:'KeyQ',key:'q',repeat:Boolean(row.repeat),shiftKey:false});events.dispatchEvent(event);await input.queue;
  assert.equal(requests.length,1);assert.equal(requests[0].transmit,true);assert.equal(requests[0].flags,row.calls.find(c=>c.kind==='drive').flags);assert.deepEqual(previews,[4]);assert.equal(input.inputPending,false);
  input.update();await input.queue;assert.equal(requests.length,1,'Consumed event must not force every render frame');
  events.dispatchEvent(new Event('blur'));await input.queue;assert.equal(requests.at(-1).operation,'stop');assert.equal(input.inputPending,false);
 }
});
