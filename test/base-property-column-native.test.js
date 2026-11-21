import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-base-property-column-observations.json',import.meta.url)));
test('base-item eligibility reads native PropColumn and narrows its output, ignoring the invented BasePropColumn header',()=>{
 assert.equal(capture.rows.length,48);
 for(const row of capture.rows.filter(r=>r.case.mode==='PropColumn')){
  assert.deepEqual(row.calls,[{row:7,column:'PropColumn'}]);const s=new ModuleSession(null),value=row.case.value;
  s.characterRules={baseitems:parse2da(`2DA V2.0\nDEFAULT: ${value}\n\n${row.case.status?'PropColumn':'Missing'} BasePropColumn\n0 ${value} 19`)};
  assert.equal(s.items.baseInfo({baseItem:0}).basePropColumn,row.byte,JSON.stringify(row.case));
 }
});
test('RangedWeapon loader has its own failed-query zero and ammunition lookup reads its BYTE as a base-item ID',()=>{
 for(const row of capture.rows.filter(r=>r.case.mode==='RangedWeapon')){
  assert.deepEqual(row.calls,[{row:7,column:'RangedWeapon'}]);const s=new ModuleSession(null),value=row.case.value;
  s.characterRules={baseitems:parse2da(`2DA V2.0\nDEFAULT: ${value}\n\n${row.case.status?'RangedWeapon':'Missing'}\n0 ${value}`)};
  assert.equal(s.items.baseInfo({baseItem:0}).ranged,row.byte,JSON.stringify(row.case));
 }
 assert.equal(capture.lookups.length,42);for(const row of capture.lookups)assert.deepEqual(row.calls,[['base',7],['base',row.case.ranged&255],['equipped',row.case.slot]]);
});
