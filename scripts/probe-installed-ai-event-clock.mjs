import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {addPauseExclusion,removePauseExclusion} from '../src/server_pause.js';
import {advanceLocalClocks} from './advance-effect-clock.mjs';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-ai-event-clock-v1.json',report={checks:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,actor=s.player,other=[...s.registry.objects.values()].find(o=>o.objectType===5&&o!==actor&&o.stats&&o.areaId===s.currentArea.id),ids=[...s.registry.objects],cursor=s.registry.nextObjectId[0],state=s.nativeServerPause;assert.ok(other);
 // Isolate event dispatch from general AI; a separate runtime test drives the
 // actual NativeAIMaster traversal with the same NCS situation ownership.
 s.scheduler.beforePump=()=>{};
 const command=s.vm.api.findIndex(r=>r.name==='SetLocalInt');assert.ok(command>=0);
 const situation=(name,value,target)=>{const frame={stack:[]};s.vm.push(frame,'int',value);s.vm.push(frame,'string','event_clock_result');s.vm.push(frame,'object',target.id);return{program:{name,instructions:new Map([[13,{pc:13,op:5,command,argc:3,next:14}],[14,{pc:14,op:0x20,next:15}]])},pc:13,bp:0,stack:frame.stack};};
 const trace=[],dispatch=s.dispatch.bind(s);s.dispatch=async q=>{trace.push({name:q.event.situation.program.name,targetId:q.targetId,world:s.worldTimer.time()});await dispatch(q);};
 const before=s.worldTimer.time(),item=s.spells.itemActionProviders();for(const o of [actor,other]){o.objectActionState.startDay=before.day;o.objectActionState.startTime=before.time;}
 addPauseExclusion(state,actor.id,2);await s.setPauseState(2,1);
 s.commands.DelayCommand([0.1,situation('first',1,actor)],{self:actor.id});s.commands.DelayCommand([0.1,situation('second',2,actor)],{self:actor.id});s.commands.DelayCommand([0,situation('immediate',3,other)],{self:other.id});
 advanceLocalClocks(s,1000);await s.scheduler.pump();assert.deepEqual(trace.map(r=>r.name),['immediate']);assert.equal(s.local(other.id,'event_clock_result','int'),3);assert.equal(s.spells.elapsed(actor),1000);assert.equal(s.spells.elapsed(other),0);assert.deepEqual(item.worldTime(actor),s.activeTimer(actor.id).time());assert.deepEqual(item.worldTime(other),before);
 assert.deepEqual(s.scheduler.events.map(e=>[e.day,e.time]),[[before.day,before.time+100],[before.day,before.time+100]]);
 report.checks.push({check:'installed-NCS-immediate-dispatch-and-delayed-world-deadlines-during-pause',world:s.worldTimer.time(),active:s.activeTimer(actor.id).time(),ordinary:s.activeTimer(other.id).time(),pending:s.scheduler.events.map(e=>({targetId:e.targetId,day:e.day,time:e.time}))});
 await s.setPauseState(2,0);removePauseExclusion(state,actor.id,2);advanceLocalClocks(s,99);await s.scheduler.pump();assert.equal(trace.length,1);advanceLocalClocks(s,1);await s.scheduler.pump();assert.deepEqual(trace.map(r=>r.name),['immediate','second','first']);assert.equal(s.local(actor.id,'event_clock_result','int'),1);assert.equal(s.scheduler.events.length,0);
 report.checks.push({check:'resume-at-native-world-deadline-delivers-equal-positive-delays-LIFO',trace});
 assert.equal(s.registry.nextObjectId[0],cursor);for(const[id,o]of ids)assert.equal(s.registry.get(id),o);report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.equal(report.diagnostics.filter(d=>d.code==='scheduler.event-added-while-paused').length,2);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.validation='PASS';
 report.limits='Installed Prelude/wizard/canonical authored NPC, actual DelayCommand/NCS situation/SetLocalInt dispatch, shared real clocks and native deadline/tie behavior. Casting provider clock selection checked without a full cast. Startup/general AI isolated; diagnostic event pump used, with independent actual NativeAIMaster runtime coverage. Explicit pause inputs, no bound Time Stop cast or complete campaign claim; all load and runtime diagnostics retained.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks.map(c=>c.check),error:report.error,diagnostics:report.diagnostics?.length}));
