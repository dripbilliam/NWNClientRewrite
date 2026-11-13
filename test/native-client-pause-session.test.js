import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NativeMessageWriter} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {captureMessage} from '../electron/scene_capture.mjs';

// Authored wire fields through the real scalar writer/decoder and received
// session owner. No peer connection, native clock simulation or renderer.
function packet(mask,value,ids=[]){
 const writer=new NativeMessageWriter(1);writer.create(2+ids.length*4,0xffffffff,1);
 writer.writeByte(mask,2,1);writer.writeBool(value);writer.writeWord(ids.length,16);
 for(const id of ids)writer.writeObjectIdClient(id);
 writer.setPrefix(Uint8Array.of(80,3,9));return Uint8Array.from(writer.getWriteMessage().data);
}
function harness(){
 const peer=new EventEmitter(),sent=[],diagnostics=[],events=[];
 peer.sendGameMessage=async message=>{sent.push(message);throw Error('Pause receipt must not send a gameplay command');};
 const session=new NetworkGameSession({peer,identity:{},build:{build:{number:8193,revision:37,postfix:17}},resources:{},language:0,
  openModule:async()=>{throw Error('Pause receipt must not load module resources');},onDiagnostic:value=>diagnostics.push(value)});
 session.areaGeneration=7;session.on('message',event=>events.push(event));
 return{peer,sent,diagnostics,events,session};
}

test('actual game decoder admits native module3/9 rather than unsupported',()=>{
 for(let mask=0;mask<4;mask++)for(const value of [0,1]){
  const ids=[0x80000042,0xffffffff,0x7f000000,0x80000042];
  assert.deepEqual(decodeServerGameMessage(packet(mask,value,ids)),{kind:'module-pause-state',major:3,minor:9,mask,value,exclusionIds:ids});
 }
 assert.equal(decodeServerGameMessage(Uint8Array.of(80,3,8)).kind,'unsupported','Unimplemented module minors remain unsupported');
});

test('actual game decoder rejects every truncated module-pause frame without a DTO',()=>{
 const bytes=packet(2,1,[0x80000042,0xffffffff]);
 for(let length=0;length<bytes.length;length++)assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,length)));
});

test('real session serial delivery preserves repeated transitions and ordered duplicate IDs',async()=>{
 const h=harness(),first=packet(2,1,[0x80000042,0x80000042]),second=packet(1,0,[]);
 const before=structuredClone(h.session.world.snapshot());
 for(const bytes of [first,first,second])h.peer.emit('message',bytes);
 await h.session.delivery;
 assert.equal(h.events.length,3,'Repeated mask2/value1 is not deduplicated at receipt');
 assert.deepEqual(h.events.map(event=>[event.areaGeneration,event.message.mask,event.message.value,event.message.exclusionIds]),[
  [7,2,1,[0x80000042,0x80000042]],[7,2,1,[0x80000042,0x80000042]],[7,1,0,[]]
 ]);
 assert.deepEqual(h.session.world.snapshot(),before,'A wire event cannot invent client timer/flag state in the server-state owner');
 assert.deepEqual(h.sent,[]);assert.deepEqual(h.diagnostics,[]);
 h.events[0].message.exclusionIds[0]=1;
 assert.equal(h.events[1].message.exclusionIds[0],0x80000042,'Each decoded receipt owns its own list');
 h.session.closed=true;
});

test('invalid receipt publishes only a diagnostic and later valid delivery still succeeds',async()=>{
 const h=harness(),good=packet(2,1,[0x80000042]);
 h.peer.emit('message',good.subarray(0,good.length-1));h.peer.emit('message',good);
 await h.session.delivery;
 assert.equal(h.events.length,1);assert.equal(h.events[0].message.kind,'module-pause-state');
 assert.equal(h.diagnostics.length,1);assert.equal(h.diagnostics[0].code,'network.game-message-invalid');
 assert.deepEqual(h.sent,[]);
 h.session.closed=true;h.peer.emit('message',good);await h.session.delivery;
 assert.equal(h.events.length,1,'A closed connection cannot publish another clock event');
});

test('decoded scene capture retains pause order/duplicates and stays detached and credential-free',()=>{
 const received=decodeServerGameMessage(packet(3,1,[0x80000042,0x80000042]));
 received.credentials={privateKey:'authored secret'};
 const captured=captureMessage(received);
 assert.equal(captured.kind,'module-pause-state');assert.deepEqual(captured.exclusionIds,[0x80000042,0x80000042]);
 assert.equal(captured.credentials,undefined);captured.exclusionIds[0]=1;
 assert.equal(received.exclusionIds[0],0x80000042,'Capture cleaning does not lend the live message list');
 assert.equal(captureMessage({kind:'login',credentials:{privateKey:'authored secret'}}),null);
});
