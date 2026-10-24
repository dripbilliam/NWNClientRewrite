import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageWriter} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';

const build={number:8193,revision:37,postfix:17};
test('32 isolated original reader branches clear, replace and omit effects exactly as observed',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-equipment-appearance-update-observations.json',import.meta.url)));
 assert.equal(fixture.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.cases.length,32);
 for(const c of fixture.cases){
  assert.deepEqual(c.trace,[['id',0x8000002a],['lookup',0x8000002a],['transform'],...(c.existing?[['clear'],...(c.effect?[['effect',c.effect]]:[]),['apply',true]]:[])]);
 }
});
function packet(effect=7){
 const w=new NativeMessageWriter(1);w.create(128,0xffffffff,1);w.setPrefix(Uint8Array.of(80,5,1));
 w.writeByte(80);w.writeByte(5);w.writeObjectIdClient(0x80000001);w.writeWord(512);w.writeByte(1);
 w.writeByte(85);w.writeObjectIdClient(0x80000002);w.writeDword(16);w.writeByte(effect);
 // Current transform format: keys, then keyed values, with an identity leaf.
 w.writeInt(1);w.writeInt(3);w.writeInt(1);w.writeInt(3);w.writeBool(1);
 // A different creature's appearance must survive the preceding U record.
 w.writeByte(80);w.writeByte(5);w.writeObjectIdClient(0xffffffaa);w.writeWord(1);w.writeWord(42);
 return w.getWriteMessage().data;
}
test('equipment U consumes only effect and transform, preserving the following player appearance',()=>{
 const d=decodeServerGameMessage(packet(),{clientBuild:build});assert.equal(d.complete,true);
 assert.deepEqual(d.records[0].state.equipment,[{action:'U',id:0x80000002,slot:16,item:{field462:7,visualTransform:{keys:[3],entries:[{key:3,value:{identity:true}}]}}}]);
 assert.deepEqual(d.records[1],{action:'appearance',objectType:5,id:0xffffffaa,mask:1,state:{appearance:42}});
 for(let size=3;size<packet().length;size++)assert.throws(()=>decodeServerGameMessage(packet().subarray(0,size),{clientBuild:build}));
});
test('equipment U updates existing canonical item without replacing metadata, ownership or slots',()=>{
 const world=new NetworkWorld(),actor=0x80000001,item=0x80000002;
 world.applyObjectUpdates([{action:'appearance',objectType:5,id:actor,state:{appearance:1,equipment:[{action:'A',id:item,slot:16,item:{baseItem:22,parts:[4],properties:[],name:{text:'Existing sword'},field462:3}}]}}]);
 const proxy=world.registry.get(item),owner=proxy.equipmentOwnerId;
 world.apply(decodeServerGameMessage(packet(0),{clientBuild:build}));
 assert.equal(world.registry.get(item),proxy);assert.equal(proxy.equipmentOwnerId,owner);assert.equal(proxy.item.name.text,'Existing sword');assert.deepEqual(proxy.item.parts,[4]);assert.equal(proxy.item.field462,0);
 assert.deepEqual(world.registry.get(actor).appearance.equipment.map(e=>[e.id,e.slot,e.item.field462]),[[item,16,0]]);
 const count=world.registry.objects.size;
 world.applyObjectUpdates([{action:'appearance',objectType:5,id:actor,state:{equipment:[{action:'U',id:0x80000003,slot:32,item:{field462:1,visualTransform:{keys:[],entries:[]}}}]}}]);
 assert.equal(world.registry.objects.size,count);assert.equal(world.registry.get(actor).appearance.equipment.length,1);
});

