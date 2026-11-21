import test from 'node:test';
import assert from 'node:assert/strict';
import {receiveBlockedMovementEvent as receive} from '../src/blocked_movement.js';
import {ModuleSession} from '../src/module_session.js';
test('blocked movement captures client before writing caller history then runs script12 without substituting the blocker object',async()=>{
  const actor={id:1,nativeBlockingObject528:8},trace=[];
  await receive(actor,0x80000002,{client:id=>{trace.push(['client',id,actor.nativeBlockingObject528]);return null;},possessed:()=>0,
    scriptName:(o,n)=>{trace.push(['name',o.id,n]);return'default';},runScript:(o,n)=>trace.push(['run',o.id,n,o.nativeBlockingObject528])});
  assert.deepEqual(trace,[['client',1,8],['name',1,12],['run',1,12,0x80000002]]);
});
test('blocked movement stores history even when captured client default or possessed familiar suppresses its script',async()=>{
  const actor={id:1},p={client:()=>({}),possessed:()=>0,scriptName:()=> 'default',runScript:()=>assert.fail('Suppressed script')};
  await receive(actor,2,p);assert.equal(actor.nativeBlockingObject528,2);
  p.possessed=()=>1;p.rulesetInt=(name,value)=>{assert.equal(name,'ALL_ASSOCIATES_RUN_SCRIPTS');assert.equal(value,0);return 0;};
  p.scriptName=()=>assert.fail('Familiar should gate before script lookup');await receive(actor,3,p);assert.equal(actor.nativeBlockingObject528,3);
  p.rulesetInt=()=>2;p.scriptName=()=> 'owned';let ran=0;p.runScript=()=>ran++;await receive(actor,4,p);assert.equal(ran,1);
});
test('live movement queues event10 to actor, keeps blocking history until dispatch, and GetBlockingDoor returns creatures as well as doors',async()=>{
  const s=new ModuleSession(null),actor=s.register('creature','actor',{scripts:{blocked:'owned'}}),blocker=s.register('creature','blocker',{}),trace=[];
  s.program=async name=>({name});s.vm={run:(program,id)=>trace.push([program.name,id,s.commands.GetBlockingDoor([],{self:id})])};
  s.combat.movementProviders().blockedEvent(blocker.id,actor.id,{scriptEvent:31});
  assert.equal(actor.nativeBlockingObject528,undefined);const queued=s.scheduler.events[0];assert.equal(queued.targetId,actor.id);assert.equal(queued.event.callerId,blocker.id);
  await s.dispatch(queued);assert.deepEqual(trace,[['owned',actor.id,blocker.id]]);
  assert.equal(s.commands.GetBlockingDoor([],{self:0xffffffff}),0x7f000000);
  assert.throws(()=>s.commands.GetBlockingDoor([],{self:blocker.id}),/unavailable/);
});
