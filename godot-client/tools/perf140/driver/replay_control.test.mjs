import test from 'node:test';import assert from 'node:assert/strict';
import {replayFinishAcknowledgment as ack} from './replay_control.mjs';
test('native finish is always acknowledged within the admitted replay scope',()=>{
 assert.deepEqual(ack({kind:'finished'},1),{kind:'finish-ack',connection:1});
 assert.deepEqual(ack({kind:'finished',connection:0},0),{kind:'finish-ack',connection:0});
 assert.deepEqual(ack({kind:'finished',connection:12},12),{kind:'finish-ack',connection:12});
 for(const connection of [-1,NaN,1.5,'1',2])assert.throws(()=>ack({kind:'finished',connection},1));
 assert.throws(()=>ack({kind:'hello'},1));assert.throws(()=>ack({kind:'finished'},undefined));
});
