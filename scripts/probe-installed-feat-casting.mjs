// Actual installed owned feats through decoded player input and shared casting.
// No feats/spells are granted, module data changed or native IDs replaced.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {featActivationInfo} from '../src/use_feat.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-feat-casting-v1.json',report={rows:[]};
const scriptMode=process.argv.includes('--script');
try{
 for(const [character,wanted,subfeat]of scriptMode?[['druid',305],['druid',305,1008],['barbarian',293,307]]:[['druid',305],['barbarian',293]]){
  const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/${character}.bic`)});
  const o=s.player,id=o.id,root=o.creatureData,stats=o.stats,classes=structuredClone(o.nativeTalentClasses),abilities=structuredClone(o.nativeSpellLikeAbilities),equipment=o.nativeEquipment;
  await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics??=[...runtimeDiagnostics.records];
  const highest=s.combat.highestFeat(o,wanted),before=s.combat.remainingUses(o,highest),info=featActivationInfo(s.characterRules,highest),start=runtimeDiagnostics.records.length,impacts=[],animations=[],errors=[],run=s.runScript.bind(s);assert.notEqual(highest,65535);assert.ok(before>0);
  s.runScript=async(name,actorId,options)=>{if(actorId===id&&o.nativeSpellFeat23c===highest)impacts.push({name,actorId,at:s.scheduler.time,feat:o.nativeSpellFeat23c,spell:o.nativeSpellId218});return run(name,actorId,options);};
  let script=null;
  if(scriptMode){
   const api=s.vm.api[287],args=[wanted,id],frame={stack:[]};assert.equal(api.name,'ActionUseFeat');if(subfeat!==undefined)args.push(subfeat,null);
   for(let i=args.length-1;i>=0;i--)s.vm.push(frame,api.args[i].type,args[i]);
   const program={name:'owned_action_use_feat_fixture',instructions:new Map([[13,{pc:13,op:5,command:287,argc:args.length,next:14}],[14,{pc:14,op:0x20,next:15}]])};
   const result=await s.vm.run(program,id,{situation:{pc:13,bp:0,stack:frame.stack}});assert.deepEqual(result.stack,[]);
   script={argc:args.length,subfeat,args:api.args.map(a=>a.type),returns:api.returns};
  }else{const input=s.queuePlayerFeat({actorId:id,areaId:o.areaId,featId:wanted,targetId:id});await s.drainPlayerInputs();assert.equal(await input,1);}
  assert.ok(o.objectActionState.list.count>0||s.scheduler.events.length>0);
  for(let n=0;n<180;n++){
   s.scheduler.advance(100);s.worldTimer.snapshot();try{await s.combat.runActions(o,...Object.values(s.worldTimer.time()));}catch(error){errors.push(error.message);break;}animations.push(o.animationState);
   while(s.scheduler.events[0]?.due<=s.scheduler.time){const event=s.scheduler.events.shift();try{await s.dispatch(event);}catch(error){errors.push(error.message);}}
   if(o.objectActionState.list.count===0&&impacts.length)break;
  }
  const after=s.combat.remainingUses(o,highest),diagnostics=runtimeDiagnostics.records.slice(start);report.rows.push({character,wanted,highest,script,info,before,after,impacts,animations:[...new Set(animations)],errors,effects:structuredClone(o.effects),diagnostics,queue:[...o.objectActionState.list].map(n=>n.actionId)});
  assert.deepEqual(errors,[]);assert.equal(after,before-1);assert.ok(impacts.length>0);assert.equal(o.objectActionState.list.count,0);assert.equal(s.registry.get(id),o);assert.equal(o.creatureData,root);assert.equal(o.stats,stats);assert.equal(o.nativeEquipment,equipment);assert.deepEqual(o.nativeTalentClasses,classes);assert.deepEqual(o.nativeSpellLikeAbilities,abilities);
  assert.ok(animations.some(n=>[15,16].includes(n)));assert.ok(animations.some(n=>[17,18,19,20,61,89,96].includes(n)));assert.deepEqual(diagnostics.filter(d=>d.severity==='error'),[]);
 }
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({rows:report.rows.map(r=>({character:r.character,highest:r.highest,before:r.before,after:r.after,impacts:r.impacts,errors:r.errors})),failure:report.failure}));if(report.failure)process.exitCode=1;
