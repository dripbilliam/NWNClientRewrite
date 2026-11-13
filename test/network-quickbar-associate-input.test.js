import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {associateCommandRequest,networkAssociateShortcut} from '../src/network_associate_input.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NetworkWorld} from '../src/network_world.js';

const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-quickbar-associate-observations-v1.json',import.meta.url)));
test('432 original wrappers pack the separate wire command INT and associate WORD without changing low SHORT semantics',()=>{
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.packing.length,432);
 for(const row of oracle.packing){assert.equal(row.packed>>>0,((row.command<<16)|row.associateType)>>>0);const request=networkAssociateShortcut({type:39,intParam:row.command,associateType:row.associateType,associateId:row.associateId},{companionId:10,familiarId:11});if(![1,2,3].includes(row.associateType)){assert.equal(request,null);continue;}assert.deepEqual(request,{targetId:row.associateType===1?row.associateId:row.associateType===2?10:11,command:row.packed>>16});}
});
test('1728 original widget executions prove disabled/owner/type admission, current dynamic IDs, signed command and exact6/27 bytes',()=>{
 assert.equal(oracle.cases.length,1728);
 for(const row of oracle.cases){const c=row.case,expected=!(c.widgetFlags&1)&&!c.noActor&&!c.noMessage&&[1,2,3].includes(c.associateType);assert.equal(row.packets.length,Number(expected),JSON.stringify(c));const sends=row.calls.filter(value=>value.kind==='sender');assert.equal(sends.length,Number(expected));if(!expected)continue;
  const request=networkAssociateShortcut({type:39,intParam:c.command,associateType:c.associateType,associateId:0x80000002},{companionId:0xffffffff,familiarId:0x7f000000});assert.deepEqual(sends[0],{kind:'sender',...request});if(c.format!==1)continue;
  const actual=associateCommandRequest(request),native=Buffer.from(row.packets[0],'hex'),used=native.at(-1)>>>5,mask=(255<<(8-used))&255;assert.equal(actual.length,native.length);assert.deepEqual(Buffer.from(actual.subarray(0,-1)),native.subarray(0,-1));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);
 }
});
test('actual bound39 Session resolves the current canonical shortcut and controlled actor without predicted associate state',async()=>{
 const world=new NetworkWorld(),actor={id:0xffffffff,objectType:5,areaId:0x80000001,companionId:101,familiarId:102};world.registry.addObjectAtPos(actor.id,actor);world.localObjectId=actor.id;world.areaId=actor.areaId;const packets=[],owner={world,controlledActor:(area,generation)=>{assert.equal(area,actor.areaId);assert.equal(generation,3);return actor;},peer:{sendGameMessage:async packet=>packets.push(packet)}};
 for(const associateType of [1,2,3,0,4,65535]){world.quickbar[17]={type:39,intParam:65516,associateType,associateId:100};const before=structuredClone([...world.registry.objects]),buttons=structuredClone(world.quickbar),size=packets.length;assert.deepEqual(await NetworkGameSession.prototype.activateQuickbar.call(owner,{areaId:actor.areaId,areaGeneration:3,index:17}),{sent:[1,2,3].includes(associateType)});assert.equal(packets.length-size,Number([1,2,3].includes(associateType)));if(packets.length>size)assert.deepEqual(packets.at(-1),associateCommandRequest({targetId:associateType===1?100:associateType===2?101:102,command:-20}));assert.deepEqual([...world.registry.objects],before);assert.deepEqual(world.quickbar,buttons);}
 world.quickbar[17]={type:39,intParam:-9,associateType:2,associateId:100};actor.companionId=103;await NetworkGameSession.prototype.activateQuickbar.call(owner,{areaId:actor.areaId,areaGeneration:3,index:17});assert.deepEqual(packets.at(-1),associateCommandRequest({targetId:103,command:-9}));
 const size=packets.length;owner.controlledActor=()=>{throw new Error('retired actor');};await assert.rejects(NetworkGameSession.prototype.activateQuickbar.call(owner,{index:17}),/retired/);assert.equal(packets.length,size);owner.controlledActor=()=>actor;owner.peer.sendGameMessage=async()=>{throw new Error('send failed');};await assert.rejects(NetworkGameSession.prototype.activateQuickbar.call(owner,{index:17}),/send failed/);assert.equal(packets.length,size);
});
