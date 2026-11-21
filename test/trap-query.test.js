import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {appendLoadedTrap} from '../src/trap_query.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';

function fixture(){
  const s=new ModuleSession(null),area=s.register('area','area',{}),actor=s.register('creature','actor',{areaId:area.id,position:[0,0,0]});
  const create=(kind,name,authored,position)=>{const o=s.register(kind,name,{areaId:area.id,position,authored});appendLoadedTrap(area,o);return o;};
  return {s,area,actor,create};
}
test('native trap import uses trigger Type2, BYTEasBOOL flags and physical door/placeable/trigger order',()=>{
  const {s,area,create}=fixture();
  const door=create('door','d',{TrapFlag:2,TrapActive:0,TrapDetectable:0},[3,0,0]),place=create('placeable','p',{TrapFlag:1},[3,0,0]),trigger=create('trigger','t',{Type:2,TrapFlag:0},[3,0,0]);
  const ordinary=create('trigger','ordinary',{Type:1,TrapFlag:1},[0,0,0]),truncated=create('door','truncated',{TrapFlag:256},[0,0,0]);
  assert.deepEqual([...area.nativeTrapIds158.view()],[door.id,place.id,trigger.id]);
  for(const o of [door,place,trigger])assert.equal(s.commands.GetIsTrapped([o.id]),1);
  for(const o of [ordinary,truncated])assert.equal(s.commands.GetIsTrapped([o.id]),0);
});
test('nearest trap checks exact detected flag1 and canonical known IDs; ties retain live physical list order',()=>{
  const {s,area,actor,create}=fixture();
  const a=create('door','a',{TrapFlag:1},[3,0,0]),b=create('placeable','b',{TrapFlag:1},[-3,0,0]),c=create('trigger','c',{Type:2},[0,4,0]);
  const get=n=>s.commands.GetNearestTrapToObject([actor.id,n]);
  assert.equal(get(1),OBJECT_INVALID);assert.equal(get(0),a.id);assert.equal(get(2),a.id);assert.equal(get(-1),a.id);
  b.nativeTrapKnownIds.append(actor.id);c.nativeTrapKnownIds.append(actor.id);
  assert.equal(get(1),b.id);a.nativeTrapKnownIds.append(actor.id);assert.equal(get(1),a.id);
  // A disarmed live entry is still considered until its owning event removes
  // it from the area list; the query does not recheck TrapFlag or area pointers.
  a.trapped=0;a.areaId=OBJECT_INVALID;assert.equal(get(0),a.id);
  s.unregister(a.id);assert.equal(get(1),b.id);
  area.nativeTrapIds158.remove(b.id);assert.equal(get(1),c.id);
});
test('trap squared radius is strictly below10000 and stale IDs are skipped',()=>{
  const {s,area,actor,create}=fixture();area.nativeTrapIds158.append(123456);
  const o=create('door','boundary',{TrapFlag:1},[100,0,0]);
  assert.equal(s.commands.GetNearestTrapToObject([actor.id,0]),OBJECT_INVALID);
  o.position[0]=99.99999;assert.equal(s.commands.GetNearestTrapToObject([actor.id,0]),o.id);
  assert.equal(s.commands.GetNearestTrapToObject([OBJECT_INVALID,0]),OBJECT_INVALID);
});
