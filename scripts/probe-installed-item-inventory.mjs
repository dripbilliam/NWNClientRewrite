import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-item-inventory-v1.json',report={messages:[]};
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>report.messages.push(m)}).initialize(['m0q1a'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,actor=s.player,stats=actor.stats,client=s.combat.broadcastProviders().client(actor.id),gui=client.inventoryGUI;
 // Active installed template selection, not a production stock ResRef rule.
 let template;for(const resource of s.resolver.key.resources.values()){
  if(resource.resourceType!==2025)continue;const data=await s.instance('item',{InventoryRes:resource.resref});if(s.items.baseInfo({baseItem:data.BaseItem})?.container!==0&&!data.ItemList?.length){template=resource.resref;break;}
 }
 assert.ok(template);const id=await s.commands.CreateItemOnObject([template,actor.id,1,'item_inventory_fixture']),bag=s.registry.get(id);assert.ok(bag?.nativeItemLoaded);assert.ok(bag.nativeRepository);assert.equal(bag.nativeInventoryObservers364,0);assert.equal(bag.possessorId,actor.id);
 const use=async()=>{const input=s.queuePlayerUseObject(id,{popup:1});await s.drainPlayerInputs();assert.equal(await input,1);const now=s.worldTimer.time();await s.combat.runActions(actor,now.day,now.time);assert.equal(actor.objectActionState.list.head.action.actionId,40);await s.scheduler.pump();await s.combat.clearActions(actor);};
 await use();assert.equal(bag.nativeInventoryObservers364,1);assert.equal(gui.openInventory.id,id);await s.lifecycle.openItemInventory(bag,actor.id);assert.equal(bag.nativeInventoryObservers364,1);
 await use();assert.equal(bag.nativeInventoryObservers364,0);assert.equal(gui.openInventory.id,OBJECT_INVALID);
 await use();assert.equal(bag.nativeInventoryObservers364,1);assert.equal(gui.openInventory.id,id);
 await s.commands.DestroyObject([id,0],{self:actor.id});await s.scheduler.pump();assert.equal(s.registry.get(id),undefined);assert.equal(gui.openInventory.id,OBJECT_INVALID);assert.equal(bag.nativeInventoryObservers364,0);assert.ok(![...actor.nativeRepository.ids()].includes(id));
 assert.equal(s.registry.get(actor.id),actor);assert.equal(actor.stats,stats);report.playerId=actor.id;report.bagId=id;report.template=template;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.validation='PASS';
 report.limits='Real active installed container UTI creation and native decoded UseObject/action40 open-close-reopen, repeated-open observer count, item event10 ignored, scheduled DestroyObject while open and canonical repository cleanup. AI/startup disabled, all diagnostics retained. No rendered bag GUI/pickup, packet codec or alternate-character login claim.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,playerId:report.playerId,bagId:report.bagId,template:report.template,failure:report.failure}));if(report.failure)process.exitCode=1;
