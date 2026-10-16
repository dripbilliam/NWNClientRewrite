// Installed spell/scripts and canonical objects. Startup/general AI isolated;
// this probe does not manufacture learned spells or replace script AI results.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{
 runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const actor=s.player,choices=[];
for(const [index,state]of actor.nativeTalentClasses.entries())for(const [level,slots]of state.memorized.entries())for(const slot of slots){
 if(!slot?.ready)continue;const row=s.characterRules.spells.orderedRows[slot.id];if(!/summon/i.test(row?.Label??''))continue;
 const domain=slot.domain?level-s.spellBook.metamagicCost(slot.metamagic):0;
 if(s.spellBook.uses(actor,slot.id,index,domain,slot.metamagic)>0)choices.push({spellId:slot.id,classIndex:index,domainLevel:domain,metamagic:slot.metamagic});}
assert.ok(choices.length);const cast=choices[0],input=s.queuePlayerCastSpell({...cast,targetId:actor.id});await s.drainPlayerInputs();assert.equal(await input,1);
for(let n=0;n<150;n++){s.scheduler.advance(100);s.worldTimer.snapshot();await s.effects.updateObject(actor);await s.combat.updateTimer(actor,100);if(actor.objectActionState.list.count)await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));await s.scheduler.pump();if(actor.associateIds.length)break;}
const summon=s.registry.get(s.commands.GetAssociate([4,actor.id,1],{self:actor.id}));assert.ok(summon);const start=runtimeDiagnostics.records.length,trace=[],run=s.runScript.bind(s);
s.runScript=async(name,id,options)=>{const entry={name,id,options};trace.push(entry);try{const result=await run(name,id,options);entry.executed=result.executed;return result;}catch(error){entry.error=error.message;throw error;}};
const steps=[];let following=null;
for(const command of [-5,-2,-7,-3,-4]){
 const before=runtimeDiagnostics.records.length,request=s.queuePlayerAssociateCommand(summon.id,command);await s.drainPlayerInputs();assert.equal(await request,0);await s.scheduler.pump();
 assert.equal(summon.lastSpeakerId,actor.id);assert.equal(summon.listenPatternNumber,command);
 assert.equal(s.commands.GetLastAssociateCommand([summon.id],{self:actor.id}),command);
 assert.equal(s.commands.GetMatchedSubstringsCount([],{self:summon.id}),0);
 if(command===-5){
  assert.deepEqual([...summon.objectActionState.list].map(n=>n.actionId),[55,58]);
  const from=[...summon.position],saved=[...actor.position];actor.position[0]=Math.fround(actor.position[0]+8);s.updatePositionArray(actor);
  summon.combatUpdateTime=s.scheduler.time;
  let movementError=null;const sampled=[];
  try{for(let n=0;n<150;n++){
   s.scheduler.advance(100);s.worldTimer.snapshot();await s.updateWorldObject(summon,s.scheduler.time,false);await s.scheduler.pump();
   sampled.push({at:s.scheduler.time,position:[...summon.position],animation:summon.animationState,queue:[...summon.objectActionState.list].map(n=>n.actionId)});
  }}catch(error){movementError=error.message;}
  following={from,to:[...summon.position],target:[...actor.position],sampled,movementError};
  actor.position.splice(0,3,...saved);s.updatePositionArray(actor);
 }
 steps.push({command,speaker:summon.lastSpeakerId,pattern:summon.listenPatternNumber,matchedCount:summon.nativeMatchedStrings.count,
  queue:[...summon.objectActionState.list].map(n=>({actionId:n.actionId,data:n.parameterData})),diagnostics:runtimeDiagnostics.records.slice(before)});
}
const report={cast,summon:{id:summon.id,masterId:summon.masterId,tag:summon.tag,scripts:summon.scripts},trace,steps,following,diagnostics:runtimeDiagnostics.records.slice(start),
 limits:'Installed ready memorized summon plus real conversation script-event command dispatch. Startup/general AI disabled. Queue/script evidence is not complete associate AI, original-process, renderer or multiplayer acceptance.'};
await fs.writeFile('backups/animations/live-associate-listen.json',JSON.stringify(report,null,2));
assert.equal(following.movementError,null);assert.ok(Math.hypot(...following.to.map((v,i)=>v-following.from[i]))>1,'Real update path must move the summon toward its master');
assert.ok(trace.every(entry=>entry.executed),'Every authored conversation handler must execute');
assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[],'All exercised engine calls, including conditional PlayVoiceChat, must execute without errors');
console.log(JSON.stringify({summon:report.summon,trace,following:following&&{...following,sampled:following.sampled.filter((_,i)=>i%25===0)},steps:steps.map(({command,queue,diagnostics})=>({command,queue,diagnostics:diagnostics.map(d=>({code:d.code,message:d.message,engine:d.context?.engineCall}))}))},null,2));
