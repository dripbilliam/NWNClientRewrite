import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {damageShieldIntegers,applyDamageShield,resolveDamageShields} from '../src/damage_shield.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-damage-shield-observations.json',import.meta.url)));
const create=(type,creatorId,values=[])=>({type,creatorId,durationType:0,integers:[...values,...Array(Math.max(0,8-values.length)).fill(0)]});
test('shield clamps, child icon, table reads and recursive payload order match original owners',async()=>{
 for(const {case:c,result,output,calls:expected} of oracle.rows){
  const calls=[],e=create(61,98,[c.base??3,c.die??4,c.flags??256]);e.durationType=c.durationType??2;
  if(c.owner==='construct'){const actual=create(61,99,damageShieldIntegers(c.base,c.die,c.flags,13));assert.deepEqual(actual,output,JSON.stringify(c));continue;}
  const o={id:99,effects:Array(c.shields??1).fill(e)},p={dead:()=>c.dead??0,copyConstruct:e=>structuredClone(e),create,effects:o=>o.effects,
   apply:(o,e,loading)=>calls.push(['apply',o.id,structuredClone(e),loading]),dice:(row,column)=>{calls.push(['entry',row,column]);return column==='NumDice'?c.count??1:c.sides??6;},
   visual:row=>{calls.push(['entry',row,'VisualEffectID']);return c.visual??101;},roll:(...args)=>{calls.push(['roll',...args]);return c.roll??4;}};
  if(c.owner==='apply')assert.equal(await applyDamageShield(o,e,p,c.loading??0),result,JSON.stringify(c));
  else await resolveDamageShields(o,c.attacker===false?null:{id:100},p);
  assert.deepEqual(calls,expected,JSON.stringify(c));
 }
});
