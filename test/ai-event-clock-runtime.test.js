import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {NwScriptVm} from '../src/nwscript_vm.js';
import {ScriptScheduler} from '../src/script_scheduler.js';
import {addPauseExclusion,removePauseExclusion} from '../src/server_pause.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {advanceLocalClocks} from '../scripts/advance-effect-clock.mjs';

test('ordinary and item casting read the canonical actor active timer while delayed events retain world time',async()=>{
 const s=new ModuleSession(null,{runStartupScripts:false}),actor=s.register('creature','active-caster',{authored:{},stats:{}}),other=s.register('creature','ordinary-caster',{authored:{},stats:{}});
 s.worldTimer.setTime(7,0);s.nativeServerPause.timer1.reset(s.worldTimer);s.nativeServerPause.timer2.reset(s.worldTimer);
 for(const o of [actor,other]){o.objectActionState.startDay=7;o.objectActionState.startTime=0;}
 const item=s.spells.itemActionProviders();addPauseExclusion(s.nativeServerPause,actor.id,1);await s.setPauseState(1,1);advanceLocalClocks(s,251);
 assert.equal(s.spells.elapsed(actor),251);assert.equal(s.spells.elapsed(other),0);assert.deepEqual(item.worldTime(actor),{day:7,time:251});assert.deepEqual(item.worldTime(other),{day:7,time:0});
 s.scheduler.enqueue(actor.id,{type:'clock-fixture'},0.1);assert.deepEqual(s.scheduler.events.map(e=>[e.day,e.time]),[[7,100]]);
 addPauseExclusion(s.nativeServerPause,actor.id,2);await s.setPauseState(2,1);advanceLocalClocks(s,99);assert.equal(s.spells.elapsed(actor),350);assert.equal(s.spells.elapsed(other),0);assert.deepEqual(item.worldTime(actor),{day:7,time:350});assert.equal(s.scheduler.isDue(s.scheduler.events[0]),false);
 await s.setPauseState(2,0);assert.equal(s.spells.elapsed(actor),251);await s.setPauseState(1,0);assert.equal(s.spells.elapsed(actor),0);assert.deepEqual(item.worldTime(actor),{day:7,time:0});
});

test('actual native AI traversal retains delayed NCS situations on world time despite an excluded target and transfers them in native tie order',async()=>{
 const s=new ModuleSession(null,{runNativeAI:true}),o=s.register('waypoint','event-clock-fixture',{});s.started=true;s.aiMaster.setLevel(o,1);s.worldTimer.setTime(7,0);s.nativeServerPause.timer1.reset(s.worldTimer);s.nativeServerPause.timer2.reset(s.worldTimer);
 const api=[{name:'SetLocalInt',returns:'void',args:[{type:'object'},{type:'string'},{type:'int'}]}];s.vm=new NwScriptVm({api,command:name=>s.commands[name]});
 const situation=(name,value)=>{const frame={stack:[]};s.vm.push(frame,'int',value);s.vm.push(frame,'string','event_clock_result');s.vm.push(frame,'object',o.id);return{program:{name,instructions:new Map([[13,{pc:13,op:5,command:0,argc:3,next:14}],[14,{pc:14,op:0x20,next:15}]])},pc:13,bp:0,stack:frame.stack};};
 const trace=[],dispatch=s.dispatch.bind(s);s.dispatch=async q=>{trace.push(q.event.situation.program.name);await dispatch(q);if(q.event.situation.program.name==='immediate')s.commands.DelayCommand([0,situation('nested',4)],{self:o.id});};
 const cursor=s.registry.nextObjectId[0],begin=runtimeDiagnostics.records.length;addPauseExclusion(s.nativeServerPause,o.id,2);await s.setPauseState(2,1);
 const first=situation('first',1),second=situation('second',2);s.commands.DelayCommand([0.1,first],{self:o.id});s.commands.DelayCommand([0.1,second],{self:o.id});s.commands.DelayCommand([0,situation('immediate',3)],{self:o.id});
 assert.equal(s.scheduler.events[1].event.situation,second);assert.equal(s.scheduler.events[2].event.situation,first);
 s.scheduler.advance(1000);await s.scheduler.pump();assert.deepEqual(trace,['immediate','nested']);assert.equal(s.local(o.id,'event_clock_result','int'),4);assert.deepEqual(s.scheduler.events.map(e=>[e.day,e.time]),[[7,100],[7,100]]);assert.equal(s.activeTimer(o.id),s.nativeServerPause.timer2);assert.equal(s.scheduler.events[0].due,1100);
 removePauseExclusion(s.nativeServerPause,o.id,2);await s.setPauseState(2,0);s.scheduler.advance(99);await s.scheduler.pump();assert.deepEqual(trace,['immediate','nested']);s.scheduler.advance(1);await s.scheduler.pump();assert.deepEqual(trace,['immediate','nested','second','first']);assert.equal(s.local(o.id,'event_clock_result','int'),1);
 assert.equal(s.registry.get(o.id),o);assert.equal(s.registry.nextObjectId[0],cursor);assert.equal(s.scheduler.events.length,0);const diagnostics=runtimeDiagnostics.records.slice(begin);assert.equal(diagnostics.filter(d=>d.code==='scheduler.event-added-while-paused').length,2);assert.deepEqual(diagnostics.filter(d=>d.severity==='error'),[]);
});
test('diagnostic pump captures world time once and does not deliver future events merely because a callback changes the calendar',async()=>{
 let now={day:7,time:0};const trace=[],clock={dayLength:1000,secondsPerDay:1,time:()=>({...now})},s=new ScriptScheduler({getWorldTimer:()=>clock,validTarget:()=>true,dispatch:q=>{trace.push(q.event);if(q.event==='first')now={day:7,time:900};}});
 s.enqueueAbsolute(0,'first',7,0);s.enqueueAbsolute(0,'future',7,500);await s.pump();assert.deepEqual(trace,['first']);assert.equal(s.events.length,1);await s.pump();assert.deepEqual(trace,['first','future']);
});
