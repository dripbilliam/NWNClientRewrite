import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {secondsToWorldDelta} from '../src/world_timer.js';
test('seconds-to-world delay preserves original repeated FLOAT subtraction and uint conversion',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-seconds-world-delta-observations.json',import.meta.url)));
 for(const row of fixture.rows)assert.deepEqual(secondsToWorldDelta(row.value==='NaN'?NaN:row.value,row.length),row.result,JSON.stringify(row));
 assert.throws(()=>secondsToWorldDelta(Infinity,7200),/would not advance/);assert.throws(()=>secondsToWorldDelta(1,0),/would not advance/);
});
