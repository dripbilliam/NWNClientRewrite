import test from 'node:test';
import assert from 'node:assert/strict';
import {applyPlayerState} from '../src/network_player_state_store.js';
import {effectIconGuiRequest} from '../src/network_hud_input.js';
import {NativeMessageReader} from '../src/native_message.js';

test('raw effect addition serials retain received order through coalesced snapshots',()=>{
 const before={effectIcons:{},effectIconSerials:{},effectIconNextSerial:0};
 const one=applyPlayerState(before,{effectIcons:{removed:[],added:[{icon:600,state:0},{icon:1,state:1},{icon:90,state:0}]}});
 assert.deepEqual(before,{effectIcons:{},effectIconSerials:{},effectIconNextSerial:0});
 assert.deepEqual(one.effectIconSerials,{600:0,1:1,90:2});
 const two=applyPlayerState(one,{effectIcons:{removed:[600],added:[{icon:3,state:1},{icon:600,state:0}]}});
 assert.deepEqual(two.effectIconSerials,{1:1,90:2,3:3,600:4});assert.equal(two.effectIconNextSerial,5);
 assert.deepEqual(one.effectIconSerials,{600:0,1:1,90:2});
 const state=applyPlayerState(two,{effectIcons:{removed:[1],added:[{icon:1,state:0}]}});
 assert.equal(state.effectIconSerials[1],5);assert.equal(state.effectIcons[1],0);assert.equal(state.effectIconNextSerial,6);
 const removed=applyPlayerState(state,{effectIcons:{removed:[90,1,3,600],added:[]}});
 assert.deepEqual(removed.effectIconSerials,{});assert.deepEqual(removed.effectIcons,{});
 assert.deepEqual(applyPlayerState(state,{combat:{armorClass:7}}).effectIconSerials,state.effectIconSerials);
});

test('effect click preserves original GUI event5, WORD ID, invalid object and versioned zero XYZ',()=>{
 for(const effectId of [0,1,20,255,256,65535])for(const includePosition of [false,true]){
  const packet=effectIconGuiRequest({effectId,includePosition});assert.deepEqual([...packet.subarray(0,3)],[112,53,1]);
  const r=new NativeMessageReader(1),body=packet.subarray(3);assert.equal(r.setReadMessage(body,body.length,0xffffffff,1),1);
  assert.equal(r.readWord(),5);assert.equal(r.readWord(),effectId);assert.equal(r.readObjectIdClient(),0x7f000000);
  if(includePosition)for(let n=0;n<3;n++)assert.equal(r.readFloat(),0);
  assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);
 }
 for(const effectId of [-1,65536,1.5,NaN,'1'])assert.throws(()=>effectIconGuiRequest({effectId,includePosition:true}));
 assert.throws(()=>effectIconGuiRequest({effectId:1,includePosition:1}));
});
