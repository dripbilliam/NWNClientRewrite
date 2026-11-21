import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {deathCleanupFlag,scheduleCorpseCleanup,receiveCorpseCleanup} from '../src/corpse_lifecycle.js';
const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-corpse-lifecycle-observations.json',import.meta.url)));
const actor=c=>({id:77,nativeField89c:c.pc,nativeDestroyableF0:c.destroyable,nativeNoPermDeath8bc:c.noPermDeath,nativeField771:c.field771,
  nativeLootable4e8:c.lootable,nativeDecayTime4ec:c.decay,nativeField948:c.encounterId,nativeField94c:c.removed,nativeChallengeRatingD0:1.25,associateType:c.associate});
test('death cleanup flag matches original raw integer0, BYTE field15 and destroyable/no-permanent-death gates',()=>{
  for(const row of oracle.flags)assert.equal(deathCleanupFlag(actor(row.case),row.case.spectacular),row.flag,JSON.stringify(row.case));
});
test('death scheduling matches original caller ID, unsigned decay, lootable, spectacular visual, PC and encounter order',async()=>{
  for(const row of oracle.schedules){const c=row.case,calls=[],o=actor(c);
    await scheduleCorpseCleanup(o,{creatorId:888},c.flag,17,{possessed:()=>{calls.push(['possessed']);return c.possessed;},spawnBag:()=>calls.push(['bag']),spectacularEffect:(_o,visual,context,flag)=>calls.push(['effect',30,0,visual,context,flag]),enqueue:(id,caller,target,delay,payload)=>calls.push(['event',id,caller,target,delay,payload]),encounter:id=>{calls.push(['encounter',id]);return c.encounter?{}:null;},removeActiveCount:(_e,...args)=>calls.push(['removeCount',...args]),playerDeath:()=>calls.push(['event',10,77,444,0,10])});
    assert.deepEqual({calls,removed:o.nativeField94c},{calls:row.calls,removed:row.removed},JSON.stringify(c));
  }
});
test('corpse cleanup event matches original exact-one gates, repeated possession, area observer cleanup and destruction ordering',async()=>{
  for(const row of oracle.events){const c=row.case,calls=[],o=actor(c),ids=[7,10,9,6,999],area={};
    await receiveCorpseCleanup(o,{possessed:()=>{calls.push(['possessed']);return c.possessed;},dead:()=>{calls.push(['dead']);return c.dead;},spawnBag:()=>calls.push(['bag']),removeFromArea:(_o,flag)=>calls.push(['removeArea',flag]),area:()=>{calls.push(['area']);return c.retainedArea?area:null;},trapCount:()=>ids.length,trapId:(_area,n)=>ids[n],object:id=>{calls.push(['object',id]);return id===999?null:{id,objectType:id};},removeTrapObserver:(o,id)=>calls.push(['removeObserver',o.id,id]),encounter:id=>{calls.push(['encounter',id]);return c.encounter?{}:null;},removeActiveCount:(_e,...args)=>calls.push(['removeCount',...args]),destroy:(_o,flag)=>calls.push(['destroy',flag])});
    assert.deepEqual({calls,removed:o.nativeField94c},{calls:row.calls,removed:row.removed},JSON.stringify(c));
  }
});
