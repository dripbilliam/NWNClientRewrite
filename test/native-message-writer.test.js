import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageWriter} from '../src/native_message.js';
const knownHeap=size=>({bytes:new Uint8Array(size).fill(0xa5),defined:new Uint8Array(size).fill(255)});
test('split-stream scalar writing, native growth and finalization match original message bytes',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-message-writer-observations.json',import.meta.url)));assert.equal(data.rows.length,1614);
 for(const row of data.rows){
  const c=row.case,w=new NativeMessageWriter(c.format,{allocate:knownHeap}),observations=[];
  const snapshot=()=>{
   const result=w.getWriteMessage();return{result:result.status,length:result.length,hex:result.data?Buffer.from(result.data).toString('hex'):null,byteLength:w.byteLength14,bitLength:w.bitLength24,bitOffset:w.bitOffset2c,total:w.total28,
    byteCapacity:w.byteStorage.bytes.length,bitCapacity:w.bitStorage.bytes.length,writing:w.writing30,flag:w.flag60,playerId:w.playerId64};
  };
  w.create(c.size??0,0x80000001,c.flag??1);
  for(const [name,value,bits,tag]of c.ops){
   if(name==='create')w.create(value,0x80000001,c.flag??1);
   else if(name==='get')observations.push(snapshot());
   else if(name==='unsigned')w.writeUnsigned(BigInt(value),bits);
   else if(name==='signed')w.writeSigned(BigInt(value),bits);
   else if(name==='bool')w.writeBool(value);
   else if(name==='byte')w.writeByte(value,bits,tag??1);
   else if(name==='word')w.writeWord(value,bits);
   else if(name==='dword')w.writeDword(value,bits);
   else if(name==='int')w.writeInt(value,bits);
   else w.writeFloat(value,bits,tag);
  }
  observations.push(snapshot());assert.deepEqual(observations,row.observations,JSON.stringify(c));
 }
});
test('unknown native envelope/padding bytes remain distinguished from serialized data',()=>{
 const w=new NativeMessageWriter(1);w.create(16,42,1);w.writeDword(0x80000001);w.writeBool(2);
 let result=w.getWriteMessage();assert.equal(result.status,1);assert.equal(result.prefixPending,true);assert.deepEqual([...result.defined.subarray(0,3)],[0,0,0]);
 assert.equal(w.bitOffset2c,4);assert.equal(result.defined.at(-1),240);
 w.setPrefix(Uint8Array.of(1,2,3));result=w.getWriteMessage();assert.equal(result.prefixPending,false);assert.deepEqual([...result.data.subarray(0,3)],[1,2,3]);
 assert.throws(()=>w.writeInt(0,0),/bit width/);assert.throws(()=>w.writeUnsigned(0n,65),/bit width/);
});
