import test from 'node:test';
import assert from 'node:assert/strict';
import {ammunitionAvailable as available,resolveAmmunition as release} from '../src/ammunition.js';
import {OBJECT_INVALID as invalid} from '../src/game_object_array.js';
import {ModuleSession} from '../src/module_session.js';
function fixture(){
  const actor={id:1,masterId:invalid,nativeField744:100},weapon={id:2,base:8,stack:7},ammo={id:3,base:20,stack:5},trace=[];
  const p={equippedItem:(o,slot)=>{trace.push(['slot',slot]);return slot===16?weapon:ammo;},propertyExists:()=>0,baseItem:i=>i.base,stack:i=>i.stack,
    rulesetInt:(name,value)=>value,feedback:(...args)=>trace.push(['feedback',...args]),pc:()=>1,possessed:()=>0,
    inventoryItemByBase:()=>invalid,item:()=>null,aiMaster:()=>{trace.push(['AI']);return 'ai';},baseItemInfo:base=>trace.push(['base',base]),
    enqueue:(...args)=>trace.push(['queue',...args])};return{actor,weapon,ammo,trace,p};
}
test('ammunition availability uses exact native bow/crossbow/sling slots, throwing stacks and unlimited property before classification',async()=>{
  for(const [base,slot] of [[8,2048],[11,2048],[6,8192],[7,8192],[61,4096],[59,16],[63,16],[31,16]]){
    const {actor,weapon,trace,p}=fixture();weapon.base=base;assert.equal(await available(actor,2,p),2);assert.deepEqual(trace.filter(c=>c[0]==='slot').map(c=>c[1]),slot===16?[16]:[16,slot]);
  }
  const {actor,weapon,trace,p}=fixture();weapon.base=900;p.propertyExists=()=>1;p.baseItem=()=>assert.fail('Unlimited property precedes base lookup');
  assert.equal(await available(actor,5,p),5);assert.deepEqual(trace,[['slot',16]]);
});
test('ammo warnings share native field744, throttle against ruleset decrement and precede unsigned-independent signed result clamp',async()=>{
  const {actor,ammo,trace,p}=fixture();assert.equal(await available(actor,9,p),5);assert.equal(actor.nativeField744,5);
  assert.deepEqual(trace.at(-1),['feedback',actor,24,{type:0,integers:[5]}]);trace.length=0;
  await available(actor,9,p);assert.equal(trace.some(c=>c[0]==='feedback'),false);
  ammo.stack=20;await available(actor,30,p);assert.equal(actor.nativeField744,5,'At the exact warning limit no write');
  ammo.stack=-1;assert.equal(await available(actor,3,p),-1,'Native signed invalid stack is retained for caller rejection');
});
test('automatic ammo replacement scans repository indices, uses BYTE CanEquip status and performs remove/possessor/equip before reading stack',async()=>{
  const {actor,ammo,trace,p}=fixture(),items=[{id:4,base:20,stack:9},{id:5,base:20,stack:3}];ammo.stack=0;
  p.inventoryItemByBase=(o,base,index)=>{trace.push(['repo',base,index]);return items[index]?.id??invalid;};p.item=id=>items.find(i=>i.id===id);
  p.canEquip=(o,item,slot,...args)=>{trace.push(['can',item.id,slot.value,args]);return item.id===4?0:257;};
  p.removeRepository=(o,item,n)=>trace.push(['remove',item.id,n]);p.possessor=()=>invalid;
  p.setPossessor=(...args)=>trace.push(['possessor',...args]);p.equip=(...args)=>trace.push(['equip',...args]);
  assert.equal(await available(actor,2,p),2);
  assert.deepEqual(trace.filter(c=>['repo','can','remove','possessor','equip'].includes(c[0])),[
    ['repo',20,0],['can',4,2048,[1,0,0,null]],['repo',20,1],['can',5,2048,[1,0,0,null]],['remove',5,1],['possessor',items[1],1,0,0,0],['equip',actor,2048,items[1],1,0,1]]);
});
test('empty ammo feedback distinguishes PC/familiar from associate master and does not invent repository/equip owners',async()=>{
  const {actor,ammo,trace,p}=fixture();ammo.stack=0;assert.equal(await available(actor,2,p),0);assert.deepEqual(trace.at(-1),['feedback',actor,25,null]);
  p.pc=()=>0;actor.masterId=0x80000001;const master={id:actor.masterId};p.creature=()=>master;
  trace.length=0;assert.equal(await available(actor,2,p),0);assert.deepEqual(trace.at(-1),['feedback',master,241,{type:0,objects:[1]}]);
  p.inventoryItemByBase=()=>4;p.item=()=>({id:4});await assert.rejects(available(actor,2,p),/canEquip/);
});
test('ranged release captures AI/equipment, queries base allocation and queues consumption on item at exact delayed milliseconds',async()=>{
  const {actor,trace,p}=fixture();await release(actor,0xffffffff,p);
  assert.deepEqual(trace,[['AI'],['slot',16],['base',8],['slot',2048],['queue','ai',16,1,3,0xffffffff,null]]);
  trace.length=0;p.propertyExists=()=>1;await release(actor,10,p);assert.deepEqual(trace,[['AI'],['slot',16],['base',8]]);
});
test('throwing/unknown base consumption queues the right-hand item despite unlimited property, and a missing right hand still captures AI',async()=>{
  const {actor,weapon,trace,p}=fixture();weapon.base=59;p.propertyExists=()=>assert.fail('Throwing release has no property query');
  await release(actor,2,p);assert.deepEqual(trace.at(-1),['queue','ai',16,1,2,2,null]);
  trace.length=0;p.equippedItem=()=>null;await release(actor,2,p);assert.deepEqual(trace,[['AI']]);
});
test('live ammo adapters retain canonical IDs/stacks and enqueue consumption instead of mutating immediately',async()=>{
  const s=new ModuleSession(null),actor=s.register('creature','actor',{inventory:[],reputationPCFlag:0});s.characterRules={};
  const weapon=s.register('item','bow',{ownerId:actor.id,equipmentSlot:16,authored:{BaseItem:8,StackSize:1,PropertiesList:[]}});
  const ammo=s.register('item','arrows',{ownerId:actor.id,equipmentSlot:2048,authored:{BaseItem:20,StackSize:30,PropertiesList:[]}});actor.inventory=[weapon.id,ammo.id];
  assert.equal(await s.combat.ammunition(actor,4),4);await s.combat.resolveAmmo(actor,123);
  assert.equal(ammo.authored.StackSize,30);assert.equal(s.scheduler.events[0].targetId,ammo.id);assert.equal(s.scheduler.events[0].event.eventId,16);
  assert.equal(s.scheduler.events[0].event.callerId,actor.id);assert.equal(s.scheduler.events[0].due,123);
});
