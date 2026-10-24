import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {mergeNetworkActionQueue} from '../src/network_action_queue.js';
import {applyPlayerState} from '../src/network_player_state_store.js';
import {cancelActionRequest} from '../src/network_player_requests.js';
import {readPlayerState} from '../src/network_player_state.js';
import {NativeMessageReader,NativeMessageWriter} from '../src/native_message.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {networkQueuedAction} from '../src/network_action_queue_view.js';
import {parse2da} from '../src/area.js';

test('native A/S/D queue order retains duplicates, priority entries and hidden tail',()=>{
 let state=applyPlayerState({}, {actionQueueChanges:[{action:'A',type:0,group:1,position:[1,2,3]},{action:'A',type:4,group:2,target:0xffffffff,position:[4,5,6],field5A4:37}]});
 const before=structuredClone(state);state=applyPlayerState(state,{actionQueueChanges:[{action:'S',type:7,group:1,target:0xfffffffe},{action:'S',type:8,group:2,target:0x80000002},{action:'A',type:4,group:2,target:0xffffffff,position:[7,8,9],field5A4:1}]});
 assert.deepEqual(before.actionQueue.map(e=>e.group),[1,2]);assert.deepEqual(state.actionQueue.map(e=>e.type),[7,8,0,4,4]);assert.deepEqual(state.actionQueue.map(e=>e.widgetSerial),[2,3,0,1,4]);
 state=applyPlayerState(state,{actionQueueChanges:[{action:'D',type:4,group:2},{action:'D',type:7,group:1},{action:'D',type:999,group:999}]});assert.deepEqual(state.actionQueue.map(e=>e.widgetSerial),[3,0,4]);
 state=applyPlayerState(state,{actionQueueChanges:Array.from({length:14},(_,i)=>({action:'A',type:0,group:100+i,position:[i,0,0]}))});assert.equal(state.actionQueue.length,17);assert.ok(!Object.hasOwn(state,'actionQueueChanges'));
});

test('native batch target and position carry includes U without changing existing widgets',()=>{
 const q=mergeNetworkActionQueue([],[{action:'A',type:0,group:1,position:[1,2,3]},{action:'U',type:4,group:3,target:0xfffffffe},{action:'A',type:2,group:2,position:[4,5,6]},{action:'S',type:7,group:4,target:0xffffffff},{action:'A',type:12,group:5,target:0x80000002,position:[7,8,9]},{action:'A',type:8,group:6,target:0x80000003}]);
 assert.equal(q.entries.length,5);assert.equal(q.entries[1].target,OBJECT_INVALID);assert.equal(q.entries[2].target,0xfffffffe);assert.deepEqual(q.entries[0].position,[0,0,0]);assert.deepEqual(q.entries.at(-1).position,[7,8,9]);
 const next=mergeNetworkActionQueue(q.entries,[{action:'A',type:0,group:7,position:[0,0,0]}],q.nextSerial);assert.equal(next.entries.at(-1).target,OBJECT_INVALID);assert.deepEqual(q.entries.at(-1).position,[7,8,9]);
});

test('U player-state wire consumes its target and preserves following records',()=>{
 const w=new NativeMessageWriter(1);w.create(64,0xffffffff,1);w.writeObjectIdClient(0xffffffff);w.writeWord(256);w.writeByte(2);w.writeByte('U'.charCodeAt(0));w.writeWord(4);w.writeWord(123);w.writeObjectIdClient(0xfffffffe);w.writeByte('D'.charCodeAt(0));w.writeWord(4);w.writeWord(321);const bytes=w.getWriteMessage().data.subarray(3),r=new NativeMessageReader(1);r.setReadMessage(bytes,bytes.length,0xffffffff,1);
 assert.deepEqual(readPlayerState(r,{number:8193,revision:37,postfix:17}).state.actionQueueChanges,[{action:'U',type:4,group:123,target:0xfffffffe},{action:'D',type:4,group:321}]);assert.equal(r.messageReadOverflow(),0);
});

test('cancel request matches original WORD sender and guarded vanilla receiver',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-action-cancel.json',import.meta.url)));assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,144);
 for(const {case:c,packet,decoded}of fixture.cases){assert.deepEqual(decoded.calls,c.noActor||c.commandable===0?[]:[['cancel',c.actionId,c.groupId]]);if(c.format===1){const actual=Buffer.from(cancelActionRequest(c)),native=Buffer.from(packet,'hex'),used=native.at(-1)>>>5,mask=255<<(8-used)&255;assert.equal(actual.length,native.length);assert.deepEqual(actual.subarray(0,-1),native.subarray(0,-1));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);}}
 for(const value of [-1,65536,1.5,NaN,'4']){assert.throws(()=>cancelActionRequest({actionId:value,groupId:1}));assert.throws(()=>cancelActionRequest({actionId:4,groupId:value}));}
});

test('queue presentation reads active action, spell and associated feat rows',()=>{
 const tables={actions:parse2da('2DA V2.0\n\nLABEL STRING_REF ICONRESREF\n0 Move 10 ir_move\n1 Use 11 ****\n2 Other 12 ir_other\n3 Reserved 13 ir_use\n4 Cast 14 ir_cast\n'),spells:parse2da('2DA V2.0\n\nIconResRef FeatID\n0 spell_icon 0\n1 ignored 1\n'),feat:parse2da('2DA V2.0\n\nICON\n0 unused\n1 feat_icon\n')};
 assert.equal(networkQueuedAction({type:0},tables).icon,'ir_move');assert.equal(networkQueuedAction({type:1},tables).icon,'ir_use');assert.equal(networkQueuedAction({type:4,spell:0},tables).icon,'spell_icon');assert.equal(networkQueuedAction({type:4,spell:1},tables).icon,'feat_icon');assert.equal(networkQueuedAction({type:4,spell:1,special:true},tables).icon,'ir_cast');assert.equal(networkQueuedAction({type:4,spell:999},tables).icon,null);assert.equal(networkQueuedAction({type:19,spell:999},tables).hidden,true);
});
