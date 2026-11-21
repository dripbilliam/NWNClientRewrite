import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {applyBonusSpellOfLevel,removeBonusSpellOfLevel,modifyNumberBonusSpells} from '../src/bonus_spell_slots.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-bonus-spell-slots-observations.json',import.meta.url)));
test('bonus spell slots match native property class selection, saturation, per-day consumption and locked resize',()=>{
  assert.equal(oracle.rows.length,2400);
  for(const row of oracle.rows){const c=row.case,calls=[],o={nativeField9f4:c.suppressed??0,nativeEquipmentLock97c:c.locked??0,
    classes:c.classes.map(Class=>({Class,bonusSpellSlots:Array(10).fill(c.bonus??0)})),states:c.classes.map(()=>({perDay:Array(10).fill((c.perDay??2)&255)}))};
    const p={classes:o=>o.classes,state:(o,i)=>o.states[i],classType:(o,i)=>{calls.push(['class',i]);return o.classes[i].Class;},memorizes:()=>c.memorizes??1,
      gain:(o,i,l)=>{calls.push(['gain',i,l]);return (c.gain??3)&255;},resize:(o,i,l,n,d)=>calls.push(['resize',i,l,n,d]),warning:()=>calls.push(['warning'])},property={subtype:c.subtype??2,costValue:c.level??1};
    let result=null;if(c.mode==='modify')modifyNumberBonusSpells(o,c.index??0,c.level??1,c.delta??1,p);
    else result=c.mode==='apply'?applyBonusSpellOfLevel(null,property,o,16,c.loading??0,p):removeBonusSpellOfLevel(null,property,o,16,p);
    assert.deepEqual({result,calls,bonus:o.classes.map(c=>c.bonusSpellSlots),perDay:o.states.map(s=>s.perDay)},{result:row.result,calls:row.calls,bonus:row.bonus,perDay:row.perDay},JSON.stringify(c));
  }
});
