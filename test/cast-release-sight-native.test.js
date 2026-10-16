import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {castReleaseLineOfSight} from '../src/spell_release.js';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';

test('cast release sight matches original vectors, carried-item bypass and unresolved destination behavior',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-cast-release-sight-observations.json',import.meta.url)));
 assert.equal(data.rows.length,96);
 for(const row of data.rows){
  const c=row.case,trace=[],actor={id:0x80000042,position:[1.25,-2.5,3.75]},target=c.target?{id:91,position:[-4.5,5.25,-6.75]}:null;
  const accepted=castReleaseLineOfSight(actor,target,[8.25,-9.5,10.75],{position:o=>o.position,asObject:()=>c.object,asItem:()=>c.item,area:()=>{trace.push(['area','target']);return c.placed?{}:null;},possessor:()=>c.possessor,lineOfSight:(...args)=>{trace.push(['los',...args]);return c.los;}});
  assert.deepEqual({trace,accepted},{trace:row.trace,accepted:row.accepted},JSON.stringify(c));
 }
});

test('live base-item armor-enchantment BYTE uses loader success/default255 policy',()=>{
 const s=new ModuleSession({});
 s.characterRules={baseitems:parse2da('2DA V2.0\nDEFAULT: 12\n\nAC_Enchant\n0 259\n1 ****')};
 assert.equal(s.items.baseInfo({baseItem:0}).acEnchant,3);
 assert.equal(s.items.baseInfo({baseItem:1}).acEnchant,255);
});
