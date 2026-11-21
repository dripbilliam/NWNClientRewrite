import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {addObjectAction} from '../src/object_actions.js';
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{
 runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];s.scheduler.beforePump=()=>s.worldTimer.snapshot();const player=s.player,choices=[];
for(const [index,state]of player.nativeTalentClasses.entries())for(const [level,slots]of state.memorized.entries())for(const slot of slots){
 if(!slot?.ready)continue;const row=s.characterRules.spells.orderedRows[slot.id];if(!/summon/i.test(row?.Label??''))continue;
 const domain=slot.domain?level-s.spellBook.metamagicCost(slot.metamagic):0;
 if(s.spellBook.uses(player,slot.id,index,domain,slot.metamagic)>0)choices.push({spellId:slot.id,classIndex:index,domainLevel:domain,metamagic:slot.metamagic});}
assert.ok(choices.length);const start=runtimeDiagnostics.records.length,cast=choices[0],input=s.queuePlayerCastSpell({...cast,targetId:player.id});await s.drainPlayerInputs();assert.equal(await input,1);
for(let n=0;n<150;n++){
 s.scheduler.advance(100);s.worldTimer.snapshot();await s.effects.updateObject(player);await s.combat.updateTimer(player,100);
 for(const o of [player,...player.associateIds.map(id=>s.registry.get(id)).filter(Boolean)])if(o.objectActionState.list.count)await s.combat.runActions(o,...Object.values(s.worldTimer.time()));
 await s.scheduler.pump();if(player.associateIds.length&&!player.objectActionState.list.count&&player.associateIds.every(id=>s.registry.get(id).objectActionState.list.count===0))break;
}
const id=s.commands.GetAssociate([4,player.id,1],{self:player.id}),summon=s.registry.get(id);assert.ok(summon);const inventory=[...summon.inventory],steps=[];
for(const [resRef,fixtureSpawn]of [['m0q1d',null],['m0q1a',[25,0,-15]]]){
 const destination=s.areas.get(resRef),spawn=fixtureSpawn??[...[...s.registry.objects.values()].find(o=>o.objectType===5&&o.areaId===destination.id&&o.id!==id&&!s.isDead(o)).position];
 const previous=s.registry.get(summon.areaId),old=[...summon.position],follow=s.queuePlayerAssociateCommand(id,-5);await s.drainPlayerInputs();await follow;await s.scheduler.pump();
 assert.ok([...summon.objectActionState.list].some(n=>n.actionId===55),'Queue actual authored follow before transfer');
 await s.enterArea(resRef,spawn);const area=s.currentArea;
 assert.equal(s.registry.get(id),summon);assert.equal(summon.masterId,player.id);assert.equal(summon.associateType,4);assert.equal(summon.areaId,area.id);
 assert.equal(previous.nativeSpatial.indexOf(id),-1);assert.ok(area.nativeSpatial.indexOf(id)>=0);assert.deepEqual(summon.inventory,inventory);
 assert.equal(summon.nativeField58c,0);assert.equal(summon.nativeField54c,0);assert.equal(summon.nativeField550,1);assert.equal(summon.objectActionState.list.count,0);
 assert.ok(Math.hypot(...summon.position.map((v,i)=>v-player.position[i]))<10);
 const events=s.scheduler.events.map(e=>({targetId:e.targetId,event:e.event})),pcEntry=events.findIndex(e=>e.event.type==='script'&&e.targetId===area.id&&e.event.eventObjects?.entering===player.id),npcEntry=events.findIndex(e=>e.event.type==='combatAI'&&e.targetId===area.id&&e.event.callerId===id&&e.event.payload?.type===12);
 if(area.scripts.enter){assert.ok(pcEntry>=0);assert.ok(npcEntry>pcEntry,'PC area-entry callback must precede NPC area-entry callback');}
 steps.push({resRef,actorId:id,masterId:player.id,areaId:area.id,old,position:[...summon.position],playerPosition:[...player.position],inventory,queue:[],pcEntry,npcEntry});
 // Keep transition script/perception events visible in the report, while this
 // owner fixture isolates general script AI and subsequent world combat.
 s.scheduler.events=[];
}
// Exercise real queue wait60's readiness gate in an isolated frame. This does
// not simulate a network acknowledgement or claim the PC handshake is wired.
const areaId=player.areaId;player.areaId=0x7f000000;const wait=addObjectAction(player.objectActionState,60,72);
await s.combat.runActions(player,...Object.values(s.worldTimer.time()));assert.equal(player.objectActionState.list.head.action,wait);
player.areaId=areaId;await s.combat.runActions(player,...Object.values(s.worldTimer.time()));assert.equal(player.objectActionState.list.count,0);
const diagnostics=runtimeDiagnostics.records.slice(start),report={cast,summonId:id,steps,diagnostics,limits:'Installed ready summon spell/authored follow script, legacy local PC area adapter with native recursive NPC restoration, real collision/visibility/action cleanup. General startup/AI isolated. Wait60 gate tested separately; native PC ClientArea send/ack, map presentation/persistence and campaign continuity remain unfinished.'};
await fs.writeFile('backups/animations/live-associate-transfer.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
const errors=diagnostics.filter(d=>d.severity==='error');assert.ok(errors.every(d=>d.context.operation==='native-placeable-pwk-missing-empty-mesh'&&d.message==='Resource plc_w02 (type 2053) was not found in the module, loaded HAKs, or KEY.'),'No new unavailable engine owner may hide behind the known installed PWK absence');
