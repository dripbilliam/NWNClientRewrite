// Request-stage integration only. Unchanged installed inventory, typed VM
// talent dispatch, native UseItem and AddItemCastSpellActions. Execution and
// consumption are covered by probe-installed-item-casting.mjs.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {scriptTalent} from '../src/talent.js';
import {actionParameter} from '../src/object_actions.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-item-cast-request-v1.json',report={limits:'Native request stage only; action46 execution, item consumption and item UI remain unfinished.',rows:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics=[...runtimeDiagnostics.records];const actor=s.player,classes=structuredClone(actor.nativeTalentClasses),abilities=structuredClone(actor.nativeSpellLikeAbilities);
 const choices=[];
 for(const id of actor.inventory){const item=s.registry.get(id);for(const [index,property]of item.activeProperties.entries()){
  if(property.type!==15||property.remaining===0)continue;
  const spellId=s.items.castProviders().spellIndex(property.subtype),spell=s.spellBook.castingSpell(spellId);if(!spell)continue;
  choices.push({itemId:id,index,base:item.baseItem,spellId,targetType:spell.targetType});
 }}
 report.choices=choices;assert.ok(choices.length,'Installed wizard has item spell properties');
 for(const choice of choices.filter((c,n,a)=>a.findIndex(x=>x.base===c.base)===n)){
  const item=s.registry.get(choice.itemId),before={charges:item.charges,stack:item.stackSize,properties:structuredClone(item.activeProperties)},start=runtimeDiagnostics.records.length;
  await s.combat.clearActions(actor);actor.combatRound.started=0;
  const location=(choice.targetType&1)===0&&(choice.targetType&4)!==0,ordinal=location?310:309,point=[actor.position[0],-actor.position[2],actor.position[1]],talent={...scriptTalent(0,choice.spellId),itemId:item.id,itemPropertyIndex:choice.index},args=[talent,location?{areaId:actor.areaId,position:point}:actor.id],frame={stack:[]};
  for(let n=1;n>=0;n--)s.vm.push(frame,s.vm.api[ordinal].args[n].type,args[n]);
  const program={name:'owned_item_talent_request_fixture',instructions:new Map([[13,{pc:13,op:5,command:ordinal,argc:2,next:14}],[14,{pc:14,op:0x20,next:15}]])};
  const result=await s.vm.run(program,actor.id,{situation:{pc:13,bp:0,stack:frame.stack}});assert.deepEqual(result.stack,[]);
  const actions=[...actor.objectActionState.list],node=actions.find(n=>n.actionId===46),row={choice,actorId:actor.id,actions:actions.map(n=>({id:n.actionId,group:n.groupId})),diagnostics:runtimeDiagnostics.records.slice(start)};report.rows.push(row);
  assert.ok(node,'Actual installed item queues native action46');assert.equal(actionParameter(node,0)>>>0,item.id);assert.equal(actionParameter(node,1),choice.index);assert.equal(actionParameter(node,9),1);
  assert.deepEqual({charges:item.charges,stack:item.stackSize,properties:item.activeProperties},before);assert.deepEqual(actor.nativeTalentClasses,classes);assert.deepEqual(actor.nativeSpellLikeAbilities,abilities);assert.equal(s.registry.get(item.id),item);
  row.diagnostics=runtimeDiagnostics.records.slice(start);
 }
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({choices:report.choices,rows:report.rows.map(r=>({choice:r.choice,actions:r.actions,executionBlock:r.executionBlock})),failure:report.failure}));if(report.failure)process.exitCode=1;
