import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {spawnEncounterCreatures} from '../src/encounter_spawn.js';
const f=Math.fround;
test('full encounter spawning matches original list/placement latch, allocation, delivery and pool traces',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-encounter-spawn-observations.json',import.meta.url)));assert.equal(capture.observations.length,240);
  for(const row of capture.observations){const c=row.case,calls=[],actors=[],o={id:77,nativeEncounterMaximum33c:4,nativeEncounterRecommended338:c.recommended,nativeEncounterSpawned340:c.spawned,nativeEncounterPool3c4:f(c.pool),nativeEncounterActivePool3c8:f(c.activePool),nativeEncounterMinimumPoints3bc:f(c.minimum),nativeEncounterSpawnPoints3a0:c.spawnPoints,nativeEncounterLastEntered3cc:11};let safe=0,hidden=0;
    await spawnEncounterCreatures(o,{
      area:()=>c.hasArea?{}:null,makeList:(_o,out)=>{calls.push(['make']);out.push(...c.list);},splitEntry:(_o,_out,n,e)=>calls.push(['split',n,e.resRef]),padList:(_o,out)=>{calls.push(['pad']);while(out.length<c.recommended-c.spawned)out.push({resRef:9,cr:1,points:1});},
      creature:()=>c.entered?{point:[5,6,7]}:null,position:o=>o.point??[10,20,3],cos:a=>f(Math.cos(a)),sin:a=>f(Math.sin(a)),
      normalize:v=>{const length=f(Math.sqrt(f(f(f(v[0]*v[0])+f(v[1]*v[1]))+f(v[2]*v[2]))));return v.map(n=>f(n/length));},
      construct:()=>{const actor={id:101+actors.length,nativeField948:0,nativeField89c:0};actors.push(actor);calls.push(['construct',actor.id]);return actor;},loadTemplate:(o,id)=>{calls.push(['load',o.id,id]);return c.loaded;},warning:()=>calls.push(['warning']),destroy:o=>calls.push(['destroy',o.id]),
      safeLocation:(_a,point,range,_path,flag,out)=>{calls.push(['safe',point,range,flag]);out.point=[1,2,3];return c.safe[safe++%c.safe.length];},nonVisibleLocation:(_a,point,_path,flag,out,range)=>{calls.push(['hidden',point,flag,range]);const r=c.hidden[hidden++%c.hidden.length];out.point=r.point;return r.result;},
      height:(_a,point)=>{calls.push(['height',point.slice()]);return c.height;},addToArea:(o,_a,...args)=>calls.push(['area',o.id,...args]),setAILevel:(o,n)=>calls.push(['ai',o.id,n]),playerCount:()=>c.players,setOrientation:(o,point)=>calls.push(['orientation',o.id,point]),
    });
    assert.deepEqual({spawned:o.nativeEncounterSpawned340,pool:o.nativeEncounterPool3c4,activePool:o.nativeEncounterActivePool3c8,creatures:actors.map(o=>[o.id,o.nativeField948,o.nativeField89c]),calls},
      {spawned:row.spawned,pool:row.pool,activePool:row.activePool,creatures:row.creatures,calls:row.calls},JSON.stringify(c));
  }
});
