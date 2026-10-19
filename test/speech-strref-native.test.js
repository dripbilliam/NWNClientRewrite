import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {scriptSpeakStrRef,executeSpeakStrRef,sendChatStrRef,sendChatStrRefPacket,writeChatStrRef} from '../src/speech_strref.js';
import {NativeServerMessage,NativeMessageReader} from '../src/native_message.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {GameUi} from '../src/game_ui.js';
import {GameText} from '../src/talk_table.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-speech-strref-observations.json',import.meta.url)));
test('client speech log resolves current talk-table data and records unavailable references',()=>{
 const ui={text:new GameText({base:{get:id=>id===12345?'Authored speech':undefined}}),messages:[],updateLog(){},notify(){}},begin=runtimeDiagnostics.records.length;
 GameUi.prototype.message.call(ui,{type:'speech-reference',strRef:12345,actorId:42,channel:8},'talk');assert.deepEqual(ui.messages,[{text:'Authored speech',type:'talk'}]);
 GameUi.prototype.message.call(ui,{type:'speech-reference',strRef:12346,actorId:42,channel:8},'talk');assert.equal(ui.messages.length,1);assert.ok(runtimeDiagnostics.records.slice(begin).some(r=>r.code==='speech.reference-unavailable'));
});
test('script speech and queued action33 match original wrappers including exclusions, raw statuses, commandability and cast order',async()=>{
 for(const row of native.rows.filter(r=>['script','action'].includes(r.case.mode))){const c=row.case,actor={id:42,nativeFieldEc:c.commandable},calls=[];let casts=0;
  const p={active:c.active,lookup:()=>({object:actor,status:c.status}),asObject:()=>{casts++;return c.object?actor:null;},asCreature:()=>{casts++;return c.creature?actor:null;},
   add:(_o,id,group,parameters)=>calls.push(['add',id,group,parameters[0].type,parameters[0].value|0,parameters[1].type,parameters[1].value|0]),send:(channel,id,ref)=>{calls.push(['send',channel,id,ref]);return c.sendResult;},
   activityManager:(_o,n)=>calls.push(['activityManager',n]),setActivity:(_o,mask,v)=>calls.push(['activity',mask,v])};
  if(c.mode==='script'){if(!c.pop1||!c.pop2){assert.equal(row.result,0xfffffd81);assert.deepEqual(row.calls,[]);continue;}await scriptSpeakStrRef(c.command,42,c.strRef,c.volume,p);assert.equal(row.result,0);}
  else assert.equal(await executeSpeakStrRef(actor,{parameterData:[c.strRef,c.channel]},p),row.result);
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(casts,row.casts,JSON.stringify(c));
 }
});
test('native radius/shout recipient coordinator preserves FLOAT boundaries, area identity, low-byte status and sends after failure',async()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='sender')){const c=row.case,actor={position:[0,0,0]},viewer={position:[c.point[0],c.point[2],c.point[1]]},a={},b={},clients=[{playerId:100},{playerId:101}],calls=[];let casts=0;
  const result=await sendChatStrRef(c.channel,42,c.strRef,{lookup:()=>({object:actor,status:c.status}),asObject:()=>{casts++;return c.object?actor:null;},area:o=>c.nullArea?null:o===actor||c.sameArea?a:b,players:()=>clients.slice(0,c.count),clientObject:()=>c.missingViewer?null:viewer,
   send:(client,id,channel,ref,special)=>{calls.push(['packet',client?.playerId??special,id,channel,ref]);return calls.length===1?c.sendResult:c.sendResult2;}});
  assert.equal(result>>>0,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(casts,row.casts);
 }
});
test('protected strref packet coordinator matches native call order, channel narrowing and payload/send failure results',async()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='packet')){const c=row.case,calls=[],result=await sendChatStrRefPacket({},100,42,c.channel,c.strRef,{create:(_m,...args)=>calls.push(['create',...args]),writeObject:(_m,id)=>calls.push(['object',id]),writeDword:(_m,...args)=>calls.push(['dword',...args]),payload:()=>({status:c.payloadStatus,data:new Uint8Array(17),length:17}),send:(_m,id,major,minor,_bytes,length)=>{calls.push(['transport',id,major,minor,length]);return c.sendResult;}});assert.equal(result>>>0,row.result);assert.deepEqual(calls,row.calls);}
 assert.equal(native.rows.length,5084);
 // Integration of the existing separately native-tested scalar codec. This
 // roundtrip is not an independent original client receiver oracle.
 const m=new NativeServerMessage(1),payload=await writeChatStrRef(m,42,0xffffffff,{create:(m,...a)=>m.create(...a),writeObject:(m,id)=>m.writeObjectIdServer(id),writeDword:(m,...a)=>m.writeDword(...a),payload:m=>m.getWriteMessage()}),reader=new NativeMessageReader(1),body=payload.data.slice(3,payload.length);
 assert.equal(reader.setReadMessage(body,body.length,OBJECT_INVALID,1),1);assert.equal(reader.readObjectIdClient(),0x8000002a);assert.equal(reader.readDword(),0xffffffff);
});
