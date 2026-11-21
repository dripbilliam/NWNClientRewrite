import test from 'node:test';
import assert from 'node:assert/strict';
import { associateId,manageCreatureActivities,prepareAndResolveAttack } from '../src/combat_attack_preparation.js';
import { createCombatRound } from '../src/combat_round.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';

function fixture(){
  const actor={id:0x80000001,factionId:1,combatRound:createCombatRound()},target={id:0x80000002,objectType:5,factionId:2,associateType:0,associateIds:[],effects:[],creatureState:0};
  const objects=new Map([[actor.id,actor],[target.id,target]]),trace=[];
  const p={object:id=>objects.get(id),creature:id=>objects.get(id),setAnimation:(o,n)=>trace.push(['animation',n]),
    reputations:(...a)=>trace.push(['reputation',...a]),associateId:(o,t,n)=>associateId(o,t,n,id=>objects.get(id)),
    client:()=>null,unpossess:o=>trace.push(['unpossess',o.id]),associateCommand:(o,c)=>trace.push(['command',o.id,c]),
    removeEffect:(o,id)=>trace.push(['remove',id]),activityManager:(o,r)=>trace.push(['activity',r]),
    ranged:()=>0,meleeAttack:(o,t,c,d)=>trace.push(['melee',t.id,c,d]),rangedAttack:(o,t,c,d)=>trace.push(['ranged',t.id,c,d])};
  return {actor,target,objects,trace,p};
}
test('associate lookup counts only live matching creatures, preserving canonical high-bit IDs',()=>{
  const {actor,objects}=fixture();actor.associateIds=[12,0x80000003,0x80000004];
  objects.set(0x80000003,{associateType:3});objects.set(0x80000004,{associateType:3});
  assert.equal(associateId(actor,3,2,id=>objects.get(id)),0x80000004);
  assert.equal(associateId(actor,3,-1,id=>objects.get(id)),invalid);
  assert.equal(associateId(actor,3,0,id=>objects.get(id)),invalid);
});
test('attack activity cleanup respects locks and re-reads masks after each side effect',async()=>{
  const actor={activities:1|2|8|32,lockedActivities:2},trace=[];
  await manageCreatureActivities(actor,4,(o,bit,value)=>{trace.push([bit,value]);o.activities&=~(bit|8);});
  assert.deepEqual(trace,[[1,0]]);assert.equal(actor.activities,2|32);
  await manageCreatureActivities(actor,1,(o,bit,value)=>{trace.push([bit,value]);o.activities&=~bit;});
  assert.deepEqual(trace,[[1,0],[0x1ffc00,0],[32,0]]);
});
test('invalid native target unpauses and adds zero to its existing pause timer before animation',async()=>{
  const {actor,p,trace}=fixture();actor.combatRound.paused=true;actor.combatRound.pauseTimer=50;
  await prepareAndResolveAttack(actor,invalid,1,500,p);
  assert.equal(actor.combatRound.paused,false);assert.equal(actor.combatRound.pauseTimer,50);
  assert.deepEqual(trace,[['animation',1]]);assert.equal(actor.nativeAttackTarget724,undefined);
});
test('creature strike prepares reputation and live associates before activity and melee dispatch',async()=>{
  const {actor,target,objects,trace,p}=fixture();target.associateIds=[3];objects.set(3,{id:3,associateType:0});
  p.associateCommand=(o,c)=>{trace.push(['command',o.id,c]);if(o.id===3){objects.set(4,{id:4,associateType:0});target.associateIds.push(4);}};
  await prepareAndResolveAttack(actor,target.id,2,857,p);
  assert.equal(actor.nativeAttackTarget724,target.id);
  assert.deepEqual(trace,[['reputation',target.id,actor.id,0],['command',3,-11],['command',4,-11],['activity',4],['melee',target.id,2,857]]);
});
test('possessed familiar is queried twice and unpossessed before associate retaliation',async()=>{
  const {actor,target,objects,trace,p}=fixture();target.associateIds=[3];objects.set(3,{id:3,associateType:3});p.client=id=>id===3?{}:null;
  let queries=0;const lookup=p.associateId;p.associateId=(...a)=>{queries++;return lookup(...a);};
  await prepareAndResolveAttack(actor,target.id,1,500,p);assert.equal(queries,2);
  assert.deepEqual(trace.slice(0,3),[['reputation',target.id,actor.id,0],['unpossess',target.id],['command',3,-11]]);
});
test('status removal selects only first matching native subtype/creator and occurs before ranged choice',async()=>{
  const {actor,target,trace,p}=fixture();target.associateType=5;target.factionId=actor.factionId;target.masterId=actor.id;target.creatureState=1;
  target.effects=[{id:'wrong',type:8,subtype:2,integers:[7],creatorId:actor.id},
    {id:'domination',type:8,subtype:9,integers:[7],creatorId:actor.id},
    {id:'charm',type:8,subtype:1,integers:[1],creatorId:actor.id},
    {id:'later',type:8,subtype:1,integers:[1],creatorId:actor.id}];p.ranged=()=>1;
  await prepareAndResolveAttack(actor,target.id,1,500,p);
  assert.deepEqual(trace.slice(1),[['remove','domination'],['remove','charm'],['activity',4],['ranged',target.id,1,500]]);
});
test('unavailable associate retaliation prevents a manufactured successful strike',async()=>{
  const {actor,target,objects,trace,p}=fixture();target.associateIds=[3];objects.set(3,{id:3,associateType:0});
  p.associateCommand=()=>{throw new Error('retaliation unavailable');};
  await assert.rejects(prepareAndResolveAttack(actor,target.id,1,500,p),/retaliation unavailable/);
  assert.deepEqual(trace,[['reputation',target.id,actor.id,0]]);
});
