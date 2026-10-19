import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {localSpellMessageFields} from '../src/client_spell_message.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-server-spell-message-observations.json',import.meta.url)));
test('CC8 local field projection matches original writer item lookup, exact INT==1 branch and low-bit BOOL encoding',()=>{
 for(const row of capture.rows){const c=row.case,calls=[];
  const fields=localSpellMessageFields({objects:[99,c.itemId],integers:[37,c.identified,c.casting,c.baseItem]},{item:id=>{calls.push(['item',id]);return c.item?{}:null;},itemName:()=>({localized:'ItemLoc',override:c.override?'Override':''}),warning:()=>calls.push(['warning'])});
  assert.deepEqual(fields,row.fields,JSON.stringify(c));assert.deepEqual(calls,row.calls.filter(c=>['item','warning'].includes(c[0])),JSON.stringify(c));
  assert.deepEqual(row.calls[0],['create',9,0x11223344,1]);assert.equal(row.result,c.payload?c.send:0);
 }assert.equal(capture.rows.length,1280);
});
