import test from 'node:test';
import assert from 'node:assert/strict';
import {WorldTimer} from '../src/world_timer.js';
import {ModuleSession} from '../src/module_session.js';
import {initializeModuleAI,initializeAreaAI,moduleTimeOfDay,updateModuleTime,updateModuleAI,updateAreaAI,updateModule} from '../src/module_ai.js';

function fixture(ifo={Mod_MinPerHour:5,Mod_StartYear:1372,Mod_StartMonth:1,Mod_StartDay:1,Mod_StartHour:5,Mod_DawnHour:6,Mod_DuskHour:18}){
  const timer=new WorldTimer(()=>0n);timer.loadModule(ifo);let now=timer.time();
  const module={id:0x80000001,scripts:{heartbeat:'module_beat'}},area={id:0x80000002,flags:0,scripts:{heartbeat:'area_beat'}};
  initializeModuleAI(module,ifo,timer);initializeAreaAI(area,{},timer);module.nativeAreaIds50.append(area.id);
  const trace=[],client={object:{areaId:area.id}},p={dayLength:timer.dayLength,worldTime:()=>now,calendar:d=>timer.calendar(d),timeParts:t=>timer.timeParts(t),
    random:()=>{trace.push('rand');return 0;},clients:()=>[client],clientObject:c=>c.object,area:o=>o.areaId===area.id?area:null,
    sendWeather:(_c,data)=>trace.push(['weather',data]),sendTime:(_c,data)=>trace.push(['time',data]),
    runHeartbeat:o=>trace.push(['heartbeat',o.id]),activePauseState:()=>0,areaById:id=>id===area.id?area:null};
  return{module,area,timer,p,trace,client,now:v=>{now=v;},getNow:()=>now};
}

test('time of day honors exact dawn/dusk, reverse hours, equal hours and unsigned authored bytes',()=>{
  assert.deepEqual(Array.from({length:24},(_,h)=>moduleTimeOfDay(h,6,18)),[2,2,2,2,2,2,3,1,1,1,1,1,1,1,1,1,1,1,4,2,2,2,2,2]);
  assert.deepEqual(Array.from({length:24},(_,h)=>moduleTimeOfDay(h,18,6)),[1,1,1,1,1,1,4,2,2,2,2,2,2,2,2,2,2,2,3,1,1,1,1,1]);
  for(let h=0;h<24;h++)assert.equal(moduleTimeOfDay(h,0,0),1);
  assert.equal(moduleTimeOfDay(6,262,274),3);assert.equal(moduleTimeOfDay(-1,6,18),2);
});

test('module load caches authored values before normalization, transition and first-update index',()=>{
  const {module,timer}=fixture({Mod_MinPerHour:1,Mod_StartYear:32001,Mod_StartMonth:0,Mod_StartDay:0,Mod_StartHour:255,Mod_Transition:-1});
  assert.equal(module.nativeCalendarYear3c0,32001);assert.equal(module.nativeCalendarMonth3c4,0);assert.equal(module.nativeCalendarDay3c8,0);
  assert.equal(module.nativeCalendarHour3cc,255);assert.equal(module.nativeTimeOfDay3d4,1);assert.equal(module.nativeTimeTransition3d0,0xffffffff);
  assert.equal(module.nativeCalendarDay3d8,timer.time().day);assert.equal(module.nativeAreaUpdateIndex60,-1);
});

test('DoUpdate runs module first and rotates one canonical area including missing IDs, reloading script-mutated index',async()=>{
  const f=fixture();f.module.nativeAreaIds50.append(0xffffffff);
  await updateModule(f.module,f.p);assert.equal(f.module.nativeAreaUpdateIndex60,0);assert.deepEqual(f.trace,[]);
  await updateModule(f.module,f.p);assert.equal(f.module.nativeAreaUpdateIndex60,1);assert.deepEqual(f.trace,['rand']);
  await updateModule(f.module,f.p);assert.equal(f.module.nativeAreaUpdateIndex60,2);
  await updateModule(f.module,f.p);assert.equal(f.module.nativeAreaUpdateIndex60,0);
  f.area.nativeHeartbeatTime170=1;f.p.runHeartbeat=()=>{f.module.nativeAreaUpdateIndex60=6;};
  await updateModule(f.module,f.p);assert.equal(f.module.nativeAreaUpdateIndex60,7);
});

test('module and area heartbeat use inclusive6s remainders, suppress initial time-zero script and retain captured time after script changes',async()=>{
  const f=fixture();f.now({day:1,time:5999});f.module.nativeCalendarDay3d8=1;f.module.nativeCalendarTime3dc=5999;
  await updateModuleAI(f.module,f.p);assert.equal(f.module.nativeHeartbeatTime31c,0);
  f.now({day:1,time:6000});assert.equal(await updateModuleAI(f.module,f.p),1);assert.equal(f.trace.filter(x=>Array.isArray(x)&&x[0]==='heartbeat').length,0);
  f.now({day:1,time:12000});f.p.runHeartbeat=o=>{f.trace.push(['heartbeat',o.id]);f.now({day:2,time:0});};
  assert.equal(await updateModuleAI(f.module,f.p),1);assert.equal(f.module.nativeHeartbeatDay318,1);assert.equal(f.module.nativeCalendarTime3dc,12000);
  f.now({day:1,time:6000});f.area.nativeWeatherDay33c=1;f.area.nativeWeatherTime340=6000;
  assert.equal(await updateAreaAI(f.area,f.p),1);assert.equal(f.area.nativeHeartbeatTime170,6000);
  f.now({day:2,time:11999});assert.equal(await updateAreaAI(f.area,f.p),0,'elapsed days are discarded by heartbeat owner');
  f.now({day:2,time:12000});assert.equal(await updateAreaAI(f.area,f.p),1);assert.equal(f.area.nativeHeartbeatDay16c,2);
});

test('UpdateTime broadcasts only changed fields and transition elapsed uses OLD dawn/dusk state with uint32 wrap',async()=>{
  const f=fixture(),day=f.timer.time().day;f.module.nativeTimeTransition3d0=123;
  assert.equal(await updateModuleTime(f.module,{day,time:1800000},100,f.p),3);
  assert.equal(f.module.nativeTimeOfDay3d4,3);assert.equal(f.module.nativeTimeTransition3d0,0);
  f.trace.length=0;f.module.nativeTimeTransition3d0=0xffffffff;
  assert.equal(await updateModuleTime(f.module,{day,time:1801000},2,f.p),0);assert.equal(f.module.nativeTimeTransition3d0,1);assert.deepEqual(f.trace,[]);
  assert.equal(await updateModuleTime(f.module,{day,time:2100000},7,f.p),3);assert.equal(f.module.nativeTimeTransition3d0,8);
  await updateModuleTime(f.module,{day:day+336+28+1,time:2100000},7,f.p);
  assert.equal(f.module.nativeTimeTransition3d0,0);assert.deepEqual(f.trace.at(-1),['time',{mask:28,year:1373,month:2,day:2,hour:7,timeOfDay:1,transition:0}]);
});

test('weather uses rain precedence and strict random threshold, consumes no second roll and filters actual clients by canonical area',async()=>{
  const f=fixture();f.area.nativeChanceRainE1=50;f.area.nativeChanceSnowE2=100;
  f.p.clients=()=>[f.client,{object:null},{object:{areaId:99}}];let queries=0;
  const area=f.p.area;f.p.area=o=>{queries++;return area(o);};f.p.random=()=>{f.trace.push('rand');return 49;};
  await updateAreaAI(f.area,f.p);assert.equal(f.area.nativeWeatherType330,1);assert.equal(f.area.nativeWeatherCached345,1);
  assert.deepEqual(f.trace,['rand',['weather',{areaId:f.area.id,kind:1,on:1}]]);assert.equal(queries,3);
  f.trace.length=0;f.area.nativeWeatherTimer338=0;f.p.random=()=>{f.trace.push('rand');return 50;};
  await updateAreaAI(f.area,f.p);assert.equal(f.area.nativeWeatherOn334,0);assert.equal(f.area.nativeWeatherCached345,0);
  assert.deepEqual(f.trace,['rand',['weather',{areaId:f.area.id,kind:1,on:0}]]);
});

test('weather expiry waits until next visit and dry outdoor weather still consumes shared RNG',async()=>{
  const f=fixture(),now=f.getNow();f.area.scripts={};await updateAreaAI(f.area,f.p);assert.deepEqual(f.trace,['rand']);assert.equal(f.area.nativeWeatherTimer338,300000);
  f.trace.length=0;f.now({...now,time:now.time+300000});await updateAreaAI(f.area,f.p);
  assert.equal(f.area.nativeWeatherTimer338,0);assert.deepEqual(f.trace,[]);
  await updateAreaAI(f.area,f.p);assert.deepEqual(f.trace,['rand']);assert.equal(f.area.nativeWeatherTimer338,300000);
  f.area.nativeChanceSnowE2=100;f.area.nativeWeatherTimer338=0;await updateAreaAI(f.area,f.p);
  assert.equal(f.area.nativeWeatherType330,2);assert.equal(f.area.nativeWeatherCached345,2);
});

test('indoor/override weather skips RNG and timer but commits timestamps before heartbeat; header chances wrap to bytes',async()=>{
  for(const override of [0,255]){
    const f=fixture();f.area.flags=override===255?1:0;initializeAreaAI(f.area,{ChanceRain:356,ChanceSnow:257},f.timer);
    assert.equal(f.area.nativeChanceRainE1,override===255?0:100);f.area.nativeWeatherOverride344=override;f.area.nativeWeatherTimer338=123;
    f.now({...f.getNow(),time:f.getNow().time+6000});await updateAreaAI(f.area,f.p);
    assert.equal(f.area.nativeWeatherTimer338,123);assert.equal(f.area.nativeWeatherTime340,f.getNow().time);assert.deepEqual(f.trace,[]);
  }
});

test('module checks ONLY active pause state1 and scans all exclusion effects, retaining64 or toggling with1',async()=>{
  const f=fixture(),actor={effects:[{type:64},{type:1}]};let scans=0;
  f.p.activePauseState=()=>1;f.p.exclusionIds=()=>[0xffffffff,1];f.p.creature=id=>id===1?actor:null;
  f.p.effects=o=>{scans++;return o.effects;};f.p.togglePause=v=>f.trace.push(['toggle',v]);
  await updateModuleAI(f.module,f.p);assert.equal(scans,1);assert.deepEqual(f.trace,[]);
  actor.effects=[{type:63}];await updateModuleAI(f.module,f.p);assert.deepEqual(f.trace,[['toggle',1]]);
  f.p.activePauseState=()=>2;f.p.exclusionIds=()=>{throw new Error('unexpected exclusions');};await updateModuleAI(f.module,f.p);
  assert.equal(f.trace.length,1);
});

test('failed world subtraction and missing conditional providers are explicit, never fabricated elapsed time or pause results',async()=>{
  const f=fixture();f.now({day:0,time:0});await assert.rejects(updateModuleAI(f.module,f.p),/undefined after failed subtraction/);
  await assert.rejects(updateAreaAI(f.area,f.p),/undefined after failed subtraction/);
  const g=fixture();g.p.activePauseState=()=>1;await assert.rejects(updateModuleAI(g.module,g.p),/exclusionIds is unavailable/);
});

test('live session module adapter emits typed time/weather messages and clears an orphaned Time Stop pause',async()=>{
  const messages=[],session=new ModuleSession(null,{onCombatMessage:m=>messages.push(m)});
  session.worldTimer.loadModule({Mod_MinPerHour:5,Mod_StartYear:1372,Mod_StartHour:5,Mod_DawnHour:6});
  session.module=session.register('module','module',{scripts:{}});initializeModuleAI(session.module,{Mod_StartYear:1372,Mod_StartHour:5,Mod_DawnHour:6},session.worldTimer);
  const area=session.register('area','area',{flags:0,scripts:{}});initializeAreaAI(area,{ChanceRain:100},session.worldTimer);session.module.nativeAreaIds50.append(area.id);
  session.player=session.register('player','pc',{stats:{},areaId:area.id});
  await session.updateModuleAI();await session.updateModuleAI();assert.equal(messages.at(-1).type,'areaWeather');assert.equal(messages.at(-1).recipientId,session.player.id);
  session.worldTimer.setTime(session.worldTimer.time().day,1800000);await session.updateModuleAI();assert.equal(messages.at(-1).type,'moduleTime');
  await session.setPauseState(1,1);assert.equal(session.nativeActivePauseFlags,1);await session.updateModuleAI();await session.updateModuleAI();
  assert.equal(session.nativeActivePauseFlags,0);assert.equal(messages.at(-1).type,'module-pause-state');assert.deepEqual(messages.at(-1).data,{mask:1,value:0,exclusionIds:[]});
});
