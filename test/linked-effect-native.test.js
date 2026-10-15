import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {updateLinked,applyLinkedEffect,withScriptSubtype} from '../src/linked_effect.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-linked-effect-observations.json',import.meta.url)));
test('linked effect recursion, metadata propagation, IDs and child application order match native owners',async()=>{
  for(const row of oracle.rows){const c=row.case,effect=structuredClone(c.effect),calls=[],p={
    setCreator:(e,id)=>{e.creatorId=id;if(e.spellId===-1)e.spellId=70;if(e.casterLevel===-1)e.casterLevel=8;},
    apply:(_actor,e,loading)=>calls.push({effect:structuredClone(e),loading,flag:0})};
    if(c.mode==='update')updateLinked(effect,c.icons,p);else await applyLinkedEffect({},effect,p,c.loading);
    assert.deepEqual(effect,row.effect,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
  }
});

test('Subtype wrappers preserve packed flags and update linked metadata exactly like original dispatch',()=>{
  const rows=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-linked-effect-observations-v2.json',import.meta.url))).rows;
  const project=e=>{const {type,...rest}=e;for(const key of ['linkLeft','linkRight'])if(rest[key])rest[key]=project(rest[key]);return rest;};
  for(const row of rows.filter(r=>r.case.mode==='subtype')){
    const before=structuredClone(row.case.effect),result=withScriptSubtype(before,row.case.ordinal,{setCreator:(e,id)=>{e.creatorId=id;if(e.spellId===-1)e.spellId=70;if(e.casterLevel===-1)e.casterLevel=8;}});
    assert.deepEqual(project(result),row.effect,JSON.stringify(row.case));assert.deepEqual(before,row.case.effect,'VM argument value survives subtype conversion');
  }
});
test('live linked resistance and looping visual share one ID and expire together',async()=>{
  const s=new ModuleSession(null),caster=s.register('creature','caster',{authored:{ClassList:[],FeatList:[]}}),target=s.register('creature','target',{authored:{ClassList:[],FeatList:[]}});
  s.characterRules={visualeffects:{orderedRows:[{Type_FD:'B'}],columns:['Type_FD']}};
  const frame={self:caster.id},resistance=s.commands.EffectSpellResistanceIncrease([20],frame),visual=s.commands.EffectVisualEffect([0],frame),linked=s.commands.EffectLinkEffects([resistance,visual],frame);
  assert.notEqual(resistance.id,linked.id);assert.notEqual(visual.id,linked.id);
  await s.effects.apply(1,linked,target.id,2);
  assert.deepEqual(target.effects.map(e=>e.type),[30,33,67]);assert.ok(target.effects.every(e=>e.id===linked.id));
  assert.equal(s.commands.GetSpellResistance([target.id]),20);assert.equal(target.nativeLoopingVisuals160.records.length,1);assert.equal(target.nativeEffectIcons778.records.length,1);
  s.scheduler.time=2001;await s.effects.updateObject(target);
  assert.equal(target.effects.length,0);assert.equal(target.nativeLoopingVisuals160.records.length,0);assert.equal(target.nativeEffectIcons778.records.length,0);assert.equal(s.commands.GetSpellResistance([target.id]),0);
});
