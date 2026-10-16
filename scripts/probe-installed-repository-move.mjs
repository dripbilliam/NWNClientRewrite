import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {intEntry} from '../src/combat_stats.js';
import {parseNcs} from '../src/ncs.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-repository-move-v1.json',report={messages:[]};
function marker(api){const code=[],word=v=>code.push(v>>>8&255,v&255),dword=v=>code.push(v>>>24&255,v>>>16&255,v>>>8&255,v&255),self=()=>{code.push(4,6);dword(0);},call=(name,count)=>{const index=api.findIndex(a=>a.name===name);assert.ok(index>=0,name);code.push(5,0);word(index);code.push(count);};
 for(const [query,name,setter]of [['GetInventoryDisturbType','repo_type','SetLocalInt'],['GetLastDisturbed','repo_actor','SetLocalObject'],['GetInventoryDisturbItem','repo_item','SetLocalObject']]){self();call(query,1);const bytes=Buffer.from(name);code.push(4,5);word(bytes.length);code.push(...bytes);self();call(setter,3);}
 code.push(0x20,0);const bytes=Buffer.alloc(13+code.length);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(bytes.length,9);bytes.set(code,13);return parseNcs(bytes,'repo_disturb_marker');}
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>report.messages.push(m)}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1d',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();for(const area of s.areas.values())await area.nativeGeometry.objects.load();
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,actor=s.player,stats=actor.stats,client=s.combat.broadcastProviders().client(actor.id),gui=client.inventoryGUI;
 const sources=[...s.registry.objects.values()].filter(o=>o.objectType===9&&o.areaId===actor.areaId&&o.nativeHasInventory4f8===1);
 let source,item;for(const candidate of sources){for(const id of candidate.nativeRepository.ids()){const current=s.registry.get(id);if(current?.nativeItemLoaded&&!current.cursed&&s.items.baseInfo(current)?.container===0&&current.stackSize===1){source=candidate;item=current;break;}}if(item)break;}
 assert.ok(item);report.sourceId=source.id;report.itemId=item.id;report.template=item.templateResRef;report.originalPoint=[item.repositoryX,item.repositoryY];
 report.authoredDisturbScript=source.scripts.disturbed;assert.equal(source.scripts.disturbed,'','Use a fixture source with an empty authored callback');s.programs.set('repo_disturb_marker',Promise.resolve(marker(s.vm.api)));source.scripts.disturbed='repo_disturb_marker';
 const run=async pending=>{await s.drainPlayerInputs();assert.equal(await pending,1);const deadline=performance.now()+10000;
  while(actor.objectActionState.list.count){assert.ok(performance.now()<deadline,'Native action queue must drain');const time=s.worldTimer.time();await s.combat.runActions(actor,time.day,time.time);await s.scheduler.pump();if(actor.objectActionState.list.count)await new Promise(resolve=>setTimeout(resolve,20));}
 };
 const usePoint={point:[0,0,0],range:0};await s.combat.useRange(actor,source.id,usePoint);s.setPosition(actor,usePoint.point,0);
 await run(s.queuePlayerUseObject(source.id,{popup:1}));assert.equal(gui.openInventory.id,source.id);await s.scheduler.pump();
 await run(s.queuePlayerRepositoryMove(item.id,OBJECT_INVALID,255,255));assert.equal(actor.objectActionState.list.count,0);assert.equal(item.possessorId,actor.id);assert.ok([...actor.nativeRepository.ids()].includes(item.id));assert.ok(![...source.nativeRepository.ids()].includes(item.id));assert.ok(actor.inventory.includes(item.id));assert.ok(!source.inventory.includes(item.id));await s.scheduler.pump();
 report.acquiredPoint=[item.repositoryX,item.repositoryY];report.acquiredQuantity=s.module.nativeAcquiredQuantity360;report.acquiredId=s.module.nativeAcquiredItem34c;assert.equal(report.acquiredId,item.id);assert.equal(s.module.nativeAcquiredBy354,actor.id);
 assert.equal(s.commands.GetModuleItemAcquired([]),item.id);assert.equal(s.commands.GetModuleItemAcquiredBy([]),actor.id);assert.equal(s.commands.GetModuleItemAcquiredFrom([]),source.id);
 assert.equal(s.commands.GetLastDisturbed([],{self:source.id}),actor.id);assert.equal(s.commands.GetInventoryDisturbItem([],{self:source.id}),item.id);assert.equal(s.commands.GetInventoryDisturbType([],{self:source.id}),1);report.disturbScript=source.scripts.disturbed;
 assert.equal(source.locals.getInt('repo_type'),1);assert.equal(source.locals.getObject('repo_actor'),actor.id);assert.equal(source.locals.getObject('repo_item'),item.id);
 // Native AddItem falls back to FindPosition for invalid coordinates.
 await run(s.queuePlayerRepositoryMove(item.id,source.id,254,254));assert.equal(item.possessorId,source.id);assert.ok(item.repositoryX<source.nativeRepository.width);assert.ok(item.repositoryY<source.nativeRepository.height);
 await run(s.queuePlayerRepositoryMove(item.id,OBJECT_INVALID,255,255));assert.equal(item.possessorId,actor.id);
 let bagTemplate,fillerTemplate;for(const resource of s.resolver.key.resources.values()){
  if(resource.resourceType!==2025)continue;const data=await s.instance('item',{InventoryRes:resource.resref}),info=s.items.baseInfo({baseItem:data.BaseItem});if(!info)continue;
  if(!bagTemplate&&info.container!==0&&!data.ItemList?.length)bagTemplate=resource.resref;
  const weight=intEntry(s.characterRules.baseitems,data.BaseItem,'TenthLBS');
  if(!fillerTemplate&&data.BaseItem!==76&&info.container===0&&info.width===1&&info.height===1&&weight.found&&weight.value>=0&&weight.value<=1&&!data.PropertiesList?.length)fillerTemplate=resource.resref;
  if(bagTemplate&&fillerTemplate)break;
 }
 assert.ok(bagTemplate&&fillerTemplate);const bagId=await s.commands.CreateItemOnObject([bagTemplate,actor.id,1,'repository_full_bag']),bag=s.registry.get(bagId);assert.ok(bag?.nativeRepository);assert.equal(bag.nativeRepository.expand,0);report.bagId=bagId;report.fillerTemplate=fillerTemplate;report.fillers=[];
 for(let y=0;y<bag.nativeRepository.height;y++)for(let x=0;x<bag.nativeRepository.width;x++){
  const fillerId=await s.commands.CreateItemOnObject([fillerTemplate,actor.id,1,`repository_fill_${x}_${y}`]);assert.notEqual(fillerId,OBJECT_INVALID);await run(s.queuePlayerRepositoryMove(fillerId,bagId,x,y));assert.equal(s.registry.get(fillerId).possessorId,bagId);report.fillers.push(fillerId);
 }
 assert.equal(bag.nativeRepository.length,bag.nativeRepository.width*bag.nativeRepository.height);
 const before=[item.repositoryX,item.repositoryY],startMessages=report.messages.length;
 await run(s.queuePlayerRepositoryMove(item.id,bagId,255,255));assert.equal(item.possessorId,actor.id);assert.ok([...actor.nativeRepository.ids()].includes(item.id));assert.ok(actor.inventory.includes(item.id));assert.deepEqual([item.repositoryX,item.repositoryY],before);assert.ok(![...bag.nativeRepository.ids()].includes(item.id));assert.ok(report.messages.slice(startMessages).some(m=>m.type==='inventory-repository-move-cancel'&&m.itemId===item.id));
 await run(s.queuePlayerRepositoryMove(item.id,source.id,...report.originalPoint));assert.equal(item.possessorId,source.id);assert.ok([...source.nativeRepository.ids()].includes(item.id));assert.ok(![...actor.nativeRepository.ids()].includes(item.id));assert.ok(source.inventory.includes(item.id));assert.ok(!actor.inventory.includes(item.id));await s.scheduler.pump();
 assert.equal(s.commands.GetLastDisturbed([],{self:source.id}),actor.id);assert.equal(s.commands.GetInventoryDisturbItem([],{self:source.id}),item.id);assert.equal(s.commands.GetInventoryDisturbType([],{self:source.id}),0);
 assert.equal(source.locals.getInt('repo_type'),0);assert.equal(source.locals.getObject('repo_actor'),actor.id);assert.equal(source.locals.getObject('repo_item'),item.id);
 assert.equal(s.registry.get(item.id),item);assert.equal(s.registry.get(actor.id),actor);assert.equal(actor.stats,stats);report.playerId=actor.id;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.validation='PASS';
 report.limits='Installed populated placeable opened through native UseObject, actual decoded inventory subtype9/action13 transfers, canonical IDs and projections, acquisition/module/disturbance delivery, invalid-coordinate fallback, genuinely full unexpandable bag rollback and return to original repository coordinates. Full bag fixture populated through ordinary CreateItemOnObject and queued transfers using dynamically selected active lightweight1x1 UTI with distinct native tags. Startup/AI disabled; authored module event scripts left active, empty placeable OnInvDisturbed replaced with an in-memory NCS marker using all three real disturbance queries/SetLocal owners. No rendered loot UI, original packet codec, corpse stripping or campaign progression claim.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,playerId:report.playerId,sourceId:report.sourceId,itemId:report.itemId,acquiredPoint:report.acquiredPoint,failure:report.failure}));if(report.failure)process.exitCode=1;
