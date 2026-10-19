import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {advanceToEffectExpiry} from './advance-effect-clock.mjs';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/live-summoning.json',messages=[],s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{
 runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:m=>messages.push(m)}).initialize(['m0q1a'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const actor=s.player,choices=[];
for(const [index,state]of actor.nativeTalentClasses.entries())for(const [level,slots]of state.memorized.entries())for(const slot of slots){
 if(!slot?.ready)continue;const row=s.characterRules.spells.orderedRows[slot.id];if(!/summon/i.test(row?.Label??''))continue;
 const spell=s.spellBook.castingSpell(slot.id),domain=slot.domain?level-s.spellBook.metamagicCost(slot.metamagic):0;
 if(s.spellBook.uses(actor,slot.id,index,domain,slot.metamagic)>0)choices.push({spellId:slot.id,label:row.Label,index,domain,meta:slot.metamagic,spell});
}
console.log('READY SUMMON CHOICES',JSON.stringify(choices));assert.ok(choices.length,'Installed character must have an actual ready summon spell');
const choice=choices[0],before=s.spellBook.uses(actor,choice.spellId,choice.index,choice.domain,choice.meta),start=runtimeDiagnostics.records.length,impacts=[],spawns=[],run=s.runScript.bind(s);
s.runScript=(name,id,options)=>{if(name===choice.spell.impactScript)impacts.push({name,id});const o=s.registry.get(id);if(o?.sourceKey.startsWith('runtime:creature:')&&name===o.scripts?.spawn)spawns.push({name,id,state:o.nativeSpawnState548});return run(name,id,options);};
const tick=async(ms=100)=>{s.scheduler.advance(ms);s.worldTimer.snapshot();await s.effects.updateObject(actor);for(const o of [actor,...[...s.registry.objects.values()].filter(o=>o.kind==='creature'&&o.sourceKey.startsWith('runtime:creature:'))]){
 if(s.registry.get(o.id)!==o)continue;await s.combat.updateTimer(o,ms);if(o.objectActionState.list.count)await s.combat.runActions(o,...Object.values(s.worldTimer.time()));}await s.scheduler.pump();};
const input=s.queuePlayerCastSpell({spellId:choice.spellId,classIndex:choice.index,domainLevel:choice.domain,metamagic:choice.meta,targetId:actor.id});await s.drainPlayerInputs();assert.equal(await input,1);
for(let n=0;n<150;n++){await tick();if(!actor.objectActionState.list.count&&actor.effects.some(e=>e.type===6)&&s.commands.GetAssociate([4,actor.id,1],{self:actor.id})!==0x7f000000)break;}
const effects=actor.effects.filter(e=>e.type===6),summonId=s.commands.GetAssociate([4,actor.id,1],{self:actor.id}),summon=s.registry.get(summonId),after=s.spellBook.uses(actor,choice.spellId,choice.index,choice.domain,choice.meta);
assert.ok(summon);assert.equal(summon.nativeSpawnState548,1);assert.equal(Object.hasOwn(summon,'nativeField548'),false);
assert.equal(spawns.filter(e=>e.id===summonId).length,1);await s.combat.updateSpawnHeartbeat(summon,0);await s.combat.updateSpawnHeartbeat(summon,0);assert.equal(spawns.filter(e=>e.id===summonId).length,1);
const report={choice,before,after,impacts,summon:summon?{id:summon.id,tag:summon.tag,areaId:summon.areaId,masterId:summon.masterId,associateType:summon.associateType,template:summon.templateResRef,inventory:summon.inventory,queue:[...summon.objectActionState.list].map(n=>n.actionId)}:null,
 effects:structuredClone(effects),initialSpawn:spawns.filter(e=>e.id===summonId),heartbeatSpawnState:summon.nativeSpawnState548,diagnostics:runtimeDiagnostics.records.slice(start),messages,limits:'Installed memorized spell and authored impact/spawn scripts; native API replacement, expiry, adoption and destruction fixtures. Two native heartbeat-owner updates after delivery verify no repeated OnSpawn. Startup/general AI scheduler disabled. Not independent original-process, rendered or multiplayer acceptance.'};
await fs.writeFile(output,JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
assert.equal(after,before-1);assert.equal(impacts.length,1);assert.ok(summon);assert.equal(summon.masterId,actor.id);assert.equal(summon.associateType,4);assert.equal(summon.areaId,actor.areaId);assert.equal(effects.length,1);
assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);
const invalid=0x7f000000,area=s.currentArea,cycles=[];
const absent=(id,items=[])=>{assert.equal(s.registry.get(id),undefined);for(const item of items)assert.equal(s.registry.get(item),undefined);assert.equal(area.nativeSpatial.indexOf(id),-1);assert.ok(!s.aiMaster.levels.some(list=>list.indexOf(id)>=0));assert.ok(!actor.associateIds.includes(id));};
// Strict effect expiry and all owned item/associate cleanup from the real cast.
const originalItems=[...summon.inventory],originalEffect=effects[0];
advanceToEffectExpiry(s,originalEffect);await s.effects.updateObject(actor);assert.ok(actor.effects.includes(originalEffect));
s.scheduler.advance(1);s.worldTimer.snapshot();await s.effects.updateObject(actor);await s.scheduler.pump();absent(summonId,originalItems);assert.ok(!actor.effects.includes(originalEffect));cycles.push({kind:'authored-spell-expiry',id:summonId,items:originalItems});
const resRef=report.summon.template,active=e=>actor.effects.find(value=>value.id===e.id),nextId=()=>s.registry.nextObjectId[0];
const effect=(delay=0,appear=0)=>s.commands.EffectSummonCreature([resRef,-1,delay,appear,99,invalid],{self:actor.id});
const first=effect(0,2);await s.effects.apply(1,first,actor.id,20);const firstId=active(first).objectIds[1];await s.scheduler.pump();assert.equal(s.registry.get(firstId).masterId,actor.id);
await tick();assert.equal(s.registry.get(firstId).animationState,95);const firstItems=[...s.registry.get(firstId).inventory];
const second=effect();await s.effects.apply(1,second,actor.id,30);const secondId=active(second).objectIds[1];await s.scheduler.pump();absent(firstId,firstItems);assert.ok(active(first),'Replacing a summon must not invent effect removal');assert.equal(s.commands.GetAssociate([4,actor.id,1],{self:actor.id}),secondId);assert.ok(secondId>firstId);
const secondItems=[...s.registry.get(secondId).inventory];await s.effects.remove(actor.id,second.id);await s.scheduler.pump();absent(secondId,secondItems);await s.effects.remove(actor.id,first.id);cycles.push({kind:'replacement-and-explicit-removal',firstId,secondId,firstItems,secondItems});
// The native decoded input rechecks master ownership at processing time.
const dismissedEffect=effect();await s.effects.apply(1,dismissedEffect,actor.id,20);await s.scheduler.pump();
const dismissedId=active(dismissedEffect).objectIds[1],dismissed=s.registry.get(dismissedId),dismissedItems=[...dismissed.inventory];
dismissed.masterId=invalid;let command=s.queuePlayerAssociateCommand(dismissedId,-10);await s.drainPlayerInputs();assert.equal(await command,0);
assert.equal(dismissed.lastAssociateCommand,0);assert.equal(s.registry.get(dismissedId),dismissed);
dismissed.masterId=actor.id;command=s.queuePlayerAssociateCommand(dismissedId,-10);await s.drainPlayerInputs();assert.equal(await command,0);
assert.equal(dismissed.lastAssociateCommand,-10);assert.equal(s.commands.GetLastAssociateCommand([dismissedId],{self:actor.id}),-10);
assert.equal(s.registry.get(dismissedId),dismissed,'Unsummon must queue destruction rather than delete synchronously');
await s.scheduler.pump();absent(dismissedId,dismissedItems);assert.ok(active(dismissedEffect),'Dismissal does not invent removal of the master effect');
await s.effects.remove(actor.id,dismissedEffect.id);cycles.push({kind:'native-input-dismissal',id:dismissedId,items:dismissedItems,unownedRejected:true});
// Expiry can delete a constructed creature before its delayed insertion event.
const delayed=effect(.5);await s.effects.apply(1,delayed,actor.id,.1);const delayedId=active(delayed).objectIds[1],delayedItems=[...s.registry.get(delayedId).inventory];assert.equal(s.registry.get(delayedId).areaId,invalid);
await tick(100);assert.ok(active(delayed));await tick(1);absent(delayedId,delayedItems);await tick(500);absent(delayedId,delayedItems);cycles.push({kind:'expired-before-delivery',id:delayedId,items:delayedItems});
// Adoption retains the existing canonical ID and consumes no object IDs.
const adopted=[...s.registry.objects.values()].find(o=>o.kind==='creature'&&!o.isPC&&o.nativeStatsIsPCb0===0&&o.masterId===invalid&&!s.isDead(o)&&o.stats);assert.ok(adopted);
const allocation=nextId(),adopt=s.commands.EffectSummonCreature(['',-1,0,0,99,adopted.id],{self:actor.id}),adoptedItems=[...adopted.inventory];await s.effects.apply(1,adopt,actor.id,1);
assert.equal(nextId(),allocation);assert.equal(active(adopt).objectIds[1],adopted.id);assert.equal(adopted.masterId,actor.id);await s.effects.remove(actor.id,adopt.id);await s.scheduler.pump();absent(adopted.id,adoptedItems);cycles.push({kind:'adopt-existing',id:adopted.id,items:adoptedItems,allocationUnchanged:true});
const rejected=s.commands.EffectSummonCreature(['',-1,0,0,99,actor.id],{self:actor.id});assert.equal(rejected.type,0);assert.equal(nextId(),allocation);
const victim=[...s.registry.objects.values()].find(o=>o.kind==='creature'&&!o.isPC&&!s.isDead(o)&&o.stats);assert.ok(victim);const victimItems=[...victim.inventory];
s.commands.DestroyObject([victim.id,.25],{self:actor.id});await tick(249);assert.equal(s.registry.get(victim.id),victim);await tick(1);absent(victim.id,victimItems);cycles.push({kind:'script-destroy-delay',id:victim.id,items:victimItems});
report.cycles=cycles;report.spawns=spawns;report.diagnostics=runtimeDiagnostics.records.slice(start);await fs.writeFile(output,JSON.stringify(report,null,2));console.log('FULL LIFECYCLE',JSON.stringify({cycles,diagnostics:report.diagnostics}));
assert.deepEqual(report.diagnostics.filter(d=>d.severity==='error'),[]);
