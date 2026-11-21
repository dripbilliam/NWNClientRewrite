import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {updateCreatureFrame} from '../src/combat_frame.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-player-queue-clock-observations.json',import.meta.url)));
const backwards=c=>c.now[0]<c.previous[0]||c.now[0]===c.previous[0]&&c.now[1]<c.previous[1];
async function frame(c){
 const calls=[],undefinedTimes=[],actor={id:0x80000001,isPC:true,nativeLastUpdateDayBc:1,nativeLastUpdateTimeC0:0,nativeQueueUpdateDay594:c.previous[0],nativeQueueUpdateTime598:c.previous[1],nativeSkillTimers878:new Uint32Array(0),nativeField700:0,nativeAILevel7c:0};let stats=0;
 const p={microseconds:()=>0n,beforeTimer:()=>{},activeTimer:()=>({time:()=>({day:1,time:0})}),dayLength:1000,excited:()=>{},effects:()=>{},actions:()=>{},area:()=>null,computeAIState:()=>{},combatStateTimers:()=>{},pauseTimer:()=>({time:()=>({day:c.now[0],time:c.now[1]})}),skillCount:()=>0,refreshStats:()=>{stats++;},queueClockUndefined:(o,detail)=>undefinedTimes.push({id:o.id,...detail}),actionQueue:o=>calls.push(['queue',o.nativeQueueUpdateDay594,o.nativeQueueUpdateTime598])};
 await updateCreatureFrame(actor,p);return{calls,day:actor.nativeQueueUpdateDay594,time:actor.nativeQueueUpdateTime598,undefinedTimes,stats};
}
test('defined player queue cadence matches original caller block and native subtraction at the inclusive300ms boundary',async()=>{
 assert.equal(capture.rows.length,144);
 for(const row of capture.rows){if(backwards(row.case))continue;const result=await frame(row.case);assert.deepEqual({calls:result.calls,day:result.day,time:result.time},{calls:row.calls,day:row.day,time:row.time});assert.deepEqual(result.undefinedTimes,[]);assert.equal(result.stats,1);}
});
test('backwards native output remains caller scratch; explicit local recovery retains queue state and completes gameplay work',async()=>{
 const invalid=capture.rows.filter(r=>backwards(r.case));assert.ok(invalid.some(r=>r.calls.length===0));assert.ok(invalid.some(r=>r.calls.length===1));
 for(const row of invalid){assert.equal(row.outputTime,row.case.seedTime);assert.equal(row.outputDay,row.case.seedDay);const result=await frame(row.case);assert.deepEqual(result.calls,[]);assert.equal(result.day,row.case.previous[0]);assert.equal(result.time,row.case.previous[1]);assert.equal(result.stats,1);assert.deepEqual(result.undefinedTimes,[{id:0x80000001,status:-2,now:{day:row.case.now[0],time:row.case.now[1]},previous:{day:row.case.previous[0],time:row.case.previous[1]}}]);}
});
