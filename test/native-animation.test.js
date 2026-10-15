import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {nativeAnimationName,importedAnimationOverrides} from '../src/native_animation.js';

test('animation names match30672 executions of the original client lookup across72 presentation contexts',()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-animation-name-observations.json',import.meta.url)));
  assert.equal(oracle.contexts.length,72);
  for(const c of oracle.contexts)for(let id=0;id<c.names.length;id++)assert.equal(nativeAnimationName(id,c),c.names[id],`${id}/${c.fieldDE}/${c.fieldDD}/${c.fieldE0}`);
  assert.equal(nativeAnimationName(65536,{fieldDE:1,fieldDD:3,fieldE0:0}),'pause1');
  assert.equal(nativeAnimationName(-1,{fieldDE:0,fieldDD:3,fieldE0:0}),'cpause1');
});

test('animation overrides retain physical first-match order, resref width and nonrecursive replacement',()=>{
  const pool=importedAnimationOverrides({AnimationReplace:{AnimationReplaceList:[
    {OldAnimation:'PAUSE1',NewAnimation:'Custom13'}, {OldAnimation:'pause1',NewAnimation:'Custom14'},
    {OldAnimation:'Custom13',NewAnimation:'Custom15'}, {OldAnimation:'12345678901234567',NewAnimation:'abcdefghijklmnoqr'}]}});
  const c={fieldDE:1,fieldDD:3,fieldE0:0};
  assert.equal(nativeAnimationName(0,c,pool),'custom13');assert.equal(pool[3].old,'1234567890123456');assert.equal(pool[3].replacement,'abcdefghijklmnoq');
  assert.deepEqual(importedAnimationOverrides({}),[]);
  assert.equal(nativeAnimationName(89,{fieldDE:1,fieldDD:0,fieldE0:0}),'');
  assert.throws(()=>nativeAnimationName(0,{...c,fieldEC:1}),/movement animation override/);
});
