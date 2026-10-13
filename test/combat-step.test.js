import test from 'node:test';
import assert from 'node:assert/strict';
import { doCombatStep } from '../src/combat_step.js';
import { PathInformation } from '../src/path_information.js';
import { createCombatRound } from '../src/combat_round.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture(){
  const actor={id:1,position:[5,0,-5],perceptionUpdateFlags:255,combatRound:createCombatRound(),nativePathInfo:new PathInformation(1)};
  actor.combatRound.paused=true;actor.combatRound.pauseTimer=17;actor.nativePathInfo.field28=2;
  const target={id:2,objectType:5,position:[7,0,-5]},area={width:2,height:2},trace=[];
  const p={object:()=>target,asObject:o=>o,asCreature:o=>o.objectType===5?o:null,area:()=>area,ranged:()=>0,desiredRange:()=>1,
    maximumRange:()=>2.5,setAnimation:(o,n)=>trace.push(['animation',n]),random:()=>1,
    testDirectLine:(a,from,to,radius,height,flag)=>{assert.equal(actor.nativePathInfo.field28,invalid);assert.equal(a.nativePathInfo280,actor.nativePathInfo);trace.push(['line',from,to,radius,height,flag]);return 1;},
    updateSubareas:(o,from,to,...flags)=>trace.push(['subareas',from,to,...flags]),
    setPosition:(o,point,flag)=>{trace.push(['position',point,flag]);o.position=point;},
    // Explicit numeric fixture providers; native CRT transcendental parity is
    // not established by these JS branch tests or connected as a live default.
    asin:Math.asin,atan2:Math.atan2,cos:Math.cos,sin:Math.sin,warning:m=>trace.push(['warning',m])};
  return{actor,target,area,trace,p};
}
test('invalid combat step target unpauses, adds zero to existing pause timer and sets idle animation',async()=>{
  const {actor,trace,p}=fixture();p.object=()=>null;
  assert.deepEqual(await doCombatStep(actor,1,500,invalid,p),{moved:false});
  assert.equal(actor.combatRound.paused,false);assert.equal(actor.combatRound.pauseTimer,17);assert.deepEqual(trace,[['animation',1]]);
});
test('too-far step moves toward target by native maximum0.8 and preserves successful pause timer',async()=>{
  const {actor,target,area,trace,p}=fixture(),oldPath=actor.nativePathInfo;
  const result=await doCombatStep(actor,0,9999,target.id,p);
  assert.equal(result.moved,true);assert.deepEqual(actor.position,[Math.fround(5+Math.fround(0.8)),0,-5]);
  assert.deepEqual(trace.map(a=>a[0]),['line','subareas','position']);assert.equal(actor.nativePathInfo.field28,2);
  assert.equal(area.nativePathInfo280,oldPath);assert.equal(actor.combatRound.paused,true);assert.equal(actor.combatRound.pauseTimer,17);
  assert.deepEqual(trace[0].slice(3),[Math.fround(0.6),0.5,0]);
});
test('too-close and explicit-away steps use normalized 3D direction and native delta cap',async()=>{
  const {actor,target,p}=fixture();target.position=[5,0,-4.5];p.desiredRange=()=>1;
  await doCombatStep(actor,0,500,target.id,p);assert.deepEqual(actor.position,[5,0,-5.5]);
  target.position=[5,0,-5];await doCombatStep(actor,3,500,target.id,p);
  assert.deepEqual(actor.position,[5,0,Math.fround(-5.5-Math.fround(0.8))]);
});
test('in-band non-random step ends without geometry or RNG; ranged exact-one too-far also ends',async()=>{
  const {actor,target,trace,p}=fixture();p.desiredRange=()=>2;
  delete p.testDirectLine;delete p.random;
  assert.equal((await doCombatStep(actor,0,500,target.id,p)).moved,false);assert.deepEqual(trace,[['animation',1]]);
  actor.combatRound.paused=true;p.ranged=()=>1;target.position=[15,0,-5];p.asCreature=()=>null;
  assert.equal((await doCombatStep(actor,0,500,target.id,p)).moved,false);assert.equal(actor.combatRound.paused,false);
});
test('ranged against melee uses defender maximum plus0.5; ranged against ranged forces creature reach',async()=>{
  const {actor,target,p}=fixture(),calls=[];p.ranged=o=>Number(o===actor);
  p.maximumRange=(o,id,a,b)=>{calls.push(['maximum',o.id,id,a,b]);return 2.5;};
  await doCombatStep(actor,0,500,target.id,p);assert.deepEqual(calls,[['maximum',2,1,0,0]]);
  p.ranged=()=>1;p.desiredRange=(o,id,force)=>{calls.push(['desired',o.id,id,force]);return 2;};
  await doCombatStep(actor,0,500,target.id,p);assert.deepEqual(calls.at(-1),['desired',1,2,1]);
});
test('orbit uses one conditional draw and provider asinf/atan2f/cosf/sinf, retaining target height',async()=>{
  const {actor,target,p,trace}=fixture();p.desiredRange=()=>2;let draws=0;p.random=()=>{draws++;return 1;};
  assert.equal((await doCombatStep(actor,1,500,target.id,p)).moved,true);assert.equal(draws,1);
  assert.equal(actor.position[1],target.position[1]);assert.equal(trace[0][0],'line');
});
test('missing orbital math fails before RNG and unavailable direct-line fails before path mutation',async()=>{
  const {actor,target,p}=fixture();p.desiredRange=()=>2;let draws=0;p.random=()=>{draws++;return 1;};delete p.asin;
  await assert.rejects(doCombatStep(actor,1,500,target.id,p),/asin/);assert.equal(draws,0);assert.equal(actor.nativePathInfo.field28,2);
  delete p.testDirectLine;await assert.rejects(doCombatStep(actor,2,500,target.id,p),/testDirectLine/);assert.equal(actor.nativePathInfo.field28,2);
});
test('direct-line rejection and native area bounds prevent subarea/position changes; exception restores path target',async()=>{
  for(const reject of ['line','bounds','error']){
    const {actor,target,p,trace,area}=fixture();
    if(reject==='line')p.testDirectLine=()=>0;
    if(reject==='bounds')area.width=0;
    if(reject==='error')p.testDirectLine=()=>{throw new Error('geometry unavailable');};
    if(reject==='error')await assert.rejects(doCombatStep(actor,2,500,target.id,p),/geometry unavailable/);
    else assert.equal((await doCombatStep(actor,2,500,target.id,p)).moved,false);
    assert.deepEqual(actor.position,[5,0,-5]);assert.equal(actor.nativePathInfo.field28,2);
    assert.ok(!trace.some(a=>['subareas','position'].includes(a[0])));
  }
});
