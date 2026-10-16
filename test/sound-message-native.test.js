import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeSoundMessageState,loadSoundMessageState} from '../src/sound_message.js';
import {decodeGffText} from '../src/gff_text.js';
const parsed=v=>typeof v==='string'?decodeGffText(Uint8Array.from(Buffer.from(v,'latin1'))):Array.isArray(v)?v.map(parsed):v&&typeof v==='object'?Object.fromEntries(Object.entries(v).map(([k,value])=>[k,parsed(value)])):v;

test('sound protocol state/defaults, resource bytes and append/growth/reload match original loader blocks',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-sound-message-observations.json',import.meta.url)));assert.equal(fixture.rows.length,64);
 let executions=0;
 for(const row of fixture.rows){
  const object={id:123};initializeSoundMessageState(object);
  for(const [i,data]of row.case.steps.entries()){
   loadSoundMessageState(object,parsed(data));const value={fields:object.nativeMessageFields,capacity:object.nativeSoundRefCapacity344,refs:object.nativeSoundRefs338.map(ref=>Buffer.from(ref).toString('hex')),position:[object.position[0],-object.position[2],object.position[1]]};
   assert.deepEqual(value,row.observations[i],JSON.stringify({case:row.case,i}));assert.equal(object.id,123);executions++;
  }
 }
 assert.equal(executions,89);
});
