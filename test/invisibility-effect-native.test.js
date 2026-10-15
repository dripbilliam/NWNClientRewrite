import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {invisibilityEffect,applyInvisibility,removeInvisibility} from '../src/invisibility_effect.js';
import {ModuleSession} from '../src/module_session.js';
import {concealmentEffect,applyConcealment} from '../src/concealment_effect.js';
import {defensiveChances} from '../src/combat_defense.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-invisibility-concealment-observations.json',import.meta.url)));
const project=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,spellId:e.spellId,creatorId:e.creatorId,casterLevel:e.casterLevel,showIcon:e.showIcon,exposed:Number(e.exposed),integers:e.integers});
test('invisibility constructors, list membership and source-sensitive removal match original instructions',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],actor={id:99,objectType:c.objectType??5},effect={id:'000000000000004d',type:c.mode==='concealApply'?76:47,subtype:8,durationType:c.durationType??2,
    spellId:11,creatorId:98,casterLevel:7,showIcon:c.showIcon??1,exposed:true,integers:[c.mode==='concealApply'?c.amount:c.kind??1,28,...Array(6).fill(0)]},
    effects=(c.effects??[]).map((e,i)=>e.samePointer?effect:{type:e.type,id:BigInt(e.id??10+i).toString(16).padStart(16,'0')}),p={effects:()=>effects,dead:()=>c.dead??0,
    addInvisible:id=>calls.push(['addInvisible',id]),removeInvisible:id=>calls.push(['removeInvisible',id]),
    copy:(e,icons)=>({...structuredClone(e),exposed:false,showIcon:icons?e.showIcon:0}),apply:(_o,e,loading)=>calls.push(['apply',project(e),loading])};
    if(['constructor','concealConstructor'].includes(c.mode)){
      const invalid=()=>({id:'0000000000000064',type:0,subtype:0,durationType:0,spellId:-1,creatorId:0x7f000000,casterLevel:-1,showIcon:1,exposed:1,integers:Array(8).fill(0)});
      const provider={invalid,create:(type,creatorId,ints,subtype)=>({...invalid(),type,creatorId,integers:[...ints,...Array(8-ints.length).fill(0)],subtype})},
        e=c.mode==='concealConstructor'?concealmentEffect(c.amount,c.argc===1?0:c.kind,99,provider):invisibilityEffect(c.kind,99,provider);
      assert.deepEqual(project(e),row.output,JSON.stringify(c));continue;
    }
    const result=c.mode==='remove'?removeInvisibility(actor,effect,p):await(c.mode==='concealApply'?applyConcealment:applyInvisibility)(actor,effect,p,c.loading??0);
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
  }
});
test('live concealment reaches the existing combat defense owner with native ranged/melee selection',async()=>{
  const s=new ModuleSession(null),attacker=s.register('creature','attacker',{authored:{Race:6}}),target=s.register('creature','target',{authored:{Race:6}}),
    e=s.commands.EffectConcealment([50,1],{self:0x7f000000}),p={effects:o=>o.effects,hasFeat:()=>0};
  await s.effects.apply(2,e,target.id);assert.equal(s.commands.GetEffectType([e]),72);
  assert.deepEqual(await defensiveChances(attacker,target,{ranged:0},{},p),{missChance:0,concealment:0});
  assert.deepEqual(await defensiveChances(attacker,target,{ranged:1},{},p),{missChance:0,concealment:50});
  await s.effects.remove(target.id,e.id);assert.deepEqual(await defensiveChances(attacker,target,{ranged:1},{},p),{missChance:0,concealment:0});
  assert.equal(target.effects.length,0);assert.equal(target.nativeEffectIcons778.records.length,0);
});
test('live invisibility shares the observer rules and keeps module membership until the last source is removed',async()=>{
  const s=new ModuleSession(null);s.module=s.register('module','module',{});
  const actor=s.register('creature','actor',{authored:{Race:6},position:[0,0,0]}),viewer=s.register('creature','viewer',{authored:{Race:6},position:[1,0,0]}),frame={self:0x7f000000};
  const normal=s.commands.EffectInvisibility([1],frame),darkness=s.commands.EffectInvisibility([2],frame);
  await s.effects.apply(2,normal,actor.id);await s.effects.apply(2,darkness,actor.id);
  assert.deepEqual(s.module.nativeInvisibleCreatureIds330,[actor.id]);assert.equal(await s.combat.invisible(actor,viewer),1);
  viewer.visionFlags=2;assert.equal(await s.combat.invisible(actor,viewer),1,'darkvision does not see through normal invisibility');
  await s.effects.remove(actor.id,normal.id);assert.deepEqual(s.module.nativeInvisibleCreatureIds330,[actor.id]);assert.equal(await s.combat.invisible(actor,viewer),0);
  viewer.visionFlags=0;assert.equal(await s.combat.invisible(actor,viewer),1);
  await s.effects.remove(actor.id,darkness.id);assert.deepEqual(s.module.nativeInvisibleCreatureIds330,[]);assert.equal(await s.combat.invisible(actor,viewer),0);assert.equal(actor.effects.length,0);
  assert.equal(actor.nativeEffectIcons778.records.length,0);assert.equal(s.registry.get(actor.id),actor);
});
