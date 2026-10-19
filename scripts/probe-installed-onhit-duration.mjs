import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {resolveOnHitProperty} from '../src/on_hit_property.js';
import {onHitDurationNames} from '../src/on_hit_duration.js';
import {getAttackData} from '../src/combat_attack_data.js';
import {advanceLocalClocks,advanceToEffectExpiry} from './advance-effect-clock.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {skillInfo} from '../src/skill_rank.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-onhit-duration-v1.json',controlFrames=process.argv.includes('--control-frames'),report={checks:[],controlFrames};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/cleric.bic`)}),actor=s.player,target=[...s.registry.objects.values()].find(o=>o.objectType===5&&/goblin/i.test(o.tag)&&!o.plot&&!s.isDead(o)&&s.scriptEmotion(actor.id,o.id,'enemy')===1);assert.ok(target);
 await s.enterArea(s.registry.get(target.areaId).resRef,[target.position[0]+2,target.position[1],target.position[2]]);s.scheduler.events=[];s.scheduler.beforePump=()=>{};
 if(controlFrames)await s.combat.combatStepProviders().preflightMovement(target,s.currentArea);
 const item=s.equippedItems(actor).find(i=>(i.data.PropertiesList??[]).some(p=>p.PropertyName===48&&p.Subtype===9));assert.ok(item);const template=item.data.PropertiesList.find(p=>p.PropertyName===48&&p.Subtype===9),begin=runtimeDiagnostics.records.length,refs=[...s.registry.objects],cursor=s.registry.nextObjectId[0],round=getAttackData(actor.combatRound,actor.combatRound.currentAttack&255);
 // Select subtype->owner pairs from the independent original dispatcher.
 // Only an owned temporary property record changes; installed items do not.
 const original=JSON.parse(await fs.readFile('backups/animations/native-onhit-dispatch-observations.json')),choices=new Map();
 const scriptCalls=[],runScript=s.runScript.bind(s),home=[...target.position];s.runScript=(name,id,options)=>{scriptCalls.push({name,id});return runScript(name,id,options);};
 for(const row of original.rows){if(row.case.type!==48)continue;const apply=row.trace.find(t=>t[0]==='apply'&&onHitDurationNames.includes(t[1]));if(apply)choices.set(apply[1],row.case.subtype);}assert.equal(choices.size,11);
 for(const[name,subtype]of choices){
  const property={...template,Subtype:subtype},attempts=[];let selected=false;
  for(let seed=1;seed<=128&&!selected;seed++){s.random.seed(seed);round.lists[0].length=0;await resolveOnHitProperty(actor,target,item,property,0,0,s.combat.onHitPropertyProviders(item,property));attempts.push({seed,payloadTypes:round.lists[0].map(e=>e.type)});selected=round.lists[0].some(e=>e.type===40);}assert.ok(selected,`${name}: native chance/save gates must admit a payload`);
  const payloads=round.lists[0].splice(0),link=payloads.find(e=>e.type===40),id=link.id;report.current={name,subtype,attempts,id,duration:link.duration};
  for(const payload of payloads)await s.combat.dispatchEvent(target,{eventId:5,callerId:actor.id,payload});assert.equal(target.nativeField180,0);
  const active=target.effects.filter(e=>e.id===id),mechanical=active.filter(e=>e.type!==30);report.current.applied=active.map(e=>({type:e.type,integers:e.integers,duration:e.duration,durationType:e.durationType}));assert.ok(mechanical.length,`${name}: native mechanical state retained`);assert.ok(active.some(e=>e.type===30&&e.integers[0]===207));
  if(controlFrames){
   // Each owner fixture starts a fresh frame interval after the preceding
   // effect-only deadline jump; startup/spawn/general scheduling stay isolated.
   target.nativeSpawnState548=1;const now=s.activeTimer(target.id).time();target.nativeLastUpdateDayBc=now.day;target.nativeLastUpdateTimeC0=now.time;const first=scriptCalls.length,state=target.nativeField771,position=[...target.position];
   for(let frame=0;frame<2;frame++){advanceLocalClocks(s,100);await s.combat.updateNativeFrame(target);await s.scheduler.pump();}
   report.current.control={state,position,after:[...target.position],scripts:scriptCalls.slice(first)};
   // Native heartbeat deliberately excludes Daze state5 from control-script
   // dispatch; its controller handles commandability without a state script.
   if([2,3,6,8,9].includes(state)){const table=await s.items.table('statescripts'),script=String(table.orderedRows[state].SCRIPTNAME).toLowerCase();assert.ok(scriptCalls.slice(first).some(c=>c.id===target.id&&c.name.toLowerCase()===script),`${name}: active StateScripts entry must execute`);}
  }
  advanceToEffectExpiry(s,mechanical[0]);await s.effects.updateObject(target,s.activeTimer(target.id).time());advanceLocalClocks(s,1);await s.effects.updateObject(target,s.activeTimer(target.id).time());assert.ok(!target.effects.some(e=>e.id===id),`${name}: shared ID expires naturally`);assert.equal(target.nativeField771,0);assert.equal(target.nativeSlow764,0);
  report.checks.push({...report.current,check:'active-onhit-tables-real-save-native-payload-delivery-and-natural-expiry'});
  if(controlFrames){await s.combat.clearActions(target);s.setPosition(target,home,0);}
 }
 const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name);assert.ok(ordinal>=0);const f={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(f,s.vm.api[ordinal].args[i].type,args[i]);return(await s.vm.run({name:'skill_buff_probe_'+name,instructions:new Map([[13,{pc:13,op:5,command:ordinal,argc:args.length,next:14}],[14,{pc:14,op:0x20,next:15}]])},actor.id,{situation:{pc:13,bp:0,stack:f.stack}})).stack[0]?.value;};
 const skill=s.characterRules.skills.orderedRows.findIndex((_r,i)=>skillInfo(s.characterRules,i).untrained!==0);assert.ok(skill>=0);
 for(const[name,delta,icon]of[['EffectSkillIncrease',3,43],['EffectSkillDecrease',-2,44]]){
  const before=await invoke('GetSkillRank',[skill,actor.id,0]),effect=await invoke(name,[skill,Math.abs(delta)]);await invoke('ApplyEffectToObject',[1,effect,actor.id,6]);const after=await invoke('GetSkillRank',[skill,actor.id,0]);assert.equal(after,before+delta);assert.ok(actor.effects.some(e=>e.type===67&&e.id===effect.id&&e.integers[0]===icon));assert.ok(actor.nativeEffectIcons778.records.some(r=>r.iconId===icon));
  const stored=actor.effects.find(e=>e.type===effect.type&&e.id===effect.id);advanceToEffectExpiry(s,stored);advanceLocalClocks(s,1);await s.effects.updateObject(actor,s.activeTimer(actor.id).time());assert.equal(await invoke('GetSkillRank',[skill,actor.id,0]),before);assert.ok(!actor.nativeEffectIcons778.records.some(r=>r.iconId===icon));report.checks.push({name,check:'NCS-skill-buff-changes-effective-rank-creates-native-icon-and-expires',skill,before,after,icon});
 }
 for(const[id,o]of refs)assert.equal(s.registry.get(id),o);report.registry={before:cursor,after:s.registry.nextObjectId[0],added:[...s.registry.objects].filter(([id])=>!refs.some(([prior])=>prior===id)).map(([id,o])=>({id,kind:o.kind,sourceKey:o.sourceKey}))};if(!controlFrames)assert.equal(s.registry.nextObjectId[0],cursor);runtimeDiagnostics.flushRepeated();report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.loadDiagnostics=runtimeDiagnostics.records.slice(0,begin);report.validation='PASS';report.limits='Installed Prelude/cleric/goblin; explicit owned property subtype variants selected from original dispatcher observations, active chance/duration/DC tables and real saves with documented seed search. Actual payload construction, combat event5 and effect/control/stat/vision application plus natural shared-ID expiry. NCS skill buff/rank/application wrappers verify effective totals and icon43/44 expiry on the PC. Original items/assets unchanged and existing canonical references stable. Default fixture isolates control scripts; optional --control-frames runs two actual native frames/heartbeat/perception and verifies active StateScripts, reporting legitimate authored registry additions. Frame stamps/spawn state/position/action resets isolate consecutive effect fixtures. Startup/general scheduling/strike admission and renderer remain isolated; broad Fear/UI probes cover separate paths. Not full on-hit/combat/spell/campaign/network completion; all diagnostics retained.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks.map(c=>c.name),current:report.current?.name,error:report.error,diagnostics:report.diagnostics?.length}));
