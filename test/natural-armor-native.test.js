import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {naturalArmorParts,naturalArmorTotal} from '../src/natural_armor.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-natural-armor-observations.json',import.meta.url)));
test('natural armor retains native class/monk/feat gates and switches base during polymorph or transition',()=>{
 assert.equal(fixture.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,2400);
 for(const row of fixture.rows){const c=row.case,calls=[],o={creatureData:{ClassList:c.classes??[],NaturalAC:c.natural??5},nativeField9f4:c.transition??0,nativeField97c:c.polymorph??0,nativeNaturalACD51:c.override??9},feats=new Set([...(c.permanent??[]),...(c.bonus??[])].map(v=>v&65535));
  const parts=naturalArmorParts(o,c.flag??0,{monkAbilities:()=>{calls.push(['monk']);return c.monk??1;},hasFeat:(_o,id)=>Number(feats.has(id)),wisdomModifier:()=>c.wisdom??4,
   rule:(name,fallback)=>{calls.push(['rule',name,fallback]);return c.rule??2;},classCount:()=>c.classCount??44,classGain:(id,level)=>{calls.push(['gain',id,level]);return c.gains?.[id]??3;}});
  assert.equal(naturalArmorTotal(parts),row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
