import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageWriter,NativeMessageReader} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {scriptTargetKinds,scriptTargetAllowed,scriptTargetSelectionRequest} from '../src/network_script_targeting.js';
import {NetworkSpellTargeting} from '../src/network_spell_targeting.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkFrontend} from '../src/network_frontend.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';

const mode={kind:'script-targeting',objectMask:513,cursor:7,badCursor:13};
function fixture(){
 const world=new NetworkWorld(),actor={id:0xffffffce,objectType:5,areaId:1,replicated:{position:[3,4,.3]}},target={id:0x80000002,objectType:5,areaId:1,replicated:{position:[5,6,.3]}};
 for(const o of [actor,target])world.registry.addObjectAtPos(o.id,o);world.localObjectId=actor.id;world.areaId=1;world.apply(mode);
 const requests=[],states=[],context={sessionId:'owned',areaGeneration:1};
 const targeting=new NetworkSpellTargeting({world:()=>world,tables:()=>({}),context:()=>context,submit:async r=>{requests.push(r);return{sent:true};},onChange:s=>states.push(s)});
 return{world,actor,target,targeting,requests,states,context};
}
const packet=(major,minor,write)=>{const w=new NativeMessageWriter(1);w.create(32,0xffffffff,1);write(w);w.setPrefix(Uint8Array.of(80,major,minor));return Uint8Array.from(w.getWriteMessage().data);};

test('server enter/cancel targeting and target-display fields decode without discarded commands',()=>{
 for(const objectMask of [0,1,512,1023,0xffffffff]){const bytes=packet(18,23,w=>{w.writeDword(objectMask);w.writeDword(7);w.writeDword(13);});assert.deepEqual(decodeServerGameMessage(bytes),{...mode,objectMask,major:18,minor:23});assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,-2)));}
 const bytes=packet(57,2,w=>{w.writeInt(3);w.writeFloat(1.5,1,32);w.writeFloat(2.5,1,32);w.writeInt(4);w.writeFloat(30,1,32);w.writeInt(17);w.writeInt(-1);});assert.deepEqual(decodeServerGameMessage(bytes),{kind:'script-targeting-data',shape:3,sizeX:1.5,sizeY:2.5,flags:4,range:30,spellId:17,featId:-1,major:57,minor:2});assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,-2)));
});

test('script target mask branches and selection bytes match unchanged original-code observations',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-targeting-v1.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of oracle.masks){assert.deepEqual(scriptTargetKinds(row.mask),row.kinds.map(([kind])=>kind));assert.ok(row.kinds.every(([,cursor])=>cursor===7));assert.equal(row.badCursor,13);}
 for(const row of oracle.cases){const actual=scriptTargetSelectionRequest(row),expected=Uint8Array.from(Buffer.from(row.packet,'hex'));assert.equal(actual.length,expected.length);assert.deepEqual(actual.subarray(0,-1),expected.subarray(0,-1));const mask=255<<(8-(expected.at(-1)>>>5))&255;assert.equal(actual.at(-1)&mask,expected.at(-1)&mask);}
 for(const change of [{targetId:-1},{targetId:2**32},{position:[0,NaN,0]},{position:[0,0,Infinity]},{position:[0,0,1e100]}])assert.throws(()=>scriptTargetSelectionRequest({targetId:0x7f000000,position:[1,2,3],...change}));
});

test('toolbar targeting routes creature and ground selection to the script callback, preserving server authority',async()=>{
 for(const ground of [false,true]){const f=fixture(),before=structuredClone(f.actor);f.targeting.beginServer();assert.equal(f.targeting.active,true);assert.equal(f.states.at(-1).scriptTarget,true);const point=ground?[7,8,.3]:f.target.replicated.position;await f.targeting.select(ground?null:f.target,point);assert.equal(f.targeting.active,false);assert.deepEqual(f.requests,[{kind:'script-target',version:1,targetId:ground?0x7f000000:f.target.id,position:point}]);assert.deepEqual(f.actor,before);}
 const f=fixture();f.world.apply({...mode,objectMask:1});f.targeting.beginServer();await assert.rejects(()=>f.targeting.select(null,[1,2,3]),/not valid/);assert.equal(f.targeting.active,true);assert.equal(f.requests.length,0);assert.equal(scriptTargetAllowed({...mode,objectMask:2},f.target),false);
});

test('server cancel/replacement, Escape reset and area/control changes cannot submit old targets',async()=>{
 const f=fixture();f.targeting.beginServer();f.targeting.reset();assert.equal(f.requests.length,0);assert.equal(f.targeting.active,false);
 f.targeting.beginServer();f.world.apply({...mode,objectMask:0});await assert.rejects(()=>f.targeting.select(f.target,[0,0,0]),/replaced/);f.targeting.beginServer();assert.equal(f.targeting.active,false);
 f.world.apply(mode);f.targeting.beginServer();f.world.apply(mode);await assert.rejects(()=>f.targeting.select(f.target,[0,0,0]),/replaced/);
 f.targeting.beginServer();f.context.areaGeneration++;await assert.rejects(()=>f.targeting.select(f.target,[0,0,0]),/old area/);
 f.targeting.beginServer();f.world.localObjectId=f.target.id;await assert.rejects(()=>f.targeting.select(f.target,[0,0,0]),/old area or controlled/);assert.equal(f.requests.length,0);
 f.world.reset();assert.equal(f.world.scriptTargeting,null);assert.equal(f.world.scriptTargetVersion,0);
});

test('ready-area target commands bypass blocked presentation work and old connections remain isolated',()=>{
 const f=fixture(),errors=[],frontend={id:'owned',phase:'playing',areaGeneration:1,world:f.world,queue:new Promise(()=>{}),onHud:m=>{if(m.kind==='script-targeting')f.targeting.beginServer();},showError:e=>errors.push(e.message)};
 NetworkFrontend.prototype.receive.call(frontend,{sessionId:'owned',kind:'message',areaGeneration:1,message:mode});assert.equal(f.targeting.active,true);const version=f.world.scriptTargeting.version;
 NetworkFrontend.prototype.receive.call(frontend,{sessionId:'old',kind:'message',areaGeneration:1,message:{...mode,objectMask:0}});assert.equal(f.world.scriptTargeting.version,version);assert.deepEqual(errors,[]);
});

test('typed session reply checks target masks, one-use version and ownership; a late send preserves newer commands',async()=>{
 const f=fixture(),packets=[];let release;const session={world:f.world,closed:false,phase:'playing',areaReadySent:true,areaGeneration:1,controlledActor:NetworkGameSession.prototype.controlledActor,peer:{sendGameMessage:packet=>{packets.push(packet);return new Promise(r=>release=r);}}};
 const request={areaId:1,areaGeneration:1,actorId:f.actor.id,version:1,targetId:f.target.id,position:[5,6,.3]};
 await assert.rejects(()=>NetworkGameSession.prototype.selectScriptTarget.call(session,{...request,actorId:3}),/stale/);await assert.rejects(()=>NetworkGameSession.prototype.selectScriptTarget.call(session,{...request,targetId:3}),/unavailable/);
 const pending=NetworkGameSession.prototype.selectScriptTarget.call(session,request);assert.equal(f.world.scriptTargeting,null);assert.equal(packets.length,1);await assert.rejects(()=>NetworkGameSession.prototype.selectScriptTarget.call(session,request),/stale/);f.world.apply(mode);release();await pending;assert.equal(f.world.scriptTargeting.version,2);
 const r=new NativeMessageReader(1),bytes=packets[0];assert.deepEqual([...bytes.subarray(0,3)],[112,6,37]);assert.ok(r.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,1));assert.equal(r.readObjectIdClient(),f.target.id);
});
