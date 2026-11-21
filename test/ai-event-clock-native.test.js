import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {ScriptScheduler} from '../src/script_scheduler.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-ai-event-clock-observations.json',import.meta.url)));
const pointer=n=>BigInt(n).toString(16).padStart(16,'0');
function fixture(c){const calls=[],rejections=[],clock={dayLength:1000,secondsPerDay:1,time:()=>({day:c.now?.[0]??1,time:c.now?.[1]??0})},s=new ScriptScheduler({getWorldTimer:()=>clock,activePauseState:()=>c.pause??0,validTarget:()=>true,dispatch:()=>{},onPausedEvent:()=>calls.push('paused-warning'),onRejectedEvent:detail=>rejections.push(detail)});
 for(const[day,time]of c.queue){const i=s.events.length;s.events.push(s.record(200+i,{label:'old'+i,callerId:100+i,eventId:300+i,payload:{pointer:0x12340000+i}},{day,time}));}
 return{s,calls,rejections};}
const view=r=>({day:r.day,time:r.time,caller:r.event.callerId,target:r.targetId,eventId:r.event.eventId,payload:pointer(r.event.payload.pointer)});

test('native absolute/head and absolute/tail insertion preserve their distinct equal-time order and invalid comparisons',()=>{
 for(const row of capture.rows){const c=row.case;if(!['absolute','tail'].includes(c.mode))continue;const{s}=fixture(c),event={label:'new',callerId:0xf0000001,eventId:999,payload:{pointer:0xdeadbeef}},record=s.enqueueAbsolute(0x80000001,event,...c.deadline,c.mode==='tail');assert.equal(record.event,event);assert.deepEqual(s.events.map(r=>r.event.label),row.order);assert.deepEqual(s.events.map(view),row.events,JSON.stringify(c));}
});
test('native delta insertion matches world addition, zero-time FIFO, positive-time LIFO, raw pause warning and rejection',()=>{
 assert.equal(capture.rows.length,786);
 for(const row of capture.rows){const c=row.case;if(c.mode!=='delta')continue;const{s,calls,rejections}=fixture(c),event={label:'new',callerId:0xf0000001,eventId:999,payload:{pointer:0xdeadbeef}},record=s.enqueueDelta(0x80000001,event,...c.delta);assert.equal(Number(record!==null),row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(rejections.length,row.result===0?1:0);assert.deepEqual(s.events.map(r=>r.event.label),row.order);assert.deepEqual(s.events.map(view),row.events,JSON.stringify(c));}
});
test('native pending admits compare<1 including invalid operands, and pop transfers payload identity without reordering',()=>{
 for(const row of capture.rows){const c=row.case;if(!['pending','pop'].includes(c.mode))continue;const{s}=fixture(c);
  if(c.mode==='pending'){assert.equal(Number(s.isDue(s.events[0],{day:c.now[0],time:c.now[1]})),row.result);continue;}
  const previous=s.events[0],record=s.takeEvent();assert.equal(Number(record!==undefined),row.result);if(record){assert.equal(record.event.payload,previous.event.payload);assert.deepEqual(view(record),row.output);assert.deepEqual(row.freed,[{name:'old0',payloadAfterClear:'0000000000000000'}]);}assert.deepEqual(s.events.map(r=>r.event.label),row.order);
 }
});
