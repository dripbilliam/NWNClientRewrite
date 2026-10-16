import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {acquirePlaceableItem} from '../src/item_acquisition.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-world-ownership-v1.json',report={inventories:[],deleted:[]};
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 for(const area of s.areas.values())await area.nativeGeometry.objects.load();
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,player=s.player,placeables=[...s.registry.objects.values()].filter(o=>o.objectType===9);
 const enumerate=o=>{const ids=[];for(let id=s.commands.GetFirstItemInInventory([o.id]);id!==OBJECT_INVALID;id=s.commands.GetNextItemInInventory([o.id])){ids.push(id);assert.ok(ids.length<1000,'Inventory enumeration must terminate');}return ids;};
 for(const o of placeables){
  const repo=o.nativeRepository;assert.equal(repo.ownerId,o.id);assert.equal(repo.width,7);assert.equal(repo.boundary,35);assert.equal(repo.expand,1);assert.equal(o.nativeField508,0);
  const ids=[...repo.ids()];assert.deepEqual(enumerate(o),ids);
  for(const id of ids){const item=s.registry.get(id);assert.equal(item?.objectType,6);assert.equal(item.possessorId,o.id);assert.equal(item.nativeItemLoaded,true);}
  if(ids.length)report.inventories.push({id:o.id,tag:o.tag,ids,hasInventory:o.nativeHasInventory4f8});
 }
 assert.ok(report.inventories.length,'Installed placeable inventory must exercise loaded canonical items');
 const destinations=placeables.filter(o=>o.nativeHasInventory4f8===1&&o.areaId===s.currentArea.id);assert.ok(destinations.length>=2);
 let template;
 for(const owner of placeables)for(const entry of owner.authored.ItemList??[]){
  if(!entry.InventoryRes)continue;const data=await s.instance('item',entry),info=s.items.baseInfo({baseItem:data.BaseItem});
  if(info?.container===0){template=entry.InventoryRes;break;}
 }
 if(!template)for(const resource of s.resolver.key.resources.values()){
  if(resource.resourceType!==2025)continue;const data=await s.instance('item',{InventoryRes:resource.resref}),info=s.items.baseInfo({baseItem:data.BaseItem});
  if(info?.container===0&&!data.ItemList?.length){template=resource.resref;break;}
 }
 assert.ok(template,'A real installed non-container UTI is required');
 const [source,destination]=destinations,newTag='world_ownership_probe',createdId=await s.commands.CreateItemOnObject([template,source.id,1,newTag]),created=s.registry.get(createdId);
 assert.ok(created?.nativeItemLoaded);assert.equal(created.possessorId,source.id);assert.ok([...source.nativeRepository.ids()].includes(createdId));
 await acquirePlaceableItem(destination,{item:created},source.id,255,255,1,s.itemAcquisitionProviders());
 assert.equal(s.registry.get(createdId),created);assert.equal(created.possessorId,destination.id);assert.ok(![...source.nativeRepository.ids()].includes(createdId));assert.ok(enumerate(destination).includes(createdId));
 report.created={template,id:createdId,sourceId:source.id,destinationId:destination.id};
 await s.commands.DestroyObject([createdId,0],{self:player.id});await s.scheduler.pump();
 assert.equal(s.registry.get(createdId),undefined);assert.ok(!enumerate(destination).includes(createdId));assert.ok(!s.tags.get(newTag)?.includes(createdId));report.deleted.push(createdId);
 // A populated native destructor owns its children, independent of the
 // scheduled event's loot-preservation coordinator (still separately gated).
 const populated=placeables.find(o=>o.nativeRepository.length>0);assert.ok(populated);
 const area=s.registry.get(populated.areaId),children=[...populated.nativeRepository.ids()],tree=[];
 const collect=id=>{tree.push(id);const item=s.registry.get(id);for(const child of item?.nativeRepository?.ids()??[])collect(child);};children.forEach(collect);
 const cursors=[...s.registry.nextObjectId],slot=populated.nativeCollisionSlot;await s.lifecycle.destroy(populated);
 assert.equal(s.registry.get(populated.id),undefined);for(const id of tree)assert.equal(s.registry.get(id),undefined);
 assert.ok(!area.nativeSpatial.view().includes(populated.id));assert.ok(!area.objects.includes(populated.id));assert.ok(!area.nativeTrapIds158.view().includes(populated.id));assert.ok(!area.nativeGeometry.objects.snapshots.has(populated.id));
 for(const level of s.aiMaster.levels)for(const id of [populated.id,...tree])assert.ok(!level.view().includes(id));
 for(const ids of s.tags.values())for(const id of [populated.id,...tree])assert.ok(!ids.includes(id));assert.deepEqual(s.registry.nextObjectId,cursors);
 report.recursiveDestruction={id:populated.id,children,allChildren:tree,oldSlot:slot};
 const empty=placeables.find(o=>s.registry.get(o.id)&&o.nativeRepository.length===0&&o.areaId===s.currentArea.id);assert.ok(empty);empty.nativeDestroyableF0=0;
 await s.commands.DestroyObject([empty.id,0],{self:player.id});await s.scheduler.pump();assert.equal(s.registry.get(empty.id),undefined);report.deleted.push(empty.id);
 const waypoint=[...s.registry.objects.values()].find(o=>o.objectType===12&&o.areaId===s.currentArea.id);assert.ok(waypoint);waypoint.nativeDestroyableF0=0;
 await s.commands.DestroyObject([waypoint.id,0],{self:player.id});await s.scheduler.pump();assert.equal(s.registry.get(waypoint.id),waypoint);
 waypoint.nativeDestroyableF0=1;await s.commands.DestroyObject([waypoint.id,0],{self:player.id});await s.scheduler.pump();assert.equal(s.registry.get(waypoint.id),undefined);report.deleted.push(waypoint.id);
 assert.equal(s.registry.get(player.id),player);report.playerId=player.id;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);
 report.limits='Installed Prelude canonical placeable inventory, active UTI creation, transfer, script enumeration, scheduled item/placeable/waypoint deletion and recursive destructor ownership. Startup/AI disabled. Populated placeable event loot, store import/GUI, world rendering and campaign progression remain separate gates; all diagnostics retained.';report.validation='PASS';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,inventories:report.inventories.length,created:report.created,recursive:report.recursiveDestruction,deleted:report.deleted,failure:report.failure}));if(report.failure)process.exitCode=1;
