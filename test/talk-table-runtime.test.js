import test from 'node:test';
import assert from 'node:assert/strict';
import {TalkTableRuntime} from '../src/talk_table_runtime.js';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {loadNamedTalkTokens} from '../src/game_talk_tokens.js';
import {parse2da} from '../src/area.js';
const tlk=(entries,language=0)=>{const start=20+entries.length*40,text=Buffer.concat(entries.map(e=>Buffer.from(e.text))),bytes=Buffer.alloc(start+text.length);bytes.write('TLK V3.0');bytes.writeUInt32LE(language,8);bytes.writeUInt32LE(entries.length,12);bytes.writeUInt32LE(start,16);let offset=0;
 for(const[i,e]of entries.entries()){const at=20+i*40;bytes.writeUInt32LE(e.flags??7,at);bytes.write(e.sound??'WAVE',at+4,16,'ascii');bytes.writeUInt32LE(offset,at+28);bytes.writeUInt32LE(Buffer.byteLength(e.text),at+32);bytes.writeFloatLE(e.duration??2.5,at+36);offset+=Buffer.byteLength(e.text);}text.copy(bytes,start);return bytes;};
const file=(name,bytes)=>({name,arrayBuffer:async()=>bytes});
const session=()=>({diagnosticContext:()=>({}),player:{id:42}});
test('active base/custom gender pairs share native file/cache owners and persist female fallback',async()=>{
 const t=new TalkTableRuntime(session());await t.loadFiles([file('dialog.tlk',tlk([{text:'male'},{text:'second'}])),file('dialogf.tlk',tlk([{text:'female'}])),file('module.tlk',tlk([{text:'custom'}]))],'module');
 assert.equal(await t.getString(0,1),'female');assert.equal(t.state.gender,1);assert.equal(await t.getString(1,1),'second');assert.equal(t.state.gender,0);
 assert.equal(await t.getString(0x1000000,1),'custom');assert.equal(t.custom[0],t.custom[1]);assert.equal(await t.getString(0,0),'male');assert.equal(t.base[0].cache.size,2);
 const record=(await t.fetch(0)).record;assert.deepEqual([...record.sound],[87,65,86,69]);assert.equal(record.durationBits,0x40200000);
 assert.equal(await t.getString(0xffffffff,1),'');assert.equal(t.state.gender,1);assert.equal(await t.getString(0,256),'male');assert.equal(t.state.gender,0);
});
test('missing female aliases male; corrupt female rejects the pair and records load failure',async()=>{
 const t=new TalkTableRuntime(session()),male=file('dialog.tlk',tlk([{text:'male'}]));await t.loadFiles([male]);assert.equal(t.base[0],t.base[1]);assert.equal(await t.getString(0,1),'male');
 const before=runtimeDiagnostics.records.length;await assert.rejects(t.loadFiles([male,file('dialogf.tlk',Buffer.alloc(20))]),/Unsupported TLK/);assert.deepEqual(t.base,[null,null]);assert.ok(runtimeDiagnostics.records.slice(before).some(r=>r.code==='load.talk-table-failed'));
});
test('missing resources/native token owner stay diagnosed without substituting UI strings',async()=>{
 const s=new ModuleSession(null),before=runtimeDiagnostics.records.length;assert.equal(await s.commands.GetStringByStrRef([42]),'');assert.equal(await s.commands.GetStringByStrRef([0x1000000]),'BadStrRef(16777216)');
 s.talkTable.namedTokens=loadNamedTalkTokens(parse2da('2DA V2.0\n\nToken Action Default A B C D\n0 FullName 2 -1 -1 -1 -1 -1'));s.talkTable.overrides.set(42,new TextEncoder().encode('override<FullName>'));await assert.rejects(s.commands.GetStringByStrRef([42]),/server named-token context/);
 assert.ok(runtimeDiagnostics.records.slice(before).some(r=>r.code==='text.native-tlk-warning'));assert.equal(s.registry.objects.size,0);
});
export {tlk};
