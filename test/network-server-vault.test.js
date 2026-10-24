import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {serverCharacterListRequest,serverCharacterPreviewRequest,serverCharacterPlayRequest} from '../src/network_character_selection.js';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {writeGff,gffRecord} from '../src/gff_writer.js';
import {NativeMessageWriter} from '../src/native_message.js';
import {serverCharacterPreviewSummary} from '../src/network_character_preview.js';
const observed=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-server-vault-observations.json',import.meta.url)));
test('server list fields decode original instruction-produced wire fixtures',()=>{
 assert.equal(observed.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const row of observed.lists){const decoded=decodeServerGameMessage(Buffer.from(row.packet,'hex'));assert.equal(decoded.kind,'server-character-list');assert.equal(decoded.characters.length,row.characters.length);for(const [i,wanted]of row.characters.entries()){const got=decoded.characters[i];assert.deepEqual(got.firstName,typeof wanted.firstName==='number'?{gender:0,strRef:wanted.firstName}:{text:wanted.firstName});assert.equal(got.lastName.text,wanted.lastName);for(const key of ['source','resref','portrait','portraitRef','classes'])assert.deepEqual(got[key],wanted[key]);}}
 for(const row of observed.lists)for(let length=3;length<Buffer.from(row.packet,'hex').length-1;length++)assert.throws(()=>decodeServerGameMessage(Buffer.from(row.packet,'hex').subarray(0,length)));
});
test('preview/Play match original writers and are consumed by original request handlers',()=>{
 assert.deepEqual([...serverCharacterListRequest()],[112,17,1]);
 for(const row of observed.requests){const actual=(row.kind==='preview'?serverCharacterPreviewRequest:serverCharacterPlayRequest)(row),expected=Buffer.from(row.packet,'hex');assert.equal(actual.length,expected.length);for(let i=0;i<actual.length;i++){const mask=i===actual.length-1?224:255;assert.equal(actual[i]&mask,expected[i]&mask);}assert.equal(row.calls[0].resref,row.resref);assert.equal(row.calls[0].kind,row.kind);if(row.kind==='play')assert.equal(row.calls[0].source,row.source);else assert.equal(row.calls[0].previewType,row.source===17?5:row.source===14?4:1);}
 for(const ref of ['', '../foo','C:\\secret','long_character_ref','with\0null'])assert.throws(()=>serverCharacterPlayRequest({source:17,resref:ref}));assert.throws(()=>serverCharacterPlayRequest({source:1,resref:'valid'}));
});
const createSession=()=>{const peer=new EventEmitter(),sent=[],events=[],diagnostics=[];peer.sendGameMessage=async bytes=>sent.push([...bytes]);peer.disconnect=async()=>peer.emit('closed');const session=new NetworkGameSession({peer,identity:{dispose(){}},build:{build:{},dispose(){}},resources:{close(){}},language:0,openModule:async()=>({}),decodeMessage:m=>m,localVaultAllowed:false,onDiagnostic:d=>diagnostics.push(d)});session.resolver={};session.resourceResult={ready:true};session.phase='character-selection';session.on('message',e=>events.push(e.message));return{session,sent,events,diagnostics};};
test('server-only selection waits for list and explicit Play, checks identity/generation, never uploads BIC',async()=>{
 const h=createSession(),s=h.session;await s.requestServerCharacters();await s.requestServerCharacters();assert.equal(h.sent.length,1);await assert.rejects(s.selectCharacter(writeGff('BIC ',gffRecord({}))),/requires server-vault/);
 const entry={source:17,resref:'hero',firstName:{text:'Hero'},lastName:{text:''},classes:[],portrait:0,portraitRef:''};await s.receive({kind:'server-character-list',characters:[entry]});const selection={source:17,resref:'hero',generation:1};assert.equal(h.sent.length,1);await s.previewServerCharacter(selection);assert.deepEqual(h.sent[1],[...serverCharacterPreviewRequest(entry)]);assert.equal(s.characterSubmitted,undefined);
 await assert.rejects(s.playServerCharacter({...selection,resref:'other'}),/current server list/);await assert.rejects(s.playServerCharacter({...selection,generation:0}),/stale/);
 await s.playServerCharacter(selection);assert.equal(s.state().characterSubmitted,true);assert.equal(s.state().characterUploaded,false);assert.equal(s.world.registry.objects.size,0);assert.deepEqual(h.sent[2],[...serverCharacterPlayRequest(entry)]);await assert.rejects(s.playServerCharacter(selection),/stale/);await s.receive({kind:'character-confirmed'});assert.equal(s.characterConfirmed,true);await s.disconnect();
});
test('preview bytes stay in main, stale replies are ignored and list refresh invalidates selection',async()=>{
 const h=createSession(),s=h.session;await s.requestServerCharacters();await s.receive({kind:'server-character-list',characters:[{source:17,resref:'hero'}]});await s.previewServerCharacter({source:17,resref:'hero',generation:1});
 const data=writeGff('BIC ',gffRecord({Str:{type:0,value:14},Experience:{type:4,value:100}}));await s.receive({kind:'server-character-preview',previewType:5,resref:'hero',data});const view=h.events.at(-1);assert.equal(view.preview.abilities.Str,14);assert.equal(view.preview.experience,100);assert.equal(view.data,undefined);assert.ok(data.every(byte=>byte===0));
 await s.requestServerCharacters();await assert.rejects(s.playServerCharacter({source:17,resref:'hero',generation:1}),/stale/);await s.receive({kind:'server-character-list',characters:[]});assert.equal(s.characterListGeneration,2);assert.equal(s.selectedServerCharacter,null);await s.disconnect();
});

test('lobby player-list records retain raw IDs and stay separate from world admission',async()=>{
 const w=new NativeMessageWriter(1);w.create(128,0xffffffff,1);w.writeBool(true);w.writeDword(0x12345678);for(const s of ['Other','Player']){w.writeBool(false);w.writeCExoString({bytes:new TextEncoder().encode(s),length:s.length,capacity:s.length+1});}w.writeWord(3);w.writeByte(1);w.writeByte(10);w.writeByte(30);w.setPrefix(Uint8Array.of(80,49,3));const bytes=Uint8Array.from(w.getWriteMessage().data),m=decodeServerGameMessage(bytes);assert.equal(m.character.id,0x12345678);assert.equal(m.character.firstName.text,'Other');assert.deepEqual(m.character.classes,[{id:10,level:30}]);
 const h=createSession();await h.session.lobbyPlayers(true);await h.session.receive(m);assert.equal(h.events.at(-1).character.id,0x12345678);assert.equal(h.session.world.registry.objects.size,0);await h.session.lobbyPlayers(false);const count=h.events.length;await h.session.receive(m);assert.equal(h.events.length,count);assert.deepEqual(h.sent,[[112,49,1],[112,49,2]]);await h.session.disconnect();
});

test('preview presentation preserves localized names without importing saved effects',()=>{
 const bytes=writeGff('BIC ',gffRecord({FirstName:{type:12,value:{strRef:0xffffffff,entries:[{language:0,text:'Native name'}]}},EffectList:{type:15,value:[gffRecord({Type:{type:4,value:12345}})]}})),summary=serverCharacterPreviewSummary(bytes);assert.deepEqual(summary.firstName,{text:'Native name'});assert.equal(summary.EffectList,undefined);assert.equal(summary.id,undefined);assert.equal(summary.data,undefined);
});

