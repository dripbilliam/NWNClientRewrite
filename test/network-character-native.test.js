import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {characterBlobRequest} from '../src/network_character.js';
import {decodeServerGameMessage,moduleReadyRequest} from '../src/network_game_messages.js';
import {NetworkMessageAssembler} from '../src/network_messages.js';
import {NetworkMessageInflater} from '../electron/network_message_inflater.mjs';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-character-observations.json',import.meta.url)));

test('character upload matches original scalar writer and exact native admission blob ABI',()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of native.cases){
  const source=Buffer.from(row.blob,'hex'),wire=characterBlobRequest(source,{subtype:row.subtype}),expected=Buffer.from(row.packet,'hex');
  assert.equal(wire.length,expected.length);for(let i=0;i<wire.length;i++){const mask=i===wire.length-1?224:255;assert.equal(wire[i]&mask,expected[i]&mask);}
  assert.equal(row.calls[0].size,source.length);assert.equal(row.calls[0].blob,row.blob);source.fill(0);assert.notEqual(wire[11],0);
 }
 assert.throws(()=>characterBlobRequest(new Uint8Array(),{subtype:1}),/upload/);assert.throws(()=>characterBlobRequest(Uint8Array.of(1),{subtype:2}),/upload/);
});

test('real native character confirmation, module information, IDs and persistent compression decode',async()=>{
 const report=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-character-v2.json',import.meta.url))),assembler=new NetworkMessageAssembler(),inflater=new NetworkMessageInflater(),decoded=[];
 for(const hex of report.transport.applicationFrames)assembler.push(Buffer.from(hex,'hex'));
 try{for(const message of assembler.drain())decoded.push(decodeServerGameMessage(await inflater.decode(message.bytes),{clientBuild:report.clientBuild}));}finally{inflater.close();}
 assert.equal(report.transport.resources.ready,true);assert.equal(report.transport.character.confirmed,true);assert.equal(report.transport.moduleReadyRequested,true);
 assert.ok(decoded.some(m=>m.kind==='character-confirmed'));const module=decoded.find(m=>m.kind==='module-info').module;
 assert.equal(module.resourceName,'Prelude');assert.equal(module.entryArea,'prelude');assert.equal(module.areas.length,5);
 assert.equal(module.minutesPerHour,2);
 assert.equal(module.areas[0].id,0x80000001);assert.ok(module.areas.every(a=>a.id>0x7fffffff&&a.id<=0xffffffff));
 assert.ok(decoded.some(m=>m.major===4&&m.minor===1));assert.ok(decoded.some(m=>m.major===5&&m.minor===1));
 assert.deepEqual([...moduleReadyRequest()],[112,3,2]);
 assert.ok(!report.diagnostics.some(d=>/compression|invalid/.test(d.code)));
});
