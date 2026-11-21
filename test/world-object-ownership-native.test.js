import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeWorldObjectOwnership} from '../src/world_object_state.js';
import {destroyPlaceable,destroyStore,destroyWaypoint} from '../src/object_destruction.js';
import {ItemRepository} from '../src/item_repository.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-world-object-ownership-observations.json',import.meta.url)));

test('world constructors match original repository allocation, direct owner IDs, AI order and state cells',()=>{
 for(const row of data.rows.filter(r=>r.mode==='construct')){
  const calls=[],o={id:row.id,objectType:{placeable:9,store:14,waypoint:12}[row.kind],nativeAILevel7c:-1};
  initializeWorldObjectOwnership(o,{setAILevel:(o,level)=>{calls.push(['ai',o.id,level]);o.nativeAILevel7c=level;},repository:(...args)=>{calls.push(['repository',...args]);return new ItemRepository(...args);}},row.case.requestedId);
  const label=JSON.stringify({kind:row.kind,...row.case});assert.deepEqual(calls,row.calls,label);assert.equal(o.nativeAILevel7c,row.aiLevel,label);
  const repository=r=>({ownerId:r.ownerId,width:r.width,height:r.height,boundary:r.boundary,expand:r.expand});
  if(row.kind==='placeable'){
   assert.deepEqual(repository(o.nativeRepository),row.repo,label);assert.equal(o.nativeCollisionSlot,row.slot,label);assert.equal(o.nativeStaticLoadOverride5a4,row.override,label);assert.equal(o.nativeField504,row.dieWhenEmpty,label);assert.equal(o.nativeOccupant36c,row.occupant,label);assert.equal(o.nativeEffectSpellId590,row.effectSpell,label);assert.deepEqual(o.nativePlaceableActionPoints550,row.points,label);
   assert.equal(o.nativeHasInventory4f8,undefined,'HasInventory is load-owned, not an invented constructor default');
   assert.deepEqual([o.nativeTrapType3d0,o.nativeTrapRecoverable3c8,o.nativeTrapActive3d4,o.nativeTrapFaction3d8,o.nativeGroundPile368,o.nativeBodyBag59c],row.loadDefaults,label);
  }else if(row.kind==='store'){
   assert.deepEqual(o.nativeStoreRepositories.map(repository),row.repos,label);assert.equal(o.nativeStoreClients350.length,row.clients,label);assert.deepEqual([o.nativeStoreEnumeration388,o.nativeStoreEnumeration38a],row.enumeration,label);
   assert.deepEqual([0x398,0x3a8].map(offset=>[0,o.nativeStoreBuyArrays[offset].values.length,o.nativeStoreBuyArrays[offset].capacity]),row.buyArrays,label);
  }else{assert.equal(o.nativeAnimationD8,row.animation,label);assert.deepEqual([o.nativeMessageFields[0x308],o.nativeMessageFields[0x30c]],row.mapFlags,label);}
 }
});

test('world destructors match original child, live client, area, AI and tag cleanup ordering',async()=>{
 for(const row of data.rows.filter(r=>r.mode==='destroy')){
  const c=row.case,calls=[],o={id:99,areaId:c.area?88:OBJECT_INVALID,nativeRepository:c.repo===false?null:{index:0},nativeStoreRepositories:(c.repos??Array(5).fill(true)).map((present,index)=>present?{index}:null),nativeStoreClients350:(c.clients??[]).map(id=>id===null?null:{playerId:id})},p={
   repository:o=>o.nativeRepository,storeRepositories:o=>o.nativeStoreRepositories,destroyRepository:r=>calls.push(['repository',r.index]),
   area:o=>{calls.push(['area']);return o.areaId===88?{}:null;},removePlaceableArea:o=>{calls.push(['removeArea','placeable']);o.areaId=OBJECT_INVALID;},removeWaypointArea:o=>{calls.push(['removeArea','waypoint']);o.areaId=OBJECT_INVALID;},
   removeAI:()=>calls.push(['ai']),module:()=>{calls.push(['module']);return c.module?{}:null;},removeTag:o=>calls.push(['tag',o.id]),releaseLocal:()=>{},destroyBase:()=>calls.push(['base']),
   removeAreaObject:(_a,id)=>calls.push(['removeObject',id]),setArea:o=>{calls.push(['setArea',null]);o.areaId=OBJECT_INVALID;},
   client:id=>{calls.push(['client',id]);return c.present?.includes(id)?{id}:null;},closeStore:(client,flag)=>{calls.push(['closeStore',client.id,flag]);if(c.mutate)o.nativeStoreClients350[0]=null;},releaseStoreClient:r=>calls.push(['freeClient',r.playerId]),
  };
  await({placeable:destroyPlaceable,store:destroyStore,waypoint:destroyWaypoint}[row.kind])(o,p);
  const label=JSON.stringify({kind:row.kind,...c});assert.deepEqual(calls,row.calls,label);assert.equal(o.areaId,row.areaId,label);
 }
 assert.equal(data.rows.length,408);
});
