import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-body-bags-v1.json',report={bags:[]};
try{
 const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 for(const area of s.areas.values())await area.nativeGeometry.objects.load();
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,player=s.player,sources=[...s.registry.objects.values()].filter(o=>o.objectType===9&&o.nativeRepository.length>0);
 assert.ok(sources.length>0);
 for(const source of sources){
  const area=s.registry.get(source.areaId),position=[...source.position],items=[...source.nativeRepository.ids()].map(id=>s.registry.get(id)),nextId=s.registry.nextObjectId[0],startTime=s.scheduler.time;
  await s.commands.DestroyObject([source.id,0],{self:player.id});await s.scheduler.pump();assert.equal(s.registry.get(source.id),undefined);
  const bag=s.registry.get(nextId);assert.equal(bag?.objectType,9);assert.equal(bag.tag,'BodyBag');assert.equal(bag.areaId,OBJECT_INVALID);assert.equal(bag.nativeBodyBagSource510,OBJECT_INVALID);
  assert.equal(bag.nativeField514,1);assert.equal(bag.nativeField504,1);assert.equal(bag.nativeHasInventory4f8,1);assert.equal(bag.plot,true);assert.equal(s.hitPoints(bag.id,false),12);assert.equal(s.hitPoints(bag.id,true),12);assert.equal(bag.nativeBodyBagLocalized[0x308].strRef,0x9cac);
  for(const item of items){assert.equal(s.registry.get(item.id),item);assert.equal(item.possessorId,bag.id);assert.ok([...bag.nativeRepository.ids()].includes(item.id));}
  assert.ok(!area.nativeSpatial.view().includes(source.id));assert.ok(!area.nativeGeometry.objects.snapshots.has(source.id));assert.ok(!area.nativeSpatial.view().includes(bag.id));
  const event=s.scheduler.events.find(e=>e.event.eventId===17&&e.event.payload?.id===bag.id);assert.ok(event);assert.equal(event.targetId,area.id);assert.equal(event.event.callerId,source.id);assert.equal(event.due,startTime+1000);
  s.scheduler.advance(999);await s.scheduler.pump();assert.equal(bag.areaId,OBJECT_INVALID);
  s.scheduler.advance(1);await s.scheduler.pump();assert.equal(bag.areaId,area.id);assert.deepEqual(bag.position,position);assert.ok(area.objects.includes(bag.id));assert.ok(area.nativeSpatial.view().includes(bag.id));assert.ok(area.nativeGeometry.objects.snapshots.has(bag.id));
  const inventory=[];for(let id=s.commands.GetFirstItemInInventory([bag.id]);id!==OBJECT_INVALID;id=s.commands.GetNextItemInInventory([bag.id])){inventory.push(id);assert.ok(inventory.length<=items.length);}
  assert.deepEqual(new Set(inventory),new Set(items.map(i=>i.id)));assert.ok(s.tags.get('BodyBag').includes(bag.id));
  report.bags.push({sourceId:source.id,bagId:bag.id,areaId:area.id,appearance:bag.nativeMessageFields[0x32c],items:inventory,position,slot:bag.nativeCollisionSlot,eventDue:event.due});
 }
 assert.equal(s.registry.get(player.id),player);report.playerId=player.id;report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);report.validation='PASS';
 report.limits='Installed populated placeable DestroyObject, actual active-table appearance, synthetic body-bag load, canonical item transfer, source cleanup, exact1000ms area event, PWK/spatial insertion and script enumeration. AI/startup disabled. Creature equipment copying, loot GUI/player pickup, rendered bag models and campaign progression remain separate gates; all diagnostics retained.';
}catch(error){report.failure={message:error.message,stack:error.stack};report.diagnostics=[...runtimeDiagnostics.records];}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,bags:report.bags,failure:report.failure}));if(report.failure)process.exitCode=1;
