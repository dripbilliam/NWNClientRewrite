import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {calculateSpellProjectileTime} from '../src/spell_projectile_time.js';
const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-spell-projectile-observations.json',import.meta.url)));
assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
test('spell travel timing matches original distance/log/path, inventory and missing-target branches',()=>{
  for(const row of oracle.rows){const c=row.case,trace=[],actor={nativeSpellId218:1,nativeSpellTarget214:c.location?0x7f000000:100,
    nativeSpellPoint208:c.to??[4,6,7],position:c.from??[1,2,3],nativeSpellProjectileTime220:777},target={position:c.to??[4,6,7]};
    const providers={spell:()=>c.spellExists===false?null:{useProjectile:c.projectile??1,projectilePath:c.defaultPath??0},
      asCreature:()=>c.creature===false?null:actor,item:()=>c.item?{}:null,
      inRepository:()=>{trace.push(['repository']);return c.repository??0;},equipped:()=>{trace.push(['equipped']);return c.equipped??0;},
      object:()=>c.targetExists===false?null:target,position:o=>o.position,zeroLogStatus:()=>trace.push(['log-exception',1])};
    calculateSpellProjectileTime(actor,c.path??0,providers);
    assert.equal(actor.nativeSpellProjectileTime220,row.time,JSON.stringify(c));assert.deepEqual(trace,row.calls,JSON.stringify(c));
  }
});
test('different final CPU travel times remain explicit and do not overwrite context',()=>{
  const actor={position:[0,0,0],nativeSpellId218:1,nativeSpellTarget214:0x7f000000,nativeSpellPoint208:[10,0,0],nativeSpellProjectileTime220:777};
  assert.throws(()=>calculateSpellProjectileTime(actor,0,{spell:()=>({useProjectile:1,projectilePath:0}),asCreature:()=>null,position:o=>o.position,logBranches:()=>[1,2]}),/CPU dispatch/);
  assert.equal(actor.nativeSpellProjectileTime220,777);
});
