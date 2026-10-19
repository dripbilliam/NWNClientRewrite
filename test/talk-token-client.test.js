import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {GameUi} from '../src/game_ui.js';
import {GameText} from '../src/talk_table.js';
import {parse2da} from '../src/area.js';
import {loadNamedTalkTokens} from '../src/game_talk_tokens.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
test('live token bodies reach dialogue/reply text with native case, escaping, replacement and actor gender',async()=>{
 const s=new ModuleSession(null),a=s.register('player','token-caster',{isPC:true,stats:{},name:'Token Caster',authored:{Gender:1,FirstName:'Token',LastName:'Caster'}});s.player=a;
 s.talkTable.namedTokens=loadNamedTalkTokens(parse2da('2DA V2.0\n\nToken Action Default A B C D\n0 FullName 2 -1 -1 -1 -1 -1\n1 FirstName 3 -1 -1 -1 -1 -1\n2 StartCheck 20 -1 -1 -1 -1 -1\n3 /Start 22 -1 -1 -1 -1 -1'));
 const ui={session:s,text:new GameText()},render=value=>GameUi.prototype.dialogueText.call(ui,value),cursor=s.registry.nextObjectId[0];
 await s.commands.SetCustomToken([42,'first effect']);assert.equal(render('<FullName>: <CUSTOM42>'),'Token Caster: first effect');
 await s.commands.SetCustomToken([42,'replacement']);assert.equal(render('<StartCheck><FirstName>: <CUSTOM42></Start>'),'Token: replacement');
 assert.equal(render('<<CUSTOM42> / <firstName>'),'<CUSTOM42> / <UNRECOGNIZED TOKEN>');
 assert.equal(render({strRef:0xffffffff,entries:[{languageId:0,text:'male <CUSTOM42>'},{languageId:1,text:'female <CUSTOM42>'}]}),'female replacement');
 await s.commands.SetCustomToken([42,'<CUSTOM10>']);assert.equal(render('<CUSTOM42>'),'<CUSTOM10>');assert.equal(s.registry.nextObjectId[0],cursor);
});
test('known unsupported token providers and malformed native buffers remain diagnosed',()=>{
 const s=new ModuleSession(null),a=s.register('player','token-player',{stats:{},authored:{}});s.player=a;s.talkTable.namedTokens=loadNamedTalkTokens(parse2da('2DA V2.0\n\nToken Action Default A B C D\n0 PlayerName 23 -1 -1 -1 -1 -1'));
 const begin=runtimeDiagnostics.records.length;assert.equal(s.talkTable.parseClient('<PlayerName>',{actor:a} ),'<UNIMPLEMENTED TOKEN>');assert.equal(s.talkTable.parseClient('unclosed <token',{actor:a}),'unclosed <token');
 s.talkTable.namedTokens=loadNamedTalkTokens(parse2da('2DA V2.0\n\nToken Action Default A B C D\n0 Unknown 25 -1 -1 -1 -1 -1'));assert.equal(s.talkTable.parseClient('<Unknown>',{actor:a}),'<UNRECOGNIZED TOKEN>');
 const records=runtimeDiagnostics.records.slice(begin);assert.ok(records.some(r=>r.code==='text.named-token-unimplemented'));assert.ok(records.some(r=>r.code==='text.token-parse-failed'));assert.ok(records.some(r=>r.context.nativeFunction==='GetTokenValue'&&r.context.nativeLine===0x175));
});
test('language reload imports the active named-token table while preserving separate custom and override state',async()=>{
 let token='Alpha';const s=new ModuleSession({getResource:async name=>{assert.equal(name,'stringtokens');return new TextEncoder().encode(`2DA V2.0\n\nToken Action Default A B C D\n0 ${token} 0 -1 -1 -1 -1 -1`);}}),bytes=new Uint8Array(20),view=new DataView(bytes.buffer);bytes.set(new TextEncoder().encode('TLK V3.0'));view.setUint32(16,20,true);const files=[{name:'dialog.tlk',arrayBuffer:async()=>bytes}];
 await s.talkTable.loadFiles(files);assert.equal(Buffer.from(s.talkTable.namedTokens[0].name).toString(),'Alpha');await s.commands.SetCustomToken([42,'persistent']);s.talkTable.overrides.set(7,new TextEncoder().encode('override'));
 token='Beta';await s.talkTable.loadFiles(files);assert.equal(Buffer.from(s.talkTable.namedTokens[0].name).toString(),'Beta');assert.equal(Buffer.from(s.talkTable.tokens.records[0].bytes).toString(),'persistent');assert.ok(s.talkTable.overrides.has(7));
});
