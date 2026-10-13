import test from 'node:test';
import assert from 'node:assert/strict';
import { setLastHostileActor } from '../src/combat_hostile.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture() {
  const owner = { id:1, objectType:5, factionId:1, lastHostileActorId:99 }, actor = { id:2, objectType:5, factionId:2, hp:10 };
  const aoe = { id:3, objectType:11, creatorId:2 }, area = { pvp:0 }, objects = new Map([[1,owner],[2,actor],[3,aoe]]), trace = [];
  const p = { object:id=>objects.get(id), creature:id=>objects.get(id)?.objectType === 5 ? objects.get(id) : null,
    dead:c=>Number(Boolean(c.dead)), dm:c=>Number(Boolean(c.isDM)), hitPoints:c=>{trace.push('HP');return c.hp},
    area:()=>area, pvp:a=>a.pvp, faction:c=>c.factionId, warning:m=>trace.push(m) };
  return { owner,actor,aoe,area,objects,p,trace, set:(id,force=0)=>setLastHostileActor(owner,id,force,p) };
}
test('hostile lookup failure preserves history; existing self/noncreature/dead/DM clears it', () => {
  const { owner,actor,objects,set } = fixture(); set(123); assert.equal(owner.lastHostileActorId,99);
  set(1); assert.equal(owner.lastHostileActorId,invalid);
  owner.lastHostileActorId=99; objects.set(7,{id:7,objectType:9});set(7);assert.equal(owner.lastHostileActorId,invalid);
  actor.dead=true;set(2);assert.equal(owner.lastHostileActorId,invalid);
  actor.dead=false;actor.isDM=true;set(2);assert.equal(owner.lastHostileActorId,invalid);
  actor.isDM=false;set(2);assert.equal(owner.lastHostileActorId,2);
});
test('same-faction restricted PVP retains old history; unrestricted and missing areas assign', () => {
  const { owner,actor,area,p,set } = fixture();actor.factionId=1;set(2);assert.equal(owner.lastHostileActorId,99);
  area.pvp=1;set(2);assert.equal(owner.lastHostileActorId,99);area.pvp=2;set(2);assert.equal(owner.lastHostileActorId,2);
  owner.lastHostileActorId=99;area.pvp=0;p.area=()=>null;set(2);assert.equal(owner.lastHostileActorId,2);
});
test('PC HP is queried twice for dying veto; AoE creator-self path differs from direct-self path', () => {
  const { owner,actor,aoe,p,set,trace } = fixture();actor.isPC=true;actor.hp=0;set(2);
  assert.equal(owner.lastHostileActorId,invalid);assert.deepEqual(trace,['HP','HP']);
  actor.hp=-10;p.dead=()=>0;set(2);assert.equal(owner.lastHostileActorId,2); // Preserve native branch even with injected dead getter.
  aoe.creatorId=1;owner.factionId=9;p.area=()=>null;set(3);assert.equal(owner.lastHostileActorId,1);
  set(1);assert.equal(owner.lastHostileActorId,invalid);
});
test('forced non-invalid assignment warns but writes, exact-one plot and force gates remain distinct', () => {
  const { owner,set,trace } = fixture();owner.plot=true;set(2);assert.equal(owner.lastHostileActorId,invalid);
  set(2,1);assert.equal(owner.lastHostileActorId,2);assert.equal(trace.length,1);
  owner.plot=2;set(2,2);assert.equal(owner.lastHostileActorId,2);set(invalid,1);assert.equal(owner.lastHostileActorId,invalid);
});
