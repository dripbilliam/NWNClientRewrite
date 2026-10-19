import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseNcs} from '../src/ncs.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-script-log-v1.json',report={queries:[],authored:[]};
try{
 const messages=[],s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>messages.push(m)}).initialize([],{character:await fs.readFile(`${install}/data/lcv/cleric.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>{};s.scriptLog.now=()=>new Date(2026,0,1,0,0,0);
 const invoke=async(text)=>{const ordinal=s.vm.api.findIndex(row=>row.name==='WriteTimestampedLogEntry');assert.equal(ordinal,560);const frame={stack:[]};s.vm.push(frame,'string',text);const ncs=Buffer.alloc(20);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(20,9);ncs.set([5,0,ordinal>>>8,ordinal&255,1,0x20,0],13);return s.vm.run(parseNcs(ncs,'timestamped_runtime'),s.player.id,{situation:{pc:13,bp:0,stack:frame.stack}});};
 const start=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0];
 for(const[mode,echo,text]of[[0,false,'Plain %s\0hidden'],[0,true,'Config only'],[1,false,'Debug only'],[2,true,'Enabled €']]){
  s.scriptLog.debugMode100f0=mode;s.scriptLog.debugLogToPlayers=echo;const begin=runtimeDiagnostics.records.length,before=messages.length,result=await invoke(text);assert.equal(result.stack.length,0);
  const records=runtimeDiagnostics.records.slice(begin),logs=records.filter(r=>r.code==='script.timestamped-log-entry');assert.equal(logs.length,1);assert.equal(logs[0].message,`[Thu Jan  1 00:00:00] ${text.split('\0')[0]}\n`);assert.equal(logs[0].context.objectId,s.player.id);assert.equal(logs[0].context.script,'timestamped_runtime');
  assert.equal(messages.length-before,mode&&echo?1:0);if(mode&&echo)assert.equal(messages.at(-1).text,'[ServerLog:Thu Jan  1 00:00:00] '+text);
  report.queries.push({mode,echo,log:logs[0],messages:messages.slice(before)});
 }
 assert.equal(s.registry.nextObjectId[0],cursor);
 // Real installed script's invalid recipe-tag branch. Active spell metadata
 // selects the impact; no replacement script, intercepted engine call or
 // JavaScript spell outcome. Startup/general AI remain isolated.
 const source=s.registry.get(s.equipmentSlot(s.player,2)?.id);assert.ok(source);const armor=source.id,sourceTag=source.tag,propertyCount=source.activeProperties.length+source.passiveProperties.length;
 const spell=s.spellBook.castingSpell(654);assert.equal(spell.impactScript.toLowerCase(),'x2_s2_addprop');s.scriptLog.debugMode100f0=0;s.scriptLog.debugLogToPlayers=false;
 const begin=runtimeDiagnostics.records.length,before=messages.length;
 s.combat.enqueueEvent(19,s.player.id,s.player.id,0,{spellId:spell.id,casterId:s.player.id,targetId:armor,itemId:0x7f000000,featId:65535,casterLevel:1,position:[s.player.position[0],-s.player.position[2],s.player.position[1]],script:spell.impactScript});await s.scheduler.pump();
 const diagnostics=runtimeDiagnostics.records.slice(begin),logs=diagnostics.filter(r=>r.code==='script.timestamped-log-entry');assert.equal(logs.length,1);assert.match(logs[0].message,/AddItemProperty spellscript attached but tag does not contain 3 letter receipe code/);assert.equal(logs[0].context.script,'x2_s2_addprop');assert.equal(s.registry.get(armor),source);assert.equal(source.tag,sourceTag);assert.equal(source.activeProperties.length+source.passiveProperties.length,propertyCount);assert.deepEqual(diagnostics.filter(r=>r.severity==='error'),[]);
 report.authored.push({spellId:spell.id,script:spell.impactScript,armor,castItem:0x7f000000,diagnostics,messages:messages.slice(before)});
 report.diagnostics=runtimeDiagnostics.records.slice(start);assert.deepEqual(report.diagnostics.filter(r=>r.severity==='error'),[]);report.validation='PASS';report.limits='Real parsed NCS command560, installed Prelude/cleric/canonical IDs and untouched installed add-property script error branch through event19. Native-code cases separately validate wrapper, timestamp and sender. Controlled wall clock, isolated startup/AI; no full spell cast/resource-consumption, encoded network envelope or original client debug-window parity claim.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,queries:report.queries.length,authored:report.authored.length,error:report.error}));
