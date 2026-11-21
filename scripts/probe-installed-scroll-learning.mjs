// Installed UTI selected using active spell/class/school/known data, created
// through native item acquisition, then real menu -> input13 -> LearnScroll
// -> reply14, stack decrement, duplicate rejection and immediate destruction.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {selectInstalledLearnableScrolls} from './select-installed-scrolls.mjs';
import {selectLearnScroll} from '../src/scroll_learning.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-scroll-learning-v1.json',report={rows:[]};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),feedback=[];
 const s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:event=>{if(event.type===11)feedback.push(structuredClone(event));}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.loadDiagnostics=[...runtimeDiagnostics.records];
 const actor=s.player,choices=await selectInstalledLearnableScrolls(s);
 assert.equal(choices.length,2);report.choices=choices;
 const use=async(choice,stack,duplicate=false)=>{
  const itemId=duplicate?report.rows[0].itemId:await s.createItem(choice.template,actor.id,stack,''),item=s.registry.get(itemId);assert.ok(item);assert.equal(item.baseItem,75);
  s.scheduler.events=[];const initial={stackSize:item.stackSize,known:structuredClone(actor.nativeTalentClasses.map(c=>c.known))},start=runtimeDiagnostics.records.length,feedbackStart=feedback.length;
  let input;const selection=selectLearnScroll(itemId,{item:id=>s.registry.get(id),transport:()=>s,send:(_transport,id)=>{input=s.queuePlayerLearnScroll({actorId:actor.id,areaId:actor.areaId,itemId:id});return input;}});
  assert.equal(item.nativeItemPending240,1);assert.equal(item.stackSize,initial.stackSize);await s.drainPlayerInputs();const ack=await input;await selection;
  const diagnostics=runtimeDiagnostics.records.slice(start),errors=diagnostics.filter(d=>d.severity==='error'),after={stackSize:item.stackSize,pending:item.nativeItemPending240,present:s.registry.get(itemId)===item,inventory:actor.inventory.includes(itemId),repository:[...actor.nativeRepository.ids()].includes(itemId),known:structuredClone(actor.nativeTalentClasses.map(c=>c.known))};
  report.rows.push({choice,itemId,duplicate,initial,ack,learn:s.items.lastLearnScroll,after,feedback:feedback.slice(feedbackStart),diagnostics});
  assert.equal(ack,1);assert.equal(s.items.lastLearnScroll.result,duplicate?0:1);assert.deepEqual(errors,[]);assert.equal(s.nativeLocalClient.nativePlayerId48,undefined,'Local learning does not invent a transport PLAYER_ID');
  if(duplicate){assert.deepEqual(after.known,initial.known);assert.equal(after.stackSize,initial.stackSize);assert.equal(after.pending,0);assert.ok(feedback.slice(feedbackStart).some(e=>e.data.integers[9]===221));}
  else{assert.equal(after.known[choice.classIndex][choice.level].filter(id=>id===choice.spellId).length,1);assert.ok(feedback.slice(feedbackStart).some(e=>e.data.integers[9]===222&&e.data.integers[0]===choice.spellId));
   if(initial.stackSize>1){assert.equal(after.stackSize,initial.stackSize-1);assert.equal(after.pending,0);}else{assert.equal(after.present,false);assert.equal(after.inventory,false);assert.equal(after.repository,false);}}
 };
 await use(choices[0],2);await use(choices[0],1,true);await use(choices[1],1);
 report.limits='Unchanged installed wizard; installed scroll templates chosen from current class/spell/school/known metadata and created through shared native acquisition in this owned fixture. Actual menu, canonical queues, LearnScroll, duplicate feedback, reply/pending, immediate removal/destruction and canonical known pools. Startup/general AI/module acquire/lost events isolated; no renderer, save/reload or campaign acceptance.';
}catch(error){report.failure={message:error.message,stack:error.stack};}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({choices:report.choices,rows:report.rows.map(({itemId,duplicate,ack,learn,after})=>({itemId,duplicate,ack,learn,after:{stackSize:after.stackSize,present:after.present,pending:after.pending}})),failure:report.failure}));if(report.failure)process.exitCode=1;
