import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-speech-strref-v1.json',report={events:[],actions:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:e=>report.events.push(e)}).initialize(['m0q1a'],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();report.events=[];const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0],a=s.player;
 const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name);assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,args.length,0x20,0],13);await s.vm.run(parseNcs(ncs,'speech_'+name),a.id,{situation:{pc:13,bp:0,stack:frame.stack}});};
 for(const volume of[0,1,2,3]){await invoke('SpeakStringByStrRef',[12345,volume]);const e=report.events.at(-1);assert.equal(e.strRef,12345);assert.equal(e.actorId,a.id);assert.equal(e.recipientId,a.id);assert.equal(e.wireActorId,(a.id|0x80000000)>>>0);assert.equal(e.channel,volume===1?10:volume===2?9:8);}
 let count=report.events.length;await invoke('SpeakStringByStrRef',[0x24,0]);assert.equal(report.events.length,count);
 const oldCommandable=a.nativeFieldEc;try{a.nativeFieldEc=0;await invoke('ActionSpeakStringByStrRef',[12345,0]);assert.equal(a.objectActionState.list.count,0);await invoke('SpeakStringByStrRef',[12345,0]);assert.equal(report.events.length,++count);}finally{a.nativeFieldEc=oldCommandable;}
 await invoke('ActionSpeakStringByStrRef',[12345,1]);assert.equal(report.events.length,count);const node=a.objectActionState.list.head.action;assert.equal(node.actionId,33);assert.deepEqual([...node.parameterTypes].slice(0,2),[1,1]);report.actions.push({id:node.actionId,group:node.groupId,parameters:node.parameterData.slice(0,2)});
 const now=s.worldTimer.time();await s.combat.runActions(a,now.day,now.time);assert.equal(a.objectActionState.list.count,0);assert.equal(report.events.length,count+1);assert.equal(report.events.at(-1).channel,10);
 assert.equal(s.registry.nextObjectId[0],cursor);report.delivery=s.speech.lastDelivery;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);report.validation='PASS';report.limits='Installed real NCS immediate/queued speech, canonical ID preservation, native scalar packet body, active shared action dispatch. Local recipient/body projection is separate from whole native client/network broadcast/TLK voice/lip/overhead behavior, which remains diagnosed. No Bane/Prayer or complete affected spell claim.';
 await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log('INSTALLED IMMEDIATE/QUEUED SPEECH STRREF PASS');
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error.stack);process.exitCode=1;}
