import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
const [install,fixture='backups/native-perception-oracle/home/modules/codex_perception_oracle.mod',
  logPath='backups/native-perception-oracle/home/logs/nwserverLog1.txt']=process.argv.slice(2);
if(!install)throw new Error('Usage: node scripts/verify-perception-oracle.mjs <install> [authored fixture] [original server log]');
const bytes=await fs.readFile(fixture),log=await fs.readFile(logPath,'utf8');
const lines=log.split(/\r?\n/).filter(line=>line.startsWith('PERCEPTION_ORACLE '));
const native=lines.filter(line=>line.startsWith('PERCEPTION_ORACLE NOTICE ')).map(line=>{
  const get=key=>{const match=line.match(new RegExp(`(?:^| )${key}=(\\d+)(?: |$)`));assert.ok(match,`${key}: ${line}`);return Number(match[1]);};
  const fields=['heard','seen','inaudible','vanished'].map(get);assert.equal(fields.filter(Boolean).length,1);
  const code=fields[0]?0:fields[1]?2:fields[2]?1:3;
  return{code,seen:get('cached_seen'),heard:get('cached_heard')};
});
assert.ok(native.length>=8,'Original native run has not completed four transitions');
const session=await new ModuleSession(await openLocalModule(install,fixture),{runStartupScripts:false}).initialize([]);
const actor=session.byTag('po_observer')[0],target=session.byTag('po_target')[0];assert.ok(actor&&target);
const replacement=[];
for(const x of [6,45,6,45]){
  session.setPosition(target,[x,0,-5]);
  await session.combat.updateVisibility(actor);
  const events=session.scheduler.events.filter(e=>e.targetId===actor.id&&e.event.type==='combatAI'&&e.event.eventId===10);
  for(const e of events){
    // Invoke the mapped event owner, replacing only script execution with
    // an observation hook. The native event slots and cached flags are read
    // through the same NWScript accessors as the original fixture script.
    const name=actor.scripts.perception;actor.scripts.perception='';
    try{await session.combat.dispatchEvent(actor,e.event);}finally{actor.scripts.perception=name;}
    replacement.push({code:e.event.payload.integers[0],seen:session.commands.GetObjectSeen([target.id,actor.id]),heard:session.commands.GetObjectHeard([target.id,actor.id])});
    assert.equal(session.commands.GetLastPerceived([],{self:actor.id}),target.id);
  }
  session.scheduler.events=session.scheduler.events.filter(e=>!events.includes(e));
}
assert.deepEqual(replacement,native.slice(0,8));
const metadata={fixtureSha256:createHash('sha256').update(bytes).digest('hex'),nativeEventCount:native.length,
  comparedEvents:replacement.length,events:replacement,limits:'Normal nonstealthed NPC gain/loss order and flags only. Original RNG seed and AI scheduling are not replayed; stealth, effects, indoor sound and combat encounters remain separate gates.'};
await fs.writeFile('backups/animations/native-perception-oracle-observations.json',JSON.stringify({metadata,lines},null,2)+'\n');
console.log(JSON.stringify(metadata));
