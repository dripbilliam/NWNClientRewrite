import test from 'node:test';
import assert from 'node:assert/strict';
import { createCombatRound } from '../src/combat_round.js';
import { getFlanked, resolvePrecisionAttack } from '../src/combat_sneak.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture() {
  const a={id:1,areaId:5,position:[0,0,0],combatRound:createCombatRound(),feats:[221,455],classes:[]},t={id:2,areaId:5,position:[0,0,0],nativeAttackTarget724:invalid,attackActionTargetId:invalid,spellActionTargetId:invalid,nativeTarget740:invalid,feats:[],classes:[]};
  const data=a.combatRound.attacks[0],trace=[],hasFeat=(o,f)=>{trace.push(['feat',o.id,f]);return Number(o.feats.includes(f))};
  const p={hasFeat,visibility:()=>null,flatFooted:()=>{trace.push('flat');return 0},flanked:(a,t)=>getFlanked(a,t,hasFeat),classes:o=>o.classes,
    effectImmunity:(o,k)=>{trace.push(['immune',k]);return 0},message:(type,fields)=>({type,...fields})};
  return{a,t,data,p,trace};
}
test('native flanked query uses stored target IDs; attacker, area and defender spell references each veto it',()=>{
  const {a,t,p}=fixture();assert.equal(getFlanked(a,t,p.hasFeat),0);t.nativeAttackTarget724=9;assert.equal(getFlanked(a,t,p.hasFeat),1);
  for(const field of ['nativeAttackTarget724','attackActionTargetId','spellActionTargetId','nativeTarget740']){
    const previous=t[field];t[field]=a.id;assert.equal(getFlanked(a,t,p.hasFeat),0);t[field]=previous;
  }
  t.spellActionTargetId=a.areaId;assert.equal(getFlanked(a,t,p.hasFeat),0);t.spellActionTargetId=t.id;assert.equal(getFlanked(a,t,p.hasFeat),0);
  t.spellActionTargetId=invalid;t.feats=[950];assert.equal(getFlanked(a,t,p.hasFeat),0);
});
test('unseen precision attacks do not query flat-footed state, and sneak/death write distinct fields',async()=>{
  const{a,t,data,p,trace}=fixture();await resolvePrecisionAttack('sneak',a,t,{},p);await resolvePrecisionAttack('death',a,t,{},p);
  assert.equal(data.sneakAttack,1);assert.equal(data.deathAttack,1);assert.ok(!trace.includes('flat'));
});
test('ranged eligibility includes the ten-unit boundary and full height; seen flat-footed and flanked paths remain separate',async()=>{
  const{a,t,data,p}=fixture();data.ranged=1;t.position=[10,0,0];await resolvePrecisionAttack('sneak',a,t,{},p);assert.equal(data.sneakAttack,1);
  data.sneakAttack=0;t.position=[10,1,0];await resolvePrecisionAttack('sneak',a,t,{},p);assert.equal(data.sneakAttack,0);
  t.position=[0,0,0];p.visibility=()=>1;p.flatFooted=()=>1;await resolvePrecisionAttack('sneak',a,t,{},p);assert.equal(data.sneakAttack,1);
  data.sneakAttack=0;p.flatFooted=()=>0;t.nativeAttackTarget724=9;await resolvePrecisionAttack('sneak',a,t,{},p);assert.equal(data.sneakAttack,1);
});
test('improved uncanny dodge only blocks flanking until class-level difference; unseen eligibility survives it',async()=>{
  const{a,t,data,p}=fixture();t.feats=[251];p.visibility=()=>1;t.nativeAttackTarget724=9;t.classes=[{Class:8,ClassLevel:5}];a.classes=[{Class:8,ClassLevel:8},{Class:4,ClassLevel:20}];
  await resolvePrecisionAttack('sneak',a,t,{},p);assert.equal(data.sneakAttack,0);a.classes[0].ClassLevel=9;
  await resolvePrecisionAttack('sneak',a,t,{},p);assert.equal(data.sneakAttack,1);
  data.sneakAttack=0;a.classes[0].ClassLevel=1;p.visibility=()=>null;await resolvePrecisionAttack('sneak',a,t,{},p);assert.equal(data.sneakAttack,1);
});
test('precision immunity short-circuits critical immunity and emits native type-zero feedback',async()=>{
  const{a,t,data,p,trace}=fixture();p.effectImmunity=(o,k)=>{trace.push(['immune',k]);return 1};
  await resolvePrecisionAttack('sneak',a,t,{},p);assert.equal(data.sneakAttack,0);assert.deepEqual(data.lists[3],[{type:0,objects:[2],integers:[134]}]);
  assert.ok(!trace.some(x=>Array.isArray(x)&&x[0]==='immune'&&x[1]===31));
});
test('chain special attacks and featless actors return before perception; native eligibility epic ladder is preserved separately',async()=>{
  const{a,t,data,p}=fixture();p.visibility=()=>assert.fail('Unexpected perception query');data.attackType=868;
  await resolvePrecisionAttack('sneak',a,t,{},p);data.attackType=0;a.feats=[];await resolvePrecisionAttack('sneak',a,t,{},p);
  a.feats=[851];await resolvePrecisionAttack('sneak',a,t,{},p);assert.equal(data.sneakAttack,0);
  a.feats=[834];p.visibility=()=>null;await resolvePrecisionAttack('sneak',a,t,{},p);assert.equal(data.sneakAttack,1);
});
