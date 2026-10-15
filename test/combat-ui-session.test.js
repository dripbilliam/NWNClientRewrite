import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';

test('a UI session can skip opening scripts while retaining native AI traversal',async()=>{
  const s=new ModuleSession(null,{runStartupScripts:false,runNativeAI:true});
  s.started=true;
  const visited=[];
  s.aiMaster.updateState=async p=>{visited.push('native');await p.updateObject({id:1});};
  s.updateWorldObject=async(object,now,native)=>visited.push([object.id,native]);
  await s.updateWorld();
  assert.deepEqual(visited,['native',[1,true]]);
  assert.equal(s.runStartupScripts,false);
  // Isolated owner tests still explicitly omit full AI by default.
  assert.equal(new ModuleSession(null,{runStartupScripts:false}).runNativeAI,false);
});

test('native session delivers a large finite startup batch before AI, retaining same-time appends and future events',async()=>{
  const s=new ModuleSession(null,{runNativeAI:true});s.started=true;
  const actor=s.register('waypoint','batch',{nativeAILevel7c:-1,nativeAILocked80:0});s.aiMaster.setLevel(actor,1);
  const trace=[];s.updateModuleAI=async()=>{};s.updateWorldObject=async()=>trace.push('AI');
  s.dispatch=async({event})=>{trace.push(event.ordinal);if(event.ordinal===0)s.scheduler.enqueueMilliseconds(actor.id,{ordinal:1250},0);};
  for(let ordinal=0;ordinal<1250;ordinal++)s.scheduler.enqueueMilliseconds(actor.id,{ordinal},0);
  s.scheduler.enqueueMilliseconds(actor.id,{ordinal:'future'},1000);
  await s.scheduler.pump();
  assert.deepEqual(trace.filter(v=>v!=='AI'),Array.from({length:1251},(_,i)=>i));
  if(trace.includes('AI'))assert.ok(trace.indexOf('AI')>trace.indexOf(1250));
  assert.deepEqual(s.scheduler.events.map(e=>[e.event.ordinal,e.due]),[['future',1000]]);
});

test('a failed perception target retains its flags and does not prevent the next query',async()=>{
  const s=new ModuleSession(null),actor={id:1},blocked={id:2,flags:3},visible={id:3,flags:0},errors=[];
  s.report=(error,context)=>errors.push([error.message,context.targetId,context.operation]);
  const error=new Error('Indoor sound owner unavailable');
  s.combat.updatePerception=async(a,target)=>{assert.equal(a,actor);if(target===blocked)throw error;target.flags=1;};
  const p=s.combat.perceptionProviders();
  await p.updatePerception(actor,blocked,0);
  await p.updatePerception(actor,visible,0);
  assert.equal(blocked.flags,3);
  assert.equal(visible.flags,1);
  assert.deepEqual(errors,[[error.message,2,'perception-target-update']]);
});

test('repeated engine failures notify once per area while retaining all occurrences in the journal',()=>{
  const notices=[],s=new ModuleSession(null,{onDiagnostic:message=>notices.push(message)});
  const begin=runtimeDiagnostics.records.length;
  for(let i=0;i<50;i++)s.report(new Error('Sound path unavailable'),{area:'inside',objectId:i});
  s.report(new Error('ActionUseSkill unavailable'),{area:'inside'});
  s.report(new Error('Sound path unavailable'),{area:'outside'});
  assert.deepEqual(notices,['Sound path unavailable','ActionUseSkill unavailable','Sound path unavailable']);
  assert.equal(runtimeDiagnostics.records.length-begin,52);
  assert.deepEqual([...s.diagnosticNotifications.values()],[50,1,1]);
});
