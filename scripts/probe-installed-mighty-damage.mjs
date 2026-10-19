// Active installed character/items/rules; generic NCS constructors and item
// mutation, real equipment owners and actual damage-roll pipeline. No asset edits.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {canonicalItemData} from '../src/native_item_runtime.js';
import {damageBonus} from '../src/damage_bonus.js';
import {createAttackData} from '../src/combat_attack_data.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-mighty-damage-v1.json',report={checks:[]};
try{
 const s=await new ModuleSession(await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:()=>{}}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 const actor=s.player,target=[...s.registry.objects.values()].find(o=>o.objectType===5&&o!==actor&&!s.isDead(o)&&/goblin/i.test(o.tag));assert.ok(target);await s.enterArea(s.registry.get(target.areaId).resRef,[target.position[0]+1,target.position[1],target.position[2]]);
 report.loadDiagnostics=[...runtimeDiagnostics.records];const begin=runtimeDiagnostics.records.length,cursor=s.registry.nextObjectId[0];s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();
 const invoke=async(name,args)=>{const ordinal=s.vm.api.findIndex(r=>r.name===name);assert.ok(ordinal>=0);const frame={stack:[]};for(let i=args.length-1;i>=0;i--)s.vm.push(frame,s.vm.api[ordinal].args[i].type,args[i]);return(await s.vm.run({name:'installed_mighty_fixture',instructions:new Map([[13,{pc:13,op:5,command:ordinal,argc:args.length,next:14}],[14,{pc:14,op:0x20,next:15}]])},actor.id,{situation:{pc:13,bp:0,stack:frame.stack}})).stack[0]?.value;};
 const originalWeapon=s.equipmentSlot(actor,16),bow=actor.inventory.map(id=>s.registry.get(id)).find(i=>i.baseItem===7);assert.ok(bow);const originalInventory=[...actor.inventory],originalStats={str:actor.stats.equippedAbilities.Str,cache:actor.nativeStrModifierD39},originalProperties=structuredClone(bow.passiveProperties);
 const buff=await invoke('EffectAbilityIncrease',[0,12]);await invoke('ApplyEffectToObject',[2,buff,actor.id,0]);s.refreshCombat(actor);const modifier=(actor.nativeStrModifierD39<<24)>>24;assert.ok(modifier>3);
 if(originalWeapon)assert.equal(await s.unequipItem(actor,originalWeapon,1,0),1);assert.equal(await s.equipItem(actor,16,bow,1,0,0),1);assert.equal(s.equipmentSlot(actor,16),bow);
 const attack=()=>Object.assign(createAttackData(),{weaponAttackType:1,ranged:1,attackType:0});
 const bonus=()=>damageBonus(actor,null,s.characterRules,s.equippedItems(actor),s.random,{attack:attack()});
 const roll=async()=>{s.random.seed(1);return s.damage.roll(actor,target,attack(),{maximize:true,offhand:false,critical:false,sneak:false,death:false});};
 const before={nominal:s.combat.nominalRangedDamage(actor),bonus:bonus(),roll:await roll()};
 const property=await invoke('ItemPropertyMaxRangeStrengthMod',[3]);assert.equal(property.type,91);assert.equal(property.integers[0],45);await invoke('AddItemProperty',[2,property,bow.id]);
 const raw=canonicalItemData(bow).PropertiesList.find(p=>p.PropertyName===45);assert.ok(raw);assert.equal(raw.CostValue,3);assert.equal(raw.Subtype,65535);const after={nominal:s.combat.nominalRangedDamage(actor),bonus:bonus(),roll:await roll()};
 assert.equal(after.bonus.parts.strength,3);assert.equal(after.nominal-before.nominal,3);assert.equal(after.bonus.total-before.bonus.total,3);assert.equal(after.roll-before.roll,3);
 await invoke('RemoveItemProperty',[bow.id,property]);s.scheduler.advance(501);await s.scheduler.pump();assert.deepEqual(bow.passiveProperties,originalProperties);const removed={nominal:s.combat.nominalRangedDamage(actor),bonus:bonus(),roll:await roll()};assert.deepEqual(removed,before);report.checks.push({check:'NCS-Mighty-property-uses-CostValue-in-nominal-and-real-roll',playerId:actor.id,itemId:bow.id,modifier,raw,before,after,removed});
 assert.equal(await s.unequipItem(actor,bow,1,0),1);if(originalWeapon)assert.equal(await s.equipItem(actor,16,originalWeapon,1,0,0),1);await s.effects.remove(actor.id,buff.id);s.refreshCombat(actor);assert.deepEqual({str:actor.stats.equippedAbilities.Str,cache:actor.nativeStrModifierD39},originalStats);assert.deepEqual(actor.inventory,originalInventory);assert.equal(s.registry.nextObjectId[0],cursor);assert.equal(s.registry.get(actor.id),actor);assert.equal(s.registry.get(bow.id),bow);
 report.diagnostics=runtimeDiagnostics.records.slice(begin);assert.deepEqual(report.diagnostics.filter(r=>r.code==='combat.inventory-slot-warning'),[]);const errors=report.diagnostics.filter(r=>r.severity==='error');report.knownLoadFailures=errors.filter(r=>r.context?.operation==='native-placeable-pwk-missing-empty-mesh'&&r.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.');report.newFailures=errors.filter(r=>!report.knownLoadFailures.includes(r));assert.deepEqual(report.newFailures,[]);report.validation='PASS';report.limits='Prelude/wizard, installed crossbow, generic NCS ability/property constructors, real equip/remove, live nominal queries and actual maximized damage pipeline with unchanged canonical IDs and restored character/items. Startup/periodic AI isolated; direct roll does not prove attack scheduling, HP impact, visuals, synchronous native combat-information owner or full campaign acceptance.';
}catch(error){report.validation='FAIL';report.error=error.stack;report.diagnostics=[...runtimeDiagnostics.records];process.exitCode=1;}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,checks:report.checks.map(c=>({check:c.check,before:c.before.roll,after:c.after.roll,removed:c.removed.roll})),error:report.error}));
