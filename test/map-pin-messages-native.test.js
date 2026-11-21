import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeServerMessage,NativeMessageReader} from '../src/native_message.js';
import {playerMessageLanguage,serverMessageLanguage} from '../src/native_message_text.js';
import {sendMapPinCreated,sendMapPinEnabled,receiveMapPinCreated,receiveMapPinEnabled,findMapPin,receiveMapPin} from '../src/map_pin_messages.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-map-pin-message-observations.json',import.meta.url)));
const bytes=hex=>Uint8Array.from(Buffer.from(hex,'hex')),hex=value=>value?Buffer.from(value).toString('hex'):null;

test('complete Created/Enabled senders match670 original executions including language, disposal and failure paths',async()=>{
 assert.equal(data.senders.length,670);
 for(const row of data.senders){
  const c=row.case,diagnostics=[],trace=[],message=new NativeServerMessage(c.format,{allocate:size=>({bytes:new Uint8Array(size).fill(0xa5),defined:new Uint8Array(size).fill(255)})});let packetHex=null;
  const clients=(c.clients??[{id:0x80000001,language:c.language??0}]).map(v=>({nativePlayerId48:v.id,nativeLanguage4c:v.language}));
  const p={create:(m,...args)=>m.create(...args),writeObject:(m,id)=>m.writeObjectIdServer(id),writeFloat:(m,...args)=>m.writeFloat(...args),writeBool:(m,v)=>m.writeBool(v),
   server:()=>c.noServer?null:{},playerLanguage:(_s,id)=>playerMessageLanguage(clients,id),serverLanguage:serverMessageLanguage,warning:kind=>diagnostics.push({kind}),
   payload:m=>c.payloadFail?{status:0}:m.getWriteMessage(),send:(_m,id,major,minor,packet,length)=>{packetHex=hex(packet);trace.push(['send',id,major,minor,length]);return c.sendResult;},disposeLocalized:()=>trace.push(['disposeLocalized'])};
  const note={strRef:c.strRef,entries:c.entries.map(e=>({key:e.key,bytes:bytes(e.hex)}))},client={nativePlayerId48:c.playerId};
  const result=await(c.kind==='created'?sendMapPinCreated(message,client,c.id,c.point,note,c.enabled,p):sendMapPinEnabled(message,client,c.id,c.enabled,p));
  assert.deepEqual({result:result>>>0,packetHex,trace,diagnostics},{result:row.result,packetHex:row.packetHex,trace:row.trace,diagnostics:row.diagnostics},JSON.stringify(c));
 }
});

test('complete client Created/Enabled handlers match148 original executions and first duplicate lookup',async()=>{
 assert.equal(data.receivers.length,148);
 for(const row of data.receivers){
  const c=row.case,trace=[],diagnostics=[],message=new NativeMessageReader(c.format,{diagnose:value=>diagnostics.push(value)}),body=bytes(row.bodyHex);message.setReadMessage(body,body.length,42,1);
  if(c.declaredDelta)message.byteSize40=(message.byteSize40+c.declaredDelta)>>>0;
  if(c.overflow)message.messageReadOverflow=()=>{trace.push(['overflow']);return 1;};if(c.underflow)message.messageReadUnderflow=()=>{trace.push(['underflow']);return 1;};
  const area={nativeMapPins2b8:(c.initial??[]).map(o=>o?{nativeReference188:o.id,nativeType18c:o.type,nativeEnabled170:o.enabled}:null),capacity:c.initial?.length??0};let gender=7;
  const p={area:()=>{trace.push(['area']);return area;},construct:()=>{trace.push(['construct']);return{};},position:(o,v)=>{trace.push(['position',v]);o.position=v;},text:(o,v)=>{o.text=v;},
   append:(a,o)=>{if(a.nativeMapPins2b8.length===a.capacity)a.capacity=a.capacity?2*a.capacity:16;a.nativeMapPins2b8.push(o);},find:findMapPin,
   gui:()=>{trace.push(['gui']);return c.gui&&c.control?{}:null;},refresh:(_g,v)=>trace.push(['refresh',v]),setGender:g=>{gender=g;},
   talkString:id=>{trace.push(['talkString',id,gender]);return{status:c.talkStatus??1,bytes:bytes(c.talkText??'54616c6b80')};},warning:kind=>trace.push(['warning',kind])};
  const result=await(c.kind==='created'?receiveMapPinCreated(message,p):receiveMapPinEnabled(message,p)),pins=area.nativeMapPins2b8.map((o,i)=>{
   if(!o)return null;const v={id:o.nativeReference188,type:o.nativeType18c,enabled:o.nativeEnabled170};if(c.kind==='created'&&i>=(c.initial?.length??0))Object.assign(v,{position:o.position,text:{hex:hex(o.text.bytes),length:o.text.length,capacity:o.text.capacity}});return v;
  });
  const state={byteSize:message.byteSize40,byteCursor:message.byteCursor44,fragmentSize:message.fragmentSize50,fragmentCursor:message.fragmentCursor54,fragmentOffset:message.fragmentOffset58,flag:message.flag60,playerId:message.playerId64,curBit:message.curReadBit5c,lastBits:message.lastByteBits5d};
  assert.deepEqual({result,pins,trace,state,diagnostics,capacity:area.capacity},{result:row.result,pins:row.pins,trace:row.trace,state:row.state,diagnostics:row.diagnostics,capacity:row.capacity},JSON.stringify(c));
 }
});

test('map dispatch rejects unsupported minors and forwards reference-number owner',async()=>{
 const trace=[],p={referenceNumber:m=>{trace.push(m);return 7;}};
 for(let minor=0;minor<256;minor++)if(![1,4,6].includes(minor))assert.equal(await receiveMapPin(null,minor,p),0);
 assert.equal(await receiveMapPin('message',4,p),7);assert.deepEqual(trace,['message']);
});

test('complete native senders require a transport PLAYER_ID instead of substituting a canonical object ID',async()=>{
 const message=new NativeServerMessage(1),p={create:(m,...args)=>m.create(...args),writeObject:(m,id)=>m.writeObjectIdServer(id),writeBool:(m,v)=>m.writeBool(v),payload:m=>m.getWriteMessage(),send:()=>assert.fail('No transport send is authorized without PLAYER_ID')};
 await assert.rejects(()=>sendMapPinEnabled(message,{object:{id:123}},7,1,p),/recipient PLAYER_ID is unavailable/);
});
