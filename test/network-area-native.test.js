import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeMessageReader,NativeMessageWriter} from '../src/native_message.js';
import {readAreaState,readClientArea} from '../src/network_area.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkMessageAssembler} from '../src/network_messages.js';
import {NetworkMessageInflater} from '../electron/network_message_inflater.mjs';
import {satisfiesNativeBuild} from '../src/network_build.js';
const load=name=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/${name}.json`,import.meta.url)));
const build={number:8193,revision:37,postfix:17};
const external=id=>((id&0x7fffffff)|0x80000000)>>>0;
function read(row){
 const bytes=Buffer.from(row.nativeHex,'hex').subarray(3),errors=[],r=new NativeMessageReader(row.format,{diagnose:e=>errors.push(e)});
 assert.equal(r.setReadMessage(bytes,bytes.length,0xffffffff,1),1);const a=readAreaState(r,build);
 assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.deepEqual(errors,[]);return a;
}
async function capturedMessages(){
 const report=load('local-network-character-v3'),a=new NetworkMessageAssembler(),inflater=new NetworkMessageInflater(),messages=[];
 for(const hex of report.transport.applicationFrames)a.push(Buffer.from(hex,'hex'));
 try{for(const m of a.drain())messages.push(await inflater.decode(m.bytes));}finally{inflater.close();}return messages;
}

test('ten original area bodies recover native inputs across five areas and both format modes',()=>{
 const native=load('native-live-area-pack-observations'),cases=load('live-area-pack-cases');assert.equal(native.rows.length,10);
 for(const row of native.rows){
  const a=read(row),c=cases.cases.find(x=>x.case.id===row.areaId&&x.case.format===row.format).case;
  assert.equal(a.id,external(c.id));assert.deepEqual(a.moduleEntry,c.point);assert.equal(a.width,c.area.c[1]);assert.equal(a.height,c.area['10'][1]);
  assert.equal(a.pvp,c.pvp);assert.equal(a.tiles.length,c.tiles.length);
  for(const [index,tile]of a.tiles.entries())for(const [offset,[,value]]of Object.entries(c.tiles[index]))assert.equal(tile.fields[offset],value);
  for(const [offset,value]of Object.entries(a.fields))assert.equal(value,c.area[offset][1]);
  for(const [offset,value]of Object.entries(a.ambient))assert.equal(value,c.ambient[offset][1]);
  const objects=new Map(c.objects.map(o=>[external(o.id),o]));
  for(const s of a.sounds){const source=objects.get(s.id);assert.equal(source.type,16);for(const [offset,value]of Object.entries(s.fields))assert.equal(value,source.fields[offset][1]);assert.deepEqual(s.position,['a4','a8','ac'].map(o=>source.fields[o][1]));assert.equal(s.refs.length,source.refsHex.length);}
  for(const p of a.staticPlaceables){const source=objects.get(p.id);assert.equal(source.type,9);assert.equal(p.appearance,source.fields['32c'][1]);assert.deepEqual(p.position,['a4','a8','ac'].map(o=>source.fields[o][1]));assert.deepEqual(p.orientation,['b0','b4','b8'].map(o=>source.fields[o][1]));}
 }
});

test('original synthetic area bodies cover build gates, fog, grass, pins and corrupt static-count state',()=>{
 let accepted=0,rejected=0;
 for(const row of load('native-area-pack-observations').rows){
  const c=row.case;if(row.result!==1||c.onLookup||c.onLight)continue;
  const compatible=[{number:8193,revision:13,postfix:0},{number:8193,revision:14,postfix:0},{number:8193,revision:35,postfix:0},{number:8193,revision:36,postfix:3},build].find(b=>Object.entries(c.expansions).every(([key,v])=>{const [revision,postfix]=key.split(':').map(Number);return !!v===satisfiesNativeBuild(b,{number:8193,revision,postfix});}));
  if(!compatible)continue;
  const bytes=Buffer.from(row.observation.hex,'hex').subarray(3),r=new NativeMessageReader(c.format),decode=()=>{
   assert.equal(r.setReadMessage(bytes,bytes.length,0xffffffff,1),1);const area=readAreaState(r,compatible);assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);return area;
  };
  // Native counter accepts any nonzero static flag but its writer accepts
  // exactly1. These deliberate corrupt-state fixtures announce absent records.
  if(c.objects.some(o=>o.type===9&&o.fields['5a0'][1]!==0&&o.fields['5a0'][1]!==1)){
   assert.throws(decode,/static-placeable count/);rejected++;
  }else{const area=decode();assert.equal(area.id,external(c.id));assert.deepEqual(area.moduleEntry,c.point);accepted++;}
 }
 assert.equal(accepted,393);assert.equal(rejected,32);
});

test('captured native ClientArea retains canonical IDs and static proxies while recreating sound instances',async()=>{
 const world=new NetworkWorld(),messages=await capturedMessages();let entry;
 for(const bytes of messages){const d=decodeServerGameMessage(bytes,{clientBuild:build});if(d.kind!=='object-updates')world.apply(d);if(d.kind==='client-area')entry=d;}
 assert.ok(entry);const a=entry.area;assert.equal(a.resRef,'m0q1a');assert.equal(a.tileset,'tic01');assert.equal(a.tiles.length,9);assert.equal(a.sounds.length,10);assert.equal(a.staticPlaceables.length,13);
 assert.deepEqual(entry.position,[6,3,0]);assert.equal(world.registry.objects.size,24);assert.equal(world.areaId,0x80000001);
 const sound=world.registry.get(a.sounds[0].id),placeable=world.registry.get(a.staticPlaceables[0].id),area=world.registry.get(a.id);
 // Native area teardown7e7770 deletes its sound instances. Their server IDs
 // survive the reload, while the replacement's unrelated static caches stay.
 assert.equal(world.registry.get(a.id&0x7fffffff),undefined);world.apply(entry);assert.notEqual(world.registry.get(sound.id),sound);assert.equal(world.registry.get(sound.id).id,sound.id);assert.equal(world.registry.get(placeable.id),placeable);assert.equal(world.registry.get(area.id),area);
 const before=world.snapshot(),bad=structuredClone(entry);bad.area.sounds[0].id=bad.area.id;
 assert.throws(()=>world.apply(bad),/Conflicting/);assert.deepEqual(world.snapshot(),before);assert.equal(area.state.sounds[0].id,sound.id);
 world.reset();assert.equal(world.registry.objects.size,0);assert.equal(world.registry.get(sound.id),undefined);
});

test('truncated real area packets, forged counts and trailing bytes fail without creating world state',async()=>{
 const packet=(await capturedMessages()).find(b=>b[1]===4&&b[2]===1);assert.ok(packet);
 for(let size=3;size<packet.length;size++)assert.throws(()=>decodeServerGameMessage(packet.subarray(0,size),{clientBuild:build}),`size ${size}`);
 const extra=Buffer.concat([packet,Buffer.from([0])]);assert.throws(()=>decodeServerGameMessage(extra,{clientBuild:build}));
 const reader=new NativeMessageReader(1),refs=[],words=[];reader.setReadMessage(packet.subarray(3),packet.length-3,0xffffffff,1);
 const readRef=reader.readCResRef.bind(reader),readWord=reader.readWord.bind(reader);
 reader.readCResRef=(...args)=>{refs.push(reader.byteCursor44);return readRef(...args);};reader.readWord=(...args)=>{words.push(reader.byteCursor44);return readWord(...args);};readClientArea(reader,build);
 // Locate the dimensions and reserved footer through actual typed reads.
 for(const [offset,value]of [[refs[1]-8,0x7fffffff],[refs[1]-4,-1],[words.at(-2),1]]){
  const forged=Buffer.from(packet);if(offset===words.at(-2))forged.writeUInt16LE(value,offset+3);else forged.writeInt32LE(value,offset+3);
  assert.throws(()=>decodeServerGameMessage(forged,{clientBuild:build}));
 }
 assert.throws(()=>decodeServerGameMessage(packet,{clientBuild:null}),/build/);
});

test('ObjControl binds PLAYER_ID separately from full client OBJECT_ID',()=>{
 for(const playerId of [0,1,0xffffffff])for(const id of [0x80000001,0xffffffff,0x7f000000]){
  const w=new NativeMessageWriter(1);w.create(8,0xffffffff,1);w.setPrefix(Uint8Array.of(80,5,2));w.writeDword(playerId);w.writeObjectIdServer(id);const p=w.getWriteMessage().data;
  const d=decodeServerGameMessage(p);assert.deepEqual(d,{kind:'object-control',major:5,minor:2,playerId,objectId:id});const world=new NetworkWorld();world.apply(d);assert.equal(world.controls.get(playerId),id);assert.equal(world.registry.objects.size,0);
 }
});
