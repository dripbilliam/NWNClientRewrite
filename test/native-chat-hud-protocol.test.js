import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeMessageReader} from '../src/native_message.js';
import {chatFocusGuiRequest,chatReplyGuiRequest} from '../src/network_hud_input.js';

test('original chat focus events1/2 carry the five-mode index and versioned zero position',()=>{
 for(const mode of [0,1,2,3,4])for(const focused of [false,true])for(const includePosition of [false,true]){
  const packet=chatFocusGuiRequest({mode,focused,includePosition});assert.deepEqual([...packet.subarray(0,3)],[112,53,1]);
  const body=packet.subarray(3),r=new NativeMessageReader(1);assert.equal(r.setReadMessage(body,body.length,0xffffffff,1),1);
  assert.equal(r.readWord(),focused?1:2);assert.equal(r.readWord(),mode);assert.equal(r.readObjectIdClient(),0x7f000000);
  if(includePosition)for(let n=0;n<3;n++)assert.equal(r.readFloat(),0);
  assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);
 }
 for(const mode of [-1,5,1.5,'2'])assert.throws(()=>chatFocusGuiRequest({mode,focused:true,includePosition:true}));
 assert.throws(()=>chatFocusGuiRequest({mode:2,focused:1,includePosition:true}));
});
test('original chat reply event27 retains the target character and versioned position fields',()=>{
 for(const targetId of [0,0x7f000000,0x80001234,0xffffffff])for(const includePosition of [false,true]){
  const packet=chatReplyGuiRequest({targetId,includePosition}),body=packet.subarray(3),r=new NativeMessageReader(1);
  assert.deepEqual([...packet.subarray(0,3)],[112,53,1]);assert.equal(r.setReadMessage(body,body.length,0xffffffff,1),1);
  assert.equal(r.readWord(),27);assert.equal(r.readWord(),0);assert.equal(r.readObjectIdClient(),targetId);
  if(includePosition)for(let i=0;i<3;i++)assert.equal(r.readFloat(),0);
  assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);
 }
 for(const targetId of [-1,1.5,0x100000000,'1'])assert.throws(()=>chatReplyGuiRequest({targetId,includePosition:true}));
});
