import test from 'node:test';
import assert from 'node:assert/strict';
import {parseSoundSet,soundSetString} from '../src/sound_set.js';
import fs from 'node:fs';
import {VoicePresentation} from '../src/voice_presentation.js';
import {RESOURCE_TYPE} from '../src/resource_archive.js';
const ssf=(entries)=>{
 const count=entries.length,start=40+count*4,bytes=new Uint8Array(start+entries.filter(Boolean).length*20),v=new DataView(bytes.buffer);bytes.set(new TextEncoder().encode('SSF V1.0'));v.setUint32(8,count,true);v.setUint32(12,40,true);let offset=start;
 entries.forEach((e,i)=>{if(!e)return;v.setUint32(40+i*4,offset,true);bytes.set(new TextEncoder().encode(e.resRef).subarray(0,16),offset);v.setUint32(offset+16,e.strRef,true);offset+=20;});return bytes;
};
test('SSF text and explicit sound override match original GetStrres instruction observations',()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-sound-set-observations.json',import.meta.url)));
 for(const row of native.rows.filter(r=>r.case.operation==='entry')){
  const c=row.case,calls=[],set=parseSoundSet(ssf([{resRef:c.resRef,strRef:c.strRef},null,{resRef:c.resRef,strRef:c.strRef}])),out=soundSetString(set,c.id,{
   text:ref=>{calls.push(['tlk',ref,0,0]);return'spoken caption';},warning:()=>calls.push(['warning'])});
  assert.deepEqual(out,{text:row.text,resRef:row.resRef},JSON.stringify(c));assert.deepEqual([['data'],...calls],row.calls);
 }
});
test('soundset offset table bounds, empty offsets, 16-byte names and WORD indexing remain distinct',()=>{
 const s=parseSoundSet(ssf([{resRef:'abcdefghijklmnop',strRef:123},null,{resRef:'',strRef:0xffffffff}]));
 assert.deepEqual(s.get(65536),{resRef:'abcdefghijklmnop',strRef:123});assert.equal(s.get(1),null);assert.equal(s.get(3),undefined);assert.equal(s.get(-1),undefined);
 assert.deepEqual(s.get(2),{resRef:'',strRef:0xffffffff});assert.throws(()=>parseSoundSet(new Uint8Array(10)),/bounds/);
 const bad=ssf([{resRef:'cue',strRef:0}]);new DataView(bad.buffer).setUint32(40,0xffffff00,true);assert.throws(()=>parseSoundSet(bad).get(0),/bounds/);
});
test('voice presentation uses active soundset/SSF and TLK text, preserves empty WAV override and canonical actor lifetime',async()=>{
 const actor={id:99,objectType:5,authored:{SoundSetFile:0},position:[1,0,-2]},captions=[],sounds=[],lookups=[],objects=new Map([[99,actor]]),
  entries=[{resRef:'actual_voice',strRef:17},{resRef:'',strRef:18},null,{resRef:'nosubtitle',strRef:0xffffffff}],
  resolver={moduleName:'fixture',getResource:async(name,type)=>{lookups.push([name,type]);if(type===RESOURCE_TYPE.TWO_DA)return new TextEncoder().encode('2DA V2.0\n\nRESREF\n0 testvoice\n');return ssf(entries);}},
  v=new VoicePresentation(resolver,{getObject:id=>objects.get(id),getPlayer:()=>actor,getText:()=>({strRef:n=>`subtitle${n}`}),onCaption:c=>captions.push(c),onSound:s=>sounds.push(s)});
 await v.receive({type:'quick-chat',actorId:99,code:0});await v.receive({type:'quick-chat',actorId:99,code:1});await v.receive({type:'quick-chat',actorId:99,code:2});await v.receive({type:'quick-chat',actorId:99,code:3});
 assert.deepEqual(captions.map(c=>c.text),['subtitle17','subtitle18']);assert.deepEqual(sounds.map(s=>s.resRef),['actual_voice','nosubtitle']);assert.ok(sounds.every(s=>s.channel==='voice'&&s.replace));
 assert.deepEqual(lookups,[['soundset',2017],['soundsettype',2017],['testvoice',2060]]);
 objects.delete(99);await v.receive({type:'quick-chat',actorId:99,code:0});assert.equal(sounds.length,2);
 objects.set(99,actor);await v.receive({type:'voice-chat',actorId:99,code:256});assert.equal(captions.length,2);assert.equal(sounds.length,3);
 v.dispose();await v.receive({type:'quick-chat',actorId:99,code:0});assert.equal(sounds.length,3);
});
test('closing a voice presentation during caption delivery cannot send audio into another session',async()=>{
 const actor={id:99,objectType:5,authored:{SoundSetFile:0},position:[0,0,0]},sounds=[],resolver={getResource:async(_name,type)=>type===2017?new TextEncoder().encode('2DA V2.0\n\nRESREF\n0 testvoice\n'):ssf([{resRef:'voice',strRef:1}])};
 const v=new VoicePresentation(resolver,{getObject:()=>actor,getPlayer:()=>actor,getText:()=>({strRef:()=> 'caption'}),onCaption:async()=>v.dispose(),onSound:e=>sounds.push(e)});
 await v.receive({type:'quick-chat',actorId:99,code:0});assert.deepEqual(sounds,[]);
});
