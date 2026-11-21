import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeCreatureImmortality,importCreatureImmortality,getCreatureImmortal,setCreatureImmortal} from '../src/creature_immortality.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffField,gffRecord} from '../src/gff_writer.js';
import {ModuleSession} from '../src/module_session.js';
import {applyEnchantment} from '../src/enchantment_effect.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-creature-immortality-observations.json',import.meta.url)));
test('368 original immortality wrapper/load cases preserve raw script INTs and Boolean BYTE import',()=>{
 assert.equal(native.rows.length,368);
 for(const row of native.rows){const c=row.case,actor={objectType:5,nativeFlag8b8:c.initial};initializeCreatureImmortality(actor);
  if(c.command.startsWith('load')){const value=c.fieldType===0?c.value&255:c.fieldType===1?(c.value<<24)>>24:c.fieldType===4?c.value>>>0:c.value;const fields=c.present?{IsImmortal:gffField(c.fieldType,value)}:{};const data=parseGff(writeGff('UTC ',gffRecord(fields))).root;importCreatureImmortality(actor,data);assert.equal(actor.nativeFlag8b8,row.stored);continue;}
  const calls=['popObject'];if(c.objectPop&&c.command==='set')calls.push('popInt');
  const popped=c.objectPop&&(c.command==='get'||c.intPop);
  if(popped){calls.push('lookup');if(c.command==='set')setCreatureImmortal(c.creature?actor:null,c.value);else{assert.equal(getCreatureImmortal(c.creature?actor:null),row.output|0);calls.push('push');}}
  assert.deepEqual(row.calls,calls);assert.equal(actor.nativeFlag8b8,row.stored);assert.equal(row.result,!popped?0xfffffd81:c.command==='get'&&!c.push?0xfffffd82:0);
 }
});
test('canonical creature immortality aliases raw state and diagnoses conflicting/unavailable values',()=>{
 const a={immortal:-1};initializeCreatureImmortality(a);assert.equal(a.nativeFlag8b8,-1);a.immortal=2;assert.equal(a.nativeFlag8b8,2);a.nativeFlag8b8=1;assert.equal(a.immortal,1);
 assert.throws(()=>initializeCreatureImmortality({nativeFlag8b8:1,immortal:0}),/Conflicting/);assert.throws(()=>getCreatureImmortal({objectType:5}),/unavailable/);assert.throws(()=>{a.immortal=true;},/unavailable/);
 assert.equal(getCreatureImmortal({objectType:4}),0);setCreatureImmortal(null,1);
});
test('script setter, getter and enchantment immunity see the same canonical field without allocating IDs',async()=>{
 const s=new ModuleSession(null),actor=s.register('creature','immortality',{authored:{IsImmortal:0}}),cursor=s.registry.nextObjectId[0];
 for(const value of[0,1,2,-1,256]){s.commands.SetImmortal([actor.id,value]);assert.equal(s.commands.GetImmortal([actor.id]),value);assert.equal(actor.immortal,value);
  if(value!==0){const p={plot:()=>0};assert.equal(await applyEnchantment(actor,{integers:[9],durationType:2},p),1);}
 }
 assert.equal(s.commands.GetImmortal([0x12345678]),0);s.commands.SetImmortal([0x12345678,1]);assert.equal(s.registry.nextObjectId[0],cursor);
});
