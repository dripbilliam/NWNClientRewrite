import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import {NativeMessageWriter} from '../src/native_message.js';import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {chatRequest} from '../src/network_chat_input.js';
import {decodeGffText} from '../src/gff_text.js';
const build={number:8193,revision:37,postfix:17},decode=p=>decodeServerGameMessage(p,{clientBuild:build});
test('one-liner fields decode complete original4d31c0 packets and retain exact IDs, sound and localization',()=>{
 const o=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-speech-observations.json',import.meta.url)));assert.equal(o.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(o.cases.length,64);for(const r of o.cases.filter(r=>r.case.format===1)){const v=decode(Uint8Array.from(Buffer.from(r.packet,'hex')));assert.equal(v.channel,r.case.oneLiner?12:11);assert.equal(v.objectId,0x80000013);assert.equal(v.contextId,0xffffffff);assert.equal(v.soundObjectId,0xffffffff);assert.equal(v.sound,r.case.sound);assert.equal(v.soundFlag,r.case.soundFlag);if(v.text.text!==undefined)assert.equal(v.text.text,'Native custom line');else{assert.equal(v.text.strRef,57779);assert.equal(v.text.gender,r.case.gender);}}
});
test('plain server text has no invented source or gameplay changes and truncated messages reject',()=>{
 const w=new NativeMessageWriter(1);w.create(20,0xffffffff,1);w.writeStringBytes(new TextEncoder().encode('Server-owned feedback'));w.setPrefix(Uint8Array.of(80,9,5));const p=Uint8Array.from(w.getWriteMessage().data),v=decode(p);assert.equal(v.text.text,'Server-owned feedback');assert.equal(v.objectId,undefined);for(const n of [0,3,p.length-2])assert.throws(()=>decode(p.subarray(0,n)));
});
test('real campaign capture contains the NPC one-liner pointing to Bim and valid empty control lines',()=>{
 const c=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-progression-v102.json',import.meta.url))),rows=c.wireMessages.filter(h=>h.startsWith('50090c')||h.startsWith('500905')).map(h=>decode(Uint8Array.from(Buffer.from(h,'hex'))));assert.ok(rows.some(v=>v.text.strRef===57779&&v.objectId===0x80000013));assert.ok(rows.some(v=>v.text.text===''));assert.ok(rows.some(v=>v.channel===5&&v.text.text.includes('PVP')));
});

test('96 complete native server chat writer cases preserve strings, source IDs, names and position',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-chat-writer-observations.json',import.meta.url)));assert.equal(oracle.cases.length,96);assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');let checked=0;
 for(const row of oracle.cases.filter(r=>r.case.format===1))for(const hex of row.packets){
  const value=decode(Buffer.from(hex,'hex')),c=row.case;checked++;
  if(c.kind==='strref'){assert.equal(value.text.strRef,57779);assert.equal(value.channel,c.channel);assert.equal(value.objectId,0x80000013);continue;}
  assert.equal(value.text.text,'Native chat €é <unsafe>');
  if(['shout','tell','party'].includes(c.kind)||c.kind.startsWith('dm-')){
   if(c.nameMode==='missing'){assert.equal(value.objectId,0x7f000000);assert.deepEqual(value.position,[0,0,0]);assert.equal(value.speakerName.firstName.strRef,67458);}
   else{assert.equal(value.objectId,0x80000013);assert.deepEqual(value.position,[12.25,-3.5,1.125]);if(c.nameMode==='custom')assert.equal(value.speakerName.text,'Renamed Speaker');else if(c.nameMode==='localized')assert.deepEqual(value.speakerName,{firstName:{text:'Remote'},lastName:{text:'Speaker'}});else assert.deepEqual(value.speakerName,{firstName:{gender:0,strRef:123},lastName:{gender:0,strRef:456}});}
  }else{assert.equal(value.objectId,0x80000013);assert.equal(value.speakerName,undefined);}
 }
 assert.equal(checked,43);
});

test('all seven complete original client chat senders match native-compatible requests byte for byte',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-chat-input-observations.json',import.meta.url)));assert.equal(oracle.cases.length,80);assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of oracle.cases.filter(r=>r.format===1)){
  const channel={talk:1,shout:2,whisper:3,party:6,dm:14,'tell-id':4,'tell-name':4}[row.kind],request={channel,text:decodeGffText(Buffer.from(row.textHex,'hex'))};if(row.kind==='tell-id')request.playerId=row.recipient;else if(row.kind==='tell-name')request.recipient=row.recipient;
  // The original fixture's allocator fills unowned padding with0xa5. Only
  // defined wire bits must agree; the reader deliberately ignores that tail.
  const native=Buffer.from(row.packet,'hex'),actual=Buffer.from(chatRequest(request)),boundary=native.readUInt32LE(3),used=native[boundary]>>>5;if(used){const mask=(255<<(8-used))&255;native[native.length-1]&=mask;actual[actual.length-1]&=mask;}
  assert.deepEqual(actual,native,JSON.stringify(row));
 }
});

test('malformed positional/name chat fails closed and invalid outgoing requests do not serialize',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-chat-writer-observations.json',import.meta.url)));
 for(const row of oracle.cases.filter(r=>r.case.format===1))for(const hex of row.packets){const p=Buffer.from(hex,'hex');for(let n=3;n<p.length;n++)assert.throws(()=>decode(p.subarray(0,n)),`truncated ${row.case.kind} ${n}`);assert.throws(()=>decode(Buffer.concat([p,Buffer.from([0,0])])));}
 for(const request of [{channel:5,text:'forged server message'},{channel:1,text:'x',playerId:7},{channel:4,text:'x'},{channel:4,text:'x',playerId:-1},{channel:4,text:'x',playerId:0x100000000},{channel:4,text:'x',playerId:1,recipient:'name'},{channel:1,text:'x\0y'}])assert.throws(()=>chatRequest(request));
});
