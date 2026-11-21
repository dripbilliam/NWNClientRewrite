import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageReader,NativeMessageWriter} from '../src/native_message.js';
const floatBits=value=>{const v=new DataView(new ArrayBuffer(4));v.setFloat32(0,value,true);return v.getUint32(0,true).toString(16).padStart(8,'0');};
const snapshot=r=>({byteSize:r.byteSize40,byteCursor:r.byteCursor44,fragmentSize:r.fragmentSize50,fragmentCursor:r.fragmentCursor54,fragmentOffset:r.fragmentOffset58,flag:r.flag60>>>0,playerId:r.playerId64,curBit:r.curReadBit5c,lastBits:r.lastByteBits5d});

test('native reader values, diagnostics and cursor states match original reader executions',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-message-reader-observations.json',import.meta.url)));assert.ok(fixture.rows.length>2000);
 for(const [rowIndex,row]of fixture.rows.entries()){
  let diagnostics=[];const r=new NativeMessageReader(row.case.format,{diagnose:value=>diagnostics.push(value)});
  for(const [i,op]of row.case.ops.entries()){
   const [name,a,b,c]=op;let result=null;
   if(name==='set')result=r.setReadMessage(a===null?null:Uint8Array.from(Buffer.from(a,'hex')),b,0x80000001,1);
   else if(name==='overflow')result=r.messageReadOverflow();
   else if(name==='underflow')result=r.messageReadUnderflow();
   else if(name==='expect')r.expectType(a);
   else if(name==='unsigned')result=r.readUnsigned(a).toString();
   else if(name==='signed')result=r.readSigned(a).toString();
   else if(name==='bits')result=r.readBits(a).toString();
   else if(name==='bit')result=r.readBit(a);
   else if(name==='bool')result=r.readBool();
   else if(name==='byte')result=r.readByte(a,b);
   else if(name==='word')result=r.readWord(a);
   else if(name==='dword')result=r.readDword(a);
   else if(name==='dword64')result=r.readDword64(a).toString();
   else if(name==='int')result=r.readInt(a);
   else if(name==='float')result=floatBits(r.readFloat(a,b));
   else if(name==='range')result=floatBits(r.readFloatRange(a,b,c));
   const actual={result,state:snapshot(r),diagnostics};diagnostics=[];
   assert.deepEqual(actual,row.observations[i],JSON.stringify({row:rowIndex,op:i,case:row.case}));
  }
 }
});

test('real split-stream bytes decode independently and unknown native tail reads are diagnosed',()=>{
 const w=new NativeMessageWriter(1);w.create(16,42,1);w.writeInt(-123);w.writeBool(1);w.writeUnsigned(0x123456789an,40);w.writeFloat(1.25);w.setPrefix(Uint8Array.of(80,4,1));
 const packet=w.getWriteMessage(),r=new NativeMessageReader(1);assert.equal(r.setReadMessage(packet.data.subarray(3),packet.length-3,42,0),1);
 assert.equal(r.readInt(),-123);assert.equal(r.readBool(),1);assert.equal(r.readUnsigned(40),0x123456789an);assert.equal(r.readFloat(),1.25);assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);
 // Complete the known fragment byte. The next physical byte is absent even
 // though the native <= comparison permits an attempt at that address.
 r.readBits(4);const diagnostics=[];r.diagnose=value=>diagnostics.push(value);
 assert.throws(()=>r.readBits(1),/physical read byte/);assert.deepEqual(diagnostics,[{kind:'unknownPhysicalByte',index:1,storage:'fragments'}]);
});

test('original binary decodes replacement ClientArea header fields from all five installed Prelude areas',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-message-reader-observations.json',import.meta.url))),live=JSON.parse(fs.readFileSync(new URL('../backups/animations/live-client-area-message.json',import.meta.url)));
 const rows=fixture.rows.filter(row=>row.case.source==='replacement-client-area-header');assert.equal(rows.length,10);assert.equal(live.reports.length,10);
 for(const report of live.reports){
  const row=rows.find(r=>r.case.format===report.formatMode28&&r.case.areaId===report.areaId);assert.ok(row);
  assert.deepEqual(row.observations.map(o=>o.result),[1,report.writes[0][1],...report.writes.slice(1,5).map(w=>floatBits(w[1])),0,0,0]);
  assert.ok(row.observations.every(o=>o.diagnostics.length===0));assert.equal(report.headerDecoded,true);
 }
});
