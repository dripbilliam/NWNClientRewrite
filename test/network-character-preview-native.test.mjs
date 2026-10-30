import test from 'node:test';
import assert from 'node:assert/strict';
import {EventEmitter} from 'node:events';
import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {writeGff,gffRecord} from '../src/gff_writer.js';
const bytes=()=>writeGff('BIC ',gffRecord({Str:{type:0,value:14}}));
function fixture(){const peer=new EventEmitter();peer.disconnect=async()=>{};peer.sendGameMessage=async()=>{};const resources={setProgress(){},close(){}};const s=new NetworkGameSession({peer,resources,identity:{dispose(){}},build:{build:8193,dispose(){}},decodeMessage:v=>v});s.phase='character-selection';s.resolver={getResource(){throw Error('JS preview rules must not load');}};s.characterListGeneration=2;s.selectedServerCharacter={source:17,resref:'hero'};return s;}
test('native local preview transports bytes without evaluating JS character rules',async()=>{
 const s=fixture(),input=bytes();let received;s.characterPreviewEncoder=async value=>{received=Uint8Array.from(value);return{format:'native-bic-file-v1',bytes:value.length};};const value=await s.previewLocalCharacter(input);assert.deepEqual(received,input);assert.equal(value.format,'native-bic-file-v1');assert.equal(s.previewRules,undefined);await s.disconnect();
});
test('native server preview preserves validated response identity and wipes received bytes',async()=>{
 const s=fixture(),events=[],input=bytes();s.on('message',v=>events.push(v.message));s.characterPreviewEncoder=async value=>({format:'native-bic-file-v1',bytes:value.length});await s.receive({kind:'server-character-preview',previewType:5,resref:'hero',data:input});assert.equal(events.length,1);assert.deepEqual(events[0],{kind:'server-character-preview',resref:'hero',source:17,generation:2,preview:{format:'native-bic-file-v1',bytes:input.length}});assert.ok(input.every(v=>v===0));assert.equal(s.previewRules,undefined);await s.disconnect();
});
test('superseded server preview encoders cannot publish into the replacement selection',async()=>{
 const s=fixture(),events=[],input=bytes();let release,started;const entered=new Promise(resolve=>{started=resolve;});s.on('message',v=>events.push(v.message));s.characterPreviewEncoder=()=>new Promise(resolve=>{release=resolve;started();});const receiving=s.receive({kind:'server-character-preview',previewType:5,resref:'hero',data:input});await entered;s.selectedServerCharacter={source:17,resref:'other'};release({format:'native-bic-file-v1'});await receiving;assert.equal(events.length,0);assert.ok(input.every(v=>v===0));await s.disconnect();
});
test('wrong server preview subtype/reference never reaches the native byte encoder',async()=>{
 const s=fixture();let calls=0;s.characterPreviewEncoder=async()=>{calls++;return{};};for(const request of [{previewType:1,resref:'hero'},{previewType:5,resref:'other'}]){const data=bytes();await s.receive({kind:'server-character-preview',...request,data});assert.ok(data.every(v=>v===0));}assert.equal(calls,0);await s.disconnect();
});
test('native local preview rejects ownership changes while byte encoding is pending',async()=>{
 const s=fixture();let release;s.characterPreviewEncoder=()=>new Promise(resolve=>{release=resolve;});const reading=s.previewLocalCharacter(bytes());s.resolver={};release({format:'native-bic-file-v1'});await assert.rejects(reading,/stale/);await s.disconnect();
});
