import test from 'node:test';
import assert from 'node:assert/strict';
import {spotDetection,listenDetection,animationStationary} from '../src/perception_detection.js';
import { PathInformation } from '../src/path_information.js';
import {OBJECT_INVALID as invalid} from '../src/game_object_array.js';
function fixture(){
  const base={position:[0,0,0],orientation:[1,0,0],visionFlags:0,blindSightRange:0,animationState:0,nativeField700:0,
    nativeField6ec:0,nativeField6ed:1,nativeField8d4:65535,nativeSightRange7b0:20,nativeCombatSightRange7b4:10,
    nativeHearingRange7b8:20,nativeCombatHearingRange7bc:10,nativeAttackRange71c:1,nativeSilence75c:0,
    nativeSize718:3,nativeHideRoll7c4:5,nativeMoveSilentlyRoll7c5:5,nativeSpotRoll7c6:5,nativeListenRoll7c7:5,
    nativeStealthTarget8fc:invalid};
  const actor={...base,id:1,nativePathInfo:new PathInformation(1)},target={...base,id:2,position:[3,0,0],nativePathInfo:new PathInformation(2)};
  const area={flags:0,nativeSpotModifier21c:0,nativeListenModifier220:0,nativeSoundPath288:new PathInformation(invalid)},calls=[];
  const ranks=new Map([[5,5],[8,5],[17,5],[6,5]]);
  const p={area:()=>area,skillRank:(o,i,t,b)=>{calls.push(['skill',o.id,i,t.id,b]);return ranks.get(i);},hasFeat:()=>0,
    timeOfDay:()=>1,visualTypes:()=>[],rulesetInt:(name,fallback)=>fallback,client:()=>null,favoredEnemyBonus:()=>0,
    itemInSlot:()=>null,creature:id=>id===target.id?target:null,visibility:()=>null,object:id=>id===target.id?target:null,
    lineOfSight:(...args)=>{calls.push(['los',...args]);return 0;},plotSoundPath:()=>1};
  return{actor,target,area,calls,ranks,p};
}
test('native stationary animation classification narrows ushort and excludes exactly the moving states',()=>{
  const moving=[2,3,4,78,79,84,85,86,87];
  for(let i=0;i<100;i++)assert.equal(animationStationary(i),Number(!moving.includes(i)),`animation ${i}`);
  assert.equal(animationStationary(65538),0);assert.equal(animationStationary(-1),1);
});
test('Spot preserves repeated Hide calls and strict positive tie, using raised three-dimensional range',async()=>{
  const {actor,target,area,p,calls}=fixture();
  assert.equal(await spotDetection(actor,target,0,p),0); // 5+5 -5-5 = tie.
  assert.deepEqual(calls,[['skill',2,5,1,0],['skill',2,5,1,0],['skill',1,17,2,0]]);
  area.nativeSpotModifier21c=1;assert.equal(await spotDetection(actor,target,0,p),1);
  target.position=[20,0,0];assert.equal(await spotDetection(actor,target,0,p),1);
  target.position=[20,1,0];assert.equal(await spotDetection(actor,target,0,p),0);
  actor.nativeField700=1;target.position=[11,0,0];assert.equal(await spotDetection(actor,target,0,p),0);
});
test('Spot blindness and retained state precede automatic senses, which still obey sight range',async()=>{
  const {actor,target,p,calls}=fixture();actor.visionFlags=4;
  assert.equal(await spotDetection(actor,target,1,p),0);assert.equal(await spotDetection(actor,target,0,p),1);assert.deepEqual(calls,[]);
  actor.visionFlags=32;actor.blindSightRange=3;assert.equal(await spotDetection(actor,target,0,p),1);
  target.position=[3.001,0,0];assert.equal(await spotDetection(actor,target,0,p),0);
  actor.visionFlags=16;assert.equal(await spotDetection(actor,target,0,p),0);
});
test('Spot night rules use native visual cache types and active ruleset values',async()=>{
  const {area,p}=fixture(),{actor,target}=fixture();area.nativeSpotModifier21c=1;p.timeOfDay=()=>2;
  const rules=[];p.rulesetInt=(name,fallback)=>{rules.push([name,fallback]);return fallback;};
  assert.equal(await spotDetection(actor,target,0,p),0);
  p.visualTypes=o=>o===actor?[182]:[];assert.equal(await spotDetection(actor,target,0,p),1);
  p.visualTypes=o=>o===actor?[]:[153];assert.equal(await spotDetection(actor,target,0,p),1);
  assert.deepEqual(rules,[['SPOT_NO_LIGHT_MODIFIER',5],['SPOT_NO_LIGHT_MODIFIER',5],['HIDING_LIGHT_MODIFIER',10]]);
});
test('Spot client-facing penalty uses native orientation and signed byte rank with passive halving',async()=>{
  const {actor,target,p,area,ranks}=fixture();area.nativeSpotModifier21c=5;p.client=o=>o===target?{}:null;
  target.position=[-3,0,0];assert.equal(await spotDetection(actor,target,0,p),0);
  target.position=[3,0,0];assert.equal(await spotDetection(actor,target,0,p),1);
  actor.animationState=2;ranks.set(17,255);area.nativeSpotModifier21c=11;
  assert.equal(await spotDetection(actor,target,0,p),1); // signed -1 / 2 truncates to zero.
});
test('Listen retains two directional LOS calls and distance penalty despite both LOS results being blocked',async()=>{
  const {actor,target,area,p,calls}=fixture();area.nativeListenModifier220=1;
  assert.equal(await listenDetection(actor,target,0,p),0); // tie after distance penalty -1.
  area.nativeListenModifier220=2;assert.equal(await listenDetection(actor,target,0,p),1);
  const rays=calls.filter(c=>c[0]==='los');assert.deepEqual(rays[0].slice(2,4),[[0,-0,1],[3,-0,1]]);
  assert.deepEqual(rays[1].slice(2,4),[[3,-0,1],[0,-0,1]]);
  assert.deepEqual(rays[0].slice(-3),[invalid,invalid,0]);
});
test('Listen silence, update bit and retained melee reach veto before LOS; sanctuary state veto remains distinct',async()=>{
  const {actor,target,p,calls}=fixture();target.nativeSilence75c=1;
  assert.equal(await listenDetection(actor,target,0,p),0);target.nativeSilence75c=0;actor.nativeField8d4=0;
  assert.equal(await listenDetection(actor,target,0,p),0);assert.deepEqual(calls,[]);
  actor.nativeField8d4=65535;assert.equal(await listenDetection(actor,target,1,p),0);
  target.position=[2,0,0];p.visibility=()=>7;assert.equal(await listenDetection(actor,target,1,p),0);
  assert.deepEqual(calls,[]);
});
test('Listen wall hit IDs preserve native first-ID lookup quirk and outdoor truncation before multiplication',async()=>{
  const {actor,target,area,p}=fixture();area.nativeListenModifier220=2;
  let ray=0;const lookups=[];
  p.lineOfSight=(a,from,to,hit,id)=>{id.id=++ray%2?99:100;hit.splice(0,3,...(ray%2?[0,0,0]:[10,0,0]));return 0;};
  p.object=id=>{lookups.push(id);return{position:[1,0,0]};};
  assert.equal(await listenDetection(actor,target,0,p),1);assert.deepEqual(lookups,[99,99]);
  p.lineOfSight=(a,from,to,hit,id)=>{hit.splice(0,3,...(++ray%2?[0,0,0]:[.99,0,0]));return 0;};
  assert.equal(await listenDetection(actor,target,0,p),1);
  p.lineOfSight=(a,from,to,hit,id)=>{hit.splice(0,3,...(++ray%2?[0,0,0]:[1,0,0]));return 0;};
  assert.equal(await listenDetection(actor,target,0,p),0);
});
test('Listen indoor sound path writes native XY and preserves exact result gate even for unstealthed targets',async()=>{
  const {actor,target,area,p}=fixture();area.flags=1;target.nativeField6ed=0;
  p.lineOfSight=(a,from,to,hit,id)=>{id.id=99;return 1;};
  p.plotSoundPath=(a,path)=>{assert.equal(a,area);assert.equal(path.raw.getFloat32(0x64,true),0);assert.equal(path.raw.getFloat32(0x4c,true),3);return 2;};
  assert.equal(await listenDetection(actor,target,0,p),0);
  p.plotSoundPath=()=>1;assert.equal(await listenDetection(actor,target,0,p),1);
  delete p.plotSoundPath;await assert.rejects(listenDetection(actor,target,0,p),/provider plotSoundPath/);
});
