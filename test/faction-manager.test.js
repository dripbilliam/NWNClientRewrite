import test from 'node:test';
import assert from 'node:assert/strict';
import {NativeFactionManager,initializeCreatureFaction} from '../src/faction_manager.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';

const fixture=()=>{
  const manager=new NativeFactionManager();manager.createDefaults();const objects=new Map(),trace=[];
  const p={creature:id=>objects.get(id)??null,pc:o=>o.pc,statsPC:o=>o.statsPC,possessed:o=>o.possessed,dm:o=>o.dm,
    client:id=>objects.get(id)?.client??null,bringAssociates:(o,n)=>trace.push(['associates',o.id,n]),
    warning:message=>trace.push(['warning',message]),setLikes:(o,id,a,b)=>trace.push(['likes',o.id,id,a,b]),
    attitude:(a,b,value)=>trace.push(['attitude',a.object.id,b.object.id,value]),
    partyList:(c,ids,type,subject)=>trace.push(['party',c.object.id,[...ids],type,subject]),
    reprocessAssociates:o=>trace.push(['reprocess',o.id]),autoParty:o=>trace.push(['autoParty',o.id])};
  const add=(id,pc=0)=>{const o={id,pc,statsPC:pc,possessed:0,dm:0,factionId:-1,masterId:OBJECT_INVALID};if(pc)o.client={object:o};objects.set(id,o);return o;};
  return {manager,objects,trace,p,add};
};
test('native faction slots grow 16 then 32, retain holes and preserve FAC physical order and default-pointer differences',()=>{
  const m=new NativeFactionManager();m.load(Array.from({length:17},(_,i)=>({FactionName:`F${16-i}`,FactionParentID:i-1,FactionGlobal:i===1?2:undefined})));
  assert.equal(m.count,17);assert.equal(m.capacity,32);assert.equal(m.npcCount,16);
  assert.equal(m.defaultCommoner.id,2);assert.equal(m.defaultDefender.id,4);assert.equal(m.get(1).global,2);assert.equal(m.get(0).parentId,0xffffffff);
  m.delete(7);const next=m.create();assert.equal(next.id,17);assert.equal(m.get(7),null);assert.equal(m.get(-1),null);assert.equal(m.get(18),null);
  assert.equal(m.get(0).name,'F16');assert.equal(m.defaultPC,null);
  const d=new NativeFactionManager();d.createDefaults();assert.equal(d.defaultCommoner.id,4);assert.equal(d.defaultDefender.id,3);
  assert.equal('parentId' in d.get(0),false);assert.equal(d.isNPC(0),false);assert.equal(d.isNPC(4),true);assert.equal(d.isNPC(5),false);
});
test('PostProcess registers NPC IDs in admission order, imports valid originals and routes invalid factions to Hostile',async()=>{
  const {manager,p,add,trace}=fixture(),a=add(0x80000002),b=add(1),c=add(0xffffffff);
  a.factionId=2;b.factionId=2;c.factionId=0;c.originalFactionId=123;
  await initializeCreatureFaction(a,manager,p);await initializeCreatureFaction(b,manager,p);await initializeCreatureFaction(c,manager,p);
  assert.deepEqual([...manager.get(2).members.view()],[a.id,b.id]);assert.equal(a.originalFactionId,2);assert.equal(b.originalFactionId,2);
  assert.equal(c.factionId,1);assert.equal(c.originalFactionId,123);assert.equal(manager.count,5);
  assert.deepEqual(trace,[['associates',a.id,2],['associates',b.id,2],['associates',c.id,1]]);
});
test('PC private constructors are registered factions; GetFaction identity suppresses even a missing member repair',async()=>{
  const {manager,p,add,trace}=fixture(),a=add(0x80000001,2);a.factionId=65535;
  await initializeCreatureFaction(a,manager,p);assert.equal(a.factionId,5);assert.equal(a.originalFactionId,5);assert.equal(manager.npcCount,4);
  assert.deepEqual([...manager.members(a).view()],[a.id]);assert.deepEqual(trace,[['associates',a.id,5],['reprocess',a.id],['autoParty',a.id]]);
  manager.members(a).remove(a.id);trace.length=0;await manager.addMember(manager.get(5),a.id,0,p);
  assert.equal(manager.members(a).count,0);assert.deepEqual(trace,[]);
});
test('party transfer preserves the native intermediate private faction and both attitude messages before updates',async()=>{
  const {manager,p,add,trace}=fixture(),a=add(1,1),b=add(0x80000002,1);
  await initializeCreatureFaction(a,manager,p);await initializeCreatureFaction(b,manager,p);trace.length=0;
  await manager.addMember(manager.get(a.factionId),b.id,0,p);
  assert.equal(b.factionId,5);assert.equal(manager.count,8);assert.equal(manager.get(6),null);
  assert.deepEqual([...manager.get(7).members.view()],[b.id]);assert.deepEqual([...manager.get(5).members.view()],[a.id,b.id]);
  assert.deepEqual(trace,[['associates',b.id,7],['party',b.id,[b.id],1,b.id],['likes',b.id,a.id,1,1],
    ['attitude',b.id,a.id,1],['attitude',a.id,b.id,1],['party',a.id,[b.id],3,a.id],
    ['associates',b.id,5],['party',b.id,[a.id,b.id],1,b.id]]);
});
test('RemoveMember skips likes for a departing master, preserves member capacity, then sends the private list and removal',async()=>{
  const {manager,p,add,trace}=fixture(),a=add(1,1),b=add(2,1);
  await initializeCreatureFaction(a,manager,p);await initializeCreatureFaction(b,manager,p);
  await manager.addMember(manager.get(a.factionId),b.id,1,p);a.masterId=b.id;trace.length=0;
  const party=manager.get(a.factionId),capacity=party.members.capacity;
  await manager.removeMember(party,b.id,p);
  assert.equal(party.members.capacity,capacity);assert.deepEqual([...party.members.view()],[a.id]);assert.equal(b.factionId,8);
  assert.deepEqual(trace,[['attitude',b.id,a.id,1],['attitude',a.id,b.id,1],['associates',b.id,8],
    ['party',b.id,[b.id],1,b.id],['party',a.id,[b.id],4,OBJECT_INVALID]]);
  trace.length=0;await manager.removeMember(party,b.id,p);assert.deepEqual(trace,[]);
});
test('native AddMember loops use live members after awaited sends; missing owners fail explicitly',async()=>{
  const {manager,p,add,trace}=fixture(),a=add(1,1),b=add(2),c=add(3);
  await initializeCreatureFaction(a,manager,p);const party=manager.get(a.factionId);
  p.partyList=async(client,ids,type,subject)=>{trace.push(['party',client.object.id,[...ids],type,subject]);if(type===3){party.members.append(c.id);c.factionId=party.id;}};
  await manager.addMember(party,b.id,0,p);assert.deepEqual([...party.members.view()],[a.id,c.id,b.id]);
  const x=add(4,1);await initializeCreatureFaction(x,manager,p);
  await assert.rejects(manager.addMember(party,x.id,0,{...p,setLikes:undefined}),/provider setLikes/);
  await assert.rejects(initializeCreatureFaction({...x,dm:1},manager,p),/DM PostProcess/);
});
