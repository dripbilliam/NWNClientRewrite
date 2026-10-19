import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageReader} from '../src/native_message.js';
import {readAreaMapPins} from '../src/area_map_pin_reader.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-area-map-pin-observations.json',import.meta.url)));
test('both initial-area map-pin loops match116 original bounded executions, including separate reference namespaces',async()=>{
 assert.equal(data.rows.length,116);
 for(const row of data.rows){
  const c=row.case,trace=[],diagnostics=[],message=new NativeMessageReader(c.format,{diagnose:v=>diagnostics.push(v)}),body=Uint8Array.from(Buffer.from(row.bodyHex,'hex'));message.setReadMessage(body,body.length,42,1);let gender=7;
  const area={pins:[],capacity:0},p={construct:()=>{trace.push(['construct']);return{};},position:(o,v)=>{trace.push(['position',v]);o.position=v;},text:(o,v)=>{const bytes=v.bytes;o.text={hex:bytes?.length?Buffer.from(bytes).toString('hex'):null,length:bytes?.length??0,capacity:bytes?.length?bytes.length+1:0};},
   append:(a,o)=>{if(a.pins.length===a.capacity)a.capacity=a.capacity?2*a.capacity:16;a.pins.push(o);},setGender:g=>{gender=g;},talkString:id=>{trace.push(['talkString',id,gender]);return{status:c.talkStatus??1,bytes:Uint8Array.from(Buffer.from('54616c6b80','hex'))};},warning:site=>trace.push(['warning',site])};
  await readAreaMapPins(message,area,p);
  const pins=area.pins.map(o=>({id:o.nativeReference188,type:o.nativeType18c,enabled:o.nativeEnabled170,position:o.position,text:o.text})),state={byteSize:message.byteSize40,byteCursor:message.byteCursor44,fragmentSize:message.fragmentSize50,fragmentCursor:message.fragmentCursor54,fragmentOffset:message.fragmentOffset58,flag:message.flag60,playerId:message.playerId64,curBit:message.curReadBit5c,lastBits:message.lastByteBits5d};
  assert.deepEqual({pins,trace,state,diagnostics,capacity:area.capacity},{pins:row.pins,trace:row.trace,state:row.state,diagnostics:row.diagnostics,capacity:row.capacity},JSON.stringify(c));
 }
});
