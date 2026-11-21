import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {advanceLocalClocks} from '../scripts/advance-effect-clock.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';

function fixture(){const s=new ModuleSession(null,{runStartupScripts:false}),actor=s.register('creature','time-stop-caster',{authored:{ClassList:[]},stats:{}}),other=s.register('creature','ordinary-target',{authored:{ClassList:[]},stats:{}});s.worldTimer.setTime(7,0);s.nativeServerPause.timer1.reset(s.worldTimer);s.nativeServerPause.timer2.reset(s.worldTimer);return{s,actor,other};}
async function stop(s,actor,seconds){const e=s.commands.EffectTimeStop([],{self:actor.id});await s.effects.apply(1,e,actor.id,seconds);return actor.effects.find(r=>r.type===64);}

test('retained Time Stop owns active-clock expiry, recast merges into first effect, removal resumes unchanged world deadline and IDs',async()=>{
 const{s,actor,other}=fixture(),cursor=s.registry.nextObjectId[0],begin=runtimeDiagnostics.records.length,first=await stop(s,actor,1);
 assert.ok(first);assert.equal(s.nativeServerPause.flags,1);assert.deepEqual(s.nativeServerPause.list10100,[actor.id]);assert.equal(s.activeTimer(other.id),s.worldTimer);assert.equal(s.activeTimer(actor.id),s.nativeServerPause.timer1);
 advanceLocalClocks(s,500);const merged=await stop(s,actor,1);assert.equal(merged,first);assert.equal(actor.effects.filter(e=>e.type===64).length,1);assert.deepEqual([first.expiryDay,first.expiryTime],[7,1500]);assert.deepEqual(s.worldTimer.time(),{day:7,time:0});
 advanceLocalClocks(s,1000);await s.effects.updateObject(actor);assert.ok(actor.effects.includes(first));advanceLocalClocks(s,1);await s.effects.updateObject(actor);assert.ok(!actor.effects.includes(first));assert.equal(s.nativeServerPause.flags,0);assert.deepEqual(s.nativeServerPause.list10100,[]);assert.deepEqual(s.worldTimer.time(),{day:7,time:0});assert.equal(s.registry.nextObjectId[0],cursor);assert.equal(s.registry.get(actor.id),actor);assert.equal(s.registry.get(other.id),other);
 assert.deepEqual(runtimeDiagnostics.records.slice(begin).filter(d=>d.severity==='error'),[]);
});

test('Time Stop immunity retains duplicate and DM exclusions and survives Time Stop cleanup until its own removal',async()=>{
 const{s,actor,other}=fixture();const immunity=target=>s.effects.create(98,target.id,[],8);
 const a=immunity(actor),b=immunity(other),c=immunity(other);await s.effects.applyNative(a,actor.id);await s.effects.applyNative(b,other.id);await s.effects.applyNative(c,other.id);assert.deepEqual(s.nativeServerPause.list10100,[actor.id,other.id]);
 const first=await stop(s,actor,1);await s.effects.remove(actor.id,first.id);assert.equal(s.nativeServerPause.flags,0);assert.ok(s.nativeServerPause.list10100.includes(actor.id));await s.effects.remove(other.id,b.id);assert.ok(s.nativeServerPause.list10100.includes(other.id));await s.effects.remove(other.id,c.id);assert.ok(!s.nativeServerPause.list10100.includes(other.id));
 actor.isDM=true;await s.effects.remove(actor.id,a.id);assert.ok(s.nativeServerPause.list10100.includes(actor.id));assert.deepEqual(actor.effects,[]);
});

test('Time Stop admitted during pause2 retains without changing exclusion or pause state as the original handler does',async()=>{
 const{s,actor}=fixture();await s.setPauseState(2,1);const e=await stop(s,actor,1);assert.ok(e);assert.equal(s.nativeServerPause.flags,2);assert.deepEqual(s.nativeServerPause.list10100,[]);assert.deepEqual(s.nativeServerPause.list100f8,[]);
});
