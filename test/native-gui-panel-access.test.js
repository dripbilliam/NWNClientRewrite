import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NativeMessageWriter,NativeMessageReader} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {GuiPanelAccess,GUI_PANEL_EVENT_LIMIT,guiPanelAttemptRequest,guiPanelEventForHost,guiPanelHeaderForHost} from '../src/network_gui_panel_access.js';
const INVALID=0x7f000000,build=revision=>({number:8193,revision,postfix:0});
function packet(major,minor,write){const w=new NativeMessageWriter(1);w.create(32,0xffffffff,1);write(w);w.setPrefix(Uint8Array.of(80,major,minor));return Uint8Array.from(w.getWriteMessage().data);}
const wireDisabled=(panelId,disabled,targetId,revision)=>packet(53,2,w=>{w.writeInt(panelId);w.writeBool(disabled);if(revision>=35)w.writeObjectIdServer(targetId);});
const disabled=(panelId=6,value=true,targetId=INVALID,targetSource='received')=>({kind:'gui-panel-disabled',panelId,disabled:value,targetId,targetSource});
function guiFields(bytes,position=true){const r=new NativeMessageReader(1),body=bytes.subarray(3);assert.deepEqual([...bytes.subarray(0,3)],[112,53,1]);assert.equal(r.setReadMessage(body,body.length,0xffffffff,1),1);const value={event:r.readWord(),panelId:r.readWord(),targetId:r.readObjectIdClient()};if(position)value.position=[r.readFloat(),r.readFloat(),r.readFloat()];assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);return value;}
function world(){const w=new NetworkWorld(),actor={id:0xffffffce,objectType:5,areaId:0x80000001};w.areaId=actor.areaId;w.localObjectId=actor.id;w.registry.addObjectAtPos(actor.id,actor);return{w,actor};}
test('original53/2 decoding preserves BOOL, signed panel, target IDs and legacy default provenance',()=>{
 for(const revision of [34,35])for(const panelId of [-1,0,5,6,7,8,22,23])for(const value of [false,true])for(const targetId of [0,42,0x80000002,INVALID,0xffffffff]){
  const m=decodeServerGameMessage(wireDisabled(panelId,value,targetId,revision),{serverBuild:build(revision)});
  assert.deepEqual(m,{kind:'gui-panel-disabled',panelId,disabled:value,targetId:revision>=35?(targetId===INVALID?INVALID:(targetId|0x80000000)>>>0):INVALID,targetSource:revision>=35?'received':'legacy_protocol_default',major:53,minor:2});
 }
});
test('forced36/4 decodes a separate INT command and malformed streams/build metadata reject',()=>{
 for(const panelId of [-1,2,4,5,6,7,8,23])assert.deepEqual(decodeServerGameMessage(packet(36,4,w=>w.writeInt(panelId))),{kind:'gui-panel-popup',panelId,major:36,minor:4});
 const bytes=wireDisabled(6,true,42,35);for(const count of [3,4,8,bytes.length-1])assert.throws(()=>decodeServerGameMessage(bytes.slice(0,count),{serverBuild:build(35)}));
 assert.throws(()=>decodeServerGameMessage(bytes));assert.throws(()=>decodeServerGameMessage(packet(36,4,()=>{})));
});
test('GUI14 encoder has typed WORDs, exact attempt target and versioned zero XYZ',()=>{
 for(const includePosition of [false,true])for(const panelId of [2,4,5,6,7,8,22])for(const targetId of [0,42,0x80000002,INVALID,0xffffffff])assert.deepEqual(guiFields(guiPanelAttemptRequest({panelId,targetId,includePosition}),includePosition),{event:14,panelId,targetId,...(includePosition?{position:[0,0,0]}:{})});
 for(const panelId of [undefined,null,0,1,3,23,-1,'6'])assert.throws(()=>guiPanelAttemptRequest({panelId,targetId:INVALID,includePosition:true}));
 for(const targetId of [undefined,null,-1,'42',1.1])assert.throws(()=>guiPanelAttemptRequest({panelId:6,targetId,includePosition:true}));
});
test('canonical exact/global sets remove only their own key and duplicate disables remain distinct effects',()=>{
 const p=new GuiPanelAccess();p.observe(disabled(8,true,42));p.observe(disabled(8,true));assert.ok(p.matches(8,42)&&p.matches(8,99));p.observe(disabled(8,false,42));assert.ok(p.matches(8,42));p.observe(disabled(8,true,42));p.observe(disabled(8,false));assert.ok(p.matches(8,42));assert.equal(p.matches(8,99),false);
 const before=p.sequence;p.observe(disabled(8,true,42));assert.equal(p.sequence,before+1);assert.equal(p.matches(8,undefined),false);
 assert.equal(p.observe(disabled(23)),false);assert.throws(()=>p.observe(disabled(6,true,42,'legacy_protocol_default')));
});
test('host binding/header snapshots are detached and never restamp a popup onto same-ID replacement',()=>{
 const {w,actor}=world(),m={kind:'gui-panel-popup',panelId:6};w.apply(disabled());w.apply(m);const first=guiPanelEventForHost(w,m,2),seed=guiPanelHeaderForHost(w,2);
 assert.equal(seed.control.controlLifetime,first.scope.controlLifetime);first.scope.actorId=123;seed.disabled[0].targetId=0;seed.events[0].disabled=false;
 assert.ok(w.guiPanelAccess.matches(6,INVALID));w.registry.delete(actor.id);w.registry.addObjectAtPos(actor.id,{...actor});const next=guiPanelHeaderForHost(w,2),old=guiPanelEventForHost(w,m,2);
 assert.ok(next.control.controlLifetime>old.scope.controlLifetime);assert.equal(old.scope.actorId,actor.id);assert.equal(JSON.stringify(next).includes('objectType'),false);
 const bad={kind:'gui-panel-popup',panelId:999};assert.equal(w.apply(bad),false);assert.equal(guiPanelEventForHost(w,bad,2),null);
});
test('bounded one-shot history retains order and unavailable scope stays explicit',()=>{
 const {w}=world();for(let i=0;i<100;i++){const m={kind:'gui-panel-popup',panelId:6};w.apply(m);guiPanelEventForHost(w,m,2);}
 const seed=guiPanelHeaderForHost(w,2);assert.equal(seed.events.length,GUI_PANEL_EVENT_LIMIT);assert.equal(seed.retiredThrough,68);assert.deepEqual(seed.events.map(e=>e.sequence),Array.from({length:32},(_,i)=>i+69));
 const empty=new NetworkWorld(),m={kind:'gui-panel-popup',panelId:8};empty.apply(m);const e=guiPanelEventForHost(empty,m,0);assert.equal(e.scope.actorId,null);assert.equal(e.scope.controlLifetime,null);
});
test('actual World area import preserves connection access; reconnect reset retires it',()=>{
 const {w,actor}=world(),access=w.guiPanelAccess;w.apply(disabled());const area={id:0x80000002,mapPins:[],sounds:[],placeableLights:[],staticPlaceables:[],time:{}};
 w.apply({kind:'client-area',area,position:[0,0,0],facing:0,flag:0});assert.equal(w.guiPanelAccess,access);assert.ok(w.guiPanelAccess.matches(6,INVALID));assert.equal(w.registry.get(actor.id).areaId,area.id);w.reset();assert.notEqual(w.guiPanelAccess,access);assert.equal(w.guiPanelAccess.sequence,0);assert.equal(w.guiPanelAccess.matches(6,INVALID),false);
});
function sessionHarness(){const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async b=>sent.push(Uint8Array.from(b));peer.disconnect=async()=>peer.emit('closed');const s=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:build(37),dispose(){}},resources:{},language:0,openModule:async()=>null});const actor={id:0xffffffce,objectType:5,areaId:0x80000001};s.phase='playing';s.areaReadySent=true;s.areaGeneration=2;s.world.areaId=actor.areaId;s.world.localObjectId=actor.id;s.world.registry.addObjectAtPos(actor.id,actor);const request={areaId:actor.areaId,areaGeneration:2,actorId:actor.id,panel:'blocked-attempt',open:true,guiPanelId:6,targetId:INVALID,accessRevision:1,attemptSerial:1};return{s,peer,actor,sent,request};}
test('real Session allows fresh repeated physical attempts, rejects replay, checks exact targets and builds',async()=>{
 const h=sessionHarness(),before=structuredClone(h.actor);h.s.world.apply(disabled());for(const attemptSerial of [1,2])await h.s.hudPanel({...h.request,attemptSerial});assert.equal(h.sent.length,2);assert.deepEqual(guiFields(h.sent[0]),{event:14,panelId:6,targetId:INVALID,position:[0,0,0]});await assert.rejects(h.s.hudPanel({...h.request,attemptSerial:2}));
 h.s.world.apply(disabled(8,true,h.actor.id));h.s.serverBuild=build(34);await h.s.hudPanel({...h.request,guiPanelId:8,targetId:h.actor.id,accessRevision:2,attemptSerial:3});assert.deepEqual(guiFields(h.sent.at(-1),false),{event:14,panelId:8,targetId:h.actor.id});assert.deepEqual(h.actor,before);await h.s.disconnect();
});
test('real Session rejects unbound/missing/stale data without packets or local UI rule projection',async()=>{
 const h=sessionHarness();h.s.world.apply(disabled());for(const change of [{guiPanelId:4},{targetId:42},{accessRevision:0},{attemptSerial:0},{attemptSerial:'1'},{areaId:0},{areaGeneration:1},{actorId:0},{open:false}])await assert.rejects(h.s.hudPanel({...h.request,...change}));h.s.world.apply(disabled(6,false));await assert.rejects(h.s.hudPanel({...h.request,accessRevision:2}));assert.equal(h.sent.length,0);await h.s.disconnect();
});
test('real Session checks actor lifetime after async submission without retry or disconnect',async()=>{
 const h=sessionHarness();h.s.world.apply(disabled());let release;const gate=new Promise(resolve=>release=resolve);h.peer.sendGameMessage=async bytes=>{h.sent.push(bytes);await gate;};const pending=h.s.hudPanel(h.request);await new Promise(resolve=>setImmediate(resolve));h.s.world.registry.delete(h.actor.id);h.s.world.registry.addObjectAtPos(h.actor.id,{...h.actor});release();await assert.rejects(pending);assert.equal(h.sent.length,1);assert.equal(h.s.closed,false);await h.s.disconnect();
});
