import test from 'node:test';
import assert from 'node:assert/strict';
import {parse2da} from '../src/area.js';
import {deathBlockedByImmunity,preserveDeathEffect,deathVisualType} from '../src/death_effects.js';
test('death immunity gates magic subtype and INT bypass then queries category32 before the spell ID gate',async()=>{
  const actor={id:1},creator={id:2},effect={subtype:8,bypassImmunity:0,spellId:3,creatorId:2},trace=[];
  const p={creature:id=>{trace.push(['creator',id]);return creator;},immunity:(...args)=>{trace.push(['immunity',...args]);return 1;},
    feedback:(...args)=>{trace.push(['feedback',args[0],args[1],structuredClone(args[2])]);args[2].objects[0]=99;}};
  assert.equal(await deathBlockedByImmunity(actor,effect,p),true);
  assert.deepEqual(trace,[['creator',2],['immunity',actor,32,creator,1],['feedback',creator,127,{type:0,objects:[1]}],['feedback',actor,127,{type:0,objects:[1]}]]);
  trace.length=0;effect.spellId=-1;assert.equal(await deathBlockedByImmunity(actor,effect,p),false);assert.equal(trace.length,2);
  trace.length=0;effect.bypassImmunity=2;assert.equal(await deathBlockedByImmunity(actor,effect,p),false);assert.equal(trace.length,0);
  effect.bypassImmunity=0;effect.subtype=32;assert.equal(await deathBlockedByImmunity(actor,effect,p),false);assert.equal(trace.length,0);
});
test('death immunity sends victim-only feedback for an absent caster and does not block an unsuccessful immunity check',async()=>{
  const effect={subtype:9,bypassImmunity:0,spellId:7,creatorId:0x7f000000},actor={id:3},trace=[];
  const p={creature:()=>null,immunity:()=>1,feedback:(...args)=>trace.push(args)};
  assert.equal(await deathBlockedByImmunity(actor,effect,p),true);assert.deepEqual(trace,[[actor,127,{type:0,objects:[3]}]]);
  p.immunity=()=>0;trace.length=0;assert.equal(await deathBlockedByImmunity(actor,effect,p),false);assert.equal(trace.length,0);
});
test('death purge uses low duration/subtype bits and exact effect exceptions',()=>{
  const effect={durationType:0,type:22,subtype:0},p={visualType:()=>assert.fail('Nonvisual lookup')};
  for(const duration of [3,4,11,12])assert.equal(preserveDeathEffect({...effect,durationType:duration},p),true);
  assert.equal(preserveDeathEffect({...effect,type:32},p),true);
  for(const type of [8,9,23])assert.equal(preserveDeathEffect({...effect,type,subtype:35},p),false);
  assert.equal(preserveDeathEffect({...effect,subtype:35},p),true);assert.equal(preserveDeathEffect(effect,p),false);
});
test('death visual preservation uses active physical rows, exact B NUL bytes and lookup success',()=>{
  const table=parse2da('2DA V2.0\nDEFAULT: B\n\nType_FD\n900 B\n12 BO\n88 ****'),effect={type:30,subtype:0,durationType:0,integers:[0]};
  const p={visualType:id=>deathVisualType(table,id)};assert.equal(preserveDeathEffect(effect,p),true);
  effect.integers[0]=1;assert.equal(preserveDeathEffect(effect,p),false);
  effect.integers[0]=2;assert.equal(preserveDeathEffect(effect,p),false);
  effect.integers[0]=900;assert.equal(preserveDeathEffect(effect,p),false);
  table.orderedRows[0].Type_FD='B\0suffix';effect.integers[0]=0;assert.equal(preserveDeathEffect(effect,p),true);
  assert.throws(()=>deathVisualType(null,0),/unavailable/);
});
