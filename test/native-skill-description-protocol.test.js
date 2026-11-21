import test from 'node:test';
import assert from 'node:assert/strict';
import {skillDescriptionGuiRequest} from '../src/network_hud_input.js';
import {NativeMessageReader} from '../src/native_message.js';

test('skill inspection uses native GUI3 with the selected WORD and displayed character, not a skill-use action',()=>{
 for(const skillId of [0,1,11,26,255,256,65535])for(const targetId of [0,42,0x80000001,0xffffffce,0xffffffff])for(const includePosition of [false,true]){
  const packet=skillDescriptionGuiRequest({skillId,targetId,includePosition});
  assert.deepEqual([...packet.subarray(0,3)],[112,53,1]);
  const reader=new NativeMessageReader(1),body=packet.subarray(3);
  assert.equal(reader.setReadMessage(body,body.length,0xffffffff,1),1);
  assert.equal(reader.readWord(),3);assert.equal(reader.readWord(),skillId);assert.equal(reader.readObjectIdClient(),targetId);
  if(includePosition)for(let index=0;index<3;index++)assert.equal(reader.readFloat(),0);
  assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);
 }
 for(const skillId of [-1,65536,1.5,NaN,'11'])assert.throws(()=>skillDescriptionGuiRequest({skillId,targetId:42,includePosition:true}));
 for(const targetId of [-1,4294967296,1.5,'42'])assert.throws(()=>skillDescriptionGuiRequest({skillId:11,targetId,includePosition:true}));
 for(const includePosition of [null,undefined,0,1,'true'])assert.throws(()=>skillDescriptionGuiRequest({skillId:11,targetId:42,includePosition}));
});
