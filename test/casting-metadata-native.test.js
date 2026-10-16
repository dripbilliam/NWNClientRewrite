import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {parse2da} from '../src/area.js';
import {castingSpell,conjureAnimationType,castAnimationType,projectilePathType,spellStringEntry} from '../src/spell_metadata.js';
const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-casting-metadata-observations.json',import.meta.url)));
assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
test('casting animation/path enums and scalar widths match original loader block executions',()=>{
  for(const row of oracle.rows){
    const mapping={conjure:conjureAnimationType,cast:castAnimationType,path:projectilePathType}[row.mode];
    if(mapping){assert.equal(mapping(row.input),row.value,JSON.stringify(row));continue;}
    const fields={conjureTime:['ConjTime','conjureTime'],castTime:['CastTime','castTime'],projectile:['Proj','useProjectile'],userType:['UserType','userType'],spontaneous:['SpontaneouslyCast','spontaneouslyCast'],targetType:['TargetType','targetType'],concentration:['UseConcentration','useConcentration'],hasProjectile:['HasProjectile','hasProjectile']};
    const [column,key]=fields[row.mode],rules={spells:parse2da(`2DA V2.0\n\n${column}\n999 ${row.input}`)};
    assert.equal(castingSpell(rules,0)[key]>>>0,row.value,JSON.stringify(row));
  }
});
test('casting metadata follows active physical rows/columns/defaults and native range truncation',()=>{
  const table=parse2da('2DA V2.0\n\nRange ConjTime ConjAnim CastTime CastAnim Proj ProjType UserType ImpactScript VS\n999 TT 0xffffffff HEAD 0x400 ATTACK 1 SPIRAL 257 My_Impact_Script_With_Long_Name VS');
  const rules={spells:table},spell=castingSpell(rules,0);
  assert.equal(spell.range,'T');assert.equal(spell.conjureTime,0xffffffff);assert.equal(spell.conjureAnimation,2);
  assert.equal(spell.castTime,1024);assert.equal(spell.castAnimation,7);assert.equal(spell.projectilePath,6);assert.equal(spell.userType,1);
  assert.equal(spell.impactScript,'My_Impact_Script_With_Long_Name');assert.equal(spell.components,'VS');
  assert.equal(castingSpell(rules,999),null);assert.equal(castingSpell(rules,-1),null);
  const duplicate=parse2da('2DA V2.0\nDEFAULT: hand\n\nConjAnim ConjAnim\n0 head out');
  assert.equal(spellStringEntry(duplicate,0,'ConjAnim'),'head');assert.equal(spellStringEntry(duplicate,0,'Missing'),'hand');
  assert.equal(castingSpell({spells:duplicate},0).conjureAnimation,2);
  rules.spells=parse2da('2DA V2.0\n\nCastAnim\n0 point');assert.equal(castingSpell(rules,0).castAnimation,6);
  rules.spells=parse2da('2DA V2.0\n\nCounter1 Counter2\n0 0xffffffff 0x7a\n1 **** ****');
  assert.equal(castingSpell(rules,0).counter1,-1);assert.equal(castingSpell(rules,0).counter2,122);
  assert.equal(castingSpell(rules,1).counter1,-1);assert.equal(castingSpell(rules,1).counter2,-1);
  assert.throws(()=>castingSpell({},0),/unavailable/);
});
