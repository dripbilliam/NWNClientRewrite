import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {walkToWaypointRequest} from '../src/network_player_requests.js';
import {NativeMessageReader,NativeMessageWriter} from '../src/native_message.js';
const observations=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-walk-observations.json',import.meta.url)));

test('waypoint packet defined bytes match the original sender and native server action arguments',()=>{
 for(const row of observations.cases.filter(r=>r.case.format===1)){
  const c=row.case,packet=walkToWaypointRequest({...c,position:c.point}),native=Buffer.from(row.packet,'hex');assert.equal(packet.length,native.length);assert.deepEqual(Buffer.from(packet.subarray(0,-1)),native.subarray(0,-1));
  // Three residual padding bits are native uninitialized heap bytes (A5 in
  // the oracle). Our deterministic zero padding carries identical used bits.
  assert.equal(packet.at(-1)&0xf8,native.at(-1)&0xf8);
  const reader=new NativeMessageReader(1);assert.equal(reader.setReadMessage(packet.subarray(3),packet.length-3,0xffffffff,1),1);
  assert.equal(reader.readObjectIdServer(),c.areaId&0x7fffffff);assert.deepEqual([reader.readFloat(),reader.readFloat(),reader.readFloat()],c.point);assert.equal(reader.readByte(),c.sequence);assert.equal(reader.readBool(),c.run);assert.equal(reader.readBool(),c.clientPath);assert.equal(reader.readByte(),c.fractional);assert.equal(reader.readObjectIdServer(),c.targetId&0x7fffffff);assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);
  const move=row.decoded.calls.find(c=>c[0]==='move');assert.equal(move[5],c.run);assert.equal(move[8],c.clientPath);assert.equal(move[9],c.sequence);assert.equal(move[11],c.fractional);assert.equal(row.decoded.fractional,Number(c.fractional===1));
 }
});
test('client OBJECT_ID helper preserves high bits rather than allocating or rewriting an ID',()=>{
 const writer=new NativeMessageWriter(1);writer.create(8,0xffffffff,1);writer.writeObjectIdClient(0xffffffff);writer.writeObjectIdClient(0x7f000000);writer.setPrefix(Uint8Array.of(112,6,1));const p=writer.getWriteMessage().data;
 assert.equal(new DataView(p.buffer,p.byteOffset).getUint32(7,true),0xffffffff);assert.equal(new DataView(p.buffer,p.byteOffset).getUint32(11,true),0x7f000000);
});
test('non-native coordinates, ID widths, sequence values and flags are rejected before transport',()=>{
 const valid={areaId:0x80000001,position:[6,3,0],sequence:1,run:true};
 for(const change of [{areaId:-1},{areaId:0x100000000},{position:[NaN,3,0]},{position:[1e100,3,0]},{position:[1,2]},{sequence:256},{sequence:-1},{run:2},{clientPath:2},{fractional:256},{targetId:-1}])assert.throws(()=>walkToWaypointRequest({...valid,...change}),/Invalid/);
});

test('real renderer preload/IPC requests produce native-server running, walking and final rest at the requested points',()=>{
 const live=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v10.json',import.meta.url)));
 assert.equal(live.connected,true);assert.equal(live.failure,undefined);assert.equal(live.sampleFailure,undefined);assert.equal(live.states.at(-1).phase,'closed');
 assert.deepEqual(live.moves.map(m=>[m.result.sequence,m.run]),[[1,true],[2,false]]);
 const frames=live.samples.map(s=>({at:s.at,actor:s.scene?.objects.find(o=>o.id===0xffffffff)})).filter(f=>f.actor);
 for(const [index,animation,clip] of [[0,4,'run'],[1,2,'walk']]){
  const move=live.moves[index],end=live.moves[index+1]?.at??Infinity,relevant=frames.filter(f=>f.at>=move.at&&f.at<end);
  assert.ok(relevant.some(f=>f.actor.animation===animation&&f.actor.clip===clip));
  assert.ok(relevant.some(f=>Math.abs(f.actor.position[2]+move.position[1])<0.03&&f.actor.animation===0&&f.actor.clip==='pause1'));
 }
 assert.ok(frames.every(f=>f.actor.id===0xffffffff));assert.deepEqual(live.renderer.scene.failedObjects,[]);
});
