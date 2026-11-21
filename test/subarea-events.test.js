import test from 'node:test';
import assert from 'node:assert/strict';
import { dispatchSubareaEvent } from '../src/subarea_events.js';
import { encounterGeometry } from '../src/trigger_geometry.js';
import { OBJECT_INVALID } from '../src/game_object_array.js';

test('trigger script events distinguish AI ID10 from payload12/13 and set canonical actor at dispatch', async () => {
  const target = { id: 1, objectType: 7, eventObjects: {} }, calls = [];
  const p = { runScript: (o, slot) => calls.push([slot, {...o.eventObjects}]) };
  await dispatchSubareaEvent(target, 12, {scriptEvent:12,objectIds:[0x80000001]}, p);
  assert.deepEqual(calls, []);
  await dispatchSubareaEvent(target, 10, {scriptEvent:12,objectIds:[0x80000001]}, p);
  await dispatchSubareaEvent(target, 10, {scriptEvent:13}, p);
  assert.deepEqual(calls, [[1,{entering:0x80000001}],[2,{entering:0x80000001,exiting:OBJECT_INVALID}]]);
});
test('trap entry uses default integer0 and suppresses ordinary enter; exit script depends on trap firing query', async () => {
  const target = {id:1,objectType:7,authored:{TrapFlag:1}}, calls = [];
  const p = {enterTrap:(o,flag)=>calls.push(['trap',flag]),canFireTrap:(o,id,flag)=>{calls.push(['canFire',id,flag]);return 0;},runScript:()=>calls.push('script')};
  await dispatchSubareaEvent(target,10,{scriptEvent:12,objectIds:[2]},p);
  await dispatchSubareaEvent(target,10,{scriptEvent:13,objectIds:[2]},p);
  assert.deepEqual(calls,[['trap',0],['canFire',2,0]]);
  p.canFireTrap=()=>1;
  await dispatchSubareaEvent(target,10,{scriptEvent:13,objectIds:[2]},p);
  assert.equal(calls.at(-1),'script');
  await assert.rejects(dispatchSubareaEvent(target,10,{scriptEvent:12},{runScript:()=>assert.fail()}),/enterTrap/);
});
test('encounter dispatch preserves configurable enter/tally order and refreshes activation before exit', async () => {
  for(const before of [0,1]){
    const target={id:3,objectType:13},calls=[];
    await dispatchSubareaEvent(target,10,{scriptEvent:12,objectIds:[2]}, {
      encounterEnterBeforeSpawn:()=>before,activateEncounter:(o,id,flag)=>calls.push(['spawn',id,flag]),runScript:(o,slot)=>calls.push(['script',slot,o.eventObjects.entering]),
    });
    assert.deepEqual(calls,before?[['script',0,2],['spawn',2,-1]]:[['spawn',2,-1],['script',0,2]]);
    await dispatchSubareaEvent(target,10,{scriptEvent:13,objectIds:[2]}, {
      updateEncounterActivation:(o,id)=>calls.push(['refresh',id]),runScript:(o,slot)=>calls.push(['script',slot,o.eventObjects.exiting]),
    });
    assert.deepEqual(calls.slice(-2),[['refresh',OBJECT_INVALID],['script',1,2]]);
    assert.equal(target.nativeEncounterLastEntered3cc,2);assert.equal(target.nativeEncounterLastLeft3d0,2);
  }
});
test('encounter geometry uses local X/Y and native f32 position addition; absent and empty Geometry differ',()=>{
  assert.deepEqual(encounterGeometry({XPosition:4,YPosition:5,Geometry:[{X:1,Y:2,PointX:99,PointY:99},{}]}),[[5,7],[4,5]]);
  assert.deepEqual(encounterGeometry({}),[]);
  assert.throws(()=>encounterGeometry({Geometry:[]}),/no vertices/);
});
