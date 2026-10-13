import test from 'node:test';
import assert from 'node:assert/strict';
import { addPersonalReputation,adjustFactionReputation,adjustCombatReputations,reputationAdjustments } from '../src/combat_reputation.js';
import { FactionReputationTable,personalReputationAdjustment,subtractWorldTimes } from '../src/reputation.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';
import { parse2da } from '../src/area.js';

const create=(id,faction,x=0)=>({id,factionId:faction,originalFactionId:faction,masterId:invalid,associateType:0,
  plot:0,reputationPCFlag:0,personalReputationList:[],factionReputation:null,position:[x,0,0]});
function fixture(){
  const actor=create(0x80000001,1),target=create(2,2),area={},objects=new Map([[actor.id,actor],[target.id,target]]),ids=[actor.id,target.id],trace=[];
  const providers={creature:id=>objects.get(id)??null,dm:()=>0,area:()=>area,firstByX:()=>0,areaIds:()=>ids,
    adjustments:()=>Array.from({length:11},(_,i)=>i+1),dead:()=>0,visibility:()=>1,
    reputation:(t,id)=>objects.get(id).rep??100,npcFaction:()=>1,
    personal:async(o,id,amount,decays,duration)=>trace.push(['personal',id,amount,decays,duration]),
    faction:async(o,id,amount)=>trace.push(['faction',id,amount])};
  return{actor,target,area,objects,ids,trace,providers};
}
test('personal reputation appends independent native records and decays through the shared world-time reader',()=>{
  const actor=create(1,1),target=create(2,2),lookup={creature:()=>target,worldTime:()=>({day:7,time:100})};
  addPersonalReputation(actor,2,-80,1,180.9,lookup);addPersonalReputation(actor,2,-10,0,1,lookup);
  assert.equal(actor.personalReputationCapacity,16);assert.equal(actor.personalReputationList.length,2);
  assert.equal(actor.personalReputationList[0].duration,180);
  assert.equal(personalReputationAdjustment(actor,2,{creature:()=>target,elapsed:e=>subtractWorldTimes({day:7,time:90100},e,2880000)}),-50);
  assert.equal(actor.personalReputationList.length,2);
  assert.equal(personalReputationAdjustment(actor,2,{creature:()=>target,elapsed:e=>subtractWorldTimes({day:7,time:180101},e,2880000)}),-10);
  assert.equal(actor.personalReputationList.length,1);
  target.reputationPCFlag=1;addPersonalReputation(actor,2,-10,1,180,lookup);
  target.reputationPCFlag=0;target.masterId=9;addPersonalReputation(actor,2,-10,1,180,lookup);
  target.masterId=invalid;target.factionId=1;addPersonalReputation(actor,2,-10,1,180,lookup);
  assert.equal(actor.personalReputationList.length,1);
});
test('faction mutation preserves asymmetric native Get and Set argument order and actual familiar client ownership',async()=>{
  const table=new FactionReputationTable(2,[{FactionID1:2,FactionID2:1,FactionRep:80},{FactionID1:1,FactionID2:2,FactionRep:20}]);
  const actor=create(1,1),p={table,client:()=>false};
  await adjustFactionReputation(actor,2,-5,p);assert.equal(table.get(2,1),75);assert.equal(table.get(1,2),80);
  const before=table.values.slice();await adjustFactionReputation(actor,1,-50,p);assert.deepEqual(table.values,before);
  actor.associateType=3;actor.factionReputation=[40,50];
  await adjustFactionReputation(actor,2,100,{...p,client:()=>true});assert.deepEqual(actor.factionReputation,[40,100]);
  actor.reputationPCFlag=1;await adjustFactionReputation(actor,2,2147483647,p);assert.equal(actor.factionReputation[1],0,'int32 addition wraps before clamp');
  await adjustFactionReputation(actor,0,10,p);assert.equal(actor.factionReputation[0],40);
});
test('reputation adjustments use four physical active rows and GetINTEntry outputs including DEFAULT',()=>{
  const table=parse2da('2DA V2.0\nDEFAULT: 5\n\nPERSONALREP FACTIONREP\n90 -100 0\n80 **** 1');
  const rows=reputationAdjustments(table);assert.equal(rows.length,4);assert.equal(rows[0][0],-100);
  assert.equal(rows[1][0],0);assert.equal(rows[2][0],5);assert.equal(rows[0][2],5);
  assert.throws(()=>reputationAdjustments(null),/unavailable/);
});
test('witness scan adjusts factions once and gives friendly target adjustment precedence over neutral and enemy',async()=>{
  const f=fixture();
  for(const [id,faction,rep]of [[3,3,0],[4,3,50],[5,4,90],[6,2,100]]){
    f.objects.set(id,{...create(id,faction),rep});f.ids.push(id);
  }
  await adjustCombatReputations(f.target.id,f.actor.id,0,f.providers);
  assert.deepEqual(f.trace,[['personal',2,1,1,180],['faction',3,11],['personal',3,10,1,180],
    ['personal',4,7,1,180],['faction',4,5],['personal',5,4,1,180],['personal',6,4,1,180],['faction',2,5]]);
});
test('native witness X-window intersects actor and target and uses seen flags, not distance or heard flags',async()=>{
  const f=fixture();f.actor.position[0]=20;f.target.position[0]=50;
  f.providers.firstByX=(a,low)=>{assert.equal(low,5);return 2;};
  for(const [id,x]of [[3,5],[4,65],[5,66]]){const o=create(id,3,x);o.position[1]=10000;f.objects.set(id,o);f.ids.push(id);}
  f.providers.visibility=(o,id)=>o.id===3?2:1;
  await adjustCombatReputations(2,f.actor.id,0,f.providers);
  assert.deepEqual(f.trace,[['personal',2,1,1,180],['faction',3,5],['personal',4,4,1,180],['faction',2,5]]);
  f.trace.length=0;f.providers.firstByX=()=>null;await adjustCombatReputations(2,f.actor.id,0,f.providers);assert.deepEqual(f.trace,[]);
});
test('witness scan observes live appended objects and owned summon gate/original faction before final adjustment',async()=>{
  const f=fixture();f.target.masterId=f.actor.id;f.target.associateType=5;f.target.originalFactionId=7;
  f.objects.set(3,create(3,3));f.ids.push(3);
  f.providers.faction=async(o,id,amount)=>{f.trace.push(['faction',id,amount]);if(id===3){f.objects.set(4,create(4,4));f.ids.push(4);}};
  await adjustCombatReputations(2,f.actor.id,0,f.providers);
  assert.deepEqual(f.trace,[['faction',3,5],['personal',3,4,1,180],['faction',4,5],['personal',4,4,1,180],['faction',7,5]]);
  f.trace.length=0;f.target.associateType=1;await adjustCombatReputations(2,f.actor.id,0,f.providers);assert.deepEqual(f.trace,[]);
  f.target.masterId=invalid;f.target.plot=1;await adjustCombatReputations(2,f.actor.id,0,f.providers);assert.deepEqual(f.trace,[]);
});
