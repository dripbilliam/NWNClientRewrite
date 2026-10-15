import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applySpellResistanceEffect,removeSpellResistanceEffect,applySpellProtectionEffect} from '../src/spell_defense_effect.js';
import {applyEffectIcon,removeEffectIcon} from '../src/effect_icon.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-defense-effect-observations.json',import.meta.url)));
const types=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-effect-script-type-observations-v2.json',import.meta.url)));
const project=e=>({type:e.type,subtype:e.subtype??0,durationType:e.durationType,integers:e.integers,creatorId:e.creatorId});
test('spell defense constructors, cache handlers and icon lifecycle compare with original instructions',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],actor={objectType:c.objectType??5,nativeSpellResistanceIncreaseD84:(c.increase??0)&255,nativeSpellResistanceDecreaseD85:(c.decrease??0)&255,combatInformationDirty:0,nativeFlag8b0:0,nativeFlag8b4:0,
      nativeEffectIcons778:{records:(c.icons??[]).map(([iconId,state,permanent])=>({iconId,state,permanent})),capacity:c.capacity??16}},
      effect={type:c.type,id:String(c.id??1),durationType:c.durationType??2,showIcon:c.showIcon??1,integers:Array(8).fill(0),bypassImmunity:c.bypass??0,creatorId:99};
    (c.integers??[c.amount??1,0,0,c.kind??0]).forEach((v,i)=>effect.integers[i]=v);
    actor.effects=(c.effects??[]).map((e,i)=>e.samePointer?effect:{...structuredClone(e),id:String(e.id??i+2)});
    const p={dead:()=>c.dead??0,plot:()=>c.plot??0,object:()=>c.sourceExists===false?null:{objectType:5},
      immunity:(_o,id)=>{calls.push(['immunity',id]);return c.immune??0;},resistance:()=>{calls.push(['resistance']);return c.totalResistance??0;},effects:o=>o.effects,
      setCache:(o,down,value)=>{calls.push(['cache',down,value]);o[down?'nativeSpellResistanceDecreaseD85':'nativeSpellResistanceIncreaseD84']=value;},
      applyIcon:(_o,e,loading)=>calls.push(['icon',project(e),loading])};let result=0,output=null;
    if(c.mode==='constructor'){
      const s=new ModuleSession(null),o=s.register('creature','caster',{});s.characterRules={spells:{orderedRows:Array(840)}};
      const name=({33:'EffectSpellResistanceIncrease',34:'EffectSpellResistanceDecrease',50:'EffectSpellImmunity',65:'EffectSpellLevelAbsorption'})[c.type];
      const e=s.commands[name](c.args,{self:o.id});output=project(e);if(e.creatorId===o.id)output.creatorId=99;
    }else if(c.mode==='apply')result=await([33,34].includes(c.type)?applySpellResistanceEffect:applySpellProtectionEffect)(actor,effect,p,c.loading??0);
    else if(c.mode==='remove')result=removeSpellResistanceEffect(actor,effect,p);
    else result=(c.mode==='iconApply'?applyEffectIcon:removeEffectIcon)(actor,effect);
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(output,row.output,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
    assert.equal(actor.nativeSpellResistanceIncreaseD84,row.increase,JSON.stringify(c));assert.equal(actor.nativeSpellResistanceDecreaseD85,row.decrease,JSON.stringify(c));
    assert.equal(actor.combatInformationDirty,row.dirty,JSON.stringify(c));assert.equal(effect.integers[1],row.integer1,JSON.stringify(c));
    assert.equal(actor.nativeEffectIcons778.capacity,row.capacity,JSON.stringify(c));assert.deepEqual(actor.nativeEffectIcons778.records.map(r=>[r.iconId,r.state,r.permanent]),row.icons,JSON.stringify(c));
    assert.equal(actor.nativeFlag8b0,row.flag20,JSON.stringify(c));assert.equal(actor.nativeFlag8b4,row.flag21,JSON.stringify(c));
  }
});
test('new protection and icon public effect types match the original query owner',()=>{
  const s=new ModuleSession(null);
  for(const row of types.rows.filter(r=>[33,34,40,50,65,67].includes(r.type)))assert.equal(s.commands.GetEffectType([{type:row.type,integers:[0,0,0,row.integer3??0]},row.all]),row.value);
});
