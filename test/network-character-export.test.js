import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {EventEmitter} from 'node:events';
import {NativeMessageWriter} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {characterExportRequest} from '../src/network_character.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
const bic=()=>writeGff('BIC ',gffRecord({EffectList:gffField(15,[gffRecord({Type:gffField(3,40)})])}));
function reply(data,length=data.length){const w=new NativeMessageWriter(1);w.create(data.length+32,0xffffffff,1);for(const name of ['Export','Hero']){w.writeBool(0);w.writeStringBytes(new TextEncoder().encode(name));}w.writeDword(length);w.writeOpaqueBytes(data);w.setPrefix(Uint8Array.of(80,3,10));return Uint8Array.from(w.getWriteMessage().data);}
test('original export request and ten real native format1 writer cases preserve localized names and every opaque byte',()=>{
 const o=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-character-export-wire-observations.json',import.meta.url)));assert.equal(o.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(o.rows.length,20);
 for(const row of o.rows){assert.deepEqual([...characterExportRequest()],row.request);if(row.case.format!==1)continue;const p=Buffer.from(row.body.hex,'hex');p.set([80,3,10]);const v=decodeServerGameMessage(p);assert.equal(Buffer.from(v.data).toString('hex'),row.payload);assert.deepEqual(v.firstName,row.case.localized?{text:'Native €é'}:{gender:0,strRef:123});assert.deepEqual(v.lastName,row.case.localized?{text:'Export'}:{gender:0,strRef:456});}
});
test('export decoding rejects truncated, oversized and trailing streams without interpreting a name as a path',()=>{
 const data=bic(),p=reply(data);for(const n of [...Array.from({length:Math.min(28,p.length)},(_,i)=>i),p.length-2])assert.throws(()=>decodeServerGameMessage(p.subarray(0,n)));assert.throws(()=>decodeServerGameMessage(reply(data,0xffffffff)));assert.throws(()=>decodeServerGameMessage(Buffer.concat([p,Buffer.from([0,0])])));assert.deepEqual(decodeServerGameMessage(p).data,data);
});
function harness(persistCharacter,timeout=1000){const peer=new EventEmitter(),sent=[],messages=[],diagnostics=[];peer.sendGameMessage=async b=>sent.push([...b]);peer.disconnect=async()=>peer.emit('closed');const s=new NetworkGameSession({peer,identity:{dispose(){}},build:{dispose(){}},resources:{},openModule:async()=>null,language:0,persistCharacter,characterExportTimeoutMs:timeout,onDiagnostic:d=>diagnostics.push(d)});s.phase='playing';s.characterConfirmed=true;s.on('message',e=>messages.push(e));return{s,peer,sent,messages,diagnostics,deliver:async p=>{peer.emit('message',p);await s.delivery;}};}
test('session coalesces export clicks and waits for durable storage; only metadata reaches the renderer',async()=>{
 let commit,seen;const h=harness(async m=>{seen=Uint8Array.from(m.data);await new Promise(r=>commit=r);return{id:'saved',name:'Export Hero'};}),before=h.s.world.snapshot(),a=h.s.exportCharacter();assert.strictEqual(h.s.exportCharacter(),a);await Promise.resolve();assert.deepEqual(h.sent,[[112,6,31]]);
 const packet=reply(bic()),delivery=h.deliver(packet);await new Promise(r=>setImmediate(r));assert.deepEqual(seen,bic());let done=false;a.then(()=>done=true);await Promise.resolve();assert.equal(done,false);commit();assert.deepEqual(await a,{id:'saved',name:'Export Hero'});await delivery;assert.equal(h.messages[0].message.kind,'character-saved');assert.equal('data'in h.messages[0].message,false);assert.deepEqual(h.s.world.snapshot(),before);assert.deepEqual(decodeServerGameMessage(packet).data,bic());await h.s.disconnect();
});
test('save failure leaves the session live and allows a fresh authoritative retry',async()=>{
 let fail=true;const h=harness(async()=>{if(fail)throw Error('disk full');return{id:'ok'};});const p=h.s.exportCharacter(),rejected=assert.rejects(p,/disk full/);await h.deliver(reply(bic()));await rejected;assert.equal(h.s.closed,false);assert.equal(h.diagnostics.at(-1).code,'network.character-save-failed');fail=false;const next=h.s.exportCharacter();await h.deliver(reply(bic()));assert.deepEqual(await next,{id:'ok'});await h.s.disconnect();
});
test('timeout cannot let an old reply satisfy a later request, and closure rejects a pending save',async()=>{
 const h=harness(async()=>({id:'late'}),10);await assert.rejects(h.s.exportCharacter(),/Timed out/);assert.throws(()=>h.s.exportCharacter(),/previous character export/);assert.equal(h.s.closed,false);await h.deliver(reply(bic()));assert.equal(h.s.savedCharacter.id,'late');const pending=h.s.exportCharacter(),rejected=assert.rejects(pending,/Connection closed/);await h.s.disconnect();await rejected;
});
