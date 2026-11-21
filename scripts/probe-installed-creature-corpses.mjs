import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {canonicalItemData} from '../src/native_item_runtime.js';
import {setCreatureGold} from '../src/creature_gold.js';
import {advanceLocalClocks} from './advance-effect-clock.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {setItemPartColor} from '../src/item_part_colors.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-creature-corpses-v1.json',report={checks:[]};
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),character=await fs.readFile(`${install}/data/lcv/cleric.bic`);
 for(const mode of['death','spectacular','no-permanent-death','lootable','damage','massive-damage','temporary-hp']){
  const s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character}),actor=s.player,target=s.byTag('M1Q0D19Goblin').find(o=>!o.plot&&!s.isDead(o));assert.ok(target);
  await s.enterArea(s.registry.get(target.areaId).resRef,[target.position[0]+2,target.position[1],target.position[2]]);s.scheduler.events=[];s.scheduler.beforePump=()=>{};
  if(mode==='death'){
   const copies=[],before=runtimeDiagnostics.records.length;
   for(const record of s.equippedItems(actor)){
    const item=s.registry.get(record.id),owned=item.possessorId,originalParts=structuredClone(item.partColors),old={cursed:item.cursed,droppable:item.droppable,pickpocketable:item.pickpocketable,price:item.nativeBasePrice38c};
    item.locals.setInt('copy_probe',17);item.locals.setObject('copy_owner',actor.id);item.cursed=1;item.droppable=0;item.pickpocketable=0;item.nativeBasePrice38c=123;item.possessorId=0x80000042;setItemPartColor(item,0,0,37);
    const copy=await s.items.copy(item,1);assert.ok(copy);assert.notEqual(copy.id,item.id);assert.equal(copy.possessorId,0x80000042);assert.equal(copy.cursed,0);assert.equal(copy.droppable,1);assert.equal(copy.pickpocketable,1);assert.equal(copy.nativeBasePrice38c,0);assert.equal(copy.nativePriceDirty398,1);assert.equal(copy.locals.getInt('copy_probe'),17);assert.equal(copy.locals.getObject('copy_owner'),actor.id);
    assert.deepEqual(copy.activeProperties,item.activeProperties);assert.deepEqual(copy.passiveProperties,item.passiveProperties);assert.deepEqual(copy.armorParts,item.armorParts);assert.deepEqual(copy.modelParts,item.modelParts);assert.deepEqual(copy.partColors,item.partColors);assert.deepEqual(copy.nativeItemLocalized,item.nativeItemLocalized);
    assert.equal(copy.effects.length,item.effects.length);for(let n=0;n<copy.effects.length;n++){assert.notEqual(copy.effects[n].id,item.effects[n].id);const a=structuredClone(copy.effects[n]),b=structuredClone(item.effects[n]);delete a.id;delete b.id;assert.deepEqual(a,b);}
    copy.partColors[0][0]=38;assert.equal(item.partColors[0][0],37);assert.ok(!actor.nativeEquipment.contains(copy));assert.ok(![...actor.nativeRepository.ids()].includes(copy.id));assert.equal(s.registry.get(item.id),item);
    copies.push({source:item.id,copy:copy.id,effects:item.effects.length,properties:item.activeProperties.length+item.passiveProperties.length});await s.lifecycle.destroy(copy);assert.equal(s.registry.get(copy.id),undefined);item.possessorId=owned;item.cursed=old.cursed;item.droppable=old.droppable;item.pickpocketable=old.pickpocketable;item.nativeBasePrice38c=old.price;item.partColors=originalParts;
   }
   report.copyItems={copies,diagnostics:runtimeDiagnostics.records.slice(before)};assert.equal(copies.length,7);assert.deepEqual(report.copyItems.diagnostics.filter(d=>d.severity==='error'),[]);
  }
  const area=s.registry.get(target.areaId),original=s.equippedItems(target).find(i=>[1,2,16,32].includes(i.slot));assert.ok(original);const weapon=s.registry.get(original.id);weapon.droppable=1;setCreatureGold(target,17);
  target.nativeLootable4e8=Number(mode==='lootable');target.nativeNoPermDeath8bc=Number(mode==='no-permanent-death');const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0],sourceName=structuredClone(target.creatureData.FirstName),weaponData=structuredClone(canonicalItemData(weapon));
  report.current={mode,targetId:target.id,originalWeapon:weapon.id,cursor,loadDiagnostics:runtimeDiagnostics.records.slice(0,begin)};
  if(mode==='damage'||mode==='massive-damage'){
   target.stats.currentHP=2;s.damage.synchronize(target);const damage=s.commands.EffectDamage([mode==='damage'?2:40,4],{self:actor.id});await s.effects.applyNative(damage,target.id);
  }else if(mode==='temporary-hp'){
   const temporary=s.commands.EffectTemporaryHitpoints([4],{self:actor.id});await s.effects.applyNative(temporary,target.id);target.stats.currentHP=0;s.damage.synchronize(target);await s.effects.remove(target.id,temporary.id);
   assert.ok(s.scheduler.events.some(e=>e.event.eventId===5&&e.event.payload.type===19),'Temporary HP must queue a distinct death effect');
  }else await s.effects.applyNative(s.commands.EffectDeath([Number(['spectacular','no-permanent-death'].includes(mode)),1],{self:actor.id}),target.id);
  await s.scheduler.pump();assert.ok(target.deathHandled);assert.ok(s.isDead(target));assert.equal(s.registry.get(target.id),target);assert.equal(s.registry.get(weapon.id),weapon);assert.equal(s.player,actor);
  const expectedDelay=['spectacular','massive-damage'].includes(mode)?3000:target.nativeDecayTime4ec;
  const cleanup=s.scheduler.events.find(e=>e.event.eventId===11&&e.targetId===target.id);report.current.cleanup=cleanup?{delay:cleanup.due-s.scheduler.time,caller:cleanup.event.callerId}:null;
  if(mode==='lootable')assert.equal(cleanup,undefined);else{assert.ok(cleanup);assert.equal(cleanup.due-s.scheduler.time,expectedDelay);}
  const bagNow=()=>[...s.registry.objects.values()].find(o=>o.objectType===9&&o.nativeField514===1);
  if(mode==='lootable'){
   const bag=bagNow();assert.ok(bag);assert.equal(target.nativeBodyBagId4f0,bag.id);assert.equal(bag.nativeBodyBagSource510,target.id);assert.equal(bag.areaId,0x7f000000);
   advanceLocalClocks(s,999);await s.scheduler.pump();assert.equal(bag.areaId,0x7f000000);advanceLocalClocks(s,1);await s.scheduler.pump();assert.equal(bag.areaId,area.id);advanceLocalClocks(s,expectedDelay+1000);await s.scheduler.pump();assert.equal(s.registry.get(target.id),target);
  }else{
   advanceLocalClocks(s,expectedDelay-1);await s.scheduler.pump();assert.equal(s.registry.get(target.id),target);assert.equal(bagNow(),undefined);
   advanceLocalClocks(s,1);await s.scheduler.pump();assert.equal(s.registry.get(target.id),undefined);assert.ok(!area.objects.includes(target.id));assert.equal(s.registry.get(weapon.id),undefined);
   const bag=bagNow();assert.ok(bag);assert.equal(bag.areaId,0x7f000000);advanceLocalClocks(s,999);await s.scheduler.pump();assert.equal(bag.areaId,0x7f000000);advanceLocalClocks(s,1);await s.scheduler.pump();assert.equal(bag.areaId,area.id);
  }
  const bag=bagNow(),items=[...bag.nativeRepository.ids()].map(id=>s.registry.get(id));assert.ok(items.every(i=>i?.objectType===6&&i.possessorId===bag.id));const copied=items.find(i=>i.tag===weapon.tag);assert.ok(copied);assert.notEqual(copied.id,weapon.id);assert.equal(copied.baseItem,weapon.baseItem);assert.deepEqual(copied.modelParts,weapon.modelParts);assert.deepEqual(copied.partColors,weapon.partColors);assert.deepEqual(copied.passiveProperties,weapon.passiveProperties);
  assert.deepEqual(bag.nativeBodyBagLocalized[0x330],sourceName);assert.ok(area.objects.includes(bag.id));assert.equal(items.find(i=>String(i.templateResRef).toLowerCase()==='nw_it_gold001')?.stackSize,17);assert.equal(target.nativeGold898,0);assert.equal(s.registry.get(actor.id),actor);
  report.current.bag={id:bag.id,appearance:bag.nativeMessageFields[0x32c],position:bag.position,items:items.map(i=>({id:i.id,tag:i.tag,baseItem:i.baseItem,stackSize:i.stackSize,owner:i.possessorId})),originalWeaponData:weaponData,copiedWeaponData:canonicalItemData(copied)};report.current.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.current.diagnostics.filter(d=>d.severity==='error'),[]);report.checks.push(report.current);
 }
 report.validation='PASS';report.limits='Installed Prelude/cleric/goblin, active item/gold/bag tables, real OnDeath script and canonical item-copy/transfer, corpse scheduling, event11 removal/destruction and event17 bag insertion. Explicit live weapon droppable/gold/HP/lootable/NoPermDeath phases; native startup/general AI isolated. Tests exact delay-1/delay and999/1000 boundaries, source gear preservation until destruction, copied IDs, transferred gold, bag name/model and player identity. No full rendered corpse/loot pickup/save/campaign acceptance. All diagnostics retained.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks.map(c=>c.mode),current:report.current?.mode,error:report.error}));
