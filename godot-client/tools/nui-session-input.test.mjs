import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NetworkGameSession} from '../../electron/network_game_session.mjs';
import {NativeMessageReader} from '../../src/native_message.js';
import {readNuiJson} from '../../src/network_nui.js';
test('native whole-array input preserves the changed-row metadata and canonical array without nesting',async()=>{
 const peer=new EventEmitter();let sent;
 peer.sendGameMessage=async bytes=>{sent=bytes;};
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:37,postfix:17},dispose(){}},resources:{},language:0});
 session.resolver={};session.world.nui.apply({kind:'nui-create',token:1,id:'rows',layout:{root:{type:'list'}}});
 session.world.nui.apply({kind:'nui-binds',updates:[{token:1,bind:'checks',value:[false,false,false]}]});
 const serial=session.world.nui.windows.get(1).serial;
 await session.nuiInput({token:1,serial,binds:[{bind:'checks',value:[false,false,true],index:2,wholeValue:true}]});
 assert.deepEqual(session.world.nui.windows.get(1).bindings.get('checks'),[false,false,true]);
 const r=new NativeMessageReader(1);assert.ok(r.setReadMessage(sent.subarray(3),sent.length-3,0xffffffff,1));
 assert.equal(r.readInt(),1);assert.equal(r.readInt(),1);assert.equal(new TextDecoder().decode(r.readCExoString().bytes),'checks');assert.deepEqual(readNuiJson(r),[false,false,true]);assert.equal(r.readInt(),2);assert.equal(r.messageReadUnderflow(),0);assert.equal(r.messageReadOverflow(),0);
});
