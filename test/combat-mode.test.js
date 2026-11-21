import test from 'node:test';
import assert from 'node:assert/strict';
import { setCombatMode,setCombatActivity } from '../src/combat_mode.js';
import {toggleCreatureMode} from '../src/combat_mode.js';
import {receiveModeInput} from '../src/combat_input.js';
import fs from 'node:fs';
import {ModuleSession} from '../src/module_session.js';

test('toggle mode and decoded input match untouched native instructions, including associate notifications',async()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-mode-toggle-observations.json',import.meta.url)));
  for(const {case:c,calls:expected,result} of oracle.rows){
    const calls=[],actor={id:99,combatMode:c.mode??0,nativeField6ed:c.stealth??0};
    const actual=await toggleCreatureMode(actor,c.requested,{dead:()=>c.dead??0,dying:()=>c.dying??0,
      detect:()=>{calls.push(['detect']);return c.detect??0;},stealthBusy:()=>Boolean(c.busy),
      canUseSkill:(_o,id)=>{calls.push(['skill',id]);return Number(c.skills?.includes(id)??false);},
      hasFeat:(_o,id)=>{calls.push(['feat',id]);return Number(c.feats?.includes(id)??false);},feedback:(_o,id)=>calls.push(['feedback',id]),
      activity:(_o,mask,value)=>calls.push(['activity',mask,value]),setMode:(_o,mode,force)=>calls.push(['mode',mode,force]),
      associates:()=>c.associates??[],creature:id=>id===100?{id}:null,event:(o,a,number)=>calls.push(['event',10,o.id,a.id,11,number])});
    assert.equal(actual,result,JSON.stringify(c));assert.deepEqual(calls,expected,JSON.stringify(c));
  }
  for(const {case:c,calls:expected,result} of oracle.inputs){
    const calls=[],actor={objectType:5,nativeField8ac:0,nativeFieldEc:c.commandable};let overflowCalls=0;
    const actual=await receiveModeInput({}, {clientObject:()=>c.actor?actor:null,asCreature:o=>o,
      overflow:()=>{if(overflowCalls++===0)return 0;return Number(c.overflow===overflowCalls-1);},underflow:()=>c.underflow,
      readByte:()=>{calls.push(['read']);return c.requested;},readObjectId:()=>{calls.push(['target']);return 100;},
      addCounter:(_o,id)=>calls.push(['counter',id]),toggle:(_o,mode)=>{calls.push(['toggle',mode]);return 0;}});
    assert.equal(actual,result,JSON.stringify(c));assert.deepEqual(calls,expected,JSON.stringify(c));
  }
});

test('serialized defensive casting input owns activity and canonical associate script events',async()=>{
  const s=new ModuleSession(null,{runStartupScripts:false}),area=s.register('area','area',{resRef:'test'}),actor=s.register('player','player',{areaId:area.id,authored:{},stats:{}}),associate=s.register('creature','associate',{areaId:area.id,authored:{},stats:{}});
  s.player=actor;actor.stats.currentHP=10;actor.associateIds=[associate.id];associate.scripts={userDefined:'mode_event'};actor.combatRound={started:false};s.combat.broadcastProviders=()=>({client:()=>({object:actor})});
  s.equippedItems=()=>[];let event;
  s.combat.enqueueEvent=(eventId,callerId,targetId,delay,payload)=>{event={eventId,callerId,targetId,delay,payload};};
  let script;s.runScript=async(...args)=>{script=args;};
  const request=s.queuePlayerMode(10);await s.drainPlayerInputs();assert.equal(await request,10);
  assert.equal(actor.combatMode,9);assert.equal(actor.nativeField6ee,1);assert.equal(actor.activities&0x40000,0x40000);
  assert.deepEqual(event,{eventId:10,callerId:actor.id,targetId:associate.id,delay:0,payload:{type:11,integers:[20010],objectIds:[]}});
  await s.combat.dispatchEvent(associate,event);assert.equal(associate.eventObjects.userDefined,20010);assert.deepEqual(script,['mode_event',associate.id,{scriptEventContext:5011}]);
  const off=s.queuePlayerMode(10);await s.drainPlayerInputs();await off;assert.equal(actor.combatMode,0);assert.equal(actor.nativeField6ee,0);
  const stale=s.queuePlayerMode(10);actor.areaId=0x7f000000;await s.drainPlayerInputs();assert.equal(await stale,0);
});

function fixture(){
  const actor={combatMode:0,pendingCombatMode:0,combatRound:{started:false},activities:0,lockedActivities:0,effects:[]},trace=[],items=new Map();
  const p={item:(o,slot)=>{trace.push(['item',slot]);return items.get(slot)??null;},ranged:i=>i.ranged??0,
    classIndex:()=>255,monkWeapon:i=>i.monk??0,relativeSize:()=>0,hasFeat:()=>0,
    feedback:(o,n)=>trace.push(['feedback',n]),warning:m=>trace.push(['warning',m]),remainingUses:()=>1,
    decrementUses:(o,n)=>trace.push(['decrement',n]),activity:(o,mask,value)=>setCombatActivity(o,mask,value,{
      defensiveCasting:(o,v)=>{o.defensiveCasting=Number(v);trace.push(['casting',v]);},
      applyStance:()=>trace.push('stance+'),removeStance:(o,id)=>trace.push(['stance-',id])})};
  return{actor,trace,items,p};
}
test('native started exact-one defers mode byte without equipment query; forced switches immediately',async()=>{
  const {actor,p,trace}=fixture();actor.combatRound.started=true;
  await setCombatMode(actor,0x109,0,p);assert.equal(actor.pendingCombatMode,9);assert.equal(actor.combatMode,0);assert.deepEqual(trace,[]);
  await setCombatMode(actor,9,1,p);assert.equal(actor.combatMode,9);assert.equal(actor.activities,0x40000);assert.equal(actor.defensiveCasting,1);
});
test('ranged Parry rejection preserves old mode and activity while emitting native feedback188',async()=>{
  const {actor,p,trace,items}=fixture();actor.combatMode=9;actor.activities=0x40000;items.set(16,{ranged:1});
  await setCombatMode(actor,1,1,p);assert.equal(actor.combatMode,9);assert.equal(actor.activities,0x40000);
  assert.deepEqual(trace,[['item',16],['feedback',188]]);
});
test('forced same-mode refresh clears then re-enables and observes defensive casting side effects',async()=>{
  const {actor,p,trace}=fixture();actor.combatMode=9;actor.activities=0x40000;
  await setCombatMode(actor,9,1,p);
  assert.deepEqual(trace,[['item',16],['casting',false],['casting',true]]);assert.equal(actor.combatMode,9);
});
test('enabling a combat bit clears other unlocked combat bits in native order, preserving locked bits',async()=>{
  const {actor,p,trace}=fixture();actor.activities=0x400|0x40000|0x100000;actor.lockedActivities=0x400;actor.effects=[{type:95,id:'stance'}];
  await setCombatMode(actor,1,1,p);
  assert.deepEqual(trace,[['item',16],['casting',false],['stance-','stance']]);assert.equal(actor.activities,0x400|0x1000);
});
test('Flurry validates either native class slot and monk weapons or conditional feats; Rapid Shot rejects crossbows',async()=>{
  const {actor,p,items,trace}=fixture();items.set(16,{data:{BaseItem:1},monk:1});items.set(32,{monk:0});
  p.classIndex=(o,id)=>id===40?1:255;p.relativeSize=()=>-1;p.hasFeat=(o,id)=>Number(id===866);
  await setCombatMode(actor,5,1,p);assert.equal(actor.combatMode,5);
  items.set(16,{data:{BaseItem:6},ranged:1});await setCombatMode(actor,6,1,p);
  assert.equal(actor.combatMode,5);assert.deepEqual(trace.at(-1),['feedback',188]);
  items.set(16,{data:{BaseItem:8},ranged:1});await setCombatMode(actor,6,1,p);assert.equal(actor.combatMode,6);
});
test('no stance uses still clears the old mode before feedback199; successful activation consumes feat947',async()=>{
  const {actor,p,trace}=fixture();actor.combatMode=9;actor.activities=0x40000;p.remainingUses=()=>0;
  await setCombatMode(actor,11,1,p);assert.equal(actor.combatMode,0);assert.equal(actor.activities,0);
  assert.deepEqual(trace,[['item',16],['casting',false],['feedback',199]]);
  p.remainingUses=()=>1;trace.length=0;await setCombatMode(actor,11,1,p);
  assert.deepEqual(trace,[['item',16],'stance+',['decrement',947]]);assert.equal(actor.combatMode,11);
});
test('locked selected activity changes stored mode without enabling its bit; unknown bytes warn and remain stored',async()=>{
  const {actor,p,trace}=fixture();actor.lockedActivities=0x1000;
  await setCombatMode(actor,1,1,p);assert.equal(actor.combatMode,1);assert.equal(actor.activities,0);
  await setCombatMode(actor,0xff,1,p);assert.equal(actor.combatMode,255);assert.equal(trace.filter(a=>a[0]==='warning').length,1);
});
