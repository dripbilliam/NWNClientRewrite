import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {clientProjectileTargetPrefix,setClientProjectileTarget} from '../src/client_projectile_target.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-projectile-target-observations.json',import.meta.url)));

test('native model-prefix installation and target setter match all original type/name/ID cases',()=>{
 for(const row of native.rows){const c=row.case,state={targetId:123,impactNode:'old'},target=c.kind?{objectType:c.kind}:null;
  const prefix=clientProjectileTargetPrefix(c.kind,c.model?c.name:null);if([9,10].includes(c.kind))assert.equal(prefix,row.prefix,JSON.stringify(c));
  let queries=0;setClientProjectileTarget(state,c.targetId,c.node,{object:id=>{queries++;assert.equal(id,c.targetId);return target;},targetPrefix:()=>prefix});
  assert.equal(queries,1);assert.equal(state.targetId,row.targetId);assert.equal(state.impactNode,row.impactNode,JSON.stringify(c));assert.equal(row.inputCleared,true);
 }
 assert.equal(native.rows.length,768);
});
