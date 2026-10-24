import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-sound-objects-observations.json',import.meta.url))),id=value=>value===0x7f000000?value:(value|0x80000000)>>>0;
test('complete native sound-object writers and packer retain canonical IDs and all scalar/list fields',()=>{
 assert.equal(data.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(data.cases.length,384);
 for(const c of data.cases.filter(c=>c.format===1))for(const hex of c.packets){const packet=Buffer.from(hex,'hex'),m=decodeServerGameMessage(packet);assert.equal(m.kind,'sound-object');assert.equal(m.operation,c.operation);assert.equal(m.objectId,id(c.objectId));
  if(c.operation===4)assert.equal(m.volume,c.value);if(c.operation===5)assert.deepEqual(m.position,c.position.map(Math.fround));
  if(c.operation===6){assert.equal(m.areaId,id(0x47));assert.equal(m.sound.id,id(c.objectId));assert.deepEqual(m.sound.position,c.position.map(Math.fround));assert.deepEqual(m.sound.refs,['case_Sound','abcdefghijklmnop','a','']);for(const [key,value]of Object.entries(c.fields)){const k=key.slice(2);assert.equal(m.sound.fields[k],[0x308,0x30c,0x310,0x358,0x35c,0x32c].includes(Number(key))?value&1:[0x314,0x318,0x31c,0x328].includes(Number(key))?value&255:value===1.25?value:value>>>0,k);}}
  for(let i=3;i<packet.length;i++)assert.throws(()=>decodeServerGameMessage(packet.subarray(0,i)));assert.throws(()=>decodeServerGameMessage(Buffer.concat([packet,Buffer.of(0,0)])));
 }
});
test('native sound lifecycle updates only its existing type16 proxy; duplicate/wrong-area creation and unrelated IDs cannot replace actors',()=>{
 const diagnostics=[],world=new NetworkWorld({onDiagnostic:d=>diagnostics.push(d)});world.areaId=0x80000047;world.registry.addObjectAtPos(world.areaId,{objectType:4,state:{sounds:[]}});const c=data.cases.find(c=>c.format===1&&c.operation===6&&c.objectId===0x13&&c.value===1),m=decodeServerGameMessage(Buffer.from(c.packets[0],'hex'));
 assert.equal(world.apply(m),true);const sound=world.registry.get(m.objectId);assert.equal(sound.objectType,16);assert.equal(world.registry.get(world.areaId).state.sounds.length,1);assert.equal(world.apply(m),false);assert.equal(world.registry.get(m.objectId),sound);
 world.apply({kind:'sound-object',operation:4,objectId:sound.id,volume:-1});assert.equal(sound.state.fields['314'],-1);world.apply({kind:'sound-object',operation:5,objectId:sound.id,position:[8,9,10]});assert.deepEqual(sound.state.position,[8,9,Math.fround(10+Math.fround(1.8))]);world.apply({kind:'sound-object',operation:3,objectId:sound.id});assert.equal(sound.state.fields['308'],0);world.apply({kind:'sound-object',operation:2,objectId:sound.id});assert.equal(sound.state.fields['308'],1);
 world.registry.addObjectAtPos(0xffffffff,{objectType:5,replicated:{name:'player'}});const actor=structuredClone(world.registry.get(0xffffffff));assert.equal(world.apply({kind:'sound-object',operation:7,objectId:0xffffffff}),false);assert.deepEqual(world.registry.get(0xffffffff),actor);
 assert.equal(world.apply({...m,objectId:0x80000123,sound:{...m.sound,id:0x80000123},areaId:0x80000048}),false);assert.equal(world.registry.get(0x80000123),undefined);world.apply({kind:'sound-object',operation:7,objectId:sound.id});assert.equal(world.registry.get(sound.id),undefined);assert.equal(world.registry.get(world.areaId).state.sounds.length,0);assert.ok(diagnostics.length>=2);
});
test('native area teardown removes old sound IDs before new imports while keeping the controlled creature',()=>{
 const world=new NetworkWorld(),firstId=0x80000047,nextId=0x80000048,sound={id:0x80000013,position:[0,0,1.5],refs:['torch'],fields:{}},entry=(id,sounds)=>({kind:'client-area',position:[1,2,0],facing:0,flag:0,area:{id,mapPins:[],sounds,placeableLights:[],staticPlaceables:[],time:{hour:6},tiles:[]}});world.localObjectId=0xffffffff;world.registry.addExternalObject(0xffffffff,{objectType:5,replicated:{}});const creature=world.registry.get(0xffffffff);
 world.apply(entry(firstId,[sound]));assert.ok(world.registry.get(sound.id));world.apply(entry(nextId,[]));assert.equal(world.registry.get(sound.id),undefined);assert.equal(world.registry.get(firstId).state.sounds.length,0);assert.equal(world.registry.get(0xffffffff),creature);assert.equal(creature.areaId,nextId);
 const create={kind:'sound-object',operation:6,objectId:sound.id,areaId:nextId,sound};assert.equal(world.apply(create),true);assert.equal(world.registry.get(sound.id).areaId,nextId);
});
