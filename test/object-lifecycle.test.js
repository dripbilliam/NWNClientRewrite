import test from 'node:test';
import assert from 'node:assert/strict';
import {setObjectDestroyable} from '../src/object_lifecycle.js';
import {ModuleSession} from '../src/module_session.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';

test('destroyability defaults match constructor and wrapper defaults, with raw raiseable/selectable integers',async()=>{
  const s=new ModuleSession(null),o=s.register('placeable','p',{});
  assert.deepEqual([s.commands.GetIsDestroyable([o.id]),s.commands.GetIsRaiseable([o.id]),s.commands.GetIsSelectableWhenDead([o.id])],[1,0,0]);
  await s.commands.SetIsDestroyable([0],{self:o.id});assert.deepEqual([o.nativeDestroyableF0,o.nativeRaiseableF4,o.nativeSelectableWhenDeadF8],[0,1,0]);
  await s.commands.SetIsDestroyable([-4,-7,5,o.id]);assert.deepEqual([o.nativeDestroyableF0,o.nativeRaiseableF4,o.nativeSelectableWhenDeadF8],[1,-7,5]);
  assert.equal(s.commands.GetIsDestroyable([OBJECT_INVALID]),0);
});
test('enabling destroyability on a dead NPC unlocks first, then schedules canonical event11 at3000ms',async()=>{
  const trace=[],o={id:0x80000001,objectType:5,nativeField89c:0,lastDamagerId:7};
  const p={dead:()=>1,setLock:(...a)=>trace.push(['lock',a[1]]),possessedFamiliar:()=>0,enqueue:(...a)=>trace.push(['event',...a])};
  await setObjectDestroyable(o,1,3,4,p);assert.deepEqual(trace,[['lock',OBJECT_INVALID],['event',11,7,o.id,3000,null]]);
  assert.deepEqual([o.nativeRaiseableF4,o.nativeSelectableWhenDeadF8],[3,4]);
  for(const overrides of [{nativeField89c:1},{nativeField89c:0,possessed:1}]){
    trace.length=0;await setObjectDestroyable({...o,...overrides},1,1,0,{...p,possessedFamiliar:()=>overrides.possessed??0});assert.deepEqual(trace,[['lock',OBJECT_INVALID]]);
  }
  trace.length=0;await setObjectDestroyable(o,0,1,0,p);assert.deepEqual(trace,[]);
});
test('missing corpse ownership fails after the native destroyability and lock writes, before final flag writes',async()=>{
  const o={objectType:5,nativeRaiseableF4:9,nativeSelectableWhenDeadF8:8},trace=[];
  await assert.rejects(setObjectDestroyable(o,1,1,0,{dead:()=>1,setLock:()=>trace.push('lock')}),/field89c/);
  assert.equal(o.nativeDestroyableF0,1);assert.equal(o.nativeRaiseableF4,9);assert.equal(o.nativeSelectableWhenDeadF8,8);assert.deepEqual(trace,['lock']);
});
