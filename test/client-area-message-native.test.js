import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {sendClientArea,setAreaTransitionBmp,sameTilesetName} from '../src/client_area_message.js';
test('ClientArea loading screens, write order and failure gates match 606 original sender executions',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-area-message-observations.json',import.meta.url)));assert.equal(data.rows.length,606);
 for(const row of data.rows){
  const c=row.case,calls=[],client={nativeAreaTransitionBmp20:c.bmp,nativeUserTransitionBmp28:'custom',nativePlayerId48:42,nativeLastUpdateObjectA8:c.lastMap===false?null:{}},area={nativeLoadScreenId350:c.defaultBmp},message={},module={nativeField108:Object.fromEntries(['float14','float18','float1c'].map((key,i)=>[key,(c.packFloats??[2.9,-3.9,4.1])[i]]))};let randoms=0;
  const p={
   module:()=>{calls.push(['module']);return c.module===false?null:module;},serverMode:()=>{calls.push(['mode']);return c.mode??2;},clientObject:()=>{calls.push(['clientObject']);return c.object===false?null:{};},
   clearLastMap:()=>calls.push(['clearLastMap']),create:(_m,...args)=>calls.push(['create',...args]),
   setBmp:(o,value,text)=>{calls.push(['setBmp',value,text]);setAreaTransitionBmp(o,value,text);},loadingCount:()=>c.rows.length,tileset:()=>c.tileset,
   loadingString:(row,column)=>{calls.push(['loadingString',row,column]);const entry=(column==='TILESET'?(c.secondRows??c.rows):c.rows)[row];return{status:entry.status??1,value:entry.value??''};},
   random:()=>{calls.push(['random']);return c.random[Math.min(randoms++,c.random.length-1)];},warning:site=>calls.push(['warning',site]),
   writeInt:(_m,...args)=>calls.push(['writeInt',...args]),writeFloat:(_m,...args)=>calls.push(['writeFloat',...args]),writeBool:(_m,...args)=>calls.push(['writeBool',...args]),
   packArea:(_a,...args)=>{calls.push(['packArea',...args.slice(0,3)]);return c.pack??1;},payload:()=>{calls.push(['payload']);return{status:c.payload??1,data:[1,2,3],length:3};},
   send:(_m,...args)=>{calls.push(['send',...args]);return c.send??1;},
  };
  const result=await sendClientArea(message,client,c.area===false?null:area,c.point??[1.1,-2.2,3.3],c.orientation??[1,0,0],c.flag??-2,p);
  assert.deepEqual({calls,result,bmp:client.nativeAreaTransitionBmp20,user:client.nativeUserTransitionBmp28},{calls:row.calls,result:row.result,bmp:row.bmp,user:row.user},JSON.stringify(c));
 }
});
test('unsupported loading-screen table/locale state is explicit',async()=>{
 assert.equal(sameTilesetName('tni01','TNI01'),true);assert.equal(sameTilesetName('tni01','tni01 '),false);
 assert.throws(()=>sameTilesetName('é','É'),/unavailable/);
 const client={nativePlayerId48:42,nativeAreaTransitionBmp20:0},p={module:()=>({}),serverMode:()=>2,clientObject:()=>({}),create:()=>{},loadingCount:()=>2,tileset:()=>''};
 await assert.rejects(sendClientArea({},client,{},[0,0,0],[1,0,0],0,p),/divides by zero/);
});
