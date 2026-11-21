import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {parse2da} from '../src/area.js';
import {creatureMaxHitPoints} from '../src/creature_hit_points.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-maximum-hp-observations.json',import.meta.url)));
test('maximum HP matches original instructions for all installed presets and PC/NPC/feat/possession rules',()=>{
 assert.equal(capture.rows.length,1526);
 for(const {case:c,result}of capture.rows){
  const root={IsPC:c.pc,ClassList:[{Class:34,ClassLevel:c.pale},{Class:10,ClassLevel:c.level-c.pale}],FeatList:c.feats.map(Feat=>({Feat})),LvlStatList:c.dice.map(LvlStatHitDie=>({LvlStatHitDie})),HitPoints:c.stored};
  const rules={ruleset:parse2da(`2DA V2.0\n\nLabel Value\n${Object.entries(c.rules??{}).map(([key,value],i)=>`${i} ${key} ${value}`).join('\n')}`)},actual=creatureMaxHitPoints(root,(c.constitution<<24)>>24,rules,{possessedFamiliar:Boolean(c.possessed),includeFeatBonuses:c.include===1});
  assert.equal(actual,result,JSON.stringify(c));
 }
});
test('installed live maximum agrees with original execution even when the serialized snapshot differs',()=>{
 const rows=capture.rows.filter(r=>r.case.name&&r.case.include===1);assert.equal(rows.length,39);
 for(const r of rows)assert.equal(r.case.computed,r.result,r.case.name);
 const differences=rows.filter(r=>r.case.saved!==r.result);assert.equal(differences.length,1);assert.equal(differences[0].case.saved,114);assert.equal(differences[0].result,102);
});
