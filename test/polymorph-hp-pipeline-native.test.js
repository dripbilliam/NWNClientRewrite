import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {setBaseAbility} from '../src/base_ability.js';
import {refreshAbilityModifierCache,scriptAbilityModifier} from '../src/ability_modifier_cache.js';
import {creatureMaxHitPoints} from '../src/creature_hit_points.js';
test('shared base setters and cache refresh reproduce original HP pipeline, including absent CON overrides',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-polymorph-hp-pipeline-observations.json',import.meta.url)));assert.equal(data.rows.length,128);
 for(const row of data.rows){const c=row.case,root={IsPC:1,ClassList:[{Class:10,ClassLevel:c.dice.length}],LvlStatList:c.dice.map(LvlStatHitDie=>({LvlStatHitDie})),FeatList:c.toughness?[{Feat:40}]:[],Str:12,Dex:12,Con:c.base,Int:12,Wis:12,Cha:12},o={creatureData:root,stats:{equippedAbilities:{}}};let race=c.initialAdjust;
  const names=['Str','Dex','Con','Int','Wis','Cha'],score=(_o,n)=>Math.max(3,root[names[n]]+(n===2?race:0))&255,maximum=()=>creatureMaxHitPoints(root,scriptAbilityModifier(o,2),{}),refresh=()=>{o.stats.equippedAbilities=Object.fromEntries(names.map((name,n)=>[name,score(o,n)]));refreshAbilityModifierCache(o,{});},p={score,modifier:n=>Math.floor((n-10)/2),maximumHP:maximum,currentBaseHP:()=>o.hp,writeBaseHP:(_o,n)=>{o.hp=n;},encumbrance:()=>{}};
  refresh();o.hp=maximum()-c.injury;const snapshot=()=>({hp:o.hp,maximum:maximum(),con:root.Con,modifier:scriptAbilityModifier(o,2)});assert.deepEqual(snapshot(),row.before);
  race=c.formAdjust;await setBaseAbility(o,0,18,0,p);if(c.formCon!==null)await setBaseAbility(o,2,c.formCon,1,p);await setBaseAbility(o,1,16,0,p);refresh();assert.deepEqual(snapshot(),row.changed,JSON.stringify(c));
  refresh();race=c.initialAdjust;await setBaseAbility(o,0,12,0,p);await setBaseAbility(o,2,c.base,1,p);await setBaseAbility(o,1,12,0,p);assert.deepEqual(snapshot(),row.restored,JSON.stringify(c));
 }
});
