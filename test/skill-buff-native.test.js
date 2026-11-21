import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {applySkillBuff} from '../src/skill_buff_effect.js';
import {ModuleSession} from '../src/module_session.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-skill-buff-observations.json',import.meta.url)));
const snapshot=e=>({id:e.id,type:e.type,subtype:e.subtype,durationType:e.durationType,duration:e.duration,creatorId:e.creatorId,spellId:e.spellId,casterLevel:e.casterLevel,showIcon:Number(e.showIcon),exposed:Number(e.exposed),integers:e.integers.slice(0,8),bypassImmunity:e.bypassImmunity});
test('skill buffs match complete original magnitude/loading/dead/plot/immunity gates, cast order and copied icon metadata',async()=>{
 assert.equal(data.rows.length,552);
 for(const row of data.rows){const c=row.case,s=new ModuleSession(null),actor={},source={},trace=[],effect={...s.effects.create(c.type),id:'1234567800000011',creatorId:0x80000042,spellId:70,casterLevel:8,duration:9.25,durationType:c.duration??1,subtype:c.subtype??8,showIcon:c.showIcon??1,exposed:c.exposed??1,bypassImmunity:c.bypass??0,integers:[c.skill??255,c.amount??2,28,0,0,0,0,0]};
  const result=await applySkillBuff(actor,effect,{dead:()=>{trace.push(['dead']);return c.dead??0;},plot:()=>c.plot??0,asCreature:()=>{trace.push(['asCreature']);return(c.objectType??5)===5?actor:null;},creature:id=>{trace.push(['creature',id]);return c.source===false?null:source;},immunity:(_o,id,versus,flag)=>{trace.push(['immunity',id,Boolean(versus),flag]);return c.immune??0;},copyConstruct:(e,icons)=>{trace.push(['copy',icons]);return s.effects.copyConstruct(e,icons);},apply:(_o,e,loading)=>trace.push(['apply',snapshot(e),loading,0])},c.loading??0);
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(trace,row.trace,JSON.stringify(c));
 }
});
test('real skill increase application shares IDs with icon43, preserves overlapping grants, and cleans up the final icon',async()=>{
 const s=new ModuleSession(null),actor=s.register('creature','skill-icon',{stats:{currentHP:10}}),first=s.effects.create(55,undefined,[0,2]),second=s.effects.create(55,undefined,[0,3]);first.durationType=second.durationType=2;
 await s.effects.applyNative(first,actor.id);await s.effects.applyNative(second,actor.id);assert.equal(actor.nativeEffectIcons778.records.filter(r=>r.iconId===43).length,1);assert.equal(actor.effects.filter(e=>e.type===67&&e.integers[0]===43).length,2);assert.ok(actor.effects.some(e=>e.type===67&&e.id===first.id));
 await s.effects.remove(actor.id,first.id);assert.ok(!actor.effects.some(e=>e.id===first.id));assert.equal(actor.nativeEffectIcons778.records.filter(r=>r.iconId===43).length,1);await s.effects.remove(actor.id,second.id);assert.ok(!actor.nativeEffectIcons778.records.some(r=>r.iconId===43));
});
test('real skill application admits zero on dead creatures outside loading and keeps equipped icons even when hidden',async()=>{
 for(const[durationType,loading,showIcon]of[[1,0,1],[3,1,0]]){const s=new ModuleSession(null),actor=s.register('creature','dead-skill-icon',{stats:{currentHP:0}}),effect=s.effects.create(55,undefined,[0,0]);effect.durationType=durationType;effect.duration=6;effect.showIcon=showIcon;await s.effects.applyNative(effect,actor.id,undefined,loading);assert.ok(actor.effects.some(e=>e.type===55&&e.id===effect.id));assert.ok(actor.nativeEffectIcons778.records.some(r=>r.iconId===43));}
});
