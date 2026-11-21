import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createCombatRound,addSpecialAttack} from '../src/combat_round.js';
test('special attack append selects original empty remaining attack, bounds queue and rolls sequence',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-add-special-attack-observations.json',import.meta.url)));
 for(const {case:c,...expected}of oracle.rows){
  const r=createCombatRound();r.started=c.started;r.currentAttack=c.current;r.specialAttackSequence=c.sequence;[r.onhandAttacks,r.offhandAttacks,r.additionalAttacks,r.bonusEffectAttacks]=c.counts;
  r.specialAttacks=Array.from({length:c.queued},(_,i)=>10+i);r.specialAttackParameters=Array.from({length:c.queued},(_,i)=>20+i);
  r.attacks.forEach((a,i)=>{a.attackType=c.occupied==='none'||c.occupied==='first'&&i>0?0:9;a.specialParameter=255;});
  addSpecialAttack(r,c.type,()=>{});
  assert.deepEqual({sequence:r.specialAttackSequence,special:r.specialAttacks,parameters:r.specialAttackParameters,attacks:r.attacks.map(a=>[a.attackType,a.specialParameter])},expected,JSON.stringify(c));
 }
});
