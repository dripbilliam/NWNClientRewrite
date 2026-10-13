// Read-only installed-data integration. Explicit calls to mapped perception
// owners do not assert native AI-frame scheduling or an encounter oracle.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const [install,modulePath]=process.argv.slice(2);
if(!install||!modulePath)throw new Error('Usage: node scripts/smoke-perception.mjs <install> <module>');
const session=await new ModuleSession(await openLocalModule(install,modulePath),{runStartupScripts:false}).initialize([]);
const filename=(await fs.readdir(path.join(install,'data/lcv'))).find(name=>/\.bic$/i.test(name));
assert.ok(filename);await session.loadCharacter(await fs.readFile(path.join(install,'data/lcv',filename)),filename);
const actors=[...session.registry.objects.values()].filter(o=>o.objectType===5&&o.stats);
const results=[];
for(const o of actors){
  for(const name of ['nativeSightRange7b0','nativeHearingRange7b8','nativeCombatSightRange7b4','nativeCombatHearingRange7bc'])assert.ok(Number.isFinite(o[name]),`${o.sourceKey}: ${name}`);
}
// Inspect several real module placements from a colocated selected client.
// Original resources, skill providers, native LOS, caches and event dispatch
// run normally; visibility is never manually inserted or inferred.
for(const target of actors.filter(o=>o!==session.player&&!session.isDead(o)).slice(0,8)){
  const actor=session.player;actor.areaId=target.areaId;actor.position=target.position.slice();actor.perception.clear();
  const before=runtimeDiagnostics.records.length;
  try{
    await session.combat.updatePerception(actor,target,0);
    const events=session.scheduler.events.filter(e=>e.event.type==='combatAI'&&e.event.eventId===10);
    for(const event of events)await session.dispatch(event);
    session.scheduler.events=session.scheduler.events.filter(e=>!events.includes(e));
    const flags=actor.perception.get(target.id)??0;
    assert.equal(session.commands.GetObjectSeen([target.id,actor.id]),flags&1);
    assert.equal(session.commands.GetObjectHeard([target.id,actor.id]),(flags>>>1)&1);
    results.push({source:target.sourceKey,id:target.id,flags,eventCodes:events.map(e=>e.event.payload.integers[0])});
  }catch(error){results.push({source:target.sourceKey,id:target.id,failure:error.message,diagnostics:runtimeDiagnostics.records.length-before});}
}
console.log(JSON.stringify({module:session.resolver.moduleName,actors:actors.length,results,
  failures:results.filter(r=>r.failure).length,limits:'Explicit native-owner calls; AI scheduling, effect transitions and original encounter outcomes remain unverified.'}));
assert.equal(results.filter(r=>r.failure).length,0,'Live native perception owners failed');
