import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {addPauseExclusion} from '../src/server_pause.js';
import {linkEffects} from '../src/linked_effect.js';
const invalid=0x7f000000;
function fixture(){const s=new ModuleSession(null),actor=s.register('creature','effect-clock-fixture',{});s.worldTimer.setTime(7,0);s.nativeServerPause.timer1.reset(s.worldTimer);s.nativeServerPause.timer2.reset(s.worldTimer);return{s,actor,advance:ms=>{s.scheduler.advance(ms);for(const clock of [s.worldTimer,s.nativeServerPause.timer1,s.nativeServerPause.timer2])clock.snapshot();}};}
test('actual linked application captures world time before each handler and does not overwrite finalized child deadlines',async()=>{
 const{s,actor}=fixture(),left=s.effects.create(67,invalid,[1]),right=s.effects.create(67,invalid,[2]),parent=linkEffects(left,right,invalid,{create:(...a)=>s.effects.create(...a),setCreator:(...a)=>s.effects.setCreator(...a)});parent.durationType=1;parent.duration=1;
 const original=s.effects.applyNativeBody.bind(s.effects);s.effects.applyNativeBody=(value,...args)=>{if(value.type===67&&value.integers[0]===1)s.worldTimer.setTime(7,200);return original(value,...args);};
 await s.effects.applyNative(parent,actor.id);assert.equal(actor.effects.length,2);assert.deepEqual(actor.effects.map(e=>[e.expiryDay,e.expiryTime]),[[7,1000],[7,1200]]);assert.ok(actor.effects.every(e=>!Object.hasOwn(e,'expires')));assert.equal(actor.effects[0].id,actor.effects[1].id);
});
test('shared effect runtime uses native deadlines under excluded/world clocks, preserves exact-expiry and loading fields',async()=>{
 const{s,actor,advance}=fixture(),other=s.register('creature','ordinary-clock-fixture',{}),cursor=s.registry.nextObjectId[0];
 const first=s.effects.create(67,invalid,[1]),second=s.effects.create(67,invalid,[2]);for(const e of [first,second]){e.durationType=1;e.duration=1;}
 await s.effects.applyNative(first,actor.id);await s.effects.applyNative(second,other.id);assert.equal(actor.effects[0].expiryTime,1000);assert.equal(other.effects[0].expiryTime,1000);
 addPauseExclusion(s.nativeServerPause,actor.id,1);await s.setPauseState(1,1);advance(1000);await s.effects.updateObject(actor);await s.effects.updateObject(other);assert.equal(actor.effects.length,1);assert.equal(other.effects.length,1);
 advance(1);await s.effects.updateObject(actor);await s.effects.updateObject(other);assert.equal(actor.effects.length,0);assert.equal(other.effects.length,1);await s.setPauseState(1,0);
 advance(1000);await s.effects.updateObject(other);assert.equal(other.effects.length,1);advance(1);await s.effects.updateObject(other);assert.equal(other.effects.length,0);
 const loaded=s.effects.create(67,invalid,[3]);Object.assign(loaded,{durationType:1,duration:999,expiryDay:7,expiryTime:1500});await s.effects.applyNative(loaded,actor.id,undefined,1);assert.equal(actor.effects[0].expiryTime,1500);
 advance(499);await s.effects.updateObject(actor);assert.equal(actor.effects.length,1);advance(1);await s.effects.updateObject(actor);assert.equal(actor.effects.length,0);
 assert.equal(s.registry.nextObjectId[0],cursor);assert.equal(s.registry.get(actor.id),actor);assert.equal(s.registry.get(other.id),other);
});
