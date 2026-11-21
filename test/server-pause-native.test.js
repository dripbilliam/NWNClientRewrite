import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {WorldTimer} from '../src/world_timer.js';
import {addPauseExclusion,removePauseExclusion,activePauseState,activePauseExclusion,activeObjectTimer,resetCreatureUpdateTimes,reprocessPauseActions,setServerPauseState,toggleServerPauseState} from '../src/server_pause.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-server-pause-observations.json',import.meta.url)));
const rows=mode=>capture.rows.filter(r=>r.case.mode===mode);
const fields=['mode','fixedRate','counter','previousCounter','paused','pausedDay','pausedTime','dayOffset','timeOffset','minutesPerHour','dayLength','secondsPerDay'];
function timers(){return ['world','one','two'].map((name,index)=>({name,mode:index%2,fixedRate:30+index,counter:0x123456789abcdef0n+BigInt(index*1000),previousCounter:0x123456789abcdef0n+BigInt(index*1000)-100n,paused:index%2,pausedDay:100+index,pausedTime:200+index,dayOffset:300+index,timeOffset:400+index,minutesPerHour:5+index,dayLength:7200000+index,secondsPerDay:7200+index}));}
function state(c){const[world,one,two]=timers();return{world,flags:c.flags??0,list100f8:c.nullFirst?null:[...(c.first??[11,0xf0000001])],list10100:c.nullSecond?null:[...(c.second??[22,11])],timer1:one,timer2:two};}
const timerSnapshot=timer=>Object.fromEntries(fields.map(k=>[k,typeof timer[k]==='bigint'?String(timer[k]):timer[k]]));

test('pause transitions and toggle match complete original ordered clock/notification operations for raw masks and BOOLs',async()=>{
 for(const row of [...rows('set'),...rows('toggle')]){
  const c=row.case,s=state(c),calls=[],p={worldTimer:()=>s.world,
   pause:t=>{calls.push(['pause',t.name]);t.paused=1;},unpause:t=>{calls.push(['unpause',t.name]);t.paused=0;},
   snapshot:t=>{calls.push(['snapshot',t.name]);t.previousCounter=t.counter;t.counter+=100n;},syncPrevious:t=>{calls.push(['syncPrevious',t.name]);t.previousCounter=t.counter;},
   reset:(t,source)=>{calls.push(['reset',t.name,source.name]);WorldTimer.prototype.reset.call(t,source);},
   reprocess:mask=>{calls.push(['reprocess',mask]);if(c.afterReprocess!==undefined)s.flags=c.afterReprocess;},send:(mask,value)=>calls.push(['send',mask,value])};
  if(c.mode==='set')await setServerPauseState(s,c.mask,c.value,p);else await toggleServerPauseState(s,c.mask,p);
  assert.deepEqual({flags:s.flags,calls,timers:Object.fromEntries([s.world,s.timer1,s.timer2].map(t=>[t.name,timerSnapshot(t)]))},{flags:row.flags,calls:row.calls,timers:row.timers},JSON.stringify(c));
 }
});
test('exclusion insertion/removal matches native asymmetric combined-mask precedence, duplicates and canonical high IDs',()=>{
 for(const row of [...rows('add'),...rows('remove')]){const c=row.case,s=state(c);if(c.mode==='add')addPauseExclusion(s,c.id,c.mask);else removePauseExclusion(s,c.id,c.mask);assert.deepEqual([s.list100f8,s.list10100],[row.first,row.second],JSON.stringify(c));}
});
test('active timer/exclusion selection matches native pause priority, null storage and OBJECT_INVALID bypass',()=>{
 for(const row of [...rows('timer'),...rows('excluded')]){const c=row.case,s=state(c),value=c.mode==='timer'?activeObjectTimer(s,s.world,c.id).name:activePauseExclusion(s,c.id);assert.equal(value,row.value,JSON.stringify(c));assert.equal(activePauseState(s),(c.flags&2)?2:(c.flags&1)?1:0);}
});
test('reprocessing uses post-transition active clocks, canonical object IDs and live exclusion-list count',async()=>{
 for(const row of rows('reprocess')){
  const c=row.case,s=state(c),calls=[];let appended=false;
  for(const[t,day,time]of [[s.world,10,100],[s.timer1,20,200],[s.timer2,30,300]])t.time=()=>{calls.push(['time',t.name]);return{day,time};};
  await reprocessPauseActions(s,c.mask,{activeTimer:id=>activeObjectTimer(s,s.world,id),object:id=>{calls.push(['object',id]);return[11,22,0xf0000001].includes(id)?{id}:null;},resetObjectTimes:(o,day,time)=>{calls.push(['resetObject',o.id,day,time]);if(c.append&&!appended){s[c.mask===2?'list100f8':'list10100'].push(22);appended=true;}}});
  assert.deepEqual({calls,first:s.list100f8,second:s.list10100},{calls:row.calls,first:row.first,second:row.second},JSON.stringify(c));
 }
});
test('creature update-time reset matches native three pairs without touching queue/spawn state',()=>{
 for(const row of rows('creature')){const actor={nativeQueueUpdateDay594:88,nativeQueueUpdateTime598:99,nativeSpawnState548:2};resetCreatureUpdateTimes(actor,row.case.day,row.case.time);assert.deepEqual([[actor.nativeHeartbeatDay54c,actor.nativeHeartbeatTime550],[actor.nativePerceptionDay578,actor.nativePerceptionTime57c],[actor.nativeLastUpdateDayBc,actor.nativeLastUpdateTimeC0]],row.pairs);assert.equal(actor.nativeQueueUpdateDay594,88);assert.equal(actor.nativeQueueUpdateTime598,99);assert.equal(actor.nativeSpawnState548,2);}
});
test('world timer reset copies every native field and preserves the destination host tick source',()=>{
 const[world,one]=timers(),sourceTick=()=>1n;world.microseconds=sourceTick;one.microseconds=()=>2n;WorldTimer.prototype.reset.call(world,one);assert.deepEqual(timerSnapshot(world),rows('reset')[0].timers.world);assert.equal(world.microseconds,sourceTick);
});
