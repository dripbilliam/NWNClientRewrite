import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {scriptPlayAnimation,executeScriptAnimation} from '../src/script_animation.js';
import {actionParameter,addObjectAction,createObjectActionState} from '../src/object_actions.js';
import {clearCreatureMovementAction} from '../src/combat_lifecycle.js';
const bits=value=>{const v=new DataView(new ArrayBuffer(4));v.setFloat32(0,value,true);return v.getInt32(0,true);};
const actor=()=>({objectType:5,nativeFieldEc:1,objectActionState:createObjectActionState()});
function animation(o,id,speed,duration){return addObjectAction(o.objectActionState,6,65535,[{type:1,value:id},{type:2,value:bits(speed)},{type:2,value:bits(duration)},{type:1,value:1}]);}
function providers(trace,now){return{dead:()=>0,dying:()=>0,worldTime:()=>({day:1,time:now.value}),dayLength:100000,setAnimation:(_o,id)=>trace.push(id)};}

test('script IDs translate to native animation IDs, with active MODELTYPE deciding the two conditional variants',async()=>{
  const o=actor(),p={modelType:()=> 'P'};
  for(const [id,native] of [[1,52],[16,6],[92,170],[93,0],[100,53],[112,71],[113,70],[114,90],[116,23],[-1,0],[999,0]]){
    await scriptPlayAnimation(o,id,1,0,false,p);assert.equal(actionParameter(o.objectActionState.list.tail.action,0),native);
  }
  await scriptPlayAnimation(o,112,1,0,false,{modelType:()=> 'S'});assert.equal(actionParameter(o.objectActionState.list.tail.action,0),0);
  const placeable={...actor(),objectType:9};await scriptPlayAnimation(placeable,202,.5,2,false,{});assert.equal(actionParameter(placeable.objectActionState.list.head.action,0),75);
  const count=o.objectActionState.list.count;o.nativeFieldEc=0;await scriptPlayAnimation(o,1,1,0,false,p);assert.equal(o.objectActionState.list.count,count);
});
test('immediate PlayAnimation clears first and inserts at head; ActionPlayAnimation appends',async()=>{
  const o=actor(),trace=[],p={clearActions:()=>trace.push('clear')};
  addObjectAction(o.objectActionState,30,65535,[]);
  await scriptPlayAnimation(o,1,1,0,true,p);assert.deepEqual(trace,['clear']);assert.equal(o.objectActionState.list.head.action.actionId,6);
});
test('animation execution starts its own clock, uses signed speed with absolute lifetime, and returns idle at exact completion',async()=>{
  const o=actor(),n=animation(o,33,-2,0),now={value:100},trace=[],p=providers(trace,now);o.objectActionState.list.shift();
  assert.equal(await executeScriptAnimation(o,n,p),1);assert.equal(o.nativeAnimationSpeedDC,-2);assert.equal(n.parameterData[3],0);
  now.value=3599;assert.equal(await executeScriptAnimation(o,n,p),1);
  now.value=3600;assert.equal(await executeScriptAnimation(o,n,p),2);assert.equal(o.nativeAnimationSpeedDC,1);assert.deepEqual(trace,[33,33,1]);
});
test('duration controls looping animations, while one-shot animations retain native fixed lengths',async()=>{
  for(const [id,speed,seconds,milliseconds] of [[52,2,5,5000],[44,1,99,1734],[47,1,0,1500],[59,1,0,867],[36,1,0,1000],[36,1,99,99000],[0,0,0,2000]]){
    const o=actor(),n=animation(o,id,speed,seconds),now={value:10},p=providers([],now);o.objectActionState.list.shift();
    assert.equal(await executeScriptAnimation(o,n,p),1);now.value=10+milliseconds-1;assert.equal(await executeScriptAnimation(o,n,p),1,`${id} before`);
    now.value++;assert.equal(await executeScriptAnimation(o,n,p),2,`${id} at`);
  }
});
test('long animations dispose consecutive matching requests but preserve the first different request and group order',async()=>{
  const o=actor(),n=animation(o,52,1,30);o.objectActionState.list.shift();animation(o,52,1,60);animation(o,52,1,99);const other=animation(o,52,2,30);animation(o,52,1,30);
  assert.equal(await executeScriptAnimation(o,n,providers([],{value:1})),1);assert.equal(o.objectActionState.list.count,2);assert.equal(o.objectActionState.list.head.action,other);
  const dying={...providers([],{value:2}),dying:()=>1};assert.equal(await executeScriptAnimation(o,n,dying),3);
});
test('animation cancellation takes the shared native tail without resetting body animation or speed',async()=>{
  const o={...actor(),animationState:52,nativeAnimationSpeedDC:2,lockOrientationId:OBJECT_INVALID},n=animation(o,52,2,30);
  o.objectActionState.startDay=3;o.objectActionState.startTime=4;
  assert.equal(await clearCreatureMovementAction(o,n,1,{messageAvailable:()=>true,setLock:()=>assert.fail()}),1);
  assert.equal(o.animationState,52);assert.equal(o.nativeAnimationSpeedDC,2);assert.equal(o.objectActionState.startDay,0);
});
test('death constructor stores native type19 and raw flags and application delegates to the existing death owner',async()=>{
  const s=new ModuleSession(null),o=s.register('creature','o',{}),e=s.commands.EffectDeath([7,-2],{self:o.id});
  assert.equal(e.type,19);assert.equal(e.subtype,8);assert.deepEqual(e.integers,[7,-2,0,0,0,0,0,0]);
  let applied;s.damage.death=(target,e)=>{applied={target,e};};await s.effects.apply(0,e,o.id,0,{});
  assert.equal(applied.target,o);assert.equal(applied.e.type,19);assert.equal((o.effects??[]).length,0);
});
