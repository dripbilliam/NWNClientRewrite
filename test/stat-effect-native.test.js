import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {applyStatEffect,removeStatEffect} from '../src/stat_effect.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-stat-effect-observations.json',import.meta.url)));
test('shared attack/save/AC admission, icons, signed caches and pre-erase removal match original owners',async()=>{
 for(const row of oracle.rows){
  const c=row.case,actor={objectType:c.objectType,combatInformationDirty:0,cache:structuredClone(c.cache)},effect={type:c.type,integers:[...c.integers],creatorId:91,bypassImmunity:c.bypass,durationType:c.duration},calls=[];
  actor.effects=c.effects.map(e=>e.samePointer?effect:structuredClone(e));
  const p={dead:()=>{calls.push(['dead']);return c.dead;},plot:()=>c.plot,creature:id=>{calls.push(['creature',id]);return c.source?{}:null;},
   immunity:(_o,id,source,flag)=>{calls.push(['immunity',id,Boolean(source),flag]);return c.immune;},
   copyConstruct:(e,icons)=>{calls.push(['copy',icons]);return{...structuredClone(e),type:0,integers:Array(e.integers.length).fill(0)};},apply:(_o,e,loading)=>calls.push(['icon',{type:e.type,integers:e.integers},loading,0]),
   armorCache:o=>o.cache,feedback:(_o,code,data)=>calls.push(['feedback',code,data]),effects:o=>o.effects};
  const result=c.mode==='apply'?await applyStatEffect(actor,effect,p,c.loading):removeStatEffect(actor,effect,p);
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(actor.cache,row.cache,JSON.stringify(c));assert.equal(actor.combatInformationDirty,row.dirty,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));
  if(c.mode==='remove')assert.equal(row.index,actor.effects.findIndex(e=>[48,49].includes(e.type))&65535);
 }
});
test('live conditional AC/save icons share full uint64 IDs and disappear with the parent group',async()=>{
 const s=new ModuleSession(null),o=s.register('creature','target',{authored:{ClassList:[],FeatList:[]}});o.stats={combat:{saves:{},finalBreakdown:{armor:{cache:{up:[0,0,0,0,0],down:[0,0,0,0,0]}}}}};
 s.refreshCombat=()=>{};const f={self:o.id},armor=s.commands.VersusAlignmentEffect([s.commands.EffectACIncrease([2,4],f),0,5]),save=s.commands.VersusAlignmentEffect([s.commands.EffectSavingThrowIncrease([0,2],f),0,5]);
 const group=s.commands.EffectLinkEffects([armor,save],f);group.durationType=1;group.duration=10;await s.effects.applyNative(group,o.id);
 assert.deepEqual(o.effects.map(e=>e.type),[26,48,67,67]);assert.ok(o.effects.every(e=>e.id===group.id));assert.deepEqual(o.effects.filter(e=>e.type===67).map(e=>e.integers[0]),[35,39]);
 assert.ok(o.effects.filter(e=>e.type===67).every(e=>e.integers.slice(1).every(v=>v===0)),'native copy constructor clears payload even with icon flag1');
 assert.deepEqual((o.acCache??o.stats.combat.finalBreakdown.armor.cache).up,[0,0,0,0,0],'conditional AC never enters generic BYTE cache');
 await s.effects.remove(o.id,group.id);assert.deepEqual(o.effects,[]);assert.deepEqual(o.nativeEffectIcons778.records,[]);
});
