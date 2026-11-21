import test from 'node:test';
import assert from 'node:assert/strict';
import {createCombatRound} from '../src/combat_round.js';
import {resolveRangedMiss as miss} from '../src/combat_ranged_miss.js';
import {nativeAtanf} from '../src/native_math.js';
function fixture(draws=[0,0]){
  const actor={id:1,position:[10,10,0],combatRound:createCombatRound()},target={id:2,position:[15,10,2]},data=actor.combatRound.attacks[0],trace=[];
  data.result=4;data.missedBy=8;
  const p={creature:()=>null,position:o=>o.position,random:{next:()=>{trace.push('draw');assert.ok(draws.length);return draws.shift();}},
    area:()=>({width:10,height:10}),lineOfSight:(a,from,to,hit,source,other,transparent)=>{trace.push({from,to:[...to],source,other,transparent});return 1;},height:()=>7};
  return{actor,target,data,p,trace,draws};
}
const endpoint=data=>[0x80,0x84,0x88].map(n=>data.raw.getFloat32(n,true));
test('native atanf preserves signed zero, reductions, infinite slopes and finite float32 outputs',()=>{
  assert.ok(Object.is(nativeAtanf(-0),-0));assert.equal(nativeAtanf(Infinity),Math.fround(Math.PI/2));
  for(const x of [.1,.4375,.5,.6875,1,1.1875,1.5,2.4375,100,1e20]){
    assert.equal(nativeAtanf(x),Math.fround(Math.atan(Math.fround(x))));assert.equal(nativeAtanf(-x),-nativeAtanf(x));
  }
  assert.throws(()=>nativeAtanf(NaN),/exception/);
});
test('only native results4,8,9 compute miss points and other results avoid providers/RNG',async()=>{
  for(const result of [0,1,2,3,5,6,7,10,11,255]){
    const {actor,target,data}=fixture();data.result=result;await miss(actor,target,{},{});assert.deepEqual(endpoint(data),[0,0,0]);
  }
  for(const result of [4,8,9]){const {actor,target,data,p}=fixture([0,0,0]);data.result=result;await miss(actor,target,{},p);assert.equal(endpoint(data)[2],7);}
});
test('near miss retains native lateral scaling, extra distance draw, actor+1 LOS and duplicated target Z before height',async()=>{
  const {actor,target,data,p,trace}=fixture([0,0,0]);await miss(actor,target,{},p);
  assert.equal(trace.filter(v=>v==='draw').length,3);
  const line=trace.find(v=>typeof v==='object');assert.deepEqual(line.from,[10,10,1]);assert.equal(line.to[2],5);
  assert.deepEqual([line.source,line.other,line.transparent],[1,2,1]);assert.equal(endpoint(data)[2],7);
});
test('exact five-unit near distance omits extra draw and creature radius is read after repeated cast',async()=>{
  const {actor,target,data,p,trace}=fixture([0,0]);target.position=[15,10,0];let casts=0;
  p.creature=o=>{casts++;return o;};p.personalSpace=()=>Math.fround(.6);
  await miss(actor,target,{},p);assert.equal(casts,2);assert.equal(trace.filter(v=>v==='draw').length,2);
  assert.equal(endpoint(data)[2],7);
});
test('far miss uses signed missedBy, two draws and original quadrant sign before adding target',async()=>{
  const {actor,target,data,p,trace}=fixture();target.position=[30,10,2];await miss(actor,target,{},p);
  assert.equal(trace.filter(v=>v==='draw').length,2);assert.deepEqual(endpoint(data),[28,10,7]);
});
test('blocked miss copies exact LOS hit rather than applying area height or target position',async()=>{
  const {actor,target,data,p}=fixture();target.position=[30,10,0];p.lineOfSight=(a,from,to,hit)=>{hit.splice(0,3,12,13,14);return 0;};p.height=()=>assert.fail('No height on obstruction');
  await miss(actor,target,{},p);assert.deepEqual(endpoint(data),[12,13,14]);
});
test('outside endpoint clips only LOS target, then retains original XY and target Z on a clear path',async()=>{
  const {actor,target,data,p,trace}=fixture();target.position=[30,10,2];p.area=()=>({width:2,height:10});
  await miss(actor,target,{},p);assert.deepEqual(trace.find(v=>typeof v==='object').to,[20,10,3]);assert.deepEqual(endpoint(data),[28,10,2]);
});
test('native divisor faults remain visible for active rules rather than silently adjusting RNG',async()=>{
  const {actor,target,data,p}=fixture([0,0,0]);data.missedBy=0;
  await assert.rejects(miss(actor,target,{},p),/division fault/);
});
