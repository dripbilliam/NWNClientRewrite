import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';

function fixture(){
 const s=new ModuleSession(null,{runStartupScripts:false});s.scheduler.beforePump=()=>{};s.isDead=()=>false;
 s.characterRules={visualeffects:parse2da('2DA V2.0\n\nType_FD\n'+Array.from({length:248},(_,i)=>`${i} ${i===100?'B':'D'}`).join('\n'))};
 s.module=s.register('module','module',{});const o=s.register('creature','actor',{position:[0,0,0]});
 s.combat.immunity=()=>0;return{s,o};
}
test('beam children share ownership and expire together',async()=>{
 const {s,o}=fixture(),e=s.commands.EffectBeam([100,o.id,1,0],{self:o.id});
 await s.effects.apply(1,e,o.id,2);assert.deepEqual(o.effects.map(e=>e.type),[30,32]);
 assert.ok(o.effects.every(row=>row.id===e.id));assert.equal(o.nativeLoopingVisuals160.records.length,1);
 s.scheduler.time=2000;await s.effects.updateObject(o);assert.equal(o.effects.length,2,'native expiry is strictly after the timestamp');
 s.scheduler.time=2001;await s.effects.updateObject(o);assert.equal(o.effects.length,0);assert.equal(o.nativeLoopingVisuals160.records.length,0);
 assert.equal(s.commands.EffectBeam([101,o.id,1,0],{self:o.id}).type,0);
});
test('overlapping blindness sources keep flags until their final linked removal',async()=>{
 const {s,o}=fixture(),a=s.commands.EffectBlindness([],{self:o.id}),b=s.commands.EffectBlindness([],{self:o.id});
 await s.effects.apply(2,a,o.id);await s.effects.apply(2,b,o.id);assert.equal(o.visionFlags,16);assert.equal(o.effects.filter(e=>e.type===75).length,2);
 await s.effects.remove(o.id,a.id);assert.equal(o.visionFlags,16);assert.equal(o.effects.filter(e=>e.type===75).length,1);
 await s.effects.remove(o.id,b.id);assert.equal(o.visionFlags,0);assert.equal(o.effects.length,0);assert.equal(o.nativeEffectIcons778.records.length,0);
});
test('special vision suppresses darkness and restores it only inside a canonical darkness volume',async()=>{
 for(const source of ['EffectUltravision','EffectTrueSeeing'])for(const inside of [false,true]){
  const {s,o}=fixture(),dark=s.commands.EffectDarkness([],{self:o.id}),vision=s.commands[source]([],{self:o.id});
  const aoe=s.register('areaOfEffect','darkness',{nativeAreaEffectId30c:36});if(inside)o.nativeSubareaMembership.append(aoe.id);
  await s.effects.apply(2,dark,o.id);assert.equal(o.visionFlags&8,8);assert.ok(o.effects.some(e=>e.type===75));
  await s.effects.apply(2,vision,o.id);assert.equal(o.visionFlags&8,0);assert.equal(o.effects.filter(e=>e.type===75).length,0);assert.ok(o.effects.some(e=>e.type===89));
  await s.effects.remove(o.id,vision.id);assert.equal(o.visionFlags&8,inside?8:0);assert.equal(o.effects.some(e=>e.type===75),inside);
  for(const id of new Set(o.effects.map(e=>e.id)))await s.effects.remove(o.id,id);
  assert.equal(o.visionFlags,0);assert.equal(o.effects.length,0);assert.equal(s.module.nativeInvisibleCreatureIds330.length,0);
 }
});
test('overlapping see-invisible sources retain detection until the last expires',async()=>{
 const {s,o}=fixture(),a=s.commands.EffectSeeInvisible([],{self:o.id}),b=s.commands.EffectSeeInvisible([],{self:o.id});
 await s.effects.apply(1,a,o.id,1);await s.effects.apply(1,b,o.id,2);assert.equal(o.visionFlags,1);
 s.scheduler.time=1001;await s.effects.updateObject(o);assert.equal(o.visionFlags,1);
 s.scheduler.time=2001;await s.effects.updateObject(o);assert.equal(o.visionFlags,0);assert.equal(o.effects.length,0);
});
test('dispelling defers linked removal and preserves other spells when only one ID is selected',async()=>{
 for(const best of [false,true]){
  const {s,o}=fixture();s.characterRules.spells=parse2da('2DA V2.0\n\nLabel\n0 EMPTY\n1 BLIND\n2 VISION');s.random.dice=()=>20;
  const blind=s.commands.EffectBlindness([],{self:OBJECT_INVALID}),vision=s.commands.EffectSeeInvisible([],{self:OBJECT_INVALID});blind.spellId=1;vision.spellId=2;
  await s.effects.apply(2,blind,o.id);await s.effects.apply(2,vision,o.id);assert.equal(o.visionFlags,17);const before=o.effects.length;
  const dispel=s.commands[best?'EffectDispelMagicBest':'EffectDispelMagicAll']([30],{self:OBJECT_INVALID});await s.effects.apply(0,dispel,o.id);
  assert.equal(o.effects.length,before,'removal must wait for its canonical event');assert.equal(s.scheduler.events.length,best?1:2);
  await s.scheduler.pump();assert.ok(!o.effects.some(e=>e.id===blind.id));assert.equal(o.effects.some(e=>e.id===vision.id),best);assert.equal(o.visionFlags,best?1:0);
 }
});
