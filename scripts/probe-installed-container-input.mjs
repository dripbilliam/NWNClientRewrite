import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {intEntry} from '../src/combat_stats.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-container-input-v1.json',report={messages:[]};
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>report.messages.push(m)}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();for(const area of s.areas.values())await area.nativeGeometry.objects.load();
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,actor=s.player,stats=actor.stats,client=s.combat.broadcastProviders().client(actor.id),gui=client.inventoryGUI;
 const target=[...s.registry.objects.values()].find(o=>o.objectType===9&&o.areaId===actor.areaId&&o.nativeHasInventory4f8===1&&o.nativeRepository.length===0&&!o.trapped&&!o.locked);assert.ok(target);
 const input=async promise=>{await s.drainPlayerInputs();assert.equal(await promise,1);const deadline=performance.now()+10000;while(actor.objectActionState.list.count){assert.ok(performance.now()<deadline);const now=s.worldTimer.time();await s.combat.runActions(actor,now.day,now.time);await s.scheduler.pump();if(actor.objectActionState.list.count)await new Promise(r=>setTimeout(r,20));}await s.scheduler.pump();};
 const point={point:[0,0,0],range:0};await s.combat.useRange(actor,target.id,point);s.setPosition(actor,point.point,0);
 await input(s.queuePlayerUseObject(target.id,{popup:1}));assert.equal(gui.openInventory.id,target.id);assert.equal(target.nativeField508,1);
 await input(s.queuePlayerContainerInput(1));assert.equal(gui.openInventory.id,OBJECT_INVALID);assert.equal(target.nativeField508,0);assert.equal(gui.field8,1);assert.equal(s.commands.GetLastClosedBy([],{self:target.id}),actor.id);
 let template;for(const resource of s.resolver.key.resources.values()){
  if(resource.resourceType!==2025)continue;const data=await s.instance('item',{InventoryRes:resource.resref}),info=s.items.baseInfo({baseItem:data.BaseItem}),weight=intEntry(s.characterRules.baseitems,data.BaseItem,'TenthLBS');
  if(info&&data.BaseItem!==76&&info.container===0&&info.width===1&&info.height===1&&weight.found&&weight.value>=0&&weight.value<=1&&!data.PropertiesList?.length){template=resource.resref;break;}
 }
 assert.ok(template);const height=target.nativeRepository.height,fillers=[];
 while(target.nativeRepository.height===height){assert.ok(fillers.length<70);const id=await s.commands.CreateItemOnObject([template,target.id,1,`container_page_fixture_${fillers.length}`]);assert.notEqual(id,OBJECT_INVALID);fillers.push(id);}
 await s.scheduler.pump();assert.ok(target.nativeRepository.height>height);await input(s.queuePlayerUseObject(target.id,{popup:1}));assert.equal(gui.openInventory.field8,0);
 gui.lastUpdate.listA0.push({fixture:'cached container'});gui.lastUpdate.dirtyA8=0;await input(s.queuePlayerContainerInput(2));assert.equal(gui.openInventory.field8,1);assert.equal(gui.lastUpdate.listA0.length,0);assert.equal(gui.lastUpdate.dirtyA8,1);
 await input(s.queuePlayerContainerInput(2));assert.equal(gui.openInventory.field8,0);await input(s.queuePlayerContainerInput(3));assert.equal(gui.openInventory.field8,1);
 await input(s.queuePlayerContainerInput(1));assert.equal(gui.openInventory.id,OBJECT_INVALID);assert.equal(gui.openInventory.field8,0);assert.equal(target.nativeField508,0);assert.equal(s.commands.GetLastClosedBy([],{self:target.id}),actor.id);assert.equal(gui.field8,1);
 await input(s.queuePlayerInventoryStatus(0,actor.id));assert.equal(gui.field8,0);assert.equal(s.registry.get(actor.id),actor);assert.equal(actor.stats,stats);report.playerId=actor.id;report.targetId=target.id;report.template=template;report.fillers=fillers;report.height=target.nativeRepository.height;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.validation='PASS';
 report.limits='Installed normal UseObject and decoded container/input queue, canonical last-close caller/observer count, retained main inventory, real active UTI population causing native repository expansion, primary LUO cache reset, next/previous page wrapping and separate main-inventory close. AI/startup disabled, original assets unchanged, authored callbacks active, all diagnostics retained. No packet codec, original client sender or primary-owner login-init claim.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,playerId:report.playerId,targetId:report.targetId,height:report.height,fillers:report.fillers?.length,failure:report.failure}));if(report.failure)process.exitCode=1;
