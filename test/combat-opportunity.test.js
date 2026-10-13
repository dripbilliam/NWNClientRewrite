import test from 'node:test';
import assert from 'node:assert/strict';
import { broadcastOpportunityAttack, hasCombatInvisibility } from '../src/combat_opportunity.js';
import { createCombatRound, addAttackOfOpportunity, insertSpecialAttack } from '../src/combat_round.js';
import { createObjectActionState, addObjectAction, actionByGroupId, getAcceptableAction, spellOrHealActionQueued } from '../src/object_actions.js';
import { ModuleSession } from '../src/module_session.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';
import { parse2da } from '../src/area.js';

const actor=(id,fields={})=>({id,objectType:5,areaId:100,position:[0,0,0],orientation:[1,0,0],nativeField6ed:0,
  creatureState:0,combatMode:0,nativeField700:1,plot:0,attackActionTargetId:99,combatRound:createCombatRound(),...fields});
function setup(fields={}){
  const a=actor(1,{position:[1,0,0]}),b=actor(2,fields),trace=[],objects=new Map([[1,a],[2,b]]);
  const p={markAI:v=>trace.push(['AI',v]),areaCreatureIds:()=>[1,2],creature:id=>objects.get(id)??null,
    visibility:()=>1,dead:()=>0,maximumRange:()=>2,spellOrHealQueued:()=>0,ranged:()=>0,reaction:()=>2,invisible:()=>0,
    skillRank:(o,id,t,base)=>{trace.push(['skill',id,t?.id??null,base]);return base?1:5;},
    random:{dice:(n,s)=>{trace.push(['roll',n,s]);return 10;}},broadcastSkill:(o,d)=>trace.push(['feedback',d]),
    requestAttack:(...args)=>trace.push(['request',...args.map(v=>v?.id??v)]),addAttack:(r,id)=>{trace.push(['add',id]);addAttackOfOpportunity(r,id);}};
  return {a,b,trace,p,objects};
}

test('idle opportunity preserves actions but adds a bonus strike and sequenced special attack',()=>{
  const r=createCombatRound();r.actions.push({time:77});
  addAttackOfOpportunity(r,0x80000001);assert.equal(r.additionalAttacks,1);assert.deepEqual(r.actions,[{time:77}]);
  assert.deepEqual(r.specialAttacks,[65002]);assert.deepEqual(r.specialAttackParameters,[0]);
  r.specialAttackSequence=65534;insertSpecialAttack(r,39,0);assert.equal(r.specialAttackSequence,1);assert.deepEqual(r.specialAttackParameters,[0,0]);
  r.specialAttackSequence=65535;insertSpecialAttack(r,5,0);assert.equal(r.specialAttackSequence,0);assert.deepEqual(r.specialAttackParameters,[65535,0,0]);
});

test('running opportunity inserts before existing time-zero ties, rescales time and uses native duration divisor',()=>{
  for(const [count,duration] of [[1,625],[2,800],[3,916],[4,857],[256,333]]){
    const r=createCombatRound();r.started=true;r.onhandAttacks=count;r.length=6000;r.timer=1000;
    const head={time:0},later={time:3000};r.actions=[head,later];
    addAttackOfOpportunity(r,0x80000001);
    const added=r.actions[0];assert.equal(added.targetId,0x80000001);assert.equal(added.followTarget,0);assert.equal(added.animation,9);
    assert.equal(added.duration,duration);assert.equal(added.count,1);assert.equal(r.actions[1],head);
    assert.equal(r.length,6000-duration);assert.equal(later.time,Math.trunc(Math.fround(Math.fround(0.5)*Math.fround(6000-duration))));
  }
});

test('movement Tumble succeeds at 15, consumes one d20 and reports before suppressing opportunity',async()=>{
  const {a,b,p,trace}=setup();await broadcastOpportunityAttack(a,invalid,1,p);
  assert.deepEqual(trace.slice(0,4),[['AI',1],['skill',21,null,1],['skill',21,2,0],['roll',1,20]]);
  assert.deepEqual(trace[4][1],{type:0,objects:[1],integers:[0xa87,10,5,15,0,1]});
  assert.equal(trace.length,5);assert.equal(b.combatRound.attacksOfOpportunity,1);
});

test('failed Tumble retains native signed-byte rank and queues an attack after feedback',async()=>{
  const {a,b,p,trace}=setup({attackActionTargetId:invalid});
  p.skillRank=(o,s,t,base)=>base?1:250; // signed byte -6.
  await broadcastOpportunityAttack(a,invalid,1,p);
  assert.deepEqual(trace.find(t=>t[0]==='feedback')[1].integers,[0xa87,10,-6,15,0,3]);
  assert.deepEqual(trace.slice(-2),[['request',2,1,0,1,0],['add',1]]);
  assert.equal(b.combatRound.attacksOfOpportunity,0);assert.equal(b.nativeField750,1);assert.equal(b.nativeField754,1500);
});

test('specific opportunity ignores movement/Tumble and GetDead; all-target checks GetDead',async()=>{
  const {a,b,p,trace}=setup();p.dead=()=>{throw new Error('dead queried');};p.skillRank=()=>{throw new Error('Tumble queried');};
  await broadcastOpportunityAttack(a,2,1,p);assert.deepEqual(trace,[['AI',1],['add',1]]);
  b.combatRound.attacksOfOpportunity=1;await assert.rejects(broadcastOpportunityAttack(a,invalid,0,p),/dead queried/);
});

test('facing threshold is strictly greater than native float32 -0.707, including full vertical direction',async()=>{
  for(const [orientation,position,accept] of [[[-Math.fround(0.707),0,0],[1,0,0],false],[[-0.706,0,0],[1,0,0],true],
      [[0,1,0],[0,1,0],true],[[0,-1,0],[0,1,0],false]]){
    const {a,b,p}=setup({orientation});a.position=position;await broadcastOpportunityAttack(a,2,0,p);
    assert.equal(b.combatRound.attacksOfOpportunity,accept?0:1);
  }
});

test('native gates suppress opportunity without consuming RNG or mutating queued strikes',async()=>{
  const cases=[['visibility',()=>null],['visibility',()=>2],['maximumRange',()=>0.99],['spellOrHealQueued',()=>1],
    ['ranged',()=>1],['reaction',()=>1],['invisible',()=>1]];
  for(const [name,fn] of cases){const {a,b,p,trace}=setup();p[name]=fn;await broadcastOpportunityAttack(a,2,0,p);
    assert.deepEqual(trace,[['AI',1]],name);assert.equal(b.combatRound.additionalAttacks,0);}
  for(const fields of [{nativeField6ed:1},{areaId:101},{nativeField700:2},{combatMode:1},{plot:1}]){
    const {a,b,p,trace}=setup(fields);await broadcastOpportunityAttack(a,2,0,p);assert.deepEqual(trace,[['AI',1]]);assert.equal(b.combatRound.additionalAttacks,0);
  }
  for(const field of ['spellCastRound','infinitePause']){const {a,b,p,trace}=setup();b.combatRound[field]=true;
    await broadcastOpportunityAttack(a,2,0,p);assert.deepEqual(trace,[['AI',1]]);}
});

test('all-target scan requeries changing native area ordering, ignores noncreatures, and avoids ID sorting',async()=>{
  const {a,b,p,trace,objects}=setup();const c=actor(3);objects.set(3,c);let ids=[3,invalid,2];p.areaCreatureIds=()=>ids;
  p.addAttack=(r,id)=>{trace.push(['add',r===c.combatRound?3:2,id]);if(r===c.combatRound)ids=[3,2];};
  await broadcastOpportunityAttack(a,invalid,0,p);assert.deepEqual(trace,[['AI',1],['add',3,1],['add',2,1]]);
  assert.equal(b.combatRound.attacksOfOpportunity,0);assert.equal(c.combatRound.attacksOfOpportunity,0);
});

test('invisibility query accepts any type47 subtype and type63, respecting cached scan and stop type',()=>{
  assert.equal(hasCombatInvisibility([{type:46},{type:47,integers:[0]},{type:75}],1),1);
  assert.equal(hasCombatInvisibility([{type:63}],0),1);assert.equal(hasCombatInvisibility([{type:75},{type:47}],0),0);
  assert.equal(hasCombatInvisibility([{type:47}],65535),0);
});

test('spell/heal suppression uses last acceptable action in first contiguous group, not any cast node',()=>{
  const a={objectActionState:createObjectActionState()},s=a.objectActionState;
  for(let id=0;id<65;id++){assert.equal(getAcceptableAction(id),Number([1,7,9,12,15,20,21,24,25,26,27,28,29,30,38,39,40,41,42,43,45,46,50,54,55,56,57,59].includes(id)));}
  const cast=addObjectAction(s,15,1);assert.equal(spellOrHealActionQueued(a),1);
  addObjectAction(s,2,1);assert.equal(actionByGroupId(s,1),cast);assert.equal(spellOrHealActionQueued(a),1);
  const attack=addObjectAction(s,12,1);assert.equal(actionByGroupId(s,1),attack);assert.equal(spellOrHealActionQueued(a),0);
  addObjectAction(s,1,2);addObjectAction(s,15,1);assert.equal(spellOrHealActionQueued(a),0);
  addObjectAction(s,46,3);assert.equal(spellOrHealActionQueued(a),1);
  s.list=new (s.list.constructor)();s.executingNode=cast;assert.equal(spellOrHealActionQueued(a),0);
});

test('event20 reaches live canonical candidate round and preserves uint32 target ID',async()=>{
  const s=new ModuleSession({},{});s.characterRules={appearance:parse2da('2DA V2.0\n\nPREFATCKDIST HITDIST\n0 1 0.5')};
  const area=s.register('area','area',{objects:[],pvpSetting:0});
  const a=s.register('creature','a',{...actor(1,{position:[1,0,0]}),areaId:area.id,authored:{Appearance_Type:0}});
  const b=s.register('creature','b',{...actor(2),areaId:area.id,authored:{Appearance_Type:0},inventory:[]});
  b.perception={get:()=>1};s.aiReaction=()=>2;area.objects=[a.id,b.id];
  await s.combat.dispatchEvent(a,{eventId:20,callerId:a.id,payload:b.id});
  assert.equal(s.nativeAIFieldB4,1);assert.equal(b.combatRound.additionalAttacks,1);assert.deepEqual(b.combatRound.specialAttacks,[65002]);
  assert.equal(b.combatRound.attacksOfOpportunity,0);assert.equal(b.nativeField754,1500);
});

test('missing live opportunity query is reported before strike or budget mutation',async()=>{
  const {a,b,p}=setup();delete p.reaction;
  await assert.rejects(broadcastOpportunityAttack(a,2,0,p),/provider reaction/);
  assert.equal(b.combatRound.attacksOfOpportunity,1);assert.equal(b.combatRound.additionalAttacks,0);
});
