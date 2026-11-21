import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeEffectExpiry,effectHasExpired} from '../src/effect_clock.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-effect-clock-observations.json',import.meta.url)));
test('temporary effect deadline fields match original post-handler initialization, float conversion and loading preservation',()=>{
 assert.equal(capture.rows.length,1360);
 for(const row of capture.rows){const c=row.case;if(c.mode!=='initialize')continue;const effect={durationType:c.kind,duration:c.duration,expiryDay:c.expiry[0],expiryTime:c.expiry[1]},timer={dayLength:c.length,secondsPerDay:c.length/1000};initializeEffectExpiry(effect,c.loading,{day:c.now[0],time:c.now[1]},timer);assert.deepEqual([effect.expiryDay,effect.expiryTime],row.expiry,JSON.stringify(c));}
});
test('common effect expiry predicate matches original exact CompareWorldTimes result1, duration mask and invalid time behavior',()=>{
 for(const row of capture.rows){const c=row.case;if(c.mode!=='expired')continue;const effect=c.null?null:{durationType:c.kind,expiryDay:c.expiry[0],expiryTime:c.expiry[1]};assert.equal(effectHasExpired(effect,{day:c.now[0],time:c.now[1]},{dayLength:c.length}),row.calls.length===1,JSON.stringify(c));}
});
