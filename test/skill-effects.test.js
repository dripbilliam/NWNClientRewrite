import test from 'node:test';
import assert from 'node:assert/strict';
import { skillEffectBonus } from '../src/combat_modifiers.js';
import { getBlind } from '../src/perception.js';
import { ModuleSession } from '../src/module_session.js';
import { parse2da } from '../src/area.js';
const effect=(type,skill,amount,other={})=>({type,integers:[skill,amount,28,0,0],spellId:-1,...other});
test('skill effects use skill zero specifically and 255 for all; amount is integer one',()=>{
  const effects=[effect(55,0,3),effect(55,10,7),effect(55,255,2),effect(56,10,4)];
  assert.equal(skillEffectBonus(effects,[],0).total,5);assert.equal(skillEffectBonus(effects,[],10).total,5);
  assert.equal(skillEffectBonus(effects,[],16).total,2);
});
test('same spell/item retains strongest skill modifier, while unsourced effects and distinct canonical items stack',()=>{
  const items=[{id:11},{id:12}],effects=[effect(55,10,3,{spellId:4}),effect(55,10,6,{spellId:4}),effect(55,10,2),effect(55,10,1),
    effect(55,10,3,{creatorId:11}),effect(55,255,5,{creatorId:11}),effect(55,10,4,{creatorId:12})];
  assert.equal(skillEffectBonus(effects,items,10).total,18);
});
test('skill increase/decrease totals cap separately and filter opponent race/alignment',()=>{
  const effects=[effect(55,10,60),effect(56,10,52),effect(55,10,4,{integers:[10,4,6,1,1]})];
  assert.deepEqual(skillEffectBonus(effects,[],10),{increase:50,decrease:50,total:0});
  assert.deepEqual(skillEffectBonus(effects,[],10,{target:{race:6,lawChaos:1,goodEvil:1},limit:100}),{increase:64,decrease:52,total:12});
});
test('skill sources have independent fifty-slot limits, including accepted zero-valued records',()=>{
  const effects=Array.from({length:50},()=>effect(55,10,0));effects.push(effect(55,10,10),effect(56,10,4));
  assert.equal(skillEffectBonus(effects,[],10).total,-4);
  assert.throws(()=>skillEffectBonus([effect(55,10,-1)],[],10),/magnitude/);
});
test('native blindness vision overrides precede explicit and ambient blindness flags',()=>{
  for(const flags of [0,2,4,0x24,255,0x14,0x30])assert.equal(getBlind({visionFlags:flags}),0,flags.toString(16));
  for(const flags of [8,0x10,0x18])assert.equal(getBlind({visionFlags:flags}),1);
  assert.equal(getBlind({visionFlags:10}),0);assert.throws(()=>getBlind({}),/flags/);
});
function fixture(){
  const s=new ModuleSession({}),rules={skills:parse2da('2DA V2.0\n\nKeyAbility Untrained ArmorCheckPenalty\n'+Array.from({length:27},(_,i)=>`${i} DEX 1 0`).join('\n'))};s.characterRules=rules;
  const pc=s.register('player','pc',{isPC:true,stats:{currentHP:20,feats:[],skills:Array(27).fill(0)},authored:{Race:6,GoodEvil:50,LawfulChaotic:50,ClassList:[]}});s.player=pc;
  return{s,pc,frame:{self:pc.id}};
}
test('skill constructors validate active table count, preserve zero/negative magnitudes and accept native all-skills ID',()=>{
  const{s,pc,frame}=fixture();const buff=s.commands.EffectSkillIncrease([10,0],frame);assert.equal(buff.type,55);assert.equal(buff.creatorId,pc.id);assert.deepEqual(buff.integers,[10,0,28,0,0]);
  assert.equal(s.commands.EffectSkillDecrease([255,-3],frame).type,56);
  assert.equal(s.commands.GetEffectType([buff]),54);assert.equal(s.commands.GetEffectType([s.commands.EffectSkillDecrease([255,2],frame)]),55);
  for(const skill of [-1,27,256])assert.equal(s.commands.EffectSkillIncrease([skill,3],frame).type,0);
});
test('live skill modifiers preserve canonical identity, stack zero records, and remain until deferred removal',async()=>{
  const{s,pc,frame}=fixture(),id=pc.id,stats=pc.stats;
  const zero=s.commands.EffectSkillIncrease([10,0],frame),buff=s.commands.EffectSkillIncrease([10,5],frame),penalty=s.commands.EffectSkillDecrease([10,2],frame);
  for(const e of [zero,buff,penalty])s.commands.ApplyEffectToObject([2,e,id]);
  assert.equal(pc.effects.length,3);assert.equal(skillEffectBonus(pc.effects,[],10).total,3);
  s.commands.RemoveEffect([id,buff],frame);assert.equal(skillEffectBonus(pc.effects,[],10).total,3);
  await s.scheduler.pump();assert.equal(skillEffectBonus(pc.effects,[],10).total,-2);assert.equal(s.registry.get(id),pc);assert.equal(pc.stats,stats);
  pc.plot=true;s.commands.ApplyEffectToObject([2,s.commands.EffectSkillDecrease([10,8],frame),id]);assert.equal(pc.effects.length,2);
});
test('skill decrease immunity prevents new effects while retaining existing penalties; negative magnitudes are rejected on apply',()=>{
  const{s,pc,frame}=fixture();const old=s.commands.EffectSkillDecrease([10,2],frame);s.commands.ApplyEffectToObject([2,old,pc.id]);
  pc.effects.push(s.effects.create(22,pc.id,[27,28,0,0]));
  s.commands.ApplyEffectToObject([2,s.commands.EffectSkillDecrease([10,5],frame),pc.id]);
  s.commands.ApplyEffectToObject([2,s.commands.EffectSkillIncrease([10,-2],frame),pc.id]);
  assert.equal(pc.effects.length,2);assert.equal(skillEffectBonus(pc.effects,[],10).total,-2);
  const bypass=s.commands.EffectSkillDecrease([10,5],frame);bypass.bypassImmunity=true;s.effects.apply(2,bypass,pc.id);assert.equal(pc.effects.length,3);
});
test('live skill source stacking resolves unequipped canonical items through the object registry',()=>{
  const{s,pc}=fixture(),item=s.register('item','item',{authored:{},equipmentSlot:0});
  pc.effects=[effect(55,10,3,{creatorId:item.id}),effect(55,10,5,{creatorId:item.id})];
  assert.equal(s.combat.skillProviders().effectBonus(pc,10,null),5);
  s.unregister(item.id);assert.equal(s.combat.skillProviders().effectBonus(pc,10,null),8,'Deleted item no longer resolves as an item source');
});
test('conditional skill effects use only creature subjects or an AoE creator; ordinary objects are not neutral creatures',()=>{
  const{s,pc}=fixture(),door=s.register('door','door',{authored:{}}),aoe=s.register('areaOfEffect','aoe',{creatorId:pc.id}),p=s.combat.skillProviders();
  pc.effects=[effect(55,10,3,{integers:[10,3,28,1,1]})];
  assert.equal(p.effectBonus(pc,10,door),0);assert.equal(p.effectBonus(pc,10,pc),3);assert.equal(p.effectBonus(pc,10,aoe),3);
  delete aoe.creatorId;assert.throws(()=>p.effectBonus(pc,10,aoe),/creator/);
  assert.equal(skillEffectBonus([effect(55,10,3,{integers:[10,3,-1,-1,-1]})],[],10).total,3,'Native missing-subject sentinels are all -1');
});
