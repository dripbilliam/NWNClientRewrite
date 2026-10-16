import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyEnchantment,removeEnchantment,applyEnchantmentController,removeEnchantmentController} from '../src/enchantment_effect.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-enchantment-effect-observations-v2.json',import.meta.url)));
const project=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,spellId:e.spellId,creatorId:e.creatorId,casterLevel:e.casterLevel,showIcon:e.showIcon,exposed:Number(e.exposed),integers:e.integers});
const normalize=calls=>calls.map(a=>a[0].startsWith('owner')?a.slice(0,['owner1403d3680','owner1403d0c50'].includes(a[0])?a[0]==='owner1403d0c50'?4:3:2):a);

test('Enchantment priority, immunity, state controllers and removal match original handlers',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],actor={id:99,objectType:c.objectType??5,nativeField771:c.state??0,nativeFieldEc:c.commandable??1,
    nativeFlag8b8:c.immuneAll??0,associateType:c.associate??0,masterId:98,nativeField89c:0,nativeField54c:0,nativeField550:0},source={id:98},
    effect={id:'000000000000004d',type:c.type??8,subtype:c.subtype??8,durationType:c.durationType??2,spellId:c.spellId??11,creatorId:98,casterLevel:7,showIcon:c.showIcon??1,exposed:true,bypassImmunity:c.bypass??0,integers:Array(8).fill(0)};
    effect.integers[0]=c.kind??9;effect.integers[1]=c.integer1??0;let ids=100;
    let effects=(c.effects??[]).map((e,i)=>e.samePointer?effect:{type:e.type,id:BigInt(e.id??10+i).toString(16).padStart(16,'0'),creatorId:98,integers:[e.kind??0]});
    const p={effects:()=>effects,plot:()=>c.plot??0,dead:()=>c.dead??0,creature:()=>c.sourceExists===false?null:source,statsPC:()=>c.sourcePC??0,
      immunity:(_o,id)=>{calls.push(['immunity',id]);return c.immunities?.[id]??0;},feedback:(o,id,data)=>calls.push(['feedback',o.id,id,data]),
      copyConstruct:(e,icons)=>({...structuredClone(e),integers:Array(e.integers.length).fill(0),exposed:false,showIcon:icons?e.showIcon:0}),
      create:(type,creatorId,_ints,subtype)=>({id:BigInt(++ids).toString(16).padStart(16,'0'),type,creatorId,subtype,integers:Array(8).fill(0),durationType:0,spellId:-1,casterLevel:-1,showIcon:1,exposed:true}),
      apply:(_o,e,loading)=>calls.push(['apply',project(e),loading]),remove:(_o,e)=>{calls.push(['remove',e.id]);effects=effects.filter(x=>x.id!==e.id);},
      floaty:(_o,id)=>calls.push(['floaty',id,99]),clearActions:o=>calls.push(['clearActions',o.nativeFieldEc]),ambient:()=>calls.push(['ambient']),
      setLastHostile:(_o,id,flag)=>calls.push(['setLock',id,flag]),clearPersonal:(o,id)=>calls.push(['owner1403d3680',o.id,id]),
      addPersonal:(o,id,amount)=>calls.push(['owner1403d0c50',o.id,id,amount]),
      possessed:o=>{calls.push(['owner1403d54d0',o.id]);return 0;},clearVisible:o=>calls.push(['owner1403d3760',o.id]),updateVisible:o=>calls.push(['owner1403dba50',o.id]),
      refreshObservers:()=>{},removeDomination:o=>calls.push(['owner1403d70f0',o.id])};
    const result=await({apply:applyEnchantment,remove:removeEnchantment,controller:applyEnchantmentController,controllerRemove:removeEnchantmentController}[c.mode])(actor,effect,p,c.loading??0);
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(normalize(calls),normalize(row.calls),JSON.stringify(c));
    assert.equal(actor.nativeField771,row.state,JSON.stringify(c));assert.equal(actor.nativeFieldEc,row.commandable,JSON.stringify(c));
    assert.equal(actor.nativeField54c,row.field54c,JSON.stringify(c));assert.equal(actor.nativeField550,row.field550,JSON.stringify(c));
  }
});

test('live script queries expose control kinds and format raw canonical IDs as original lowercase unpadded hex',()=>{
  const s=new ModuleSession(null),types=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-effect-script-type-observations-v3.json',import.meta.url)));
  for(const row of types.rows.filter(r=>[1,3,8,28,29,59].includes(r.type)))assert.equal(s.commands.GetEffectType([{type:row.type,integers:[row.integer0??0]},row.all]),row.value,JSON.stringify(row));
  for(const [id,text] of [[0,'0'],[1,'1'],[565,'235'],[0x7f000000,'7f000000'],[-1,'ffffffff']])assert.equal(s.commands.ObjectToString([id]),text);
});

test('live Sleep supersedes paralysis and restores its remaining source before final expiry',async()=>{
  const s=new ModuleSession(null),o=s.register('creature','target',{position:[0,0,0],modelType:'P',stats:{currentHP:20,feats:[],equippedAbilities:{Dex:12}},authored:{ClassList:[],FeatList:[]}}),frame={self:o.id};
  const paralyze=s.commands.EffectParalyze([],frame),sleep=s.commands.EffectSleep([],frame);
  await s.effects.apply(2,paralyze,o.id);assert.equal(o.nativeField771,8);assert.equal(o.nativeFieldEc,0);assert.equal(o.nativeField8d4,65265);
  const firstController=o.effects.find(e=>e.type===9);assert.notEqual(firstController.id,paralyze.id);assert.equal(firstController.durationType,4);
  await s.effects.apply(1,sleep,o.id,1);assert.equal(o.nativeField771,9);assert.equal(o.animationState,6);assert.equal(o.nativeFieldEc,0);
  assert.equal(o.effects.filter(e=>e.type===9).length,1);assert.equal(o.nativeEffectIcons778.records[0].iconId,19);
  s.scheduler.time=1001;await s.effects.updateObject(o);
  assert.equal(o.nativeField771,8);assert.equal(o.nativeFieldEc,0);assert.equal(o.nativeField8d4,65265);
  const restored=o.effects.find(e=>e.type===9);assert.equal(restored.durationType,2);assert.equal(restored.spellId,-1);assert.notEqual(restored.id,firstController.id);
  await s.effects.remove(o.id,paralyze.id);assert.equal(o.nativeField771,0);assert.equal(o.nativeFieldEc,1);assert.equal(o.nativeField8d4,65535);
  assert.equal(o.effects.length,0);assert.equal(o.nativeEffectIcons778.records.length,0);assert.equal(o.animationState,0);
});
