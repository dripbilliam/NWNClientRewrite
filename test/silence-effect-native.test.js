import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applySilence,removeSilence} from '../src/silence_effect.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-silence-effect-observations.json',import.meta.url)));
const project=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,spellId:e.spellId,creatorId:e.creatorId,casterLevel:e.casterLevel,showIcon:e.showIcon,exposed:Number(e.exposed),integers:e.integers});
test('silence admission, immunity feedback, linked children and cache removal match original instructions',async()=>{
  for(const row of oracle.rows){const c=row.case,calls=[],actor={id:99,objectType:c.objectType??5,nativeSilence75c:c.silenced??0},effect={id:'000000000000004d',type:46,subtype:8,durationType:c.durationType??2,
    spellId:11,creatorId:98,casterLevel:7,showIcon:c.showIcon??1,exposed:true,integers:Array(8).fill(0),bypassImmunity:c.bypass??0},p={
    dead:()=>c.dead??0,creature:()=>c.sourceExists===false?null:{id:98},immunity:(_o,id)=>{calls.push(['immunity',id]);return c.immune??0;},plot:()=>c.plot??0,
    feedback:(o,code,data)=>calls.push(['feedback',o.id,code,{objectIds:data.objects}]),copy:(e,icons)=>({...structuredClone(e),exposed:false,showIcon:icons?e.showIcon:0}),
    apply:(_o,e,loading)=>calls.push(['apply',project(e),loading])};
    const result=c.remove?removeSilence(actor):await applySilence(actor,effect,p,c.loading??0);
    assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(actor.nativeSilence75c,row.silenced,JSON.stringify(c));
  }
});
test('live overlapping silences retain linked AI masks while native removal clears the silence cache',async()=>{
  const s=new ModuleSession(null),actor=s.register('creature','actor',{stats:{equippedAbilities:{Dex:16}}}),frame={self:0x7f000000};s.characterRules={};
  const a=s.commands.EffectSilence([],frame),b=s.commands.EffectSilence([],frame);a.bypassImmunity=b.bypassImmunity=1;
  await s.effects.apply(2,a,actor.id);await s.effects.apply(2,b,actor.id);
  assert.equal(actor.nativeSilence75c,1);assert.equal(actor.nativeField8d4,65527);assert.equal(actor.effects.filter(e=>e.type===46).length,2);
  assert.equal(actor.nativeEffectIcons778.records.length,1);
  await s.effects.remove(actor.id,a.id);assert.equal(actor.nativeSilence75c,0,'native removal does not count remaining silence sources');
  assert.equal(actor.nativeField8d4,65527);assert.equal(actor.effects.filter(e=>e.type===46).length,1);
  await s.effects.remove(actor.id,b.id);assert.equal(actor.nativeField8d4,65535);assert.equal(actor.effects.length,0);assert.equal(actor.nativeEffectIcons778.records.length,0);
});
