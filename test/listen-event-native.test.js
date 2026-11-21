import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {MatchedExpressionStrings,receiveListenEvent,matchedSubstring,matchedSubstringCount} from '../src/listen_event.js';
import {rulesetHash} from '../src/combat_stats.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-listen-event-observations.json',import.meta.url)));
test('conversation/listen event matches original state, capture ownership, default script and possession gates',async()=>{
 for(const row of native.rows.filter(r=>r.case.operation==='event')){
  const c=row.case,calls=[],actor={nativeMatchedStrings:new MatchedExpressionStrings()};actor.nativeMatchedStrings.append('old');
  await receiveListenEvent(actor,c.caller,c,{
   associateId:(_o,a,b)=>{calls.push(['associateId',a,b]);return 101;},client:id=>{calls.push(['client',id]);return c.client?{}:null;},unpossess:()=>calls.push(['unpossess']),
   integer:(e,i)=>{calls.push(['integer',i]);return e.integers[i]??0;},string:(e,i)=>{calls.push(['string',i]);return e.strings[i]??'';},
   clearMatched:o=>{calls.push(['clear']);o.nativeMatchedStrings.clear();},appendMatched:(o,s)=>{calls.push(['append',s]);o.nativeMatchedStrings.append(s);},
   scriptName:()=>{calls.push(['scriptName',7]);return c.script;},possessed:()=>{calls.push(['possessed']);return c.possessed;},
   rulesetInt:(label,fallback)=>{assert.equal(label,'ALL_ASSOCIATES_RUN_SCRIPTS');assert.equal(rulesetHash('A'),0xaf63fc4c860222ecn);
    // The native compiler prehashes first byte A, then hashes the25-byte suffix.
    calls.push(['rulesetName',label.slice(1)],['rulesetInt',fallback]);return c.rule;},
   runScript:(_o,i,s)=>calls.push(['runScript',i,s])});
  const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);assert.equal(actor.lastSpeakerId,row.speaker,label);
  assert.equal(actor.listenPatternNumber,row.pattern,label);assert.equal(actor.lastSpokenText,row.text,label);
  assert.equal(actor.lastVoiceChatId,row.voice,label);assert.equal(actor.lastSpeechVolume,row.volume,label);
  assert.deepEqual(actor.nativeMatchedStrings.entries.slice(0,actor.nativeMatchedStrings.count),row.captured,label);
 }
});
test('matched capture storage and VM string/count results match original owners',()=>{
 for(const row of native.rows.filter(r=>r.case.operation!=='event')){
  const c=row.case,storage=new MatchedExpressionStrings();storage.entries=[...c.values];storage.count=c.values.length;storage.capacity=c.capacity??c.values.length;
  const object=c.exists===false||c.lookup?null:{objectType:c.type??5,nativeMatchedStrings:storage},p={storage:o=>o.nativeMatchedStrings};
  if(c.operation==='clear')storage.clear();else if(c.operation==='append')storage.append(c.append);
  else assert.equal(c.operation==='get'?matchedSubstring(object,c.index,p):matchedSubstringCount(object,p),row.output,JSON.stringify(c));
  if(c.operation==='clear'||c.operation==='append'){
   assert.equal(storage.count,row.count);assert.equal(storage.capacity,row.capacity);assert.deepEqual(storage.entries.slice(0,storage.count),row.values);
  }
 }
});
