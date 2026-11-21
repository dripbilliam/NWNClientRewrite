import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {clientBodyTransition,clientAnimationCategory} from '../src/client_body_transition.js';

test('generic body and ambient transition choices match31684 executions of the native base-state owner',()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-body-transition-observations.json',import.meta.url)));
  assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
  assert.equal(oracle.observations.length,31684);
  for(const o of oracle.observations)assert.deepEqual(clientBodyTransition(o.previous,o.requested),o.calls,JSON.stringify(o));
  assert.equal(clientBodyTransition(171,6),null);
});
test('native loop classification matches1712 original WORD/BYTE category executions',()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-body-transition-observations.json',import.meta.url)));
  assert.equal(oracle.categories.length,1712);
  for(const row of oracle.categories)assert.equal(clientAnimationCategory(row.kind,row.animation),row.category,JSON.stringify(row));
});
