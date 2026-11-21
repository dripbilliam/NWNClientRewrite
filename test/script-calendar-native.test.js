import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {WorldTimer} from '../src/world_timer.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-calendar-observations.json',import.meta.url)));
test('script calendar getters match original wrappers and complete native timer normalization',()=>{
 for(const row of oracle.rows){const c=row.case,timer=new WorldTimer(()=>0n);for(const name of['dayOffset','timeOffset','dayLength','paused','pausedDay'])timer[name]=c[name];timer.counter=BigInt(c.counter);
  assert.equal(timer[{13:'getYear',14:'getMonth',15:'getDay'}[c.command]](),row.output,JSON.stringify(c));assert.equal(row.result,c.push?0:0xfffffd82);assert.deepEqual(row.transfers,['timer','push']);
 }
 assert.equal(oracle.rows.length,684);
});
