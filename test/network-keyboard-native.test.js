import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {driveControlRequest,abortDriveRequest,driveOrientationRequest} from '../src/network_player_requests.js';
import {NetworkKeyboardInput,keyboardDriveFlags,keyboardActorContext} from '../src/network_keyboard_input.js';
test('keyboard context accepts replicated vector records and initial entry arrays without changing either',()=>{
 const actor={replicated:{position:[1,2,3],orientation:{vector:[0,1,0],angle:90}}},frontend={id:'session',areaGeneration:2,world:{areaId:3,localObjectId:4,registry:new Map([[4,actor]])}},before=structuredClone(actor);
 assert.deepEqual(keyboardActorContext(frontend).orientation,[0,1,0]);assert.deepEqual(actor,before);
 actor.replicated.orientation=[1,0,0];assert.deepEqual(keyboardActorContext(frontend).orientation,[1,0,0]);
 actor.replicated.orientation={yaw:90};assert.ok(Math.abs(keyboardActorContext(frontend).orientation[0]+1)<1e-6);
 for(const orientation of [null,{},[NaN,0],[0]]){actor.replicated.orientation=orientation;assert.equal(keyboardActorContext(frontend),null);}
 assert.equal(keyboardActorContext(null),null);
});
test('keyboard drive, stop and turning packets match original native senders',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-drive-v1.json',import.meta.url)));
 for(const {case:c,packet}of oracle.cases){
  const bytes=c.kind==='drive'?driveControlRequest(c):c.kind==='abort'?abortDriveRequest():driveOrientationRequest({orientation:c.position});
  // Create's 3-bit prefix + heading's 4 residual bits leave one padding
  // bit for Drive; orientation has only the prefix, leaving five.
  const actual=Buffer.from(bytes),expected=Buffer.from(packet,'hex');
  if(c.kind!=='abort'){const mask=c.kind==='drive'?0xfe:0xe0;actual[actual.length-1]&=mask;expected[expected.length-1]&=mask;}
  assert.deepEqual(actual,expected,JSON.stringify(c));
 }
});
test('drive encoder rejects nonfinite positions, out-of-range heading/flags/identities',()=>{
 const r={areaId:0x80000001,position:[1,2],heading:3599,sequence:255,flags:3};
 for(const change of [{areaId:-1},{position:[NaN,0]},{position:[1e99,0]},{position:[1,2,3]},{heading:3600},{heading:-1},{sequence:256},{flags:0},{flags:64}])assert.throws(()=>driveControlRequest({...r,...change}),/Invalid/);
 assert.throws(()=>driveOrientationRequest({orientation:[2,0]}),/Invalid/);
});
function harness(){
 const events=new EventTarget(),doc=new EventTarget(),sent=[],errors=[];let time=0,allowed=true,context={sessionId:'fixture',areaGeneration:1,areaId:0x80000001,actorId:0xffffffff,position:[12,13,2],orientation:[1,0,0]};
 const input=new NetworkKeyboardInput({events,document:doc,context:()=>context,enabled:()=>allowed,send:async(c,r)=>sent.push({context:structuredClone(c),...r}),report:e=>errors.push(e),now:()=>time});
 const key=(type,code,props={})=>{const e=new Event(type,{cancelable:true}),{target,...fields}=props;Object.assign(e,{code,key:code==='ShiftLeft'?'Shift':code.slice(3),shiftKey:false,...fields});if(target)Object.defineProperty(e,'target',{value:target});events.dispatchEvent(e);return e;};
 return{events,doc,input,sent,errors,key,flush:()=>input.queue,advance:n=>{time+=n;input.update();},disable:()=>{allowed=false;input.update();},context:c=>context=c,get current(){return context;}};
}
test('native flags preserve forward/run/walk/back/strafe/turn and cancel opposing directions',()=>{
 const mask=(s,walk)=>keyboardDriveFlags(new Set(s.split(' ')),walk);
 assert.equal(mask('forward'),3);assert.equal(mask('forward',true),1);assert.equal(mask('back'),2);assert.equal(mask('forward left strafeRight'),3|16|8);assert.equal(mask('forward back left right strafeLeft strafeRight'),0);
});

test('an old keyboard reply cannot publish a sequence into a recreated motion lifetime',async()=>{
 const events=new EventTarget(),context={sessionId:'s',areaGeneration:1,areaId:1,actorId:1,motionLifetime:1,position:[10,20,0],orientation:[1,0,0]},sent=[];let release;
 const input=new NetworkKeyboardInput({events,document:new EventTarget(),context:()=>context,enabled:()=>true,send:async()=>{await new Promise(r=>release=r);return{sequence:23};},onSent:(_c,_r,result)=>sent.push(result.sequence)});
 const e=new Event('keydown',{cancelable:true});Object.assign(e,{code:'KeyW',key:'w'});events.dispatchEvent(e);await Promise.resolve();context.motionLifetime=2;release();await input.queue;assert.deepEqual(sent,[]);
});

test('failure of a previous lifetime request cannot clear newly held keys',async()=>{
 const events=new EventTarget(),context={sessionId:'s',areaGeneration:1,areaId:1,actorId:1,motionLifetime:1,position:[10,20,0],orientation:[1,0,0]};let reject,calls=0;
 const input=new NetworkKeyboardInput({events,document:new EventTarget(),context:()=>context,enabled:()=>true,send:async()=>{if(++calls===1)await new Promise((_r,j)=>reject=j);return{sequence:24};}}),key=code=>{const e=new Event('keydown',{cancelable:true});Object.assign(e,{code,key:code.slice(3)});events.dispatchEvent(e);};
 key('KeyW');await Promise.resolve();context.motionLifetime=2;key('KeyE');reject(Error('old lifetime failed'));await input.queue;assert.deepEqual([...input.keys],['KeyE']);
});
test('held movement repeats at native cadence and release sends a single server stop without mutating the actor',async()=>{
 const h=harness(),before=structuredClone(h.current);h.key('keydown','KeyW');await h.flush();assert.equal(h.sent[0].operation,'drive');assert.equal(h.sent[0].flags,3);assert.equal(h.sent[0].heading,0);assert.deepEqual(h.sent[0].position,[12,13]);
 h.advance(249);await h.flush();assert.equal(h.sent.length,1);h.advance(1);await h.flush();assert.equal(h.sent.length,2);assert.equal(h.sent[1].transmit,false);
 h.advance(249);await h.flush();assert.equal(h.sent.length,2);h.advance(1);await h.flush();assert.equal(h.sent.length,3);assert.equal(h.sent[2].transmit,true);
 h.key('keyup','KeyW');await h.flush();h.advance(2000);await h.flush();assert.equal(h.sent.length,4);assert.equal(h.sent[3].operation,'stop');assert.deepEqual(h.current,before);assert.deepEqual(h.errors,[]);
});
test('opposed keys and aliases resume correctly, shift selects walk and turning uses orientation messages',async()=>{
 const h=harness();h.key('keydown','KeyW');h.key('keydown','ArrowUp');h.key('keyup','KeyW');h.advance(500);await h.flush();assert.equal(h.sent.at(-1).operation,'drive');
 h.key('keydown','KeyS');await h.flush();assert.equal(h.sent.at(-1).operation,'stop');h.key('keyup','KeyS');await h.flush();assert.equal(h.sent.at(-1).operation,'drive');
 h.key('keydown','ShiftLeft',{shiftKey:true});h.advance(1);await h.flush();assert.equal(h.sent.at(-1).flags,1);
 h.key('keyup','ArrowUp');h.key('keydown','KeyA');await h.flush();assert.equal(h.sent.at(-1).operation,'turn');assert.ok(Math.abs(h.sent.at(-1).position[1]-.5)<1e-6);h.current.orientation=[...h.sent.at(-1).position,0];h.advance(250);await h.flush();assert.ok(Math.abs(h.sent.at(-1).position[0]-.5)<1e-6);
});
test('modal capture, blur and editable focus stop movement; queued requests cannot cross area/session ownership',async()=>{
 for(const reason of ['modal','blur','focus']){const h=harness();h.key('keydown','KeyW');await h.flush();if(reason==='modal')h.disable();else if(reason==='blur')h.events.dispatchEvent(new Event('blur'));else{const e=new Event('focusin');Object.defineProperty(e,'target',{value:{closest:()=>true}});h.events.dispatchEvent(e);}await h.flush();assert.equal(h.sent.at(-1).operation,'stop',reason);}
 const h=harness();h.key('keydown','KeyW');h.context({...h.current,areaGeneration:2});h.advance(1);await h.flush();assert.equal(h.sent.length,0);
 h.key('keydown','KeyW',{ctrlKey:true});await h.flush();assert.equal(h.sent.length,0);
 const e=h.key('keydown','KeyW',{target:{closest:()=>true}});assert.equal(e.defaultPrevented,false);
});
