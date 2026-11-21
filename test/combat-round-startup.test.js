import test from 'node:test';
import assert from 'node:assert/strict';
import { createCombatRound,initializeAttackActions,initialAttackCombatStep,startCombatRoundAsync,addCombatStep } from '../src/combat_round.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';
import { NativeRandom } from '../src/native_random.js';
import { parse2da } from '../src/area.js';
const rules={appearance:parse2da('2DA V2.0\n\nSIZECATEGORY\n0 3')};

function fixture(){
  const actor={id:1,isPC:true,combatMode:0,pendingCombatMode:0,combatAnimationSpeed:0,perceptionUpdateFlags:255,position:[0,0,0],
    creatureData:{Race:0,Appearance_Type:0,ClassList:[]},stats:{feats:[],level:1,combat:{baseAttackBonusWithoutEpic:1,finalBreakdown:{armor:{monkAbilities:false}}}}};
  const round=createCombatRound(),random=new NativeRandom(1),trace=[];
  const p={initialCombatStep:()=>false,broadcastState:()=>trace.push('broadcast'),setLock:()=>trace.push('lock'),
    setCombatMode:(o,mode,force)=>{trace.push(['mode',mode,force]);o.combatMode=mode;}};
  return{actor,round,random,trace,p};
}
test('single attack startup includes native type4 step and both 500/1250 timer decrements',async()=>{
  const {actor,round,random,trace,p}=fixture();
  await startCombatRoundAsync(round,actor,2,[],rules,random,p);
  assert.equal(round.length,4250);assert.equal(round.pausedBy,invalid);
  assert.deepEqual(round.actions.map(a=>[a.nativeActionType,a.time,a.duration]),[[1,707,1250],[4,2125,500]]);
  assert.deepEqual(trace,['lock']);assert.equal(random.draws,0);
});
test('NPC round inserts another type4 step then compresses its own time and earlier actions',async()=>{
  const {actor,round,random,p}=fixture();actor.isPC=false;
  await startCombatRoundAsync(round,actor,2,[],rules,random,p);
  assert.equal(round.length,3750);assert.equal(random.draws,1);
  assert.deepEqual(round.actions.map(a=>[a.nativeActionType,a.time,a.duration]),[[4,36,500],[1,623,1250],[4,1875,500]]);
});
test('Parry broadcast precedes parry state writes, NPC random draw and orientation lock',async()=>{
  const {actor,round,trace,p}=fixture();actor.isPC=false;actor.pendingCombatMode=1;
  round.parryActions=9;round.parryIndex=3;
  p.broadcastState=async()=>{assert.equal(round.parryActions,9);assert.equal(round.parryIndex,3);trace.push('broadcast');};
  const random={next:()=>{assert.equal(round.parryActions,1);trace.push('random');return 41;}};
  await startCombatRoundAsync(round,actor,2,[],rules,random,p);
  assert.deepEqual(trace,[['mode',1,1],'broadcast','random','lock']);
  assert.equal(actor.pendingCombatMode,0);assert.equal(round.length,5500);assert.equal(round.parryIndex,0);
  assert.equal(round.actions[0].nativeActionType,4);assert.equal(round.actions[0].time,37);
});
test('startup capability preflight fails before altering pending mode, timer or queued round actions',async()=>{
  const {actor,round,random,p}=fixture();actor.pendingCombatMode=11;round.timer=77;round.actions.push({time:1});
  p.preflight=()=>{throw new Error('mode unavailable');};
  await assert.rejects(startCombatRoundAsync(round,actor,2,[],{},random,p),/mode unavailable/);
  assert.equal(round.started,false);assert.equal(round.timer,77);assert.equal(round.actions.length,1);assert.equal(actor.pendingCombatMode,11);
});
test('initial step range uses native 3D length, inclusive quarter-unit band and independent state gates',async()=>{
  const {actor}=fixture(),target={objectType:5,position:[0,0,-3]},trace=[];
  const p={object:()=>target,dead:()=>0,dying:()=>0,ranged:()=>0,desiredRange:()=>{trace.push('range');return 2.75;}};
  assert.equal(await initialAttackCombatStep(actor,2,p),false);
  target.position[2]=-3.001;assert.equal(await initialAttackCombatStep(actor,2,p),true);
  target.position=[1,2,-2];assert.equal(await initialAttackCombatStep(actor,2,p),false);
  p.ranged=()=>1;assert.equal(await initialAttackCombatStep(actor,2,p),false);assert.equal(trace.length,3);
  p.ranged=()=>0;actor.perceptionUpdateFlags&=~2;assert.equal(await initialAttackCombatStep(actor,2,p),false);assert.equal(trace.length,3);
  actor.perceptionUpdateFlags|=2;p.dead=()=>1;assert.equal(await initialAttackCombatStep(actor,2,p),false);
});
test('explicit initial type5 step remains separate from native idle type4 insertion',()=>{
  const {actor,round}=fixture();round.started=true;round.length=6000;round.onhandAttacks=2;
  initializeAttackActions(round,actor,2,{initialCombatStep:true});
  assert.deepEqual(round.actions.map(a=>a.nativeActionType),[5,1,1]);assert.equal(round.actions[0].duration,500);
  const length=round.length;addCombatStep(round,100,2);assert.equal(round.length,length-500);
});
