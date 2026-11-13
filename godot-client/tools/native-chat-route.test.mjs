import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import fs from 'node:fs';
import {NetworkGameSession} from '../../electron/network_game_session.mjs';
import {NativeMessageReader} from '../../src/native_message.js';
import {submitNativeChat} from './chat-input.mjs';
function fixture(){
 const peer=new EventEmitter(),sent=[];peer.sendGameMessage=async packet=>sent.push(packet);
 const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{number:8193,revision:37,postfix:17},dispose(){}},resources:{},language:0});
 Object.assign(session,{phase:'playing',areaReadySent:true,areaGeneration:2});session.world.areaId=56;session.world.localObjectId=42;
 const actor={id:42,objectType:5,areaId:56,replicated:{party:{singleton:1,field7DC:0}}};session.world.registry.insert(42,actor);
 session.world.players.set(7,{name:'Other Account',objectId:77,character:{id:177}});
 return {session,sent,actor,scope:{areaId:56,areaGeneration:2}};
}
function read(packet){const r=new NativeMessageReader(1);r.setReadMessage(packet.subarray(3),packet.length-3,0xffffffff,1);return r;}
test('production adapter retains resolved Tell player ID/account and source actor',async()=>{
 const f=fixture(),message={kind:'chat',actorId:42,channel:4,text:'hello',playerId:7,playerAccount:'Other Account'};
 await submitNativeChat(f.session,f.scope,message);const r=read(f.sent[0]);assert.deepEqual([...f.sent[0].subarray(0,3)],[112,9,4]);assert.equal(r.readBool(),0);assert.equal(r.readDword(),7);assert.equal(new TextDecoder().decode(r.readCExoString().bytes),'hello');
 for(const change of [{actorId:43},{playerId:8},{playerAccount:'Reused Account'}])await assert.rejects(submitNativeChat(f.session,f.scope,{...message,...change}));assert.equal(f.sent.length,1);
});
test('name-addressed /o Tell preserves an explicitly empty recipient',async()=>{
 const f=fixture();await submitNativeChat(f.session,f.scope,{actorId:42,channel:4,recipient:'',text:'hello'});const r=read(f.sent[0]);assert.equal(r.readBool(),1);const empty=r.readCExoString();assert.equal(empty.length,0);assert.equal(empty.bytes,null);assert.equal(new TextDecoder().decode(r.readCExoString().bytes),'hello');
});
test('chat party commands use original character target and acceptance sentinel without predicting server permission',async()=>{
 const f=fixture(),before=structuredClone(f.actor);await f.session.partyChatInput({...f.scope,actorId:42,operation:'invite',playerId:7,playerAccount:'Other Account',targetId:177});assert.deepEqual([...f.sent[0].subarray(0,3)],[112,14,9]);assert.equal(read(f.sent[0]).readObjectIdClient(),177);
 await f.session.partyChatInput({...f.scope,actorId:42,operation:'accept',targetId:0x7f000000});assert.deepEqual([...f.sent[1].subarray(0,3)],[112,14,11]);assert.equal(read(f.sent[1]).readObjectIdClient(),0x7f000000);assert.deepEqual(f.actor,before);assert.deepEqual(f.session.world.party,[]);
 for(const change of [{actorId:43},{playerAccount:'Changed'},{targetId:77}])await assert.rejects(f.session.partyChatInput({...f.scope,actorId:42,operation:'invite',playerId:7,playerAccount:'Other Account',targetId:177,...change}));assert.equal(f.sent.length,2);
});
const receipt=process.env.NWN_NATIVE_CHAT_RECEIPT;
test('actual Godot entry requests survive the production adapter into native packets',{skip:!receipt},async()=>{
 const data=JSON.parse(fs.readFileSync(receipt,'utf8'));assert.equal(data.success,true);assert.ok(data.forwardedChat);assert.equal(data.forwardedChat.actorId,42);
 const f=fixture();await submitNativeChat(f.session,f.scope,data.forwardedChat);const r=read(f.sent[0]);assert.equal(r.readBool(),0);assert.equal(r.readDword(),7);assert.equal(new TextDecoder().decode(r.readCExoString().bytes),'native-route-check');
 for(const input of data.forwardedParty)await f.session.partyChatInput({...input,areaGeneration:input.generation});assert.deepEqual([...f.sent[1].subarray(0,3)],[112,14,9]);assert.deepEqual([...f.sent[2].subarray(0,3)],[112,14,11]);assert.equal(read(f.sent[1]).readObjectIdClient(),177);assert.equal(read(f.sent[2]).readObjectIdClient(),0x7f000000);
});
