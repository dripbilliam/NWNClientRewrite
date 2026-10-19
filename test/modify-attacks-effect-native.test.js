import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {modifyAttacksEffect,applyModifyAttacks,removeModifyAttacks} from '../src/modify_attacks_effect.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-modify-attacks-effect-observations.json',import.meta.url)));
test('bonus attacks match original construction, live array scans, signed sums, cap and pointer removal',()=>{
  assert.equal(oracle.rows.length,792);
  for(const row of oracle.rows){const c=row.case,calls=[];let result=0,output=null;
    const actor={combatRound:{bonusEffectAttacks:c.current??0},effects:[]},effect={id:'000000000000004d',type:44,integers:[c.amount??1],durationType:c.durationType??2};
    actor.effects=(c.effects??[]).map(e=>e.samePointer?effect:{id:(e.id??77).toString(16).padStart(16,'0'),type:e.type,integers:[e.amount??0]});
    const p={dead:()=>{calls.push(['dead']);return c.dead??0;},asCreature:()=>{calls.push(['creature']);return c.creature===false?null:actor;},effects:o=>o.effects};
    if(c.mode==='constructor'){
      calls.push(['pop']);if(c.pop===0)result=-639;
      else{const s=new ModuleSession(null),e=modifyAttacksEffect(c.amount??1,99,{create:(...a)=>{calls.push(['creator',99]);return s.effects.create(...a);},invalid:()=>s.effects.invalid()});
        output={id:'0000000000000065',type:e.type,subtype:e.subtype,durationType:e.durationType,creatorId:e.creatorId,integers:e.integers};calls.push(['push']);if(c.push===0)result=-638;}
    }else result=c.mode==='apply'?applyModifyAttacks(actor,effect,p,c.loading??0):removeModifyAttacks(actor,effect,p);
    assert.deepEqual({result,calls,output,bonusAttacks:actor.combatRound.bonusEffectAttacks},{result:row.result,calls:row.calls,output:row.output,bonusAttacks:row.bonusAttacks},JSON.stringify(c));
  }
});
