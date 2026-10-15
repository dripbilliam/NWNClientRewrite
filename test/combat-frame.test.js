import test from 'node:test';
import assert from 'node:assert/strict';
import { advanceExcitedDuration, advanceCombatStateTimers,selectActiveTimer,initializeCreatureFrame,initializeSkillTimers,advanceSkillTimers,updateCreatureFrame } from '../src/combat_frame.js';
import { parse2da } from '../src/area.js';
import { createCombatRound } from '../src/combat_round.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

const actor=()=>({nativeField700:1,nativeField704:8000,nativeAttackField748:6000,
  nativeField750:0,nativeField754:0,nativeMovementField74c:1000,excitedDuration:8000,
  animationState:1,combatRound:createCombatRound(),nativeAttackTarget724:7,attackActionTargetId:8});

test('native combat timeout expires on the frame after crossing zero, clearing round records while retaining other target references',async()=>{
  const a=actor(),r=a.combatRound;r.actions.push({time:4});r.attacks[0].result=3;
  await advanceCombatStateTimers(a,8000,{});
  assert.equal(a.nativeField700,1);assert.equal(a.nativeField704,0);assert.equal(r.attacks[0].result,3);
  await advanceCombatStateTimers(a,0,{});
  assert.equal(a.nativeField700,0);assert.equal(a.initiativePending,1);assert.equal(a.nativeField744,100);
  assert.equal(a.nativeAttackTarget724,invalid);assert.equal(a.attackActionTargetId,8);
  assert.equal(r.actions.length,0);assert.equal(r.attacks[0].result,0);
});

test('native NPC combat heartbeat checks before subtraction, resets after direct script, and skips PC/familiar and dead actors',async()=>{
  const a=actor(),trace=[];a.nativeAttackField748=100;
  const p={dead:()=>0,heartbeat:o=>{trace.push(o.nativeField704);o.nativeAttackField748=123;}};
  await advanceCombatStateTimers(a,100,p);assert.deepEqual(trace,[]);assert.equal(a.nativeAttackField748,0);
  await advanceCombatStateTimers(a,20,p);assert.deepEqual(trace,[7880]);assert.equal(a.nativeAttackField748,5980);
  for(const flag of ['isPC','isPossessedFamiliar']){
    const o=actor();o[flag]=true;o.nativeAttackField748=0;await advanceCombatStateTimers(o,20,{});
    assert.equal(o.nativeAttackField748,0);
  }
  const dead=actor();dead.nativeAttackField748=0;
  await advanceCombatStateTimers(dead,20,{dead:()=>1,heartbeat:()=>assert.fail('Dead actor ran heartbeat')});
  assert.equal(dead.nativeAttackField748,5980);
});

test('native movement opportunity cadence waits an extra frame for suppression expiry and uses raw animation4/86/87',async()=>{
  const a=actor(),trace=[];a.animationState=4;a.nativeMovementField74c=0;a.nativeField750=1;a.nativeField754=1500;
  const p={hasFeat:()=>0,opportunity:(...args)=>trace.push(args.slice(1))};
  await advanceCombatStateTimers(a,1500,p);
  assert.equal(a.nativeField750,1);assert.equal(a.nativeField754,0);assert.deepEqual(trace,[]);
  assert.equal(a.nativeMovementField74c,1500);
  await advanceCombatStateTimers(a,1500,p);
  assert.equal(a.nativeField750,0);assert.equal(a.nativeMovementField74c,0);assert.deepEqual(trace,[]);
  await advanceCombatStateTimers(a,0,p);assert.deepEqual(trace,[[invalid,1]]);
  assert.equal(a.nativeMovementField74c,1500);
  for(const animation of [4,86,87]){
    a.animationState=animation;a.nativeMovementField74c=0;await advanceCombatStateTimers(a,0,p);
  }
  assert.equal(trace.length,4);a.animationState=9;a.nativeMovementField74c=2;
  await advanceCombatStateTimers(a,100,p);assert.equal(a.nativeMovementField74c,2);
});

test('native feat392 prevents movement provocation only while combat state is nonzero, and nonzero suppression flags avoid feat queries',async()=>{
  const a=actor(),trace=[];a.animationState=86;a.nativeMovementField74c=0;
  const p={hasFeat:()=>1,opportunity:()=>trace.push('opportunity')};
  await advanceCombatStateTimers(a,0,p);assert.deepEqual(trace,[]);
  a.nativeField700=0;a.nativeMovementField74c=0;await advanceCombatStateTimers(a,0,p);
  assert.deepEqual(trace,['opportunity']);
  a.nativeField750=2;a.nativeMovementField74c=0;
  await advanceCombatStateTimers(a,0,{hasFeat:()=>assert.fail('Suppressed actor queried feat')});
  assert.equal(a.nativeField750,2);assert.equal(a.nativeMovementField74c,1500);
});

test('native excited duration uses unsigned comparison, expires immediately at equality and commits zero before notification',async()=>{
  const a=actor(),trace=[];a.excitedDuration=0xffffffff;
  const p={expired:o=>trace.push(o.excitedDuration)};
  await advanceExcitedDuration(a,1,p);assert.equal(a.excitedDuration,0xfffffffe);
  a.excitedDuration=20;await advanceExcitedDuration(a,20,p);
  assert.deepEqual(trace,[0]);await advanceExcitedDuration(a,20,{});
});

test('missing live movement-opportunity work fails without claiming its timer reset or attack completion',async()=>{
  const a=actor();a.animationState=87;a.nativeMovementField74c=0;
  await assert.rejects(advanceCombatStateTimers(a,20,{hasFeat:()=>0}),/opportunity/);
  assert.equal(a.nativeMovementField74c,0);
});

function frameFixture(){
  const a=actor();a.id=0x80000001;a.nativeAILevel7c=1;a.nativeField700=0;initializeCreatureFrame(a,{day:1,time:100});
  a.nativeSkillTimers878=new Uint32Array([20,0,0xffffffff]);
  const area={nativePlayerCount150:1},trace=[];let now={day:1,time:120};
  const p={dayLength:7200000,microseconds:()=>{trace.push('micro');return 123n;},beforeTimer:()=>trace.push('before'),
    activeTimer:id=>{trace.push(['active',id]);return{time:()=>now};},roundTimer:(_o,ms)=>trace.push(['round',ms]),
    excited:(_o,ms)=>trace.push(['excited',ms]),effects:(_o,t)=>trace.push(['effects',{...t}]),
    actions:(o,t,start)=>trace.push(['actions',{...t},start,o.nativeLastUpdateTimeC0]),
    area:()=>{trace.push('area');return area;},height:o=>trace.push(['height',o.nativeLastUpdateTimeC0]),
    computeAIState:()=>trace.push('compute'),traps:()=>trace.push('traps'),
    combatStateTimers:(_o,ms)=>trace.push(['state',ms]),possessed:()=>0,pauseTimer:()=>({time:()=>now}),
    actionQueue:()=>trace.push('queue'),skillCount:()=>3,refreshStats:()=>trace.push('stats'),
    setAILevel:(o,level)=>{trace.push(['level',level]);o.nativeAILevel7c=level;}};
  return{a,p,area,trace,now:v=>{now=v;}};
}

test('active timer checks canonical IDs, bit2 precedence and exact1 exclusion without conflating timers',()=>{
  const trace=[],world={},first={},second={},p={worldTimer:()=>world,pauseFlags:()=>3,
    excluded:id=>{trace.push(id);return 1;},timer1:()=>first,timer2:()=>second};
  assert.equal(selectActiveTimer(invalid,p),world);assert.deepEqual(trace,[]);
  assert.equal(selectActiveTimer(0x80000001,p),second);assert.deepEqual(trace,[0x80000001]);
  p.pauseFlags=()=>1;assert.equal(selectActiveTimer(7,p),first);
  for(const value of [0,2,-1]){p.excluded=()=>value;assert.equal(selectActiveTimer(7,p),world);}
  p.pauseFlags=()=>4;p.excluded=()=>assert.fail('Inactive flags queried exclusion');assert.equal(selectActiveTimer(7,p),world);
  p.pauseFlags=()=>1;p.excluded=undefined;assert.throws(()=>selectActiveTimer(7,p),/excluded is unavailable/);
});

test('native frame keeps early microsecond budget and active captured time through actions, then commits before height/AI/traps',async()=>{
  const f=frameFixture();await updateCreatureFrame(f.a,f.p);
  assert.deepEqual(f.trace,['micro','before',['active',0x80000001],['round',20],['excited',20],['effects',{day:1,time:120}],
    ['actions',{day:1,time:120},123n,100],'area','area',['height',120],'compute','area','traps',['state',20],'stats']);
  assert.equal(f.a.nativeFrameElapsedD4,20);assert.deepEqual([...f.a.nativeSkillTimers878],[0,0,0xffffffeb]);
});

test('frame time selection happens AFTER heartbeat and ignores elapsed days; failed initialized subtraction gives zero',async()=>{
  const f=frameFixture();f.p.beforeTimer=()=>f.now({day:2,time:130});await updateCreatureFrame(f.a,f.p);
  assert.equal(f.a.nativeFrameElapsedD4,30);assert.equal(f.a.nativeLastUpdateDayBc,2);
  f.p.beforeTimer=()=>f.now({day:1,time:120});await updateCreatureFrame(f.a,f.p);
  assert.equal(f.a.nativeFrameElapsedD4,0);assert.equal(f.a.nativeLastUpdateDayBc,1);assert.equal(f.a.nativeLastUpdateTimeC0,120);
});

test('action callbacks changing the clock or native elapsed preserve captured commit and later+d4 reads',async()=>{
  const f=frameFixture();f.p.actions=o=>{f.now({day:3,time:900});o.nativeFrameElapsedD4=5;};
  await updateCreatureFrame(f.a,f.p);assert.equal(f.a.nativeLastUpdateTimeC0,120);assert.equal(f.a.nativeLastUpdateDayBc,1);
  assert.deepEqual(f.trace.find(x=>Array.isArray(x)&&x[0]==='state'),['state',5]);assert.deepEqual([...f.a.nativeSkillTimers878],[15,0,0xfffffffa]);
});

test('failed action owner retains last timestamp and stops before later frame side effects',async()=>{
  const f=frameFixture();f.p.actions=()=>{throw new Error('Unimplemented action');};
  await assert.rejects(updateCreatureFrame(f.a,f.p),/Unimplemented action/);
  assert.equal(f.a.nativeLastUpdateTimeC0,100);assert.ok(!f.trace.includes('compute'));assert.equal(f.a.nativeSkillTimers878[0],20);
});

test('player/familiar display cadence uses a separate pause timer with inclusive300ms and commits AFTER callback',async()=>{
  for(const familiar of [false,true]){
    const f=frameFixture();f.a.isPC=!familiar;f.p.possessed=()=>Number(familiar);let queueTime={day:1,time:299};
    f.p.pauseTimer=()=>({time:()=>queueTime});await updateCreatureFrame(f.a,f.p);assert.ok(!f.trace.includes('queue'));
    queueTime={day:1,time:300};let previous;
    f.p.actionQueue=o=>{previous=o.nativeQueueUpdateTime598;queueTime={day:2,time:700};f.trace.push('queue');};
    await updateCreatureFrame(f.a,f.p);assert.equal(previous,0);assert.equal(f.a.nativeQueueUpdateDay594,1);assert.equal(f.a.nativeQueueUpdateTime598,300);
    queueTime={day:1,time:299};await assert.rejects(updateCreatureFrame(f.a,f.p),/undefined after failed subtraction/);
  }
});

test('native frame promotion uses unsigned levels; calm AI2 returns to actual area count only and respects callback mutation',async()=>{
  const f=frameFixture();f.a.nativeField700=1;await updateCreatureFrame(f.a,f.p);assert.equal(f.a.nativeAILevel7c,2);
  f.a.nativeField700=0;await updateCreatureFrame(f.a,f.p);assert.equal(f.a.nativeAILevel7c,1);
  f.a.nativeAILevel7c=2;f.area.nativePlayerCount150=0;await updateCreatureFrame(f.a,f.p);assert.equal(f.a.nativeAILevel7c,0);
  f.a.nativeAILevel7c=-1;f.a.nativeField700=1;await updateCreatureFrame(f.a,f.p);assert.equal(f.a.nativeAILevel7c,-1);
  f.a.nativeAILevel7c=2;f.a.nativeField700=0;f.p.area=()=>null;await updateCreatureFrame(f.a,f.p);assert.equal(f.a.nativeAILevel7c,2);
});

test('skill timer storage uses physical active Skills rows and BYTE count, with unsigned expiry and preserved identity',()=>{
  const table=parse2da('2DA V2.0\n\nLabel\n99 First\n99 Second\n400 Third\n'),a={};
  initializeSkillTimers(a,{skills:table});assert.equal(a.nativeSkillTimers878.length,3);const identity=a.nativeSkillTimers878;
  initializeSkillTimers(a,{skills:table});assert.equal(a.nativeSkillTimers878,identity);
  a.nativeSkillTimers878.set([1,20,0xffffffff]);advanceSkillTimers(a,20,3);assert.deepEqual([...identity],[0,0,0xffffffeb]);
  advanceSkillTimers(a,-1,3);assert.deepEqual([...identity],[0,0,0]);
  const extended={skills:{orderedRows:Array(258).fill({})}},b={};initializeSkillTimers(b,extended);assert.equal(b.nativeSkillTimers878.length,2);
  assert.throws(()=>initializeSkillTimers(a,extended),/does not match active rules/);advanceSkillTimers({},0,256);
});
