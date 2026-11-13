import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {readPlayerState} from '../../src/network_player_state.js';
import {applyNetworkAutomap} from '../../src/network_automap.js';
const {RawTileVisibility}=createRequire(import.meta.url)('./raw-tile-visibility.cjs');
const actor={id:17,areaId:22,nativeLifetime:3,disclosureLifetime:5,playerState:{automap:{mode:[1,0],points:[]}}};
const world={areaId:22,localObjectId:17,registry:new Map([[17,actor]])};
const packet=change=>({kind:'object-updates',records:[{action:'player-state',id:17,state:{automap:change}}]});
test('fresh raw numeric native flags/typed bytes are detached and JSON-safe',()=>{
 const owner=new RawTileVisibility(),change={mode:[1,1],bytes:Uint8Array.of(0x81,0x34)},frames=owner.frames(world,packet(change),2,9);
 assert.equal(frames.length,1);assert.deepEqual(frames[0],{kind:'raw-tile-visibility',connection:9,generation:2,areaId:22,actorId:17,lifetime:[['nativeLifetime',true,3],['disclosureLifetime',true,5]],serial:1,change:{mode:[true,true],bytes:[129,52]}});
 change.bytes[0]=0;change.mode[0]=0;assert.equal(frames[0].change.bytes[0],129);assert.equal(frames[0].change.mode[0],true);assert.deepEqual(JSON.parse(JSON.stringify(frames)),frames);
});
test('sticky snapshot fields and unrelated PlayerInfo updates never replay masks',()=>{
 const owner=new RawTileVisibility();assert.deepEqual(owner.frames(world,{kind:'object-updates',records:[{action:'player-state',id:17,state:{combat:{armorClass:10}}}]},2,9),[]);
 assert.deepEqual(owner.frames(world,{kind:'snapshot',data:{objects:[actor]}},2,9),[]);
 const change={mode:[0,0],points:[{x:1,y:2,state:1}]},frame=owner.frames(world,packet(change),2,9)[0];change.points[0].x=99;
 assert.deepEqual(frame.change,{mode:[false,false],points:[{x:1,y:2,state:true}]});
});
test('ordered repeated native reset operations remain separate deliveries',()=>{
 const owner=new RawTileVisibility(),message=packet({mode:[1,0],points:[{x:1,y:1}]});message.records.push(structuredClone(message.records[0]));
 assert.deepEqual(owner.frames(world,message,2,9).map(f=>f.serial),[1,2]);
});
test('retired/wrong observer and unknown lifetime stay explicit',()=>{
 const owner=new RawTileVisibility(),message=packet({mode:[0,0],points:[]});
 assert.deepEqual(owner.frames({...world,localObjectId:99},message,2,9),[]);
 const missing={...actor};delete missing.nativeLifetime;delete missing.disclosureLifetime;
 assert.deepEqual(owner.frames({...world,registry:new Map([[17,missing]])},message,3,10)[0].lifetime,[['nativeLifetime',false,null],['disclosureLifetime',false,null]]);
 assert.deepEqual(owner.frames({...world,registry:new Map([[17,{...actor,replicationRemoved:true}]])},message,2,9),[]);
});
test('packed automap touches only supplied bytes and accepts packed mode11',()=>{
 const before=Array(16).fill(1);assert.deepEqual(applyNetworkAutomap(before,{mode:[1,1],bytes:Uint8Array.of(0)},4,4),[...Array(8).fill(0),...Array(8).fill(1)]);assert.deepEqual(before,Array(16).fill(1));
});
test('native decoder consumes both flags before the packed-byte branch',()=>{
 const bytes=[1,0x81],flags=[1,1],reader={byteSize40:100,byteCursor44:0,readObjectIdClient:()=>17,readWord:()=>0x200,readBool:()=>flags.shift(),readByte:()=>bytes.shift()};
 const row=readPlayerState(reader,{number:8193,revision:37,postfix:17});assert.deepEqual(row.state.automap,{mode:[1,1],bytes:Uint8Array.of(0x81)});assert.equal(bytes.length,0);assert.equal(flags.length,0);
});
