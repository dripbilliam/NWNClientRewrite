import test from 'node:test';
import fs from 'node:fs';
import assert from 'node:assert/strict';
import {destroyCreature,destroyItem,destroyRepository,destroyEquipment,destroyBaseObject} from '../src/object_destruction.js';
import {ItemRepository} from '../src/item_repository.js';
import {createObjectActionState,addObjectAction,disposeObjectAction} from '../src/object_actions.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-destruction-observations.json',import.meta.url)));

test('base destruction matches native registry-first disposal without action cancellation or effect removal',async()=>{
 const observations=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-base-destruction-observations.json',import.meta.url)));
 for(const row of observations.rows){
  const c=row.case,calls=[],actor={id:99,areaId:c.area?88:OBJECT_INVALID,effects:c.effects.map(id=>id===null?null:{id}),objectActionState:createObjectActionState()};
  for(const [n,type]of c.actions.entries()){const value=type===4?new Uint8Array([65]):type===5?{id:n+1}:n+1;const node=addObjectAction(actor.objectActionState,30,65535,[{type,value}]);node.nativeField9c=c.ready;}
  await destroyBaseObject(actor,{releaseLocal:()=>{},area:()=>{calls.push(['area']);return actor.areaId===88?{}:null;},removeAreaObject:(_a,id)=>calls.push(['removeArea',id]),
   removeRegistry:o=>calls.push(['registry',o.id]),disposeEffect:e=>calls.push(['effect',e.id]),disposeAction:node=>disposeObjectAction(node,situation=>calls.push(['situation',situation.id]))});
  const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);assert.equal(actor.areaId,row.areaId,label);assert.equal(actor.effects.length,row.effectCount,label);assert.equal(actor.objectActionState.list.count,row.actions,label);
 }
});

test('creature and item destructor phases match original ownership and parent ordering',async()=>{
 for(const [kind,rows]of [['creature',native.creatures],['item',native.items]])for(const row of rows){
  const c=row.case,calls=[],actor={id:99,masterId:c.master?100:OBJECT_INVALID,chairId:c.chair?101:OBJECT_INVALID,areaId:c.area?88:OBJECT_INVALID},chair={nativeOccupant36c:99};
  for(const key of ['stats','path','round','repository','equipment'])actor[key]=c[key]?{}:null;
  const p={creature:id=>{calls.push(['creature',id]);return c.masterExists===false?null:{};},removeAssociate:(_o,id)=>calls.push(['associate',id]),
   placeable:id=>{calls.push(['placeable',id]);return c.chairExists===false?null:chair;},area:o=>{calls.push(['area']);return o.areaId===88?{}:null;},
   removeCreatureArea:(o,n)=>{calls.push(['removeArea',n]);o.areaId=OBJECT_INVALID;},removeItemArea:o=>{calls.push(['removeArea',null]);o.areaId=OBJECT_INVALID;},
   releaseLocal:(o,key)=>{if(['stats','path','round'].includes(key)&&o[key])calls.push([key]);if(['stats','path','round','repository','equipment'].includes(key))o[key]=null;},
   removeAI:()=>calls.push(['ai']),module:()=>{calls.push(['module']);return c.module===false?null:{};},removeTag:o=>calls.push(['tag',o.id]),
   repository:o=>o.repository,destroyRepository:()=>calls.push(['repository']),equipment:o=>o.equipment,destroyEquipment:()=>calls.push(['equipment']),
   clearAutoMap:()=>calls.push(['autoMap']),destroyBase:()=>calls.push(['base'])};
  if(kind==='creature')await destroyCreature(actor,p);else await destroyItem(actor,p);
  const label=JSON.stringify({kind,...c});assert.deepEqual(calls,row.calls,label);assert.equal(actor.areaId,row.areaId,label);
  if(kind==='creature'){assert.equal(actor.chairId,row.chair,label);assert.equal(chair.nativeOccupant36c,row.occupant,label);assert.deepEqual(Object.fromEntries(['stats','path','round','repository','equipment'].map(key=>[key,Number(Boolean(actor[key]))])),row.fields,label);}
 }
});

test('repository and18 equipment slots destroy canonical objects in native physical order',async()=>{
 for(const [kind,rows]of [['repository',native.repositories],['equipment',native.equipment]])for(const row of rows){
  const c=row.case,calls=[],objects=new Map([100,101].map(id=>[id,{id}])),p={object:id=>{calls.push(['object',id]);return objects.get(id)??null;},
   item:id=>{calls.push(['item',id]);return objects.get(id)??null;},destroy:(o,flag)=>{calls.push(['destroy',o.id,flag]);objects.delete(o.id);}};
  if(kind==='repository'){
   const repo=new ItemRepository(99,10,10,100,0,()=>{});for(const id of [...c.ids].reverse())repo.insertHead(id);
   await destroyRepository(repo,p);assert.deepEqual([...repo.ids()],row.ids);
  }else{const equipment={ids:[...c.ids,...Array(18).fill(OBJECT_INVALID)].slice(0,18)};await destroyEquipment(equipment,p);assert.deepEqual(equipment.ids,row.slots);}
  assert.deepEqual(calls,row.calls,JSON.stringify({kind,...c}));
 }
});
