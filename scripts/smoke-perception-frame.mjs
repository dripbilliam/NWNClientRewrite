// Uses the authored oracle module and live AI/heartbeat/perception/event loop.
// Target phase positions are replayed from the original log; script-driven
// JumpToLocation and original microsecond/RNG replay remain outside this check.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
const [install,fixture='backups/native-perception-oracle/home/modules/codex_perception_oracle.mod']=process.argv.slice(2);
if(!install)throw new Error('Usage: node scripts/smoke-perception-frame.mjs <install> [authored fixture]');
const original=JSON.parse(await fs.readFile('backups/animations/native-perception-oracle-observations.json','utf8'));
const session=await new ModuleSession(await openLocalModule(install,fixture),{runStartupScripts:true}).initialize([]);
const observer=session.byTag('po_observer')[0],target=session.byTag('po_target')[0];assert.ok(observer&&target);
// The original fixture requests script AI4, which the engine clamps to3 and
// locks. Replay that supported setup, without seeding visibility/cache flags.
for(const object of [observer,target]){session.commands.SetAILevel([object.id,4]);object.scripts={};}
session.started=true;
const results=[],dispatch=session.dispatch.bind(session);
session.dispatch=async queued=>{
  await dispatch(queued);
  if(queued.targetId===observer.id&&queued.event.type==='combatAI'&&queued.event.eventId===10){
    results.push({code:queued.event.payload.integers[0],seen:session.commands.GetObjectSeen([target.id,observer.id]),heard:session.commands.GetObjectHeard([target.id,observer.id])});
    assert.equal(session.commands.GetLastPerceived([],{self:observer.id}),target.id);
  }
};
for(let milliseconds=0;milliseconds<=32000;milliseconds+=100){
  if(milliseconds===12000||milliseconds===25000)session.setPosition(target,[45,0,-5]);
  if(milliseconds===18000)session.setPosition(target,[6,0,-5]);
  session.scheduler.advance(milliseconds===0?0:100);await session.scheduler.pump();
}
assert.deepEqual(results,original.metadata.events);
assert.equal(observer.nativeAILevel7c,3);assert.equal(observer.nativeAILocked80,1);
assert.deepEqual(session.diagnostics,[]);
console.log(JSON.stringify({comparedEvents:results.length,events:results,observerLevel:observer.nativeAILevel7c,
  aiDurationSamples:session.aiMaster.durations,limits:'Live loop and original gain/loss/flags agree; target movement replayed manually, script bodies omitted. No original RNG, microsecond timing, stealth/effect/encounter parity claim.'}));
