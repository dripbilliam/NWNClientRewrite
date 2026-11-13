import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeMessageReader} from '../src/native_message.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NetworkWorld} from '../src/network_world.js';
import {cancelPolymorphRequest} from '../src/network_polymorph_input.js';

test('type43 original256 widget/sender executions preserve disabled/current actor/message gates and exact6/30 bytes',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-quickbar-polymorph-observations-v1.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,256);assert.equal(oracle.setterIcon,'IR_SKILLSELF');assert.equal(oracle.setterLabelRef,8272);
 for(const row of oracle.cases){const c=row.case,expected=(c.widgetFlags&1)===0&&!c.noActor&&!c.noMessage;assert.equal(row.packets.length,Number(expected),JSON.stringify(c));if(!expected||c.format!==1)continue;
  const packet=cancelPolymorphRequest(c),native=Buffer.from(row.packets[0],'hex'),used=native.at(-1)>>>5,mask=(255<<(8-used))&255;assert.equal(packet.length,native.length);assert.deepEqual(Buffer.from(packet.subarray(0,-1)),native.subarray(0,-1));assert.equal(packet.at(-1)&mask,native.at(-1)&mask);
  assert.deepEqual([...packet.subarray(0,3)],[112,6,30]);const reader=new NativeMessageReader(1);reader.setReadMessage(packet.subarray(3),packet.length-3,0xffffffff,1);assert.equal(reader.readObjectIdClient(),c.actorId);assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);
 }
 for(const actorId of [-1,2**32,NaN,Infinity,1.5,undefined])assert.throws(()=>cancelPolymorphRequest({actorId}));
});

test('actual quickbar activation43 uses current controlled actor and leaves received shape/effects/layout unchanged',async()=>{
 const world=new NetworkWorld(),actor={id:0xffffffff,objectType:5,areaId:0x80000001,appearance:{appearance:864},replicated:{animation:0},playerState:{effects:[{type:62,id:'500'}]}};world.registry.addObjectAtPos(actor.id,actor);world.localObjectId=actor.id;world.areaId=actor.areaId;world.quickbar[17]={type:43,intParam:123};const packets=[],owner={world,controlledActor:(area,generation)=>{assert.equal(area,actor.areaId);assert.equal(generation,3);return actor;},peer:{sendGameMessage:async packet=>packets.push(packet)}};
 const before=structuredClone([...world.registry.objects]),buttons=structuredClone(world.quickbar);assert.deepEqual(await NetworkGameSession.prototype.activateQuickbar.call(owner,{areaId:actor.areaId,areaGeneration:3,index:17}),{sent:true});assert.equal(packets.length,1);assert.deepEqual(packets[0],cancelPolymorphRequest({actorId:actor.id}));assert.deepEqual([...world.registry.objects],before);assert.deepEqual(world.quickbar,buttons);
 for(const index of [-1,36,NaN,1.5])await assert.rejects(NetworkGameSession.prototype.activateQuickbar.call(owner,{areaId:actor.areaId,areaGeneration:3,index}));assert.equal(packets.length,1);
 owner.controlledActor=()=>{throw new Error('retired actor');};await assert.rejects(NetworkGameSession.prototype.activateQuickbar.call(owner,{index:17}),/retired/);assert.equal(packets.length,1);
 owner.controlledActor=()=>actor;owner.peer.sendGameMessage=async()=>{throw new Error('send failed');};await assert.rejects(NetworkGameSession.prototype.activateQuickbar.call(owner,{index:17}),/send failed/);assert.deepEqual([...world.registry.objects],before);assert.deepEqual(world.quickbar,buttons);
});
