import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {recomputeCombatRound} from '../src/combat_recompute.js';
test('equipment round recomputation matches original mode gates and physical future-group reductions',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-round-recompute-observations.json',import.meta.url))).rows;
  for(const row of rows){const c=row.case,calls=[],r={onhandAttacks:c.old,offhandAttacks:0,additionalAttacks:0,bonusEffectAttacks:0,currentAttack:c.current,actions:structuredClone(c.actions)},o={combatRound:r,combatMode:c.mode};
    await recomputeCombatRound(o,{classes:()=>c.classes,monkClass:()=>5,discipleClass:()=>40,equipped:()=>c.right?{baseItem:c.baseItem}:null,
      monkWeapon:()=>c.monk,ranged:()=>c.ranged,hasFeat:(_o,id)=>{calls.push(['feat',id]);return id===899?c.feat899:c.feat866;},
      relativeSize:()=>{calls.push(['size']);return c.size;},feedback:(_o,code)=>calls.push(['feedback',code]),setMode:(_o,mode,flag)=>{calls.push(['mode',mode,flag]);o.combatMode=mode;},
      initialize:()=>{calls.push(['initialize']);r.onhandAttacks=c.new;}});
    assert.deepEqual({calls,mode:o.combatMode,actions:r.actions},{calls:row.calls,mode:row.mode,actions:row.actions},JSON.stringify(c));
  }
});
