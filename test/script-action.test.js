import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {addObjectAction,actionParameter} from '../src/object_actions.js';
import {addDoCommandAction,executeDoCommand} from '../src/script_action.js';

const fixture=()=>{
  const s=new ModuleSession(null,{runStartupScripts:false});
  s.vm={};
  const actor=s.register('creature','actor',{stats:{currentHP:20},modelType:'P',commandable:true});
  return {s,actor};
};
const situation=()=>({program:{name:'owned',instructions:new Map([[13,{op:0x20,next:14}]])},pc:13,bp:0,stack:[]});

test('DoCommand waits in the canonical action queue and executes once with the actor as OBJECT_SELF',async()=>{
  const {s,actor}=fixture(),captured=situation(),calls=[];
  s.vm.run=async(program,self,options)=>calls.push([program.name,self,options.situation===captured]);
  await s.commands.ActionDoCommand([captured],{self:actor.id});
  const node=actor.objectActionState.list.head.action;
  assert.equal(node.actionId,37);assert.equal(node.parameterTypes[0],5);assert.equal(actionParameter(node,0),captured);
  assert.equal(s.scheduler.events.length,0);assert.equal(calls.length,0);
  await s.combat.runActions(actor,1,500,0n,{microseconds:()=>0n});
  assert.deepEqual(calls,[['owned',actor.id,true]]);
  assert.equal(node.parameterData[0],0);assert.equal(captured.disposed,true);
  assert.equal(actor.objectActionState.list.count,0);
  await s.combat.runActions(actor,1,501,0n,{microseconds:()=>0n});assert.equal(calls.length,1);
});

test('native rejection and cancellation release captured stacks without executing script',async()=>{
  const {s,actor}=fixture(),rejected=situation();actor.nativeFieldEc=0;
  assert.equal(await addDoCommandAction(actor,rejected,x=>s.deleteSituation(x)),0);
  assert.equal(rejected.disposed,true);assert.equal(actor.objectActionState.list.count,0);
  actor.nativeFieldEc=1;const canceled=situation();
  await s.commands.ActionDoCommand([canceled],{self:actor.id});
  actor.objectActionState.startDay=2;actor.objectActionState.startTime=123;
  await s.combat.clearActions(actor,{resetPath:()=>{}});
  assert.equal(canceled.disposed,true);assert.equal(actor.objectActionState.list.count,0);
  assert.equal(actor.objectActionState.startDay,0);assert.equal(actor.objectActionState.startTime,0);
});

test('dead and dying are exact-one native vetoes; disposition remains with the node on result3',async()=>{
  const {actor}=fixture(),captured=situation();
  const node=addObjectAction(actor.objectActionState,37,1,[{type:5,value:captured}]);
  let calls=0;const p={dead:()=>1,dying:()=>0,runSituation:()=>calls++};
  assert.equal(await executeDoCommand(actor,node,p),3);assert.equal(node.parameterData[0],captured);
  p.dead=()=>0;p.dying=()=>1;assert.equal(await executeDoCommand(actor,node,p),3);
  p.dead=()=>2;p.dying=()=>2;assert.equal(await executeDoCommand(actor,node,p),2);assert.equal(calls,1);
});

test('a resumed script failure is recorded and consumed, never replayed on the next frame',async()=>{
  const {s,actor}=fixture(),captured=situation(),errors=[];let calls=0;
  s.vm.run=async()=>{calls++;throw new Error('Script failed after a side effect');};s.report=e=>errors.push(e.message);
  await s.commands.ActionDoCommand([captured],{self:actor.id});
  await s.combat.runActions(actor,1,1,0n,{microseconds:()=>0n});
  await s.combat.runActions(actor,1,2,0n,{microseconds:()=>0n});
  assert.equal(calls,1);assert.deepEqual(errors,['Script failed after a side effect']);assert.equal(captured.disposed,true);
});
