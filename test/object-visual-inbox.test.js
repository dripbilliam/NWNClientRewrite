import test from 'node:test';
import assert from 'node:assert/strict';
import {ObjectVisualInbox} from '../src/object_visual_inbox.js';
import {parse2da} from '../src/area.js';

function fixture(){
 const actor={id:123,objectType:5,areaId:7,position:[1,2,3]},registry=new Map([[123,actor]]),session={registry,player:actor,characterRules:{visualeffects:parse2da('2DA V2.0\n\nType_FD\n0 F\n1 P\n')}};
 const objects={registry,areaId:7,renderBindings:new Map([[123,{}]])},calls=[],diagnostics=[],presentation={addTransient:(...args)=>calls.push(args)};
 const inbox=new ObjectVisualInbox({session:()=>session,report:(code,message,data)=>diagnostics.push({code,message,data})});
 const event={type:'visualEffect',recipientId:123,data:{visualId:0,targetId:123,sourceId:123,flag:0,missMode:0,position:[0,0,0],duration:12,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]}}};
 return{actor,registry,session,objects,calls,diagnostics,inbox,event,flush:()=>inbox.flush({session,objects,presentation})};
}

test('visual inbox snapshots sender positions and routes each duplicate once without changing canonical objects or IDs',()=>{
 const f=fixture();f.inbox.receive(f.event);f.inbox.receive(f.event);f.actor.position=[9,8,7];f.flush();f.flush();
 assert.equal(f.calls.length,2);assert.ok(f.calls.every(([actor,r])=>actor===f.actor&&r.sourceId===0x7f000000&&r.delivery.instant===1));assert.deepEqual(f.calls[0][1].delivery.point,[1,-3,2]);
 assert.equal(f.actor.nativeLoopingVisuals160,undefined);assert.equal(f.registry.size,1);assert.equal(f.actor.id,123);assert.deepEqual(f.diagnostics,[]);
});

test('pending binding is retained until available, with one diagnostic; another session registry cannot consume it',()=>{
 const f=fixture();f.objects.renderBindings.clear();f.inbox.receive(f.event);f.flush();f.flush();assert.equal(f.inbox.pending.length,1);assert.equal(f.diagnostics.length,1);
 f.inbox.flush({session:f.session,objects:{...f.objects,registry:new Map()},presentation:{}});assert.equal(f.inbox.pending.length,1);
 f.objects.renderBindings.set(123,{});f.flush();assert.equal(f.calls.length,1);assert.equal(f.inbox.pending.length,0);
});

test('target destruction, ID replacement and area transfer discard stale queued messages instead of binding a different actor',()=>{
 for(const mode of ['destroy','replace','area','view']){
  const f=fixture();f.inbox.receive(f.event);
  if(mode==='destroy')f.registry.delete(123);if(mode==='replace')f.registry.set(123,{...f.actor});if(mode==='area')f.actor.areaId=8;if(mode==='view')f.objects.areaId=8;
  f.flush();assert.equal(f.calls.length,0,mode);assert.equal(f.inbox.pending.length,0,mode);assert.equal(f.diagnostics.length,1,mode);
 }
});

test('area, source-dummy and point-dummy gaps are explicit and never target the player or allocate canonical IDs',()=>{
 const f=fixture();f.inbox.receive({...f.event,data:{visualId:0,position:[1,2,3]}});
 f.inbox.receive({...f.event,data:{...f.event.data,visualId:1,sourceId:456,sourcePosition:[7,8,9]}});
 f.inbox.receive({...f.event,data:{...f.event.data,targetId:0x7f000000}});f.flush();
 assert.deepEqual(f.diagnostics.map(d=>d.code),['visual.area-message-unimplemented','visual.client-dummy-unimplemented','visual.client-dummy-unimplemented']);
 assert.deepEqual(f.diagnostics.slice(1).map(d=>d.data.role),['source','point']);assert.equal(f.calls.length,0);assert.equal(f.registry.size,1);assert.equal(f.inbox.pending.length,0);
});

test('unrelated events and other recipients do not enter the visual queue',()=>{
 const f=fixture();assert.equal(f.inbox.receive({...f.event,type:'other'}),false);assert.equal(f.inbox.receive({...f.event,recipientId:999}),true);assert.equal(f.inbox.pending.length,0);
});
