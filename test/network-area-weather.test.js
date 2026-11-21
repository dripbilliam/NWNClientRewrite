import test from 'node:test';import assert from 'node:assert/strict';
import {NativeMessageWriter} from '../src/native_message.js';import {decodeServerGameMessage} from '../src/network_game_messages.js';import {NetworkWorld} from '../src/network_world.js';import {GAME_OBJECT_TYPE} from '../src/game_object_array.js';
const packet=(type,enabled)=>{const w=new NativeMessageWriter(1);w.create(5,0xffffffff,1);w.writeByte(type);w.writeBool(enabled);w.setPrefix(Uint8Array.of(80,4,4));return Uint8Array.from(w.getWriteMessage().data);};
test('native weather byte/bool messages retain all wire type values and update only the current real area',()=>{
 const world=new NetworkWorld(),area={id:0x80000001,objectType:GAME_OBJECT_TYPE.area,state:{weather:{type:0,enabled:0}}};world.registry.addObjectAtPos(area.id,area);world.areaId=area.id;
 for(const type of [0,1,2,255])for(const enabled of [0,1]){const message=decodeServerGameMessage(packet(type,enabled));assert.deepEqual(message,{kind:'area-weather',weather:{type,enabled},major:4,minor:4});assert.equal(world.apply(message),true);assert.deepEqual(area.state.weather,{type,enabled});message.weather.type=4;assert.equal(area.state.weather.type,type);}
});
test('truncated weather streams fail and absent/retired/nonarea owners are not fabricated',()=>{
 const p=packet(2,1);for(let n=3;n<p.length;n++)assert.throws(()=>decodeServerGameMessage(p.subarray(0,n)));
 const world=new NetworkWorld(),message=decodeServerGameMessage(p);assert.equal(world.apply(message),false);
 const bad={id:0x80000001,objectType:5,state:{}};world.registry.addObjectAtPos(bad.id,bad);world.areaId=bad.id;assert.equal(world.apply(message),false);bad.objectType=GAME_OBJECT_TYPE.area;bad.replicationRemoved=true;assert.equal(world.apply(message),false);
});
