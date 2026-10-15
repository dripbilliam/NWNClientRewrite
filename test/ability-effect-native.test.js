import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {abilityEffect,applyAbilityEffect,abilityEffectBonus,nativeAbilityScore,updateAbilityAttributes} from '../src/ability_effect.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-ability-effect-observations-v2.json',import.meta.url)));
test('Ability constructors, admission, source stacking and six stat getter arithmetic match original instructions',async()=>{
  for(const row of oracle.rows.filter(r=>r.case.mode!=='attribute')){const c=row.case,calls=[],actor={objectType:c.objectType??5},effect={type:c.type??36,creatorId:98,bypassImmunity:c.bypass??0,durationType:c.durationType??2,integers:[c.ability??0,c.amount??4,...Array(6).fill(0)]};let result=0,output=null;
    const p={create:(type,creatorId,ints,subtype)=>({type,creatorId,integers:[...ints,...Array(8-ints.length).fill(0)],subtype}),dead:()=>c.dead??0,dying:()=>c.dying??0,
      creature:()=>c.sourceExists===false?null:{id:98},immunity:(_o,id)=>{calls.push(['immunity',id]);return c.immune??0;},plot:()=>c.plot??0,
      score:(_o,id)=>{calls.push(['score',id]);return c.score??10;},copy:e=>structuredClone(e),apply:(_o,e,loading)=>calls.push(['icon',e.integers[0],loading]),
      item:id=>(c.items??[]).includes(id)?{id}:null,bonusLimit:()=>c.bonusLimit??12,penaltyLimit:()=>c.penaltyLimit??30};
    if(c.mode==='constructor')output=abilityEffect(c.type,c.ability,c.amount,99,p);
    else if(c.mode==='apply')result=await applyAbilityEffect(actor,effect,p,c.loading??0);
    else if(c.mode==='score')result=nativeAbilityScore(c.base??10,c.race??0,c.gain??0,c.bonus??0,{dex:c.ability===1,state:c.state??65535,mode:c.combatMode??0});
    else result=abilityEffectBonus(c.effects.map(e=>({type:e.type,creatorId:e.creator??98,spellId:e.spell??-1,integers:[e.ability??0,e.amount??4]})),c.ability,p).total;
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(output,row.output,JSON.stringify(c));
    assert.equal(effect.integers[1],row.amount,JSON.stringify(c));
  }
});

test('Live ability constructors and public enums use original layouts',()=>{
  const s=new ModuleSession(null),actor=s.register('creature','creator',{}),frame={self:actor.id};
  for(const row of oracle.rows.filter(r=>r.case.mode==='constructor')){
    const e=s.commands[row.case.type===36?'EffectAbilityIncrease':'EffectAbilityDecrease']([row.case.ability,row.case.amount],frame);
    assert.deepEqual({type:e.type,subtype:e.subtype,creatorId:99,integers:e.integers},row.output);
  }
  const types=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-effect-script-type-observations-v3.json',import.meta.url)));
  for(const row of types.rows.filter(r=>[36,37].includes(r.type)))assert.equal(s.commands.GetEffectType([{type:row.type},row.all]),row.value);
});

test('Post-effect ability caches, HP injury and death/dying transitions match original attribute owner',async()=>{
  const cells=['nativeStrModifierD39','nativeDexModifierD3b','nativeConModifierD3d','nativeIntModifierD3f','nativeWisModifierD41','nativeChaModifierD43'];
  for(const row of oracle.rows.filter(r=>r.case.mode==='attribute')){
    const c=row.case,calls=[],actor={id:99,hp:c.hp??100,nativeBodyState:c.body??0,nativeFieldEc:1,combatInformationDirty:0,nativeField544:0,...Object.fromEntries(cells.map(k=>[k,0]))},effect={type:36,creatorId:98,integers:[c.ability,4]};let reads=0;
    const p={dead:o=>Number(o.hp<(c.pc===false?1:-9)),dying:o=>Number(c.pc!==false&&o.hp<1&&o.hp>-10),
      maximumHP:()=>{calls.push(['maximum',++reads]);return reads===1?c.oldMaximum:c.newMaximum;},
      currentBaseHP:o=>{calls.push(['baseHP']);return o.hp;},writeBaseHP:(o,n)=>{o.hp=n;},score:(_o,n)=>{calls.push(['score',n]);return c.score??10;},
      modifier:n=>{calls.push(['modifier',n]);return Math.floor((n-10)/2);},encumbrance:(_o,n)=>calls.push(['encumbrance',n]),
      setAnimation:(_o,n)=>calls.push(['animation',n]),enqueueDying:()=>calls.push(['dying',99,66,10,32]),closePanels:(_o,n)=>calls.push(['closePanels',n]),
      create:(type,creatorId,_ints,subtype)=>({type,creatorId,subtype,integers:Array(8).fill(0)}),apply:(_o,e,n)=>calls.push(['apply',e,n])};
    await updateAbilityAttributes(actor,effect,p,c.loading??0);
    assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual({hp:actor.hp,body:actor.nativeBodyState,commandable:actor.nativeFieldEc,dirty:actor.combatInformationDirty,field544:actor.nativeField544,modifiers:cells.map(k=>actor[k])},row.attributes,JSON.stringify(c));
  }
});
