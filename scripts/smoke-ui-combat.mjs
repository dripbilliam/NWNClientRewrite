// Installed campaign integration, retaining authored stats and event scripts.
// This checks local input/perception/action progress, not original-game parity.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const [install,modulePath,area,tag,x,y,z]=process.argv.slice(2);
const combatMessages=[];
const s=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false,runNativeAI:true,serverPvpSetting:0,onCombatMessage:m=>combatMessages.push(m)})
  .initialize([],{character:await fs.readFile(`${install}/data/lcv/fighter.bic`)});
console.log(JSON.stringify({initializationErrors:[...new Set(runtimeDiagnostics.records.filter(r=>r.severity==='error').map(r=>r.message))]}));
if(process.argv.includes('--trace-talents')){
  const seen=new Set();s.commands.GetCreatureTalentBest=(args,f)=>{
    const actor=s.registry.get(args[2]),root=actor?.creatureData??actor?.authored;
    const entry={actorId:actor?.id,tag:actor?.tag,args,feats:root?.FeatList,classes:root?.ClassList,
      spells:root?.SpecAbilityList,inventory:(actor?.inventory??[]).map(id=>{const item=s.registry.get(id);return{id,base:item?.authored?.BaseItem,equipment:item?.equipmentSlot,properties:item?.authored?.PropertiesList};})};
    const key=JSON.stringify(entry);if(!seen.has(key)){seen.add(key);console.log('TALENT REQUEST '+key);}
    throw new Error('Engine call GetCreatureTalentBest is not implemented');
  };
}
await s.enterArea(area,[Number(x),Number(y),Number(z)]);
const skillObservations=[];
if(process.argv.includes('--observe-skills')){
  const use=s.skills.use.bind(s.skills),execute=s.skills.execute.bind(s.skills);
  s.skills.use=async(actor,...args)=>{const result=await use(actor,...args);skillObservations.push({phase:'request',actor:actor.id,args,result,actions:[...actor.objectActionState.list].map(a=>a.actionId)});return result;};
  s.skills.execute=async(actor,node)=>{const result=await execute(actor,node);skillObservations.push({phase:'execute',actor:actor.id,result,stage:actor.nativePickpocketStage830,detected:actor.nativePickpocketDetected834,timer:actor.nativeSkillTimers878[13],actions:[...actor.objectActionState.list].map(a=>a.actionId)});return result;};
}
// Optional read-only request trace, retaining the same unavailable-call stop.
// No actor, rule or module inputs are altered by this research mode.
if(process.argv.includes('--trace-skills')){
  const seen=new Set();s.commands.ActionUseSkill=(args,f)=>{
    const entry={actorId:f.self,tag:s.registry.get(f.self)?.tag,args},key=JSON.stringify(entry);
    if(!seen.has(key)){seen.add(key);console.log('SKILL REQUEST '+key);}
    throw new Error('Engine call ActionUseSkill is not implemented');
  };
}
const target=s.byTag(tag)[0],pc=s.player;
if(!target)throw new Error('Combat target not found');
const initialHP=target.stats.currentHP;
const initialPlayerHP=pc.stats.currentHP;
const begin=runtimeDiagnostics.records.length;
for(let ms=0;ms<8000;ms+=100){s.scheduler.advance(100);await s.scheduler.pump();}
const eligibility=await s.combat.evaluateAttack(pc,target.id);
console.log(JSON.stringify({decision:eligibility.decision,valid:eligibility.targetValid,range:eligibility.maximum,spatial:eligibility.spatialResult,seen:pc.perception.get(target.id)}));
const input=s.queuePlayerAttack(target.id);await s.scheduler.pump();console.log('input',await input);
for(let ms=0;ms<15000;ms+=100){s.scheduler.advance(100);await s.scheduler.pump();if(ms%1000===0)console.log(JSON.stringify({ms,seen:pc.perception.get(target.id),pos:pc.position,target:pc.attackTargetId,actionTarget:pc.attackActionTargetId,ai:pc.nativeAILevel7c,started:pc.combatRound.started,timer:pc.combatRound.timer,actions:pc.objectActionState.list.count,head:pc.objectActionState.list.head?.action.actionId,hp:target.stats.currentHP,remaining:pc.combatRound.actions.length}));}
console.log(JSON.stringify({errors:[...new Set(runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error').map(r=>r.message))]}));
if(process.argv.includes('--observe-skills'))console.log(JSON.stringify({skillObservations}));
const attacks=combatMessages.filter(m=>[5,6].includes(m.type));
console.log(JSON.stringify({initialPlayerHP,finalPlayerHP:pc.stats.currentHP,playerAttacks:attacks.filter(m=>m.data.objects[0]===pc.id).length,enemyAttacks:attacks.filter(m=>m.data.objects[0]===target.id).length,
  attacks:attacks.map(m=>({actor:m.data.objects[0],target:m.data.objects[1],...m.attack}))}));
assert.ok(target.stats.currentHP<initialHP,'Queued attack must execute and damage the authored target');
const repaired=['ActionDoCommand','GetIsInCombat','GetIsEncounterCreature','GetActionMode','GetIsNight','GetIsDay','GetIsDawn','GetIsDusk','GetFirstPC','GetNextPC','SetListening','GetIsListening','SetListenPattern','SetAssociateListenPatterns','TestStringAgainstPattern','GetIsEnemy','GetIsFriend','GetIsNeutral','GetDistanceToObject','SetFacingPoint','UnlockAchievement','GetFirstFactionMember','GetNextFactionMember','SetIsDestroyable','GetStringLength','GetStringRight','GetSubString','GetStringLowerCase','GetStringUpperCase','FloatToInt','ActionMoveToObject','ActionMoveToLocation','ActionWait','ActionPlayAnimation','PlayAnimation','EffectDeath','EffectKnockdown','GetNearestTrapToObject','ActionRandomWalk','GetLocked','GetAreaFromLocation','ActionUseSkill'];
const errors=runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error').map(r=>r.message);
for(const name of repaired)assert.ok(!errors.some(message=>message.includes(`Engine call ${name} is not implemented`)),`Repaired engine call ${name} regressed`);
assert.ok(!errors.some(message=>message.includes('Native perception sound path is unavailable')),'Native indoor hearing must have its path owner');
if(process.argv.includes('--require-retaliation'))assert.ok(attacks.some(m=>m.data.objects[0]===target.id&&m.data.objects[1]===pc.id),'Authored enemy AI must resolve a real attack against the player');
if(process.argv.includes('--require-encounter')){
  const spawned=[...s.registry.objects.values()].filter(o=>o.objectType===5&&o.areaId===pc.areaId&&o.nativeField948!==undefined&&o.nativeField948!==0x7f000000);
  assert.ok(spawned.length>0,'An authored encounter must create canonical creatures');
  for(const o of spawned){assert.equal(s.registry.get(o.id),o);assert.ok(s.aiMaster.levels[o.nativeAILevel7c].indexOf(o.id)>=0,'Spawned creature must share the native AI registry');}
  const living=spawned.filter(o=>!s.isDead(o)).sort((a,b)=>a.position.reduce((sum,v,i)=>sum+(v-pc.position[i])**2,0)-b.position.reduce((sum,v,i)=>sum+(v-pc.position[i])**2,0))[0];
  assert.ok(living,'There must be a living spawned target');const hp=living.stats.currentHP,request=s.queuePlayerAttack(living.id);await s.scheduler.pump();assert.equal(await request,1);
  for(let ms=0;ms<30000&&!s.isDead(living);ms+=100){s.scheduler.advance(100);await s.scheduler.pump();}
  console.log(JSON.stringify({spawned:spawned.map(o=>({id:o.id,encounterId:o.nativeField948,level:o.nativeAILevel7c,position:o.position,hp:o.stats.currentHP})),secondTarget:living.id,initialHP:hp,finalHP:living.stats.currentHP,
    remainingErrors:[...new Set(runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error').map(r=>r.message))]}));
  assert.ok(s.isDead(living),'Player must complete approach, attack and death against a newly spawned creature');
  assert.equal(s.registry.get(living.id),living,'Corpse retains its canonical ID through death animation');
  if(process.argv.includes('--clear-encounter')){
    const encounter=s.registry.get(living.nativeField948),before=encounter.nativeEncounterSpawned340,cleared=[];
    for(const enemy of spawned.filter(o=>o.nativeField948===encounter.id&&!s.isDead(o))){
      const attack=s.queuePlayerAttack(enemy.id);await s.scheduler.pump();assert.equal(await attack,1);
      for(let ms=0;ms<60000&&!s.isDead(enemy);ms+=100){s.scheduler.advance(100);await s.scheduler.pump();}
      assert.ok(s.isDead(enemy),`Player must defeat encounter creature ${enemy.id}`);cleared.push(enemy.id);
    }
    for(let ms=0;ms<1000;ms+=100){s.scheduler.advance(100);await s.scheduler.pump();}
    assert.equal(encounter.nativeEncounterSpawned340,0,'All encounter creatures must leave its active count');assert.equal(encounter.nativeEncounterActive320,0,'Exhausted encounter must deactivate');
    console.log(JSON.stringify({encounterCleared:encounter.id,before,cleared,spawned:encounter.nativeEncounterSpawned340,active:encounter.nativeEncounterActive320,
      errors:[...new Set(runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error').map(r=>r.message))]}));
  }
}
const finalErrors=[...new Set(runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error').map(r=>r.message))];
const missingOwners=[...new Set(runtimeDiagnostics.records.slice(begin).filter(r=>r.code.includes('unimplemented')).map(r=>`${r.code}: ${r.message}`))];
console.log(JSON.stringify({readinessAudit:{remainingErrors:finalErrors,missingOwners}}));
if(process.argv.includes('--trace-errors'))console.log(JSON.stringify({errorDetails:runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error')}));
for(const name of repaired)assert.ok(!finalErrors.some(message=>message.includes(`Engine call ${name} is not implemented`)),`Repaired engine call ${name} regressed after a spawned creature death`);
if(process.argv.includes('--require-no-engine-errors')){
  // These are absent resources in the installed fixture, not repaired calls.
  const missing=/^Resource (plc_w02 \(type 2053\)|script1 \(type 2010\))/;
  assert.deepEqual(finalErrors.filter(message=>!missing.test(message)),[],'Complete encounter must not retain an engine failure');
}
console.log(JSON.stringify({validation:'PASS',initialHP,finalHP:target.stats.currentHP,remainingErrors:finalErrors,missingOwners,limits:'Replacement integration; not a native combat parity oracle. Error-only acceptance does not establish implemented warning/information owners.'}));
if(process.argv.includes('--require-combat-ready'))assert.deepEqual(missingOwners,[],'Combat readiness must not retain observed unimplemented owners at any diagnostic severity');
