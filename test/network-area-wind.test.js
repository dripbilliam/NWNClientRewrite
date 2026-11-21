import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {decodeServerGameMessage} from '../src/network_game_messages.js';import {NetworkWorld} from '../src/network_world.js';import {GAME_OBJECT_TYPE} from '../src/game_object_array.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-wind-message-observations-v1.json',import.meta.url)));
test('complete original server wind sender decodes its six f32 fields and updates only the current area',()=>{
 assert.equal(fixture.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 const world=new NetworkWorld(),area={id:0x80000001,objectType:GAME_OBJECT_TYPE.area,state:{fields:{e4:0}}};world.registry.addObjectAtPos(area.id,area);world.areaId=area.id;
 for(const row of fixture.rows.filter(r=>r.format===1)){
  const message=decodeServerGameMessage(Buffer.from(row.packet,'hex')),fields=Object.fromEntries(['e8','ec','f0','f4','f8','fc'].map((name,i)=>[name,row.values[i]]));assert.deepEqual(message,{kind:'area-wind',fields,major:4,minor:13});assert.equal(world.apply(message),true);assert.deepEqual(area.state.fields,{...fields,e4:3});message.fields.e8=88;assert.equal(area.state.fields.e8,row.values[0]);
 }
});
test('wind packets reject truncation and never fabricate absent, retired or nonarea owners',()=>{
 const packet=Buffer.from(fixture.rows.find(r=>r.format===1).packet,'hex');for(let n=3;n<packet.length;n++)assert.throws(()=>decodeServerGameMessage(packet.subarray(0,n)));
 const world=new NetworkWorld(),message=decodeServerGameMessage(packet);assert.equal(world.apply(message),false);const wrong={id:0x80000001,objectType:5,state:{}};world.registry.addObjectAtPos(wrong.id,wrong);world.areaId=wrong.id;assert.equal(world.apply(message),false);wrong.objectType=GAME_OBJECT_TYPE.area;wrong.replicationRemoved=true;assert.equal(world.apply(message),false);
});
