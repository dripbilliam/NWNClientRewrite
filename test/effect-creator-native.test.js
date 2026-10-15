import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {setEffectCreator} from '../src/effect_creator.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-effect-creator-observations.json',import.meta.url)));
test('effect attribution and inherited spell/level metadata match original creator owner',()=>{
  for(const row of oracle.rows){
    const c=row.case,calls=[],effect={creatorId:88,spellId:c.spell??-1,casterLevel:c.level??-1},actor={};
    setEffectCreator(effect,c.id??99,{object:()=>c.exists===false?null:actor,asWorld:()=>c.world===false?null:actor,
      asAreaEffect:()=>c.aoe?actor:null,areaEffectCreator:()=>c.aoeCreator??123,effectSpell:()=>{calls.push(['spell']);return c.contextSpell??1;},
      casterLevel:()=>{calls.push(['casterLevel']);return c.contextLevel??3;}});
    assert.deepEqual(effect,{creatorId:row.creatorId,spellId:row.spellId,casterLevel:row.casterLevel},JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
  }
});
