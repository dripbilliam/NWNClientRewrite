import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeServerMessage,NativeMessageReader} from '../src/native_message.js';
import {writeLocalizedServer,playerMessageLanguage,serverMessageLanguage,localizedMessageValue,initializeAreaMessageName} from '../src/native_message_text.js';
import {writeAreaIdentityPrefix} from '../src/area_message_pack.js';
import {decodeGffText} from '../src/gff_text.js';
const knownHeap=size=>({bytes:new Uint8Array(size).fill(0xa5),defined:new Uint8Array(size).fill(255)});
const bytes=hex=>Uint8Array.from(Buffer.from(hex,'hex'));
const state=r=>({byteSize:r.byteSize40,byteCursor:r.byteCursor44,fragmentSize:r.fragmentSize50,fragmentCursor:r.fragmentCursor54,fragmentOffset:r.fragmentOffset58,flag:r.flag60>>>0,playerId:r.playerId64,curBit:r.curReadBit5c,lastBits:r.lastByteBits5d});
const stringState=s=>({hex:s.bytes?Buffer.from(s.bytes).toString('hex'):null,length:s.length,capacity:s.capacity});

test('text, resource references, canonical IDs and localized fallback match complete native writers',async()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-message-text-observations.json',import.meta.url)));assert.equal(fixture.writers.length,1108);
 for(const [index,row]of fixture.writers.entries()){
  const c=row.case,w=new NativeServerMessage(c.format,{allocate:knownHeap}),diagnostics=[];w.create(c.size??0,0x80000001,1);
  if(c.fill)w.writeCResRef(new Uint8Array(c.fill),c.fill);
  let owned=null;
  if(c.kind==='string'){owned={bytes:c.pointer===false?null:bytes(c.hex),length:c.hex.length/2,capacity:c.hex.length/2+1};w.writeCExoString(owned,c.bits);}
  else if(c.kind==='resref')w.writeCResRef(bytes(c.hex),c.count);
  else if(c.kind==='object')w.writeObjectIdServer(c.id);
  else{
   const clients=(c.clients??[{id:0x80000001,language:c.language??0}]).map(v=>({nativePlayerId48:v.id,nativeLanguage4c:v.language}));
   const value={strRef:c.strRef,entries:c.entries.map(e=>({key:e.key,bytes:bytes(e.hex)}))},p={
    server:()=>c.noServer?null:{clients},playerLanguage:(s,id)=>playerMessageLanguage(s.clients,id),serverLanguage:serverMessageLanguage,warning:kind=>diagnostics.push({kind}),
   };
   if(c.kind==='localized')await writeLocalizedServer(w,value,c.gender,p);
   else await writeAreaIdentityPrefix(w,{id:c.id,nativeName188:value,nativeCustomName358:bytes(c.custom),nativeCustomNameLength360:c.custom.length/2},bytes(c.resref),p);
  }
  const result=w.getWriteMessage(),observation={result:result.status,length:result.length,hex:result.data?Buffer.from(result.data).toString('hex'):null,byteLength:w.byteLength14,bitLength:w.bitLength24,bitOffset:w.bitOffset2c,total:w.total28,
   byteCapacity:w.byteStorage.bytes.length,bitCapacity:w.bitStorage.bytes.length,writing:w.writing30,flag:w.flag60,playerId:w.playerId64};
  assert.deepEqual({observation,owned:owned?stringState(owned):null,diagnostics},{observation:row.observation,owned:row.owned,diagnostics:row.diagnostics},JSON.stringify({index,case:c}));
 }
});

test('original text/ResRef/server-ID readers match value ownership, capacity, diagnostics and cursors',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-message-text-observations.json',import.meta.url)));assert.equal(fixture.readers.length,606);
 for(const [index,row]of fixture.readers.entries()){
  const c=row.case,diagnostics=[],r=new NativeMessageReader(c.format,{diagnose:v=>diagnostics.push(v)}),setup=r.setReadMessage(bytes(c.hex),c.length,c.playerId??0x80000001,1);let value;
  if(c.kind==='string')value=stringState(r.readCExoString(c.bits));
  else if(c.kind==='resref')value=Buffer.from(r.readCResRef(c.count,{nativeTail:row.resrefStackSource===null?null:bytes(row.resrefStackSource).subarray(Math.min(16,c.count))})).toString('hex');
  else if(c.kind==='object')value=r.readObjectIdServer();
  else{
   value={id:r.readObjectIdServer(),resref:Buffer.from(r.readCResRef()).toString('hex'),custom:r.readBool(),reference:r.readBool()};
   if(value.reference){value.gender=r.readByte(1);value.strRef=r.readDword();}else value.text=stringState(r.readCExoString());
   assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);
  }
  assert.deepEqual({setup,value,state:state(r),diagnostics},{setup:row.setup,value:row.value,state:row.state,diagnostics:row.diagnostics},JSON.stringify({index,case:c}));
 }
});

test('original readers consume replacement identity bytes from every installed Prelude area',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-message-text-observations.json',import.meta.url))),live=JSON.parse(fs.readFileSync(new URL('../backups/animations/live-message-text.json',import.meta.url)));
 const rows=fixture.readers.filter(row=>row.case.source==='replacement-installed-area-identity');assert.equal(rows.length,10);assert.equal(live.reports.length,10);
 for(const report of live.reports){const row=rows.find(r=>r.case.format===report.format&&r.case.areaId===report.areaId);assert.ok(row);assert.deepEqual(row.value,report.value);assert.deepEqual(row.diagnostics,[]);}
});

test('localized adapter preserves all Western GFF bytes without inserting Unicode encoding into messages',()=>{
 const raw=Uint8Array.from({length:256},(_,i)=>(i+1)&255),value=localizedMessageValue({strRef:0xffffffff,entries:[{languageId:7,text:decodeGffText(raw)}]});
 assert.deepEqual(value,{strRef:0xffffffff,entries:[{key:7,bytes:raw}]});
 assert.throws(()=>localizedMessageValue({strRef:123,entries:[{languageId:0,text:'😀'}]}),/cannot be saved/);
 assert.throws(()=>playerMessageLanguage([{nativePlayerId48:42}],42),/language is unavailable/);
 const area={};initializeAreaMessageName(area,{});assert.deepEqual(area,{nativeName188:{strRef:0xffffffff,entries:[]},nativeCustomName358:null,nativeCustomNameLength360:0});
});

test('GFF localized import matches original key normalization, duplicate replacement and append order',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-message-text-observations.json',import.meta.url)));assert.equal(fixture.imports.length,88);
 for(const row of fixture.imports){
  const actual=localizedMessageValue({strRef:row.case.strRef,entries:row.case.entries.map(e=>({languageId:e.key,text:decodeGffText(bytes(e.hex))}))});
  assert.deepEqual({strRef:actual.strRef,entries:actual.entries.map(e=>({key:e.key,hex:Buffer.from(e.bytes).toString('hex')}))},row.value,JSON.stringify(row.case));
 }
});

test('resource references never invent uncopied stack bytes',()=>{
 const w=new NativeServerMessage(1);w.create(0,42,1);w.writeCResRef(Uint8Array.of(65),1);const packet=w.getWriteMessage(),diagnostics=[],r=new NativeMessageReader(1,{diagnose:v=>diagnostics.push(v)});
 r.setReadMessage(packet.data.subarray(3),packet.length-3,42,1);
 assert.throws(()=>r.readCResRef(1),/stack byte/);assert.deepEqual(diagnostics,[{kind:'unknownResRefStackByte',index:1}]);
});
