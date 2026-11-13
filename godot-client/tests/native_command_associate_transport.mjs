// Consume the actual native-pointer receipt through the current Session with a
// controlled peer. Decode emitted wire scalars independently. No socket/login.
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {NetworkGameSession} from '../../electron/network_game_session.mjs';
import {NetworkWorld} from '../../src/network_world.js';
import {NativeMessageReader} from '../../src/native_message.js';
const arg=name=>process.argv.find(value=>value.startsWith('--'+name+'='))?.slice(name.length+3);
const input=JSON.parse(fs.readFileSync(arg('fixture'))),output=arg('report');
assert.equal(input.success,true);assert.ok(!fs.existsSync(output));let checks=0;
const check=(value,label)=>{checks++;assert.ok(value,label);};
const world=new NetworkWorld(),actor={id:99,objectType:5,areaId:7};world.localObjectId=99;world.areaId=7;world.registry.addObjectAtPos(99,actor);
const packets=[],owner={world,peer:{sendGameMessage:async packet=>packets.push(Uint8Array.from(packet))},controlledActor(area,generation){assert.equal(area,7);assert.equal(generation,1);return actor;}};
const read=packet=>{const reader=new NativeMessageReader(1);reader.setReadMessage(packet.subarray(3),packet.length-3,0xffffffff,1);return reader;};
const actions=[];const canonical=JSON.stringify([...world.registry.objects]);
for(const message of input.requests){
 check(message.areaId===7&&message.generation===1&&message.actorId===99,'Actual native request scope');
 const size=packets.length;
 if(message.kind==='native-quickbar-assign'){
  const result=await NetworkGameSession.prototype.assignQuickbar.call(owner,{...message,areaGeneration:message.generation});
  check(result.sent===true,'Actual Session accepts scoped native assignment');
  const packet=packets.at(-1),r=read(packet);
  check(packet[0]===112&&packet[1]===30&&packet[2]===2,'Assignment uses original30/2');
  check(r.readByte()===message.index&&r.readByte()===39&&r.readInt()===message.button.intParam&&r.readWord()===1&&r.readObjectIdClient()===message.button.associateId,'Assignment independently decodes signed command/associate WORD/exact target');
  actions.push({kind:'assign',index:message.index,target:message.button.associateId,command:message.button.intParam,packetHex:Buffer.from(packet).toString('hex')});
 }else{
  check(message.kind==='native-quickbar-activate','Only actual native shortcut Use follows assignment');
  const result=await NetworkGameSession.prototype.activateQuickbar.call(owner,{...message,areaGeneration:message.generation});
  check(result.sent===true&&!Object.hasOwn(result,'serverAcknowledged'),'Send is not fabricated acknowledgment');
  const packet=packets.at(-1),r=read(packet),button=world.quickbar[message.index];
  check(packet[0]===112&&packet[1]===6&&packet[2]===27,'Use routes original6/27');
  check(r.readObjectIdClient()===button.associateId&&r.readInt()===button.intParam,'Use independently decodes matching target/signed INT');
  actions.push({kind:'use',index:message.index,target:button.associateId,command:button.intParam,packetHex:Buffer.from(packet).toString('hex')});
 }
 check(packets.length===size+1,'One native transition emits one packet');
}
check(actions.filter(value=>value.kind==='use').map(value=>value.command).join(',')==='-19,-18,-20','Actual native inputs exercise all three source commands');
check(JSON.stringify([...world.registry.objects])===canonical,'No predicted creature/gameplay mutation');
const before=packets.length;owner.controlledActor=()=>{throw Error('Retired captured area');};
await assert.rejects(NetworkGameSession.prototype.activateQuickbar.call(owner,{areaId:7,areaGeneration:1,index:0}),/Retired/);check(packets.length===before,'Retired current Session rejects before send');
owner.controlledActor=()=>actor;owner.peer.sendGameMessage=async()=>{throw Error('Controlled send failure');};
await assert.rejects(NetworkGameSession.prototype.activateQuickbar.call(owner,{areaId:7,areaGeneration:1,index:0}),/send failure/);check(packets.length===before,'Peer failure cannot synthesize callback/result');
fs.writeFileSync(output,JSON.stringify({success:true,checks,actions,scope:'Actual staged native wheel receipt -> unchanged Session -> controlled peer; independently decoded30/2 and6/27. No socket, server, login, acknowledgment or imported producer change.'},null,2)+'\n');
console.log(JSON.stringify({success:true,checks,actions:actions.length}));
