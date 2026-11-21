// Authored flat-grass NPC fixture, real AI traversal and visibility. Hostility
// and omitted fixture scripts are explicit test setup, not campaign exceptions.
// This is replacement integration, not an original complete encounter oracle.
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const [install,fixture='backups/native-perception-oracle/home/modules/codex_perception_oracle.mod',mode='npc']=process.argv.slice(2);
if(!install)throw new Error('Usage: node scripts/smoke-native-melee-frame.mjs <install> [authored fixture]');
if(!['npc','decoded-input'].includes(mode))throw new Error('Unknown melee smoke input mode');
const s=await new ModuleSession(await openLocalModule(install,fixture),{runStartupScripts:true}).initialize([]);
const attacker=s.byTag('po_observer')[0],target=s.byTag('po_target')[0];assert.ok(attacker&&target);
for(const actor of [attacker,target]){s.commands.SetAILevel([actor.id,3]);actor.scripts={};}
s.factionTable.set(1,1,0);s.started=true;
const delivered=[],dispatch=s.dispatch.bind(s);
s.dispatch=async queued=>{await dispatch(queued);if(queued.event.type==='combatAI')delivered.push({eventId:queued.event.eventId,targetId:queued.targetId,callerId:queued.event.callerId});};
for(let elapsed=0;elapsed<=8000;elapsed+=100){s.scheduler.advance(elapsed===0?0:100);await s.scheduler.pump();}
assert.equal(s.commands.GetObjectSeen([target.id,attacker.id]),1);assert.equal(s.commands.GetObjectHeard([target.id,attacker.id]),1);
const hp=s.hitPoints(target.id,false),draws=s.random.draws,begin=runtimeDiagnostics.records.length;
let inputResult=null;
if(mode==='decoded-input'){
  // Explicit local test adapter: the selected controlled object is this NPC.
  // Its PC flag/frame remain authored, so this is not a real PC encounter test.
  s.player=attacker;
  const input=s.queuePlayerAttack(target.id);
  await s.scheduler.pump();inputResult=await input;assert.equal(inputResult,1);
}else assert.equal(await s.combat.requestAttack(attacker,target.id,0,1,0),1);
for(let elapsed=0;elapsed<30000;elapsed+=100){s.scheduler.advance(100);await s.scheduler.pump();}
const attacks=delivered.filter(e=>e.eventId===15),damage=delivered.filter(e=>e.eventId===5),failures=runtimeDiagnostics.records.slice(begin).filter(r=>r.severity==='error');
const result={mode,inputResult,attacks:attacks.length,damage:damage.length,initialHP:hp,finalHP:s.hitPoints(target.id,false),randomDraws:s.random.draws-draws,
  attackerPosition:attacker.position,targetPosition:target.position,frameElapsed:attacker.nativeFrameElapsedD4,
  failureCount:failures.length,failures:failures.slice(0,8).map(r=>({code:r.code,message:r.message})),
  pendingOwners:[...new Set(runtimeDiagnostics.records.slice(begin).filter(r=>r.code.endsWith('unimplemented')).map(r=>r.code))],
  limits:'NPC ordinary melee integration with real perception/frame/actions; authored immortal targets, explicit hostility and fixture scripts omitted. No original seed/timing/complete encounter or client/server parity claim.'};
console.log(JSON.stringify(result));
assert.equal(failures.length,0,'Native frame melee produced unimplemented/failing engine operations');
assert.ok(attacks.length>=2&&damage.length>=1,'Native frame did not complete repeated ordinary melee attacks and delayed damage');
assert.ok(result.finalHP<hp,'Native delayed damage never reached target HP');
