// Unchanged installed inventory, actual typed script talent dispatch, action46,
// authored impact script, resource consumption and delayed event11 removal.
// Startup/AI disabled to isolate casting; original install remains read-only.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {scriptTalent} from '../src/talent.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-item-casting-v1.json',report={rows:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics=[...runtimeDiagnostics.records];
 const actor=s.player,classes=structuredClone(actor.nativeTalentClasses),abilities=structuredClone(actor.nativeSpellLikeAbilities),choices=[];
 for(const id of actor.inventory){const item=s.registry.get(id);for(const [index,property]of item.activeProperties.entries()){
  if(property.type!==15||property.remaining===0)continue;const spellId=s.items.castProviders().spellIndex(property.subtype),spell=s.spellBook.castingSpell(spellId);if(spell)choices.push({itemId:id,index,base:item.baseItem,spellId,targetType:spell.targetType});
 }}report.choices=choices;assert.ok(choices.length);
 const attempts=choices.filter((c,n,a)=>a.findIndex(x=>x.base===c.base)===n).flatMap(choice=>Array.from({length:s.registry.get(choice.itemId).activeProperties[choice.index].costValue===1?s.registry.get(choice.itemId).stackSize:1},()=>choice));
 for(const [attempt,choice]of attempts.entries()){
  // Injure through the existing damage owner so the installed healing script
  // must actually restore HP; no character/spell/inventory template is edited.
  const health={beforeInjury:s.hitPoints(actor.id,false)};await s.damage.subtract(actor,Math.min(10,health.beforeInjury-1));health.beforeCast=s.hitPoints(actor.id,false);
  const item=s.registry.get(choice.itemId),before={charges:item.charges,stackSize:item.stackSize,properties:structuredClone(item.activeProperties)},start=runtimeDiagnostics.records.length,errors=[],impacts=[],animations=[],events=[],run=s.runScript.bind(s),dispatch=s.combat.dispatchEvent.bind(s.combat);
  s.runScript=async(name,id,options)=>{if(id===actor.id)impacts.push({name,id,at:s.scheduler.time,spell:actor.nativeSpellId218,itemId:actor.nativeSpellTarget818,casterOverride:actor.nativeCasterOverride820,casterLevel:actor.nativeCasterOverride824});return run(name,id,options);};
  s.combat.dispatchEvent=async(o,e)=>{if(o.id===item.id||e.eventId===8)events.push({id:e.eventId,target:o.id,at:s.scheduler.time});return dispatch(o,e);};
  await s.combat.clearActions(actor);actor.combatRound.started=0;
  const location=(choice.targetType&1)===0&&(choice.targetType&4)!==0,ordinal=location?310:309,point=[actor.position[0],-actor.position[2],actor.position[1]],args=[{...scriptTalent(0,choice.spellId),itemId:item.id,itemPropertyIndex:choice.index},location?{areaId:actor.areaId,position:point}:actor.id],frame={stack:[]};
  for(let n=1;n>=0;n--)s.vm.push(frame,s.vm.api[ordinal].args[n].type,args[n]);
  const program={name:'owned_item_cast_fixture',instructions:new Map([[13,{pc:13,op:5,command:ordinal,argc:2,next:14}],[14,{pc:14,op:0x20,next:15}]])};
  if(attempt===0){const result=await s.vm.run(program,actor.id,{situation:{pc:13,bp:0,stack:frame.stack}});assert.deepEqual(result.stack,[]);}
  else{const result=s.queuePlayerUseItem({actorId:actor.id,areaId:actor.areaId,itemId:item.id,propertyIndex:choice.index,variant:0,targetId:actor.id,location:0});await s.drainPlayerInputs();assert.equal(await result,0);}
  const queued=[...actor.objectActionState.list].map(n=>n.actionId);assert.ok(queued.includes(46));assert.deepEqual({charges:item.charges,stackSize:item.stackSize,properties:item.activeProperties},before);
  for(let n=0;n<200;n++){
   s.scheduler.advance(100);s.worldTimer.snapshot();try{await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));}catch(e){errors.push(e.message);break;}animations.push(actor.animationState);
   while(s.scheduler.events[0]?.due<=s.scheduler.time){const e=s.scheduler.events.shift();try{await s.dispatch(e);}catch(error){errors.push(error.message);}}
   if(actor.objectActionState.list.count===0&&impacts.length&&!s.scheduler.events.some(e=>e.targetId===item.id))break;
  }
  s.runScript=run;s.combat.dispatchEvent=dispatch;
  const diagnostics=runtimeDiagnostics.records.slice(start),failures=diagnostics.filter(d=>d.severity==='error'),knownLoadFailures=failures.filter(d=>d.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&d.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.'),newFailures=failures.filter(d=>!knownLoadFailures.includes(d));
  health.afterCast=s.hitPoints(actor.id,false);report.rows.push({choice,input:attempt===0?'typed-script-talent':'decoded-player-item9',actorId:actor.id,health,before,after:{charges:item.charges,stackSize:item.stackSize,properties:structuredClone(item.activeProperties),present:s.registry.get(item.id)===item,inInventory:actor.inventory.includes(item.id),inRepository:[...actor.nativeRepository.ids()].includes(item.id)},queued,queue:[...actor.objectActionState.list].map(n=>n.actionId),impacts,events,animations:[...new Set(animations)],errors,diagnostics,knownLoadFailures,newFailures});
  assert.deepEqual(errors,[]);assert.deepEqual(newFailures,[]);assert.equal(impacts.filter(i=>i.name===s.spellBook.castingSpell(choice.spellId).impactScript).length,1);assert.equal(impacts[0].spell,choice.spellId);assert.equal(impacts[0].itemId,item.id);assert.equal(impacts[0].casterOverride,1);assert.equal(actor.objectActionState.list.count,0);
  assert.deepEqual(actor.nativeTalentClasses,classes);assert.deepEqual(actor.nativeSpellLikeAbilities,abilities);assert.equal(s.registry.get(actor.id),actor);
  if(choice.spellId===31)assert.ok(health.afterCast>health.beforeCast,'Installed Cure Critical Wounds actually heals');
  if(before.properties[choice.index].costValue===1&&before.stackSize===1&&item.plot===0){assert.equal(s.registry.get(item.id),undefined);assert.ok(!actor.inventory.includes(item.id));assert.ok(![...actor.nativeRepository.ids()].includes(item.id));assert.equal(events.filter(e=>e.id===11&&e.target===item.id).length,1);}
  else assert.ok(item.charges<before.charges||item.stackSize<before.stackSize||item.activeProperties.some((p,n)=>p.usesPerDay<before.properties[n].usesPerDay));
 }
 const chargeSession=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await chargeSession.enterArea('m0q1a',[24,0,-14]);chargeSession.scheduler.events=[];
 const charged=chargeSession.registry.get(chargeSession.player.inventory.find(id=>chargeSession.registry.get(id).baseItem===49));assert.ok(charged);
 const invoke=async(ordinal,args)=>{const frame={stack:[]},api=chargeSession.vm.api[ordinal];for(let n=args.length-1;n>=0;n--)chargeSession.vm.push(frame,api.args[n].type,args[n]);return chargeSession.vm.run({name:'item_charge_fixture',instructions:new Map([[13,{pc:13,op:5,command:ordinal,argc:args.length,next:14}],[14,{pc:14,op:0x20,next:15}]])},chargeSession.player.id,{situation:{pc:13,bp:0,stack:frame.stack}});};
 assert.equal(chargeSession.vm.api[607].name,'GetItemCharges');assert.equal(chargeSession.vm.api[608].name,'SetItemCharges');
 const start=runtimeDiagnostics.records.length;assert.deepEqual((await invoke(608,[charged.id,7])).stack,[]);assert.equal((await invoke(607,[charged.id])).stack[0].value,7);
 const properties=structuredClone(charged.activeProperties);await invoke(608,[charged.id,0]);assert.equal(charged.charges,7);assert.deepEqual(charged.activeProperties,properties);
 const queued=chargeSession.scheduler.events.find(q=>q.targetId===charged.id&&q.event.eventId===11);assert.ok(queued);assert.equal(queued.due,chargeSession.scheduler.time);chargeSession.scheduler.events.splice(chargeSession.scheduler.events.indexOf(queued),1);await chargeSession.dispatch(queued);
 assert.equal(chargeSession.registry.get(charged.id),undefined);assert.equal((await invoke(607,[charged.id])).stack[0].value,0);
 const diagnostics=runtimeDiagnostics.records.slice(start);assert.deepEqual(diagnostics.filter(d=>d.severity==='error'),[]);
 report.chargeCommands={actorId:chargeSession.player.id,itemId:charged.id,storedBeforeDestroy:charged.charges,present:false,diagnostics,remainingEvents:chargeSession.scheduler.events.map(q=>({targetId:q.targetId,...q.event}))};
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({rows:report.rows.map(({choice,after,impacts,events,animations,errors})=>({choice,after,impacts,events,animations,errors})),failure:report.failure}));if(report.failure)process.exitCode=1;
