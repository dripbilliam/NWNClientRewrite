import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadWaypointMessageState} from '../src/waypoint_message.js';
import {localizedMessageValue} from '../src/native_message_text.js';

test('waypoint note presence, successful localized reads and reload commits match original guarded block',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-waypoint-note-observations.json',import.meta.url)));assert.equal(fixture.rows.length,216);
 for(const row of fixture.rows){
  const c=row.case,o={nativeMessageFields:{[0x308]:c.has??0,[0x30c]:c.enabled??0},nativeMapNote310:localizedMessageValue(c.initial??{strRef:0xffffffff,entries:[]})};
  for(const [index,step]of c.steps.entries()){
   loadWaypointMessageState(o,step);const value={has:o.nativeMessageFields[0x308],enabled:o.nativeMessageFields[0x30c],strRef:o.nativeMapNote310.strRef,entries:o.nativeMapNote310.entries.map(e=>({key:e.key,hex:Buffer.from(e.bytes).toString('hex')}))};
   assert.deepEqual(value,row.observations[index],JSON.stringify({case:c,index}));
  }
 }
});
