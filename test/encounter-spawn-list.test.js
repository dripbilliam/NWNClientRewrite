import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {makeEncounterSpawnList,padEncounterSpawnCount,splitEncounterSpawnEntry} from '../src/encounter_spawn_list.js';
const fromNative=e=>({...e,resRef:e.id,cr:Math.fround(e.cr),points:Math.fround(e.points)});
const toNative=e=>({id:e.resRef,cr:e.cr,points:e.points,used:e.used,visited:e.visited,single:e.single});
test('spawn selection, grouped RNG, padding and cheaper replacement match full original owners',()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-encounter-spawn-list-observations.json',import.meta.url)));
  assert.equal(capture.observations.length,3024);
  for(const row of capture.observations){const c=row.case,out=c.initial.map(fromNative),o={nativeEncounterCreatures390:c.entries.map(fromNative),nativeEncounterMaximum33c:c.maximum,nativeEncounterRecommended338:c.recommended,
    nativeEncounterSpawned340:c.spawned,nativeEncounterPool3c4:Math.fround(c.pool),nativeEncounterActivePool3c8:Math.fround(c.activePool),nativeEncounterMinimumPoints3bc:Math.fround(c.minimum)};let draws=0;
    const p={random:()=>c.random[draws++%c.random.length],points:(_o,cr)=>o.nativeEncounterCreatures390.find(e=>e.cr===cr)?.points??Math.fround(1.5**cr)};
    if(!row.completed){assert.throws(()=>c.mode==='make'?makeEncounterSpawnList(o,out,p):padEncounterSpawnCount(o,out,p),/action budget/);continue;}
    if(c.mode==='make')makeEncounterSpawnList(o,out,p);else if(c.mode==='pad')padEncounterSpawnCount(o,out,p);else splitEncounterSpawnEntry(o,out,c.index,fromNative(c.chosen),p);
    assert.deepEqual({out:out.map(toNative),entries:o.nativeEncounterCreatures390.map(toNative),draws},{out:row.out,entries:row.entries,draws:row.draws},JSON.stringify(c));
  }
});
