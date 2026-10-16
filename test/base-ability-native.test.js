import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {setBaseAbility} from '../src/base_ability.js';
import {abilityModifierCells} from '../src/ability_modifier_cache.js';
const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-base-ability-observations.json',import.meta.url))),names=['Str','Dex','Con','Int','Wis','Cha'];
test('six base-ability setters preserve native byte fields, cache order, CON HP arithmetic and mental dirty flags',async()=>{
 assert.equal(fixture.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(fixture.rows.length,2052);
 for(const row of fixture.rows){const c=row.case,root=Object.fromEntries(names.map((key,i)=>[key,12+i])),o={creatureData:root,hp:c.hp??80,nativeField544:7,...Object.fromEntries(abilityModifierCells.map((key,i)=>[key,1+i]))},calls=[];let reads=0;
  await setBaseAbility(o,c.ability,c.value,c.adjust??1,{score:(o,i)=>{calls.push(['score',i,root[names[i]],o[abilityModifierCells[i]]]);return c.score??18;},
   modifier:n=>{calls.push(['modifier',n]);return c.modifier??4;},maximumHP:(o,flag)=>{calls.push(['maximum',flag,root.Con,o.nativeConModifierD3d]);return++reads===1?c.oldMaximum??100:c.newMaximum??150;},
   currentBaseHP:(o,flag)=>{calls.push(['current',flag]);return o.hp;},writeBaseHP:(o,value)=>{o.hp=value;},encumbrance:(_o,flag)=>calls.push(['encumbrance',flag])});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(names.map(k=>root[k]),row.bases,JSON.stringify(c));assert.deepEqual(abilityModifierCells.map(k=>o[k]),row.modifiers,JSON.stringify(c));assert.equal(o.hp,row.hp,JSON.stringify(c));assert.equal(o.nativeField544,row.dirty,JSON.stringify(c));assert.equal(o.creatureData,root);
 }
});
