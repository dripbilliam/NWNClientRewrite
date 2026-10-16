import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {intEntry} from '../src/combat_stats.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
const actor=s.byTag('M1Q0D19Goblin').find(o=>o.objectType===5),frame={self:s.player.id};assert.ok(actor);
const id=await s.createItem('nw_wswdg001',actor.id,1,''),item=s.registry.get(id),start=runtimeDiagnostics.records.length,reports=[];
const gear=async equip=>{await s.combat.clearActions(actor);actor.combatRound.started=false;await s.commands[equip?'ActionEquipItem':'ActionUnequipItem'](equip?[id,4]:[id],{self:actor.id});await s.combat.runActions(actor,0,0);assert.equal(s.equipmentSlot(actor,16),equip?item:null);};
await gear(true);const baseline=structuredClone({attack:actor.stats.combat.attackBonuses.melee,abilities:actor.stats.equippedAbilities,hp:actor.stats.currentHP,maxHP:actor.stats.maxHP});
const linked=()=>actor.effects.filter(e=>e.creatorId===id),propertyEffect=e=>item.effects.find(v=>v.id===e.id),remove=async e=>{
 await s.commands.RemoveItemProperty([id,e],frame);const event=s.scheduler.events.find(v=>v.targetId===id&&v.event.type==='combatAI'&&v.event.eventId===14&&v.event.payload?.id===e.id);assert.ok(event);await s.dispatch(event);
};
const enhancement=await s.commands.ItemPropertyEnhancementBonus([1],frame),expected=intEntry(s.characterRules.iprp_meleecost,1,'Value').value;
await s.commands.AddItemProperty([1,enhancement,id,1],frame);const holder=propertyEffect(enhancement),effects=linked().filter(e=>[10,13].includes(e.type));assert.ok(holder);assert.deepEqual(effects.map(e=>e.type),[10,13]);assert.ok(effects.every(e=>e.propertyId===holder.propertyId));assert.equal(effects[0].id,effects[1].id);assert.equal(effects[0].exposed,true);assert.equal(effects[1].exposed,false);
assert.equal(actor.stats.combat.attackBonuses.melee,baseline.attack+expected);assert.equal(actor.itemCombatEffects.effects.filter(e=>e.sourceItemId===id).length,0);
reports.push({kind:'enhancement',baseAttack:baseline.attack,attack:actor.stats.combat.attackBonuses.melee,expectedDelta:expected,propertyId:holder.propertyId,effects:effects.map(e=>({id:e.id,type:e.type,integers:e.integers,exposed:e.exposed}))});
await gear(false);assert.ok(propertyEffect(enhancement));assert.equal(linked().length,0);await gear(true);assert.equal(actor.stats.combat.attackBonuses.melee,baseline.attack+expected);assert.equal(linked().filter(e=>[10,13].includes(e.type)).length,2);
await remove(enhancement);assert.equal(linked().length,0);assert.equal(actor.stats.combat.attackBonuses.melee,baseline.attack);
for(const [ability,name]of ['Str','Dex','Con','Int','Wis','Cha'].entries()){
 const property=await s.commands.ItemPropertyAbilityBonus([ability,2],frame),magnitude=intEntry(await s.items.costTable(1),2,'Value').value;
 await s.commands.AddItemProperty([1,property,id,1],frame);assert.equal(actor.stats.equippedAbilities[name],baseline.abilities[name]+magnitude);
 const owner=propertyEffect(property),children=linked();assert.ok(children.some(e=>e.type===36));assert.ok(children.every(e=>e.propertyId===owner.propertyId));
 reports.push({kind:'ability',name,base:baseline.abilities[name],value:actor.stats.equippedAbilities[name],magnitude,hp:actor.stats.currentHP,maxHP:actor.stats.maxHP});
 await remove(property);assert.deepEqual(actor.stats.equippedAbilities,baseline.abilities);assert.equal(actor.stats.currentHP,baseline.hp);assert.equal(actor.stats.maxHP,baseline.maxHP);assert.equal(linked().length,0);
}
const damage=await s.commands.ItemPropertyDamageBonus([8,3],frame);await s.commands.AddItemProperty([1,damage,id,.25],frame);const damageOwner=propertyEffect(damage),extra=linked().filter(e=>e.type===13);assert.equal(extra.length,1);assert.equal(extra[0].integers[0],3);assert.equal(extra[0].integers[1],1<<6);assert.equal(extra[0].propertyId,damageOwner.propertyId);assert.equal(actor.stats.combat.attackBonuses.melee,baseline.attack);
s.scheduler.time=damageOwner.expires;await s.effects.updateObject(item);assert.ok(propertyEffect(damage));s.scheduler.time++;await s.effects.updateObject(item);assert.equal(propertyEffect(damage),undefined);assert.equal(linked().length,0);
reports.push({kind:'damage',cost:3,flags:1<<6,expiryRemovedLinkedEffects:true});
const light=await s.commands.ItemPropertyLight([3,4],frame);await s.commands.AddItemProperty([1,light,id,.25],frame);
const lightOwner=propertyEffect(light),lightEffects=linked().filter(e=>[30,54].includes(e.type));assert.ok(lightOwner);assert.deepEqual(lightEffects.map(e=>e.type),[30,54]);assert.ok(lightEffects.every(e=>e.propertyId===lightOwner.propertyId&&e.integers[0]===179));assert.equal(lightEffects[0].id,lightEffects[1].id);assert.equal(lightEffects[0].exposed,false);assert.equal(lightEffects[1].exposed,true);
const loops=()=>actor.nativeLoopingVisuals160.records.filter(v=>v.visualId===179&&v.sourceId===id);assert.equal(loops().length,1);
await gear(false);assert.equal(loops().length,0);await gear(true);assert.equal(loops().length,1);
s.scheduler.time=lightOwner.expires;await s.effects.updateObject(item);assert.ok(propertyEffect(light));s.scheduler.time++;await s.effects.updateObject(item);assert.equal(propertyEffect(light),undefined);assert.equal(loops().length,0);assert.equal(linked().length,0);
reports.push({kind:'light',visualId:179,linkedTypes:[30,54],unequipReequip:true,expiryRemovedLinkedEffectsAndLoop:true});
if(process.argv.includes('--regeneration')){
 s.worldTimer.snapshot();const property=await s.commands.ItemPropertyRegeneration([3],frame);
 await s.commands.AddItemProperty([1,property,id,30],frame);const holder=propertyEffect(property),parent=linked().find(e=>e.type===7);assert.ok(holder);assert.ok(parent);
 assert.equal(parent.durationType,3);assert.deepEqual(parent.integers.slice(0,2),[3,6000]);assert.equal(parent.propertyId,holder.propertyId);assert.equal(parent.creatorId,id);
 const base=s.hitPoints(actor.id,true);actor.stats.currentHP=base-6;s.damage.synchronize(actor);
 const tick=async delta=>{s.scheduler.advance(delta);s.worldTimer.snapshot();await s.effects.updateObject(actor);};
 await tick(6000);assert.equal(actor.stats.currentHP,base-6);await tick(1);assert.equal(actor.stats.currentHP,base-3);
 const firstTick=structuredClone(parent.integers);await tick(6000);assert.equal(actor.stats.currentHP,base-3);await tick(1);assert.equal(actor.stats.currentHP,base);
 const secondTick=structuredClone(parent.integers);assert.notDeepEqual(firstTick,secondTick);
 await gear(false);assert.equal(linked().length,0);actor.stats.currentHP=base-3;s.damage.synchronize(actor);await tick(6001);assert.equal(actor.stats.currentHP,base-3);
 await gear(true);const rebuilt=linked().find(e=>e.type===7);assert.ok(rebuilt);assert.equal(rebuilt.propertyId,holder.propertyId);assert.equal(rebuilt.integers[3]>>>0,s.worldTimer.time().time);
 await tick(6000);assert.equal(actor.stats.currentHP,base-3);await tick(1);assert.equal(actor.stats.currentHP,base);
 await remove(property);assert.equal(linked().length,0);assert.equal(actor.nativeEffectIcons778.records.some(e=>e.iconId===2),false);assert.equal(item.possessorId,actor.id);
 reports.push({kind:'regeneration',amount:3,interval:6000,firstTick,secondTick,equippedDuration:3,sourceItemId:id,propertyId:holder.propertyId,strictTicks:true,unequipStopsHealing:true,reequipResetsClock:true,explicitRemovalClearsLinkedIcon:true});
}
const diagnostics=runtimeDiagnostics.records.slice(start),unexpected=diagnostics.filter(r=>r.severity==='error'&&!['effects.presentation-unimplemented','items.visual-unimplemented'].includes(r.code??r.kind));
// Retain all diagnostics, including presentation/attached-visual omissions.
const report={itemId:id,ownerId:actor.id,canonicalOwnerPreserved:item.possessorId===actor.id,reports,unequipReequipPreservedProperty:true,noDuplicateProjection:true,diagnostics,unexpected,limits:'Installed API/queued gear actions exercise a plain dagger on an authored NPC. Enhancement, all six ability bonuses, damage bonus, light controller/copied visual/loop, property-ID linkage, removal and expiry are checked. Captured native materializer/traversal comparisons validate upper engine owners; full generic ApplyEffect bookkeeping, nonzero fourth-flag loading, attached/light rendering, remaining materializers and actual authored spell impact/UI acceptance remain separate work.'};
if(process.argv.includes('--regeneration'))report.limits+=' Optional regeneration also checks actual ItemPropertyRegeneration, AddItemProperty on equipped gear, strict timed healing, unequip/re-equip clock reset and explicit property removal; no rendered recovery/GUI acceptance.';
await fs.writeFile(`backups/animations/${process.argv.includes('--regeneration')?'live-equipped-item-regeneration':'live-equipped-item-buffs'}.json`,JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));assert.deepEqual(unexpected,[]);
