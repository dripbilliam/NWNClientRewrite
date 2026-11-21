import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {setAreaTransitionBmp,clearLastSentAutomap} from '../src/client_area_message.js';
test('client area selection and last-sent-map cleanup match 36 original executions',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-area-state-observations.json',import.meta.url)));assert.equal(data.rows.length,36);
 for(const row of data.rows){
  const c=row.case,o={nativeAreaTransitionBmp20:27,nativeUserTransitionBmp28:'custom',nativeLastSentMapArea178:c.area??88,nativeLastSentMap170:c.map?new Uint8Array(128):null};
  if(c.operation==='bmp')setAreaTransitionBmp(o,c.index,c.text);else clearLastSentAutomap(o);
  assert.deepEqual({bmp:o.nativeAreaTransitionBmp20,user:o.nativeUserTransitionBmp28,area:o.nativeLastSentMapArea178,map:o.nativeLastSentMap170!==null},{bmp:row.bmp,user:row.user,area:row.area,map:row.map},JSON.stringify(c));
 }
});
