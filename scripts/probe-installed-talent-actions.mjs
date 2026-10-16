// Real typed VM dispatch using unchanged installed player/NPC pools. No
// spell/feat grants or original data writes; startup and native AI disabled.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {scriptTalent} from '../src/talent.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-talent-actions-v1.json',report={rows:[]};
try{
 for(const profile of ['class-object','class-location','feat-object','innate-object','innate-location']){
  const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/${profile==='feat-object'?'druid':'wizard'}.bic`)});
  await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics??=[...runtimeDiagnostics.records];
  let actor=s.player,talent,source;
  const location=profile.endsWith('location');
  if(profile==='feat-object')talent=scriptTalent(1,305);
  else if(profile.startsWith('class')){
   const slots=actor.nativeTalentClasses.flatMap((state,index)=>state.memorized.flatMap((rows,level)=>rows.map((slot,n)=>slot?.ready?{...slot,index,level,n}:null).filter(Boolean)));
   source=location?slots.find(slot=>(s.spellBook.castingSpell(slot.id)?.targetType&4)!==0):slots.find(slot=>slot.id===100);assert.ok(source,'Installed prepared spell exists');
   talent={...scriptTalent(0,source.id),classIndex:source.index,metamagic:source.metamagic};
  }else{
   const id=location?36:126;actor=[...s.registry.objects.values()].find(o=>o.objectType===5&&o.nativeSpellLikeAbilities?.some(a=>a.id===id&&a.remaining!==0));assert.ok(actor,'Installed NPC ability exists');
   source=actor.nativeSpellLikeAbilities.find(a=>a.id===id&&a.remaining!==0);talent={...scriptTalent(0,id),classIndex:254,casterLevel:source.casterLevel,metamagic:0};
  }
  const id=actor.id,root=actor.creatureData??actor.authored,stats=actor.stats,classes=structuredClone(actor.nativeTalentClasses),abilities=structuredClone(actor.nativeSpellLikeAbilities),feat=profile==='feat-object'?s.combat.highestFeat(actor,305):null,uses=feat===null?null:s.combat.remainingUses(actor,feat);
  const start=runtimeDiagnostics.records.length,errors=[],impacts=[],animations=[],run=s.runScript.bind(s);s.runScript=async(name,actorId,options)=>{if(actorId===id)impacts.push({name,actorId,at:s.scheduler.time,spell:actor.nativeSpellId218,feat:actor.nativeSpellFeat23c});return run(name,actorId,options);};
  const ordinal=location?310:309,api=s.vm.api[ordinal],point=[actor.position[0],-actor.position[2],actor.position[1]],args=[talent,location?{areaId:actor.areaId,position:point}:id],frame={stack:[]};
  assert.equal(api.name,location?'ActionUseTalentAtLocation':'ActionUseTalentOnObject');
  for(let n=args.length-1;n>=0;n--)s.vm.push(frame,api.args[n].type,args[n]);
  const program={name:'owned_talent_action_fixture',instructions:new Map([[13,{pc:13,op:5,command:ordinal,argc:2,next:14}],[14,{pc:14,op:0x20,next:15}]])};
  const result=await s.vm.run(program,id,{situation:{pc:13,bp:0,stack:frame.stack}});assert.deepEqual(result.stack,[]);assert.ok(actor.objectActionState.list.count>0||s.scheduler.events.length>0);
  for(let n=0;n<300;n++){
   s.scheduler.advance(100);s.worldTimer.snapshot();try{await s.combat.runActions(actor,...Object.values(s.worldTimer.time()));}catch(error){errors.push(error.message);break;}animations.push(actor.animationState);
   while(s.scheduler.events[0]?.due<=s.scheduler.time){const event=s.scheduler.events.shift();try{await s.dispatch(event);}catch(error){errors.push(error.message);}}
   if(actor.objectActionState.list.count===0&&impacts.length)break;
  }
  const diagnostics=runtimeDiagnostics.records.slice(start),failures=diagnostics.filter(d=>d.severity==='error'),knownLoadFailures=failures.filter(d=>d.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&d.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.'),newFailures=failures.filter(d=>!knownLoadFailures.includes(d));
  report.rows.push({profile,actorId:id,talent,source,usesBefore:uses,usesAfter:feat===null?null:s.combat.remainingUses(actor,feat),impacts,animations:[...new Set(animations)],errors,diagnostics,knownLoadFailures,newFailures,queue:[...actor.objectActionState.list].map(n=>n.actionId)});
  assert.deepEqual(errors,[]);assert.deepEqual(newFailures,[]);assert.ok(impacts.length);assert.equal(actor.objectActionState.list.count,0);assert.equal(s.registry.get(id),actor);assert.equal(actor.creatureData??actor.authored,root);assert.equal(actor.stats,stats);
  if(profile==='feat-object'){assert.equal(s.combat.remainingUses(actor,feat),uses-1);assert.deepEqual(actor.nativeTalentClasses,classes);assert.deepEqual(actor.nativeSpellLikeAbilities,abilities);}
  else if(profile.startsWith('innate')){assert.deepEqual(actor.nativeTalentClasses,classes);assert.ok(actor.nativeSpellLikeAbilities.some((row,n)=>row.remaining!==abilities[n].remaining));}
  else{assert.equal(actor.nativeTalentClasses[source.index].memorized[source.level][source.n].ready,0);assert.deepEqual(actor.nativeSpellLikeAbilities,abilities);}
 }
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({rows:report.rows.map(r=>({profile:r.profile,actorId:r.actorId,talent:r.talent,impacts:r.impacts,errors:r.errors})),failure:report.failure}));if(report.failure)process.exitCode=1;
