import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyDamageBuff,applyDamageImmunityBuff,removeDamageBuff} from '../src/damage_buff_effect.js';
import {setDamageImmunity} from '../src/damage_effect.js';
import {ModuleSession} from '../src/module_session.js';
import {applyDamageShield} from '../src/damage_shield.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-damage-buff-observations.json',import.meta.url)));
test('damage bonuses, resistance/reduction, immunity admission/icons and pre-erase cache removal match original owners',async()=>{
 for(const row of oracle.rows){
  const c=row.case,actor={id:77,objectType:c.objectType,combatInformationDirty:0,cache:Array(32).fill(-7)},effect={type:c.type,integers:[...c.integers],creatorId:91,bypassImmunity:c.bypass,durationType:c.duration,exposed:c.exposed},calls=[];
  actor.effects=c.effects.map(e=>e.samePointer?effect:structuredClone(e));
  const p={dead:()=>{calls.push(['dead']);return c.dead;},plot:()=>c.plot,creature:id=>{calls.push(['creature',id]);return c.source?{}:null;},
   immunity:(_o,id,source,flag)=>{calls.push(['immunity',id,Boolean(source),flag]);return c.immune;},
   copyConstruct:(e,icons)=>{calls.push(['copy',icons]);return{...structuredClone(e),type:0,integers:Array(e.integers.length).fill(0)};},
   apply:(_o,e,loading)=>calls.push(['icon',{type:e.type,integers:e.integers},loading,0]),effects:o=>o.effects,
   setImmunity:(o,flags,total)=>{calls.push(['setImmunity',flags,total]);setDamageImmunity(o.cache,flags,total);},floaty:(o,id)=>calls.push(['floaty',id,o.id])};
  const result=c.mode==='remove'?removeDamageBuff(actor,effect,p):await(c.type===61?applyDamageShield:[16,17].includes(c.type)?applyDamageImmunityBuff:applyDamageBuff)(actor,effect,p,c.loading);
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(actor.cache,row.cache,JSON.stringify(c));assert.equal(actor.combatInformationDirty,row.dirty,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
test('live immunity sums exact flags and removes contributions with shared parent/icon identity',async()=>{
 const s=new ModuleSession(null),o=s.register('creature','target',{authored:{Race:0,GoodEvil:50,LawfulChaotic:50,FeatList:[]},stats:{feats:[],currentHP:10,temporaryHP:0,maxHP:10}}),f={self:o.id};s.characterRules={damagetypes:{orderedRows:Array(13)}};
 const first=s.commands.EffectDamageImmunityIncrease([256,70],f),second=s.commands.EffectDamageImmunityIncrease([256,60],f),down=s.commands.EffectDamageImmunityDecrease([256,40],f);
 for(const e of [first,second,down])await s.effects.apply(2,e,o.id);
 assert.equal(o.damageImmunityCache[8],90);assert.equal(o.effects.filter(e=>e.type===67&&e.integers[0]===116).length,2);assert.equal(o.effects.filter(e=>e.type===67&&e.integers[0]===125).length,1);
 for(const e of o.effects.filter(e=>e.type===67)){assert.ok([first.id,second.id,down.id].includes(e.id));assert.ok(e.integers.slice(1).every(v=>v===0));}
 await s.effects.remove(o.id,first.id);assert.equal(o.damageImmunityCache[8],20);assert.ok(o.nativeEffectIcons778.records.some(r=>r.iconId===116));
 await s.effects.remove(o.id,second.id);assert.equal(o.damageImmunityCache[8],-40);assert.equal(o.nativeEffectIcons778.records.some(r=>r.iconId===116),false);
 await s.effects.remove(o.id,down.id);assert.equal(o.damageImmunityCache[8],0);assert.deepEqual(o.effects,[]);assert.deepEqual(o.nativeEffectIcons778.records,[]);
 const mitigation=s.effects.create(2,o.id,[256,-1,-1,0],8);await s.effects.apply(2,mitigation,o.id);assert.deepEqual(o.effects.map(e=>e.type),[2,67]);assert.equal(o.effects[1].integers[0],1);await s.effects.remove(o.id,mitigation.id);assert.deepEqual(o.effects,[]);
});
