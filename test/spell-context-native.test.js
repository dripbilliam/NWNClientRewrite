import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {initializeSpellContext,scriptSpellContext,spellTargetLocation} from '../src/spell_context.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-spell-context-observations.json',import.meta.url)));
assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
test('spell context defaults match original constructor stores, preserving supplied fields and independent history',()=>{
  const o={objectType:5};initializeSpellContext(o);delete o.objectType;
  assert.deepEqual(o,oracle.rows[0].fields);assert.equal(Object.hasOwn(o,'nativeSpellProjectileTime220'),false);
  o.nativeSpellId218=9;o.nativeLastSpell234=3;initializeSpellContext({...o,objectType:5});
  assert.equal(scriptSpellContext({...o,objectType:5},'GetSpellId'),9);
  assert.equal(scriptSpellContext({...o,objectType:5},'GetLastSpell'),3);
});
test('scalar spell context queries match original type gates, defaults and signed feat WORD',()=>{
  for(const row of oracle.rows.filter(row=>row.case.command!=='initialize'&&row.case.command!=='GetSpellTargetLocation')){
    const c=row.case,o=c.exists?{objectType:c.objectType,nativeSpellId218:c.value|0,nativeSpellFeat23c:c.value&65535,
      nativeSpellSpontaneous228:c.value|0,nativeLastSpellCaster230:c.value>>>0,nativeLastSpell234:c.value|0,nativeLastSpellHarmful238:c.value|0,
      nativeSpellMetamagic22d:c.value&255,nativeSpellTarget818:c.value>>>0,nativeSpellTarget214:c.value>>>0}:null;
    assert.equal(scriptSpellContext(o,c.command,{validObjectScript:c.valid??1}),row.output,JSON.stringify(c));
    assert.equal(row.result,c.push===0?(-638>>>0):0);
  }
});
test('spell target location matches original object scope, cast-point/caster orientation and target-area fallback',()=>{
  for(const row of oracle.rows.filter(row=>row.case.command==='GetSpellTargetLocation')){
    const c=row.case,actor=c.exists?{objectType:c.objectType,nativeSpellTarget214:c.value,nativeSpellPoint208:[1.25,-2.5,7]}:null,target={};
    const location=spellTargetLocation(actor,{object:()=>c.targetExists===false?null:target,
      area:o=>o===actor?(c.actorArea===false?null:{id:0x80000002}):(c.targetArea===false?null:{id:0x80000003}),
      orientation:()=>[.5,-.25,0]},{validObjectScript:c.valid??1});
    assert.deepEqual(location,row.output,JSON.stringify(c));
  }
});
test('live metamagic/caster-item/target/location queries share canonical cast context',()=>{
  const s=new ModuleSession(null,{runStartupScripts:false}),area=s.register('area','area',{position:[0,0,0]}),target=s.register('door','target',{areaId:area.id});
  const o=s.register('creature','caster',{areaId:area.id,nativeSpellPoint208:[1,2,3],nativeSpellTarget214:target.id,nativeSpellMetamagic22d:16});
  const frame={self:o.id};assert.equal(s.commands.GetMetaMagicFeat([],frame),16);assert.equal(s.commands.GetSpellCasterItem([],frame),0x7f000000);
  assert.equal(s.commands.GetSpellTargetObject([],frame),target.id);
  assert.deepEqual(s.commands.GetSpellTargetLocation([],frame),{areaId:area.id,position:[1,2,3],nativeOrientation:[1,0,0],orientation:0});
});
test('session spell queries read canonical current/history fields rather than saving throw spell metadata',()=>{
  const session=new ModuleSession(null,{runStartupScripts:false}),o=session.register('creature','caster',{lastSpellId:333});
  assert.equal(session.commands.GetSpellId([],{self:o.id}),-1);
  o.nativeSpellId218=123;o.nativeLastSpell234=234;o.nativeSpellFeat23c=65000;
  assert.equal(session.commands.GetSpellId([],{self:o.id}),123);
  assert.equal(session.commands.GetLastSpell([],{self:o.id}),234);
  assert.equal(session.commands.GetSpellFeatId([],{self:o.id}),-536);
  assert.equal(o.lastSpellId,333);
  delete o.nativeSpellId218;assert.throws(()=>session.commands.GetSpellId([],{self:o.id}),/unavailable/);
});
