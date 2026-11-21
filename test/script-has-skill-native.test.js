import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {scriptHasSkill} from '../src/script_has_skill.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-has-skill-observations.json',import.meta.url)));
test('GetHasSkill matches3072 original wrappers: BYTE skill, exact eligibility1 and native cast/lookup order',async()=>{
 assert.equal(data.rows.length,3072);for(const row of data.rows){const c=row.case;if(!c.intPop||!c.objectPop){assert.equal(row.result,0xfffffd81);assert.deepEqual(row.calls,[]);continue;}
  const object={},creature={},calls=[],result=await scriptHasSkill(c.skill,0x12345678,{lookup:id=>{calls.push(['lookup',id]);return{status:c.status,object};},asCreature:()=>{calls.push(['asCreature']);return c.creature?creature:null;},canUseSkill:(_o,skill)=>{assert.equal(_o,creature);calls.push(['canUse',skill]);return c.canUse;}});
  assert.equal(result,row.output);assert.deepEqual(calls,row.calls);assert.equal(row.result,c.push?0:0xfffffd82);
 }
});
