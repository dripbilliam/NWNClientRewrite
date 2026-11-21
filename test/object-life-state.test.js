import test from 'node:test';
import assert from 'node:assert/strict';
import {nativeObjectDead,nativeObjectDying} from '../src/object_life_state.js';
import {ModuleSession} from '../src/module_session.js';
import {readFileSync} from 'node:fs';

test('death/dying values and HP/client query counts match432 complete native executions',()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-life-state-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.observations.length,216);
  for(const {case:c,result} of oracle.observations)for(const [name,fn] of [['dead',nativeObjectDead],['dying',nativeObjectDying]]){
    let hpQueries=0,clientQueries=0;const object={nativeField89c:c.pc},p={creature:o=>c.creature?o:null,
      hitPoints:()=>{hpQueries++;return c.hp;},possessedFamiliar:()=>{if((c.associate&65535)!==3)return 0;clientQueries++;return c.client;}};
    const value=Number(fn(object,p));assert.deepEqual({value,hpQueries,clientQueries},result[name],JSON.stringify({c,name}));
  }
});

test('native death threshold belongs to object INT89c and signed SHORT HP',()=>{
  const o={objectType:5,nativeField89c:0,isPC:true,statsIsPC:1},p={creature:o=>o.objectType===5?o:null,possessedFamiliar:()=>0,hitPoints:()=>-1};
  assert.equal(nativeObjectDead(o,p),true);assert.equal(nativeObjectDying(o,p),false);
  o.nativeField89c=-1;assert.equal(nativeObjectDead(o,p),false);assert.equal(nativeObjectDying(o,p),true);
  assert.equal(nativeObjectDead(o,{...p,hitPoints:()=>65526}),true);
  o.objectType=9;assert.equal(nativeObjectDead(o,p),true);assert.equal(nativeObjectDying(o,p),false);
});

test('dying HP query order preserves short-circuit and its second live read',()=>{
  const o={nativeField89c:1},trace=[],values=[-1,-10],p={creature:o=>o,possessedFamiliar:()=>{throw new Error('PC short-circuits possession query');},hitPoints:()=>{trace.push('hp');return values.shift();}};
  assert.equal(nativeObjectDying(o,p),false);assert.deepEqual(trace,['hp','hp']);
  values.push(1);trace.length=0;assert.equal(nativeObjectDying(o,p),false);assert.deepEqual(trace,['hp']);
});

test('session possessed familiar requires WORD associate3 and an actual controlling client',()=>{
  const s=new ModuleSession(null),o=s.register('creature','a',{isPC:true,isPossessedFamiliar:true,stats:{currentHP:-1}});
  assert.equal(o.nativeField89c,0);assert.equal(o.nativeField97c,0);
  assert.equal(s.isDead(o),true);assert.equal(s.isDying(o),false);
  o.associateType=65539;s.combat.broadcastProviders=()=>({client:()=>({object:o})});
  assert.equal(s.isDead(o),false);assert.equal(s.isDying(o),true);
  s.combat.broadcastProviders=()=>({client:()=>null});assert.equal(s.isDead(o),true);
});
