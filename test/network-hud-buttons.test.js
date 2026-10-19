import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {restRequest,characterSheetRequest,journalWindowRequest,playerAttitudeRequest} from '../src/network_hud_input.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';import {NativeMessageWriter} from '../src/native_message.js';import {NetworkWorld} from '../src/network_world.js';import {applyNetworkAutomap} from '../src/network_automap.js';
const build={number:8193,revision:37,postfix:17};
const message=(major,minor,write)=>{const w=new NativeMessageWriter(1);w.create(32,0xffffffff,1);write(w);w.setPrefix(Uint8Array.of(80,major,minor));return Uint8Array.from(w.getWriteMessage().data);};
const str=(w,s)=>w.writeStringBytes(new TextEncoder().encode(s)),loc=(w,s)=>{w.writeBool(0);str(w,s);};

test('25 full original rest/sheet/attitude writers match transmitted bits including signed page and canonical IDs',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-hud-request-observations.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,25);
 for(const row of oracle.cases){const c=row.case,a=Buffer.from(c.kind==='rest'?restRequest():c.kind==='sheet'?characterSheetRequest(c):playerAttitudeRequest(c)),b=Buffer.from(row.packet,'hex');assert.equal(a.length,b.length);if(c.kind==='rest'){assert.deepEqual(a,b);continue;}assert.deepEqual(a.subarray(0,-1),b.subarray(0,-1));const used=b.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(a.at(-1)&mask,b.at(-1)&mask);}
 assert.deepEqual([...journalWindowRequest(true)],[112,28,10]);assert.deepEqual([...journalWindowRequest(false)],[112,28,11]);assert.throws(()=>characterSheetRequest({page:128,targetId:0xffffffff}));assert.throws(()=>playerAttitudeRequest({targetId:0xffffffff,likes:1}));
});
test('server timing and attitude packets retain fields; applying them never recovers resources',()=>{
 const w=new NetworkWorld(),actor={id:0xffffffff,objectType:5,playerState:{spellbooks:{0:{memorized:{0:[{spell:1,ready:0}]}}}}};w.registry.addObjectAtPos(actor.id,actor);const before=structuredClone(actor);
 const timing=decodeServerGameMessage(message(48,1,b=>{b.writeBool(1);b.writeDword(12000);b.writeByte(6);}),{clientBuild:build});assert.deepEqual(timing,{kind:'gui-timing',active:1,duration:12000,type:6,major:48,minor:1});w.apply(timing);w.apply(decodeServerGameMessage(message(48,1,b=>b.writeBool(0)),{clientBuild:build}));assert.equal(w.timing.active,0);assert.deepEqual(actor,before);
 w.apply(decodeServerGameMessage(message(41,3,b=>{b.writeDword(1);b.writeDword(2);b.writeBool(0);b.writeBool(0);}),{clientBuild:build}));assert.equal(w.playerAttitudes.get(2).likes,0);
});
test('full journal, partial field updates, completion and removal preserve unmodified server fields',()=>{
 const w=new NetworkWorld();w.apply(decodeServerGameMessage(message(28,9,b=>{b.writeBool(1);b.writeBool(1);b.writeInt(1);b.writeWord(0x8000);str(b,'quest_custom');loc(b,'A quest');loc(b,'Do the thing');b.writeDword(10);b.writeDword(11);b.writeInt(3);b.writeDword(7);b.writeWord(123);b.writeBool(0);}),{clientBuild:build}));const e=w.journal.entries.get('quest_custom');assert.equal(e.title.text,'A quest');assert.equal(e.description.text,'Do the thing');assert.equal(e.isQuest,true);
 w.apply(decodeServerGameMessage(message(28,9,b=>{b.writeBool(1);b.writeBool(0);b.writeInt(1);b.writeWord(0x80);str(b,'quest_custom');b.writeBool(1);}),{clientBuild:build}));assert.equal(w.journal.entries.get('quest_custom').completed,1);assert.equal(w.journal.entries.get('quest_custom').description.text,'Do the thing');
 w.apply(decodeServerGameMessage(message(28,7,b=>str(b,'quest_custom')),{clientBuild:build}));assert.equal(w.journal.entries.size,0);
});
test('automap supports transmitted full byte maps, reset-positive lists, and set/clear deltas without local exploration',()=>{
 assert.deepEqual(applyNetworkAutomap(null,{mode:[1,0],points:[]},3,3),Array(9).fill(1));
 let states=applyNetworkAutomap(null,{mode:[0,1],bytes:[0b10010001]},4,2);assert.deepEqual(states,[1,0,0,0,1,0,0,1]);states=applyNetworkAutomap(states,{mode:[0,0],points:[{x:0,y:0,state:0},{x:2,y:0,state:1}]},4,2);assert.deepEqual(states,[0,0,1,0,1,0,0,1]);assert.deepEqual(applyNetworkAutomap(states,{mode:[1,0],points:[{x:1,y:1}]},4,2),[0,0,0,0,0,1,0,0]);assert.throws(()=>applyNetworkAutomap(states,{mode:[0,0],points:[{x:4,y:0,state:1}]},4,2));
});
