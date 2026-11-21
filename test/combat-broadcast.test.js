import test from 'node:test';
import assert from 'node:assert/strict';
import { broadcastCombatState, broadcastBattleCry, broadcastAttackData, broadcastSavingThrow, sendCombatFeedback, receiveCombatFeedback, setExcitedState, removeCombatInvisibility } from '../src/combat_broadcast.js';
import { createAttackData } from '../src/combat_attack_data.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';
import { parse2da } from '../src/area.js';
import { ModuleSession } from '../src/module_session.js';
import { createCombatRound } from '../src/combat_round.js';

const actor=(id,x=0,extra={})=>({id,objectType:5,position:[x,0,0],areaId:8,plot:false,associateType:0,factionId:1,masterId:invalid,...extra});

test('native battle cry draws once per eligible client, rereading the live area list after delivery',async()=>{
  const a=actor(42),clients=new Map([[1,{object:actor(1,30)}],[2,{object:actor(2,31)}],
    [3,{object:actor(3,0,{areaId:9})}],[4,{object:actor(4)}],[5,{object:actor(5,0,{position:[0,31,0]})}]]);
  let ids=[1,2,3,4,5],draws=0;const trace=[];
  await broadcastBattleCry(a,{areaIds:()=>ids,client:id=>clients.get(id),random:{next:()=>draws++},
    voice:(c,id,code)=>{trace.push([c.object.id,id,code]);if(c.object.id===1)ids=[1,5,3,4];}});
  assert.deepEqual(trace,[[1,42,1],[4,42,2]]);assert.equal(draws,2);
  await broadcastBattleCry(a,{areaIds:()=>null,client:()=>assert.fail(),voice:()=>assert.fail()});
});
test('party combat activation reads IDs from the live faction list after callback mutation',async()=>{
  const a=actor(1),b=actor(2),c=actor(3),objects=new Map([a,b,c].map(o=>[o.id,o])),trace=[];
  let ids=[1,2];
  await broadcastCombatState(a,{members:()=>ids,client:id=>({object:objects.get(id)}),excited:o=>{trace.push(o.id);if(o===a)ids=[1,3];}});
  assert.deepEqual(trace,[1,3]);assert.equal(b.nativeField700,undefined);assert.equal(c.nativeField700,1);
});
test('party combat activation uses inclusive 30-unit sphere, area and actual clients; plot still marks self',async()=>{
  const source=actor(1),boundary=actor(2,30),outside=actor(3,30.001),otherArea=actor(4,0,{areaId:9}),npc=actor(5),excited=[];
  const objects=new Map([source,boundary,outside,otherArea,npc].map(o=>[o.id,o]));
  const p={members:()=>[1,2,3,4,5],client:id=>id===5?null:{object:objects.get(id)},excited:(o,n)=>excited.push([o.id,n])};
  await broadcastCombatState(source,p);assert.deepEqual(excited,[[1,1],[2,1]]);assert.equal(boundary.nativeField704,8000);
  for(const o of [outside,otherArea,npc])assert.equal(o.nativeField700,undefined);
  source.plot=true;excited.length=0;await broadcastCombatState(source,p);assert.equal(source.nativeField700,1);assert.equal(excited.length,0);
});

test('attack broadcast admits either endpoint faction/range, DM and associate7/8, excluding other areas',async()=>{
  const target=actor(1),caller=actor(2,70,{factionId:2}),viewers=[actor(3,25),actor(4,75,{factionId:2}),actor(5,25,{factionId:3,isDM:true}),
    actor(6,25,{factionId:3,associateType:7}),actor(7,25,{factionId:3,associateType:8}),actor(8,25,{factionId:3}),actor(9,25,{areaId:9}),actor(10,40),actor(11,35)];
  const deliveries=[],data=createAttackData();data.attackType=39;data.result=4;data.roll=7;
  const p={clients:()=>viewers.map(object=>({object})),faction:o=>o.factionId,dm:o=>Number(Boolean(o.isDM)),send:(c,type,msg,d)=>deliveries.push([c.object.id,type,msg,d])};
  await broadcastAttackData(target,caller,caller.id,data,p);assert.deepEqual(deliveries.map(x=>x.slice(0,2)),[[3,6],[4,6],[5,6],[6,6],[7,6],[10,6]]);
  assert.deepEqual(deliveries[0][2].objects,[2,1]);assert.notEqual(deliveries[0][3],data);assert.equal(deliveries[0][3].roll,7);
  data.roll=9;assert.equal(deliveries[0][3].roll,7);
  for(const type of [0,65002]){deliveries.length=0;data.attackType=type;await broadcastAttackData(target,caller,2,data,p);assert.equal(deliveries[0][1],5);}
  data.attackType=39;data.coupDeGrace=1;deliveries.length=0;await broadcastAttackData(target,caller,2,data,p);assert.equal(deliveries[0][1],5);
});

test('save delivery sends to nearby master and direct client, preserving native duplicate recipients and distant direct delivery',async()=>{
  const a=actor(1,0,{masterId:2}),master=actor(2,30),sent=[];
  const p={ownerId:o=>o.masterId,client:id=>({object:id===1?a:master}),send:(c,type,d)=>sent.push([c.object.id,type,d])},data={type:1,integers:[13,4,2]};
  await broadcastSavingThrow(a,data,p);assert.deepEqual(sent.map(x=>x.slice(0,2)),[[2,7],[1,7]]);
  master.position[0]=31;sent.length=0;await broadcastSavingThrow(a,data,p);assert.deepEqual(sent.map(x=>x.slice(0,2)),[[1,7]]);
  a.masterId=1;sent.length=0;await broadcastSavingThrow(a,data,p);assert.deepEqual(sent.map(x=>x.slice(0,2)),[[1,7],[1,7]]);
  sent[0][2].integers[0]=7;assert.equal(data.integers[0],13);assert.equal(sent[1][2].integers[0],13);
});

test('feedback send writes ushort code to slot9 only for actual clients, without mutating original message',async()=>{
  const a=actor(1),sent=[],data={type:2,integers:[234]},p={client:id=>id===1?{object:a}:null,send:(c,t,d)=>sent.push([t,d])};
  await sendCombatFeedback(a,65537,data,p);assert.equal(sent[0][0],11);assert.equal(sent[0][1].integers[9],1);
  assert.deepEqual(data.integers,[234]);await sendCombatFeedback(actor(2),5,data,p);assert.equal(sent.length,1);
});

test('event22 distinguishes save, attacker-only, target-only and copied dual-endpoint feedback',async()=>{
  const target=actor(1),caller=actor(2),trace=[],p={creature:id=>id===2?caller:null,
    savingThrow:(o,d)=>trace.push(['save',o.id]),feedback:(o,n,d)=>{trace.push(['feedback',o.id,n,d.integers?.[9]]);d.integers[9]=o.id;}};
  await receiveCombatFeedback(target,2,{type:1,integers:[8]},p);assert.deepEqual(trace,[['save',1],['save',2]]);
  trace.length=0;await receiveCombatFeedback(target,2,{type:3,integers:[99]},p);assert.deepEqual(trace,[['feedback',2,99,undefined]]);
  trace.length=0;await receiveCombatFeedback(target,2,{type:4,integers:[99]},p);assert.deepEqual(trace,[['feedback',1,99,undefined]]);
  trace.length=0;await receiveCombatFeedback(target,2,{type:2,integers:[234]},p);assert.deepEqual(trace,[['feedback',1,234,undefined],['feedback',2,234,undefined]]);
  trace.length=0;await receiveCombatFeedback(target,999,{type:3,integers:[99]},p);assert.equal(trace.length,0);
  p.creature=()=>target;await receiveCombatFeedback(target,1,{type:1,integers:[]},p);assert.deepEqual(trace,[['save',1],['save',1]]);
});

test('excited duration follows active table with unsigned increase-only comparison and live rest interruption',async()=>{
  const rules={excitedduration:parse2da('2DA V2.0\n\nDURATION\n0 0\n1 100\n2 -1\n3 ****')},a=actor(1,0,{excitedDuration:50}),trace=[];
  const p={client:()=>({object:a}),area:()=>({}),restController:()=>({id:8}),nearestEnemy:()=>7,cancelRest:(r,n)=>trace.push([r.id,n])};
  await setExcitedState(a,1,rules,p);assert.equal(a.excitedDuration,100);assert.deepEqual(trace,[[8,1]]);
  await setExcitedState(a,1,rules,p);assert.equal(trace.length,1);await setExcitedState(a,2,rules,p);assert.equal(a.excitedDuration,4294967295);
  await setExcitedState(a,3,rules,p);assert.equal(a.excitedDuration,4294967295);assert.equal(trace.length,2);
  await assert.rejects(setExcitedState(a,1,{},p),/ExcitedDuration/);
});

test('combat invisibility removes exact kind1 and type63, restarts cached scan, and preserves other records',async()=>{
  const a=actor(1),effects=[{id:1,type:47,integers:[0]},{id:2,type:47,integers:[1]},{id:3,type:63,integers:[]},{id:4,type:75}],removed=[];
  const p={effects:()=>effects,index:()=>0,integer:(e,n)=>e.integers[n]??0,remove:(o,e)=>{removed.push(e.id);effects.splice(effects.indexOf(e),1);}};
  await removeCombatInvisibility(a,p);assert.deepEqual(removed,[2,3]);assert.deepEqual(effects.map(e=>e.id),[1,4]);
  p.index=()=>65535;await removeCombatInvisibility(a,p);assert.equal(removed.length,2);
});

test('live event15 OnAttacked sees caller history/combat state before delayed damage, including misses',async()=>{
  const timeline=[],s=new ModuleSession({}, {onCombatMessage:m=>timeline.push(['message',m.type])});
  s.characterRules={};const area=s.register('area','ar',{pvpSetting:0});
  const a=s.register('creature','a',{...actor(1,0,{factionId:2}),areaId:area.id,stats:{currentHP:20,equippedAbilities:{Dex:10},feats:[]},authored:{ClassList:[],Race:6},combatRound:createCombatRound()});
  const t=s.register('creature','t',{...actor(2),areaId:area.id,stats:{currentHP:20,equippedAbilities:{Dex:10},feats:[]},authored:{ClassList:[],Race:6},scripts:{attacked:'observe'},combatRound:createCombatRound()});
  s.damage.runEvent=async o=>timeline.push(['attacked',o.lastAttackerId,o.nativeField700,o.stats.currentHP]);
  const data=createAttackData();data.result=4;data.attackType=39;data.weaponAttackType=7;
  await s.combat.dispatchEvent(t,{eventId:15,callerId:a.id,payload:data});
  assert.deepEqual(timeline,[['attacked',a.id,1,20]]);assert.equal(t.lastAttackType,39);assert.equal(t.lastHostileActorId,a.id);
  assert.equal(a.lastWeaponUsedId,invalid);assert.equal(t.stats.currentHP,20);
});

test('live event22 routes delayed feedback to local client and rejects malformed invisibility identity',async()=>{
  const sent=[],s=new ModuleSession({}, {onCombatMessage:m=>sent.push(m)});s.characterRules={};
  const pc=s.register('player','pc',{...actor(1),isPC:true,stats:{currentHP:10}});s.player=pc;
  await s.combat.dispatchEvent(pc,{eventId:22,callerId:pc.id,payload:{type:4,integers:[234]}});
  assert.equal(sent.length,1);assert.equal(sent[0].recipientId,pc.id);assert.equal(sent[0].type,11);assert.equal(sent[0].data.integers[9],234);
  pc.effects=[{id:'x',type:47,integers:[1]}];await assert.rejects(s.combat.removeInvisibility(pc),/effect ID is unavailable/);assert.equal(pc.effects.length,1);
});
