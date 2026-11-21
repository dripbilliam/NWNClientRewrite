import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageReader} from '../src/native_message.js';
import {readLocalizedClient} from '../src/native_message_text.js';

test('client raw IDs and localized-string TLK/optional outputs match312 original executions',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-message-identity-observations.json',import.meta.url)));assert.equal(data.rows.length,312);
 for(const row of data.rows){
  const c=row.case,diagnostics=[],reader=new NativeMessageReader(c.format,{diagnose:value=>diagnostics.push(value)}),bytes=Uint8Array.from(Buffer.from(row.bodyHex,'hex')),trace=[];
  reader.setReadMessage(bytes,bytes.length,42,1);let value,gender=7;
  if(c.kind==='object'){
   if(Object.hasOwn(c,'cursor'))reader.byteCursor44=c.cursor;
   if(Object.hasOwn(c,'declared'))reader.byteSize40=c.declared;
   value={id:reader.readObjectIdClient()};
  }else{
   const soundRef=c.soundOut?{value:new Uint8Array(17).fill(0xa5)}:null,duration=c.durationOut?{value:99}:null;
   const result=await readLocalizedClient(reader,{setGender:g=>{gender=g;},talkString:id=>{trace.push(['talkString',id,gender]);return{status:c.status,bytes:Uint8Array.from(Buffer.from(c.text,'hex')),soundRef:Uint8Array.from(Buffer.from(c.soundRef,'hex')),duration:c.duration};},warning:site=>trace.push(['warning',site])},{soundRef,duration});
   value={hex:result.bytes?Buffer.from(result.bytes).toString('hex'):null,length:result.length,capacity:result.capacity,soundRef:soundRef?Buffer.from(soundRef.value).toString('hex'):null,duration:duration?.value??null};
  }
  const state={byteSize:reader.byteSize40,byteCursor:reader.byteCursor44,fragmentSize:reader.fragmentSize50,fragmentCursor:reader.fragmentCursor54,fragmentOffset:reader.fragmentOffset58,flag:reader.flag60,playerId:reader.playerId64,curBit:reader.curReadBit5c,lastBits:reader.lastByteBits5d};
  assert.deepEqual({value,state,trace,gender,diagnostics},{value:row.value,state:row.state,trace:row.trace,gender:row.gender,diagnostics:row.diagnostics},JSON.stringify(c));
 }
});
