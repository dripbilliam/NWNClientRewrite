import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {createCombatRound} from '../src/combat_round.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {addObjectAction} from '../src/object_actions.js';
import {applyKnockdown,removeAIStateEffect} from '../src/knockdown_effect.js';

function fixture(){
  const s=new ModuleSession(null);s.characterRules={};
  const actor=s.register('creature','actor',{position:[0,0,0],orientation:[1,0,0],stats:{currentHP:10,maxHP:10,feats:[],equippedAbilities:{Dex:12}},authored:{FeatList:[]},combatRound:createCombatRound(),modelType:'P'});
  return {s,actor,effect:()=>s.commands.EffectKnockdown([],{self:OBJECT_INVALID})};
}
test('instant knockdown becomes3s, pauses the round, cancels actions and retains a hidden linked record with the SAME64-bit ID',async()=>{
  const {s,actor,effect}=fixture(),e=effect();addObjectAction(actor.objectActionState,30,65535,[]);
  assert.equal(s.commands.GetEffectType([e]),0);assert.equal(s.commands.GetEffectType([e,1]),98);
  const death=s.commands.EffectDeath([],{self:actor.id});assert.equal(s.commands.GetEffectType([death]),0);assert.equal(s.commands.GetEffectType([death,1]),94);
  await s.effects.apply(0,e,actor.id);
  assert.deepEqual(actor.effects.map(x=>[x.id,x.type,x.duration,x.exposed]),[[e.id,20,3,true],[e.id,23,4.5,false]]);
  assert.equal(actor.nativeField8d4,0xfeff);assert.equal(actor.nativeDexModifierD3b,1);
  assert.equal(actor.nativeFieldEc,0);assert.equal(actor.objectActionState.list.count,0);
  assert.equal(actor.combatRound.paused,1);assert.equal(actor.combatRound.infinitePause,1);assert.equal(actor.combatRound.pausedBy,OBJECT_INVALID);
  assert.equal(actor.nativeBodyState,5);assert.equal(actor.animationState,7);
  assert.equal(e.durationType,0);assert.equal(e.duration,0);
  s.scheduler.time=3000;await s.effects.updateObject(actor);assert.equal(actor.effects.length,2);
  // Native expiry removes BY ID, so both linked records disappear at >3s.
  s.scheduler.time=3001;await s.effects.updateObject(actor);assert.equal(actor.effects.length,0);
  assert.equal(actor.nativeField8d4,65535);assert.equal(actor.nativeFieldEc,1);
  assert.equal(actor.combatRound.paused,0);assert.equal(actor.combatRound.infinitePause,0);assert.equal(actor.animationState,0);
});
test('explicit removal hides and later removes every linked record, while other effect IDs retain their masks',async()=>{
  const {s,actor,effect}=fixture(),a=effect(),b=effect();
  await s.effects.apply(2,a,actor.id);await s.effects.apply(2,b,actor.id);
  s.effects.requestRemoval(actor.id,a,OBJECT_INVALID);
  assert.ok(actor.effects.filter(x=>x.id===a.id).every(x=>x.exposed===false));
  await s.effects.remove(actor.id,a.id);
  assert.deepEqual(actor.effects.map(x=>x.id),[b.id,b.id]);assert.equal(actor.nativeField8d4,0xfeff);
  // The native removal callback restores commandability even when another
  // knockdown record remains. Preserve this quirk rather than inventing locks.
  assert.equal(actor.nativeFieldEc,1);
  await s.effects.remove(actor.id,b.id);assert.equal(actor.nativeField8d4,65535);
});
test('native knockdown direction uses creator lookup, normalized XYZ dot and body5/6',async()=>{
  for(const [kind,position,body,animation] of [['creature',[1,0,0],5,7],['creature',[-1,0,0],6,5],['creature',[0,2,0],6,5],['placeable',[1,0,0],6,5]]){
    const {s,actor,effect}=fixture(),creator=s.register(kind,'source',{position});
    const e=effect();e.creatorId=creator.id;await s.effects.apply(1,e,actor.id,2);
    assert.equal(actor.nativeBodyState,body);assert.equal(actor.animationState,animation);
  }
});
test('immunity feedback goes source then victim, plot consumes, dying retains without disabling control',async()=>{
  const source={id:2,objectType:5},actor={id:1,objectType:5,plot:false},e={type:20,id:'1',creatorId:2,durationType:0,duration:0,bypassImmunity:0},sent=[];
  const p={object:()=>source,immunity:()=>1,feedback:async(o,c,d)=>sent.push([o.id,c,d.objects[0]]),dying:()=>1};
  assert.equal(await applyKnockdown(actor,e,p),1);assert.deepEqual(sent,[[2,129,1],[1,129,1]]);assert.equal(e.duration,3);
  actor.plot=true;assert.equal(await applyKnockdown(actor,e,{...p,immunity:()=>0}),1);
  actor.plot=false;assert.equal(await applyKnockdown(actor,e,{...p,immunity:()=>0}),0);assert.equal(actor.nativeFieldEc,undefined);
  const item={objectType:6},instant={...e,durationType:0,duration:0};assert.equal(await applyKnockdown(item,instant,p),0);assert.equal(instant.durationType,1);
});
test('AI state removal preserves the dead zero WORD and excludes the current pointer before deletion',()=>{
  const effect={type:23,integers:[-257]},other={type:23,integers:[0xfffd]},actor={objectType:5,nativeField8d4:0,effects:[effect,other]},p={refreshDex:()=>{}};
  removeAIStateEffect(actor,effect,p);assert.equal(actor.nativeField8d4,0);
  actor.nativeField8d4=0xfeff;removeAIStateEffect(actor,effect,p);assert.equal(actor.nativeField8d4,0xfffd);
});
