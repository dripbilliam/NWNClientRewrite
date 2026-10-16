import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-use-object-v1.json',report={messages:[]};
function compile(api,name,rows){
 const code=[],word=v=>code.push(v>>>8&255,v&255),dword=v=>code.push(v>>>24&255,v>>>16&255,v>>>8&255,v&255);
 for(const [kind,value,argc]of rows){if(kind==='call'){const id=api.findIndex(row=>row.name===value);assert.ok(id>=0,value);code.push(5,0);word(id);code.push(argc);}
  else if(kind==='string'){const bytes=Buffer.from(value,'ascii');code.push(4,5);word(bytes.length);code.push(...bytes);}
  else{code.push(4,kind==='self'?6:3);dword(kind==='self'?0:value);}}
 code.push(0x20,0);const bytes=Buffer.alloc(13+code.length);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(bytes.length,9);bytes.set(code,13);return parseNcs(bytes,name);
}
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>report.messages.push(m)}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();for(const area of s.areas.values())await area.nativeGeometry.objects.load();
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,actor=s.player,stats=actor.stats,client=s.combat.broadcastProviders().client(actor.id),gui=client.inventoryGUI,target=[...s.registry.objects.values()].find(o=>o.objectType===9&&o.nativeHasInventory4f8===1&&o.nativeRepository.length===0&&o.areaId===actor.areaId&&o.locked===0&&!o.trapped&&o.tag);
 assert.ok(target);for(const [slot,name]of [['used','uo_used'],['click','uo_click'],['open','uo_open'],['closed','uo_closed']]){target.scripts[slot]=name;s.programs.set(name,Promise.resolve(compile(s.vm.api,name,[['int',1],['string',name],['self'],['call','SetLocalInt',3]])));}
 const out={point:[0,0,0],range:0};await s.combat.useRange(actor,target.id,out);s.setPosition(actor,out.point,0);assert.equal(await s.combat.inUseRange(actor,target.id,0,0),1);
 const input=s.queuePlayerUseObject(target.id,{popup:1,notify:1});await s.drainPlayerInputs();assert.equal(await input,1);assert.equal(actor.objectActionState.list.count,1);const node=actor.objectActionState.list.head.action;assert.equal(node.actionId,40);assert.deepEqual([...node.parameterTypes.slice(0,3)],[3,1,1]);
 const before=Math.trunc(performance.now())>>>0,time=s.worldTimer.time();await s.combat.runActions(actor,time.day,time.time);const after=Math.trunc(performance.now())>>>0;
 assert.equal(actor.objectActionState.list.head.action,node);assert.equal(node.parameterData[2],1);assert.ok(node.parameterData[1]>=before+500&&node.parameterData[1]<=after+500);assert.equal(gui.openInventory.id,target.id);assert.equal(target.nativeField508,1);
 await s.scheduler.pump();for(const name of ['uo_used','uo_click','uo_open'])assert.equal(target.locals.getInt(name),1,name);assert.equal(s.commands.GetLastUsedBy([],{self:target.id}),actor.id);assert.equal(s.commands.GetClickingObject([],{self:target.id}),actor.id);assert.equal(s.commands.GetLastOpenedBy([],{self:target.id}),actor.id);
 assert.equal(await s.combat.executeUseObject(actor,node,{timer:()=>node.parameterData[1]-1>>>0}),1);assert.equal(await s.combat.executeUseObject(actor,node,{timer:()=>node.parameterData[1]}),2);
 report.initial={actorId:actor.id,targetId:target.id,group:node.groupId,point:out.point,range:out.range,deadline:node.parameterData[1],before,after};
 const runActions=()=>{const now=s.worldTimer.time();return s.combat.runActions(actor,now.day,now.time);};
 await new Promise(resolve=>setTimeout(resolve,510));await runActions();assert.equal(actor.objectActionState.list.count,0);assert.equal(actor.lockOrientationId,OBJECT_INVALID);
 await s.commands.ActionInteractObject([target.id],{self:actor.id});assert.equal(actor.objectActionState.list.count,1);const queued=actor.objectActionState.list.head.action;await s.combat.cancelQueuedAction(actor,40,queued.groupId);assert.equal(actor.objectActionState.list.count,0);assert.equal(gui.openInventory.id,target.id,'Cancelling an unexecuted interaction must not close an existing inventory');
 const ordinal=s.byTag(target.tag).findIndex(o=>o===target);assert.ok(ordinal>=0);
 const script=compile(s.vm.api,'uo_request',[['int',ordinal],['string',target.tag],['call','GetObjectByTag',2],['call','ActionInteractObject',1]]);await s.vm.run(script,actor.id);assert.equal(actor.objectActionState.list.head.action.actionId,40);assert.equal(actor.objectActionState.list.head.action.parameterData[0]>>>0,target.id);
 target.locals.setInt('uo_closed',0);await runActions();await s.scheduler.pump();assert.equal(gui.openInventory.id,OBJECT_INVALID);assert.equal(target.nativeField508,0);assert.equal(target.locals.getInt('uo_closed'),1);assert.equal(s.commands.GetLastClosedBy([],{self:target.id}),actor.id);
 await s.combat.clearActions(actor);assert.equal(s.registry.get(actor.id),actor);assert.equal(actor.stats,stats);report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.validation='PASS';
 report.limits='Installed native decoded input/action40/GUI/scheduler/OnClick-OnUsed-OnOpen-OnClosed callbacks, real monotonic500ms completion, cancellation and ordinary NCS GetObjectByTag/ActionInteractObject request. Positioning at an actual PWK use point and tiny in-memory marker/request scripts are fixture setup. AI/startup disabled; no rendered loot window, pickup, locked/trapped lower-owner, corpse broadcast or packet codec claim. All diagnostics retained.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,initial:report.initial,failure:report.failure}));if(report.failure)process.exitCode=1;
