import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {ListenExpression,ListenExpressions} from '../src/listen_expression.js';

test('native-emulated listening parser graphs, error codes and matcher/capture observations match',()=>{
  const native=JSON.parse(readFileSync(new URL('../backups/animations/native-listen-expression-observations.json',import.meta.url)));
  assert.equal(native.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
  for(const observation of native.observations){
    const e=new ListenExpression();e.caseSensitive=observation.caseSensitive;
    assert.equal(e.parse(observation.pattern),observation.parseResult,observation.pattern);
    assert.deepEqual(e.graph(),observation.nodes,observation.pattern);
    for(const item of observation.tests){
      const label=JSON.stringify([observation.caseSensitive,observation.pattern,item.text]);
      assert.equal(e.test(item.text,1),item.result,label);assert.deepEqual(e.matches,item.captures,label);
    }
  }
});
test('pattern updates reuse canonical owners and physical slots and only successful saved matches overwrite captures',()=>{
  const expressions=new ListenExpressions();assert.equal(expressions.set('hello',1),0);
  const e=expressions.entries[0];assert.equal(expressions.capacity,16);assert.equal(expressions.set('hello',1),1);
  assert.equal(e.test('HELLO'),1);assert.deepEqual(e.matches,['HELLO','HELLO']);
  assert.equal(e.test('hi'),0);assert.deepEqual(e.matches,['HELLO','HELLO']);
  expressions.set('hi',1);assert.equal(expressions.entries[0],e);assert.equal(expressions.count,1);
  assert.equal(e.test('hi',0),1);assert.deepEqual(e.matches,['HELLO','HELLO']);
  for(let i=2;i<=17;i++)expressions.set(`pattern${i}`,i);
  assert.equal(expressions.count,17);assert.equal(expressions.capacity,32);
  assert.equal(expressions.set('*x',1),-1004);assert.equal(e.head,null);assert.equal(e.test('hi'),0);
});
test('unmapped locale behavior is rejected rather than approximated by Unicode regular expression folding',()=>{
  const e=new ListenExpression();assert.throws(()=>e.parse('é'),/locale/);
  e.parse('hello');assert.throws(()=>e.test('é'),/locale/);
});
