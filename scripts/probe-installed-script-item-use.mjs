// Actual installed property enumeration -> typed ActionUseItem910/911 ->
// shared UseItem/action46 -> authored impact/resource/delayed destruction.
// Original character/assets unchanged; entry/startup/general AI are isolated.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-script-item-use-v1.json',report={rows:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics=[...runtimeDiagnostics.records];
 const actor=s.player,classes=structuredClone(actor.nativeTalentClasses),abilities=structuredClone(actor.nativeSpellLikeAbilities),item=actor.inventory.map(id=>s.registry.get(id)).find(i=>i.baseItem===49&&i.activeProperties.some(p=>p.type===15));assert.ok(item);
 const invoke=async(ordinal,args)=>{const api=s.vm.api[ordinal],frame={stack:[]};for(let n=args.length-1;n>=0;n--)s.vm.push(frame,api.args[n].type,args[n]);return s.vm.run({name:'owned_installed_item_command',instructions:new Map([[13,{op:5,command:ordinal,argc:args.length,pc:13,next:14}],[14,{op:0x20,pc:14,next:15}]])},actor.id,{situation:{pc:13,bp:0,stack:frame.stack}});};
 let handle=(await invoke(612,[item.id])).stack[0].value;
 while((await invoke(615,[handle])).stack[0].value!==0&&(await invoke(614,[handle])).stack[0].value!==15)handle=(await invoke(613,[item.id])).stack[0].value;
 assert.equal(handle.type,91);const index=item.activeProperties.findIndex(p=>p.propertyId===handle.propertyId);assert.ok(index>=0);report.enumerated={itemId:item.id,effectId:handle.id,propertyId:handle.propertyId,index};
 const before=structuredClone(item.activeProperties),miss={...handle,propertyId:(BigInt(`0x${handle.propertyId}`)^0x8000000000000000n).toString(16).padStart(16,'0')};
 assert.deepEqual((await invoke(910,[item.id,miss,actor.id,0,1])).stack,[]);assert.equal(actor.objectActionState.list.count,0);assert.deepEqual(item.activeProperties,before);report.noMatchingProperty={provided:miss.propertyId,queued:0};
 for(const [ordinal,consume]of [[910,0],[910,1],[911,1],[910,1]]){
  await s.combat.clearActions(actor);actor.combatRound.started=0;const health={beforeInjury:s.hitPoints(actor.id,false)};await s.damage.subtract(actor,Math.min(10,health.beforeInjury-1));health.before=s.hitPoints(actor.id,false);
  const start=runtimeDiagnostics.records.length,impacts=[],events=[],animations=[],errors=[],run=s.runScript.bind(s),dispatch=s.combat.dispatchEvent.bind(s.combat),before={charges:item.charges,stackSize:item.stackSize,properties:structuredClone(item.activeProperties)},originalHandle=structuredClone(handle);
  s.runScript=async(name,id,options)=>{if(id===actor.id)impacts.push({name,id,at:s.scheduler.time,spell:actor.nativeSpellId218,itemId:actor.nativeSpellTarget818,targetId:actor.nativeSpellTarget214,point:[...actor.nativeSpellPoint208]});return run(name,id,options);};
  s.combat.dispatchEvent=async(o,e)=>{if(o.id===item.id)events.push({id:e.eventId,target:o.id,at:s.scheduler.time});return dispatch(o,e);};
  const point=[actor.position[0],-actor.position[2],actor.position[1]],target=ordinal===910?actor.id:{areaId:0x7f000000,position:point};
  const result=await invoke(ordinal,[item.id,handle,target,0,consume]);assert.deepEqual(result.stack,[]);assert.deepEqual(handle,originalHandle);assert.deepEqual({charges:item.charges,stackSize:item.stackSize,properties:item.activeProperties},before);
  const queued=[...actor.objectActionState.list].map(n=>n.actionId);assert.ok(queued.includes(46));
  for(let n=0;n<200;n++){
   s.scheduler.advance(100);s.worldTimer.snapshot();try{await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));}catch(error){errors.push(error.message);break;}animations.push(actor.animationState);
   while(s.scheduler.events[0]?.due<=s.scheduler.time){const event=s.scheduler.events.shift();try{await s.dispatch(event);}catch(error){errors.push(error.message);}}
   if(actor.objectActionState.list.count===0&&impacts.length&&!s.scheduler.events.some(e=>e.targetId===item.id))break;
  }
  s.runScript=run;s.combat.dispatchEvent=dispatch;health.after=s.hitPoints(actor.id,false);
  const diagnostics=runtimeDiagnostics.records.slice(start),failures=diagnostics.filter(d=>d.severity==='error'),knownLoadFailures=failures.filter(d=>d.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&d.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.'),newFailures=failures.filter(d=>!knownLoadFailures.includes(d));
  report.rows.push({ordinal,consume,actorId:actor.id,itemId:item.id,propertyId:handle.propertyId,health,before,after:{charges:item.charges,stackSize:item.stackSize,present:s.registry.get(item.id)===item,inventory:actor.inventory.includes(item.id),repository:[...actor.nativeRepository.ids()].includes(item.id)},queued,remaining:[...actor.objectActionState.list].map(n=>n.actionId),impacts,events,animations:[...new Set(animations)],errors,diagnostics,knownLoadFailures,newFailures});
  assert.deepEqual(errors,[]);assert.deepEqual(newFailures,[]);assert.equal(actor.objectActionState.list.count,0);assert.ok(animations.includes(70));
  const spellId=s.items.castProviders().spellIndex(before.properties[index].subtype),impact=impacts.filter(i=>i.name===s.spellBook.castingSpell(spellId).impactScript);assert.equal(impact.length,1);assert.equal(impact[0].targetId,ordinal===910?actor.id:0x7f000000);assert.equal(impact[0].itemId,item.id);
  if(ordinal===910)assert.ok(health.after>health.before);else assert.deepEqual(impact[0].point,point.map(Math.fround));
  if(!consume)assert.equal(item.stackSize,before.stackSize);else if(before.stackSize>1)assert.equal(item.stackSize,before.stackSize-1);else{assert.equal(s.registry.get(item.id),undefined);assert.ok(!actor.inventory.includes(item.id));assert.ok(![...actor.nativeRepository.ids()].includes(item.id));assert.equal(events.filter(e=>e.id===11).length,1);}
  assert.deepEqual(actor.nativeTalentClasses,classes);assert.deepEqual(actor.nativeSpellLikeAbilities,abilities);assert.equal(s.registry.get(actor.id),actor);
 }
 report.limits='Unchanged installed wizard potion/property enumeration; actual typed910/911, consume0/1, unmatched uint64 ID no-op, shared46/70 and authored impacts, canonical stack/destruction. Location command intentionally supplies INVALID area to prove it does not gate on that field. Startup/general AI off; no renderer, full location-spell repertoire, scroll/wand or campaign acceptance.';
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({enumerated:report.enumerated,rows:report.rows.map(({ordinal,consume,health,after,errors,newFailures})=>({ordinal,consume,health,after,errors,newFailures})),failure:report.failure}));if(report.failure)process.exitCode=1;
