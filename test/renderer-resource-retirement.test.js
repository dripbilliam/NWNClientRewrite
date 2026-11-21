import test from 'node:test';
import assert from 'node:assert/strict';
import {RendererResourceRetirement} from '../src/renderer_resource_retirement.js';
test('transition retirement retains outgoing GPU owners until new models finish, then releases once',()=>{
 const retirement=new RendererResourceRetirement(),calls=[];
 retirement.retire(()=>calls.push('outside'));const finish=retirement.begin();
 retirement.retire(()=>calls.push('old material'));retirement.retire(()=>calls.push('old texture'));
 assert.deepEqual(calls,['outside']);const nested=retirement.begin();finish();finish();
 assert.deepEqual(calls,['outside']);nested();nested();
 assert.deepEqual(calls,['outside','old material','old texture']);assert.equal(retirement.pending.length,0);
 retirement.retire(()=>calls.push('after'));assert.equal(calls.at(-1),'after');
});
test('a failing resource disposal is diagnosed without leaking later outgoing resources',()=>{
 const errors=[],retirement=new RendererResourceRetirement({report:(...args)=>errors.push(args)}),finish=retirement.begin();let released=false;
 retirement.retire(()=>{throw Error('dispose failed');});retirement.retire(()=>{released=true;});finish();
 assert.equal(released,true);assert.deepEqual(errors,[['renderer.retirement-failed','dispose failed']]);assert.equal(retirement.holds,0);
});
