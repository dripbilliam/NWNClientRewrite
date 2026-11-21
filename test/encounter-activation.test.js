import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {EncounterActivateList,calculateEncounterPoints,calculateEncounterPool,updateEncounterActivation,tallyEncounterEnemyPoints,spawnEncounterIfAppropriate} from '../src/encounter_activation.js';
import {inTrigger} from '../src/trigger_geometry.js';
test('encounter points, activation, tally and spawn admission match original full owners',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-encounter-activation-observations.json',import.meta.url)));
  assert.equal(capture.observations.length,995);
  for(const row of capture.observations){const c=row.case,calls=[],list=new EncounterActivateList();for(const id of c.initial)list.append(id);
    const o={id:77,nativeFractionalCR428:c.minima.map(Math.fround),nativeEncounterActivate360:list,nativeEncounterCanSpawn36c:9,nativeEncounterPlayerOnly434:c.playerOnly,nativeEncounterLastEntered3cc:c.lastEntered,
      nativeEncounterDifficulty330:c.difficulty,nativeEncounterAreaPoints3c0:Math.fround(c.areaPoints),nativeEncounterPool3c4:Math.fround(c.pool),nativeEncounterScore3ac:0,nativeEncounterActive320:c.active,nativeEncounterStarted354:c.started,
      nativeEncounterBounds:{minX:-2,maxX:2,minY:-2,maxY:2},geometry:[[-2,-2],[2,-2],[2,2],[-2,2]]};
    const actors=c.actors.map(a=>({...a,associateType:a.associate,masterId:a.master,nativeField89c:a.pc})),p={
      pow:(a,b)=>Math.fround(Math.pow(a,b)),pointTable:()=>Array.from({length:51},(_,n)=>Math.fround(1.5**n)),log:Math.log,alwaysReset:()=>c.option??0,
      area:()=>c.hasArea?{}:null,creature:id=>actors.find(o=>o.id===id),position:o=>o.point.map(Math.fround),spatialIds:()=>actors.map(a=>a.id),
      firstByX:(_a,x)=>{const n=actors.findIndex(a=>Math.fround(a.point[0])>=x);return n<0?null:n;},
      inside:(o,point)=>Number(inTrigger(o,[point[0],point[2],-point[1]])),reaction:o=>o.reaction,dead:o=>o.dead,dying:o=>o.dying,statsPC:o=>o.statsPC,
      officialCampaign:()=>c.campaign,classes:o=>o.classes,classInfo:id=>({effective:c.effective[id]}),possessed:o=>o.possessed,potentialLevel:o=>o.level,spawn:()=>calls.push(['spawn']),
    };
    let points=null;
    if(c.mode==='points')points=calculateEncounterPoints(o,c.cr,p);
    else if(c.mode==='pool')await calculateEncounterPool(o,c.cr,p);
    else if(c.mode==='activate')await updateEncounterActivation(o,c.enterer,p);
    else if(c.mode==='tally')await tallyEncounterEnemyPoints(o,p);
    else await spawnEncounterIfAppropriate(o,c.enterer,c.cr,p);
    assert.deepEqual({points,areaPoints:o.nativeEncounterAreaPoints3c0,pool:o.nativeEncounterPool3c4,score:o.nativeEncounterScore3ac,canSpawn:o.nativeEncounterCanSpawn36c,started:o.nativeEncounterStarted354,capacity:list.capacity,ids:[...list.view()],calls},
      {points:row.points,areaPoints:row.areaPoints,pool:row.pool,score:row.score,canSpawn:row.canSpawn,started:row.started,capacity:row.capacity,ids:row.ids,calls:row.calls},JSON.stringify(c));
  }
});
