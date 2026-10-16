import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeServerMessage,NativeMessageReader,nativeMessageProviders,sendServerToPlayerMessage} from '../src/native_message.js';
import {sendClientArea,setAreaTransitionBmp} from '../src/client_area_message.js';
import {nativeAtan2f} from '../src/native_math.js';

test('outgoing prefix, logging, player state, raw send result and temporary cleanup match original owner',async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-message-send-observations.json',import.meta.url)));assert.equal(fixture.rows.length,240);
 for(const row of fixture.rows){
  const c=row.case,trace=[],message={role68:c.role,playerId64:123},packet=new Uint8Array(16).fill(0xa5),server={},net={},temp=new Uint8Array(3).fill(0xa5),p={
   messageName:(major,minor)=>{trace.push(['name',major,minor]);return'fixture';},log:({role,playerId,name,length})=>trace.push(['log',role,playerId,name==='fixture',length]),
   allocate:size=>{trace.push(['allocate',size]);return c.allocationFails?null:temp;},free:data=>trace.push(['free',data===temp]),server:()=>server,
   netLayer:s=>{trace.push(['netLayer',s===server]);return net;},send:(n,id,data,length,flag)=>{trace.push(['send',n===net,id,Buffer.from(data.subarray(0,length)).toString('hex'),length,flag]);return c.sendReturn;},
  };
  const result=await sendServerToPlayerMessage(message,c.playerId,c.major,c.minor,c.nullData?null:packet,c.length,p);
  assert.deepEqual({result,trace,playerId64:message.playerId64,packet:Buffer.from(packet).toString('hex')},{result:row.result,trace:row.trace,playerId64:row.playerId64,packet:row.packet},JSON.stringify(c));
 }
});

test('ClientArea coordinator uses real scalar streams and envelope with captured unfinished area pack boundary',async()=>{
 for(const mode of [0,1]){
  const message=new NativeServerMessage(mode),client={nativePlayerId48:42,nativeAreaTransitionBmp20:2},area={},entry={float14:3.9,float18:-2.9,float1c:0},point=[1.25,2.5,3.75],orientation=[.3,.9,0];
  let captured,packed;
  const sendOwners={messageName:()=> 'Area/ClientArea',log:()=>{},server:()=>({}),netLayer:s=>s,send:(_n,id,data,length,flag)=>{captured={id,data:data.slice(0,length),flag};return 7;}};
  const p={...nativeMessageProviders(sendOwners),module:()=>({nativeField108:entry}),serverMode:()=>2,clientObject:()=>({}),setBmp:setAreaTransitionBmp,loadingCount:()=>10,
   packArea:(a,x,y,z,c)=>{packed=[a,x,y,z,c];return 1;},
  };
  assert.equal(await sendClientArea(message,client,area,point,orientation,-2,p),7);assert.deepEqual(packed,[area,3,-2,0,client]);assert.equal(captured.id,42);assert.equal(captured.flag,0);
  assert.deepEqual([...captured.data.subarray(0,3)],[80,4,1]);assert.equal(message.getWriteMessage().prefixPending,false);
  const reader=new NativeMessageReader(mode);assert.equal(reader.setReadMessage(captured.data.subarray(3),captured.data.length-3,42,1),1);
  assert.equal(reader.readInt(),2);for(const v of [...point,nativeAtan2f(orientation[1],orientation[0])])assert.equal(reader.readFloat(),Math.fround(v));
  assert.equal(reader.readBool(),0);assert.equal(reader.messageReadOverflow(),0);assert.equal(reader.messageReadUnderflow(),0);
 }
});

test('sending does not invent physical packet bytes or a message role',async()=>{
 await assert.rejects(sendServerToPlayerMessage({},42,4,1,new Uint8Array(8),8,{}),/sender role/);
 const p={messageName:()=>'',log:()=>{}};
 await assert.rejects(sendServerToPlayerMessage({role68:1},42,4,1,new Uint8Array(2),1,p),/physical storage/);
 await assert.rejects(sendServerToPlayerMessage({role68:1},42,4,1,new Uint8Array(4),8,p),/physical storage/);
});
