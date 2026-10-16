import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
import {clearAttackData} from '../src/combat_attack_data.js';
import {intEntry} from '../src/combat_stats.js';

const root=process.argv[2]??'../FullDecomp/NwnRootInstall';
const s=await new ModuleSession(await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
const owner=s.byTag('M1Q0D19Goblin').find(o=>o.objectType===5),player=s.player;
assert.ok(owner);
await s.enterArea(s.registry.get(owner.areaId).resRef,[owner.position[0]+2,owner.position[1],owner.position[2]]);
await s.combat.updatePerception(player,owner,1);
s.scheduler.events=[];
const itemId=await s.createItem('nw_wswdg001',owner.id,1,''),item=s.registry.get(itemId);
await s.commands.ActionEquipItem([itemId,4],{self:owner.id});
await s.combat.runActions(owner,...Object.values(s.worldTimer.time()));
assert.equal(s.equipmentSlot(owner,16),item);
const baseline=owner.stats.combat.attackBonuses.melee,reports=[],run=s.runScript.bind(s);
let impacts=[];
s.runScript=async(name,id,options)=>{if(String(name).split('\0')[0].toLowerCase()===s.currentProbeScript)impacts.push({name,id,at:s.scheduler.time});return run(name,id,options);};
for(const impactScript of ['x2_s0_magcweap','x2_s0_grmagweap','x2_s0_flmeweap','x2_s0_darkfire']){
 const spell=s.characterRules.spells.orderedRows.map((_,id)=>s.spellBook.castingSpell(id)).find(v=>v?.impactScript.split('\0')[0].toLowerCase()===impactScript);
 assert.ok(spell,impactScript);s.currentProbeScript=impactScript;impacts=[];
 const start=runtimeDiagnostics.records.length,animations=[],errors=[];
 // This fixture deliberately tests the game's scripted cheat-casting form.
 // It does not manufacture memorized spells or claim spellbook acceptance.
 await s.combat.clearActions(player);player.combatRound.started=false;
 await s.commands.ActionCastSpellAtObject([spell.id,owner.id,0,1,0,0,0,-1,0],{self:player.id});
 for(let n=0;n<200;n++){
  s.scheduler.advance(100);s.worldTimer.snapshot();
  try{await s.combat.runActions(player,...Object.values(s.worldTimer.time()));}catch(e){errors.push(e.message);break;}
  animations.push(player.animationState);
  while(s.scheduler.events[0]?.due<=s.scheduler.time){const e=s.scheduler.events.shift();try{await s.dispatch(e);}catch(error){errors.push(error.message);}}
  if(player.objectActionState.list.count===0&&impacts.length)break;
 }
 const properties=item.effects.filter(e=>e.type===91&&e.spellId===spell.id),linked=owner.effects.filter(e=>e.creatorId===itemId);
 let onHit=null;
 if(properties.some(e=>(e.integers[0]&65535)===82)){
  const property=properties.find(e=>(e.integers[0]&65535)===82),expectedId=intEntry(s.characterRules.iprp_onhitspell,property.integers[1]&65535,'SpellIndex').value;
  owner.combatRound.currentAttack=0;const data=clearAttackData(owner.combatRound.attacks[0]);
  // Explicit successful strike fixture; ordinary damage resolution, impact
  // scheduling and event19 execute unchanged. This does not test attack RNG.
  data.result=1;data.weaponAttackType=1;data.animationDuration=400;data.attackDuration=1000;
  await s.combat.resolveDamage(owner,player);
  assert.equal(data.lists[1].length,1);assert.equal(data.lists[1][0].spellId,expectedId);
  assert.equal(data.lists[1][0].casterLevel,(property.integers[3]&65535)+1);
  owner.combatRound.currentAttack=1;await s.combat.signalMelee(owner,player,1);
  const event=s.scheduler.events.find(e=>e.event.type==='combatAI'&&e.event.eventId===19&&e.event.payload?.itemId===itemId);assert.ok(event);
  const hp=player.stats.currentHP,impactStart=runtimeDiagnostics.records.length;
  const context=()=>structuredClone(Object.fromEntries(['nativeSpellId218','nativeSpellTarget214','nativeSpellPoint208','nativeSpellTarget818','nativeSpellFeat23c','nativeCasterOverride820','nativeCasterOverride824'].map(key=>[key,owner[key]]))),saved=context();
  await s.dispatch(event);
  assert.deepEqual(context(),saved,'event19 restores interrupted caster context');
  onHit={payload:event.event.payload,hpBefore:hp,hpAfter:player.stats.currentHP,restoredCasterContext:true,diagnostics:runtimeDiagnostics.records.slice(impactStart)};
  // The physical strike and other combat events are outside this isolated
  // on-hit acceptance probe; retain only the authored spell's damage here.
  s.scheduler.events=[];
 }
 const diagnostics=runtimeDiagnostics.records.slice(start);
 const report={spell:{id:spell.id,impactScript},castForm:'ActionCastSpellAtObject cheat=1',impacts:[...impacts],animations:[...new Set(animations)],queue:[...player.objectActionState.list].map(n=>n.actionId),errors,properties:structuredClone(properties),linked:structuredClone(linked),attackBefore:baseline,attackAfter:owner.stats.combat.attackBonuses.melee,onHit,diagnostics};
 reports.push(report);console.log(JSON.stringify(report,null,2));
 // Always save the failing case and all original diagnostics before asserting.
 const save=()=>fs.writeFile('backups/animations/live-authored-item-buffs.json',JSON.stringify({itemId,ownerId:owner.id,reports,limits:'Installed authored NCS, scripted cheat=1 requests, ordinary queued gear and canonical objects. On-hit uses an explicit successful strike fixture through real damage resolution and impact scheduling; physical hit and other strike events are not dispatched. Startup/AI isolated. Memorized UI casting, full generic effect bookkeeping and attached visuals remain separate acceptance work.'},null,2));
 await save();
 assert.deepEqual(errors,[]);assert.equal(impacts.length,1);assert.equal(player.objectActionState.list.count,0);
 assert.deepEqual(diagnostics.filter(d=>d.severity==='error'),[],'no failed engine call or script execution');
 assert.ok(animations.some(id=>[15,16].includes(id)),'conjure animation');
 assert.ok(animations.some(id=>[17,18,19,20,61,89,96].includes(id)),'release animation');
 assert.ok(properties.length,'authored spell creates item properties');
 if(onHit)assert.ok(onHit.hpAfter<onHit.hpBefore,'authored on-hit spell damages target');else assert.ok(linked.some(e=>[10,13].includes(e.type)),'equipped effects applied');
 for(const property of [...properties])await s.effects.removeOne(itemId,property.id,undefined,property);
 assert.equal(owner.stats.combat.attackBonuses.melee,baseline);assert.equal(owner.effects.filter(e=>e.creatorId===itemId).length,0);
 report.cleanup={propertiesRemoved:properties.every(e=>!item.effects.includes(e)),restoredAttack:owner.stats.combat.attackBonuses.melee,noLinkedEffects:owner.effects.every(e=>e.creatorId!==itemId)};await save();
}
