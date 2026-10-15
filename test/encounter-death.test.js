import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {removeEncounterActiveCreature} from '../src/encounter_activation.js';
import {dispatchSubareaEvent} from '../src/subarea_events.js';
test('encounter death accounting agrees with144 full native pool, flag, exhaustion and clock traces',async()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-encounter-death-observations.json',import.meta.url)));assert.equal(oracle.observations.length,144);
  for(const row of oracle.observations){const c=row.case,calls=[],o={id:77,nativeEncounterSpawned340:c.count,nativeEncounterActivePool3c8:c.active,nativeEncounterPool3c4:5,
    nativeEncounterReset324:c.reset,nativeEncounterActive320:1,nativeEncounterStarted354:1,nativeEncounterLastSpawn34c:{day:12,time:34},nativeEncounterCreatures390:[1,2,3].map(n=>({used:n,visited:n+1}))};
    await removeEncounterActiveCreature(o,.5,c.flag,{points:(_o,cr)=>{calls.push(['points',cr]);return .75;},exhaustedEvent:()=>{assert.equal(o.nativeEncounterActive320,1,'script queues before disabling');calls.push(['object',0,77],['event',0,0,77,77,10,21]);},worldTime:()=>{calls.push(['time']);return{day:42,time:5000};}});
    assert.deepEqual({calls,count:o.nativeEncounterSpawned340,active:o.nativeEncounterActivePool3c8,pool:o.nativeEncounterPool3c4,enabled:o.nativeEncounterActive320,started:o.nativeEncounterStarted354,lastSpawn:o.nativeEncounterLastSpawn34c,entries:o.nativeEncounterCreatures390.map(e=>[e.used,e.visited])},
      {calls:row.calls,count:row.count,active:row.active,pool:row.pool,enabled:row.enabled,started:row.started,lastSpawn:row.lastSpawn,entries:row.entries},JSON.stringify(c));
  }
});
test('encounter exhaustion dispatch runs slot3 without changing entering/leaving histories',async()=>{
  const o={objectType:13,nativeEncounterLastEntered3cc:8,nativeEncounterLastLeft3d0:9,eventObjects:{entering:8,exiting:9}},calls=[];
  await dispatchSubareaEvent(o,10,{scriptEvent:21,objectIds:[77]},{runScript:(object,index)=>calls.push([object,index])});
  assert.deepEqual(calls,[[o,3]]);assert.equal(o.nativeEncounterLastEntered3cc,8);assert.equal(o.nativeEncounterLastLeft3d0,9);assert.deepEqual(o.eventObjects,{entering:8,exiting:9});
});
