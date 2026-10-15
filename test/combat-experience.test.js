import test from 'node:test';
import assert from 'node:assert/strict';
import {parse2da} from '../src/area.js';
import {NativeIdList} from '../src/native_id_list.js';
import {ModuleSession} from '../src/module_session.js';
import {nativeFloatEntryByIndex} from '../src/movement_rate.js';
import {officialCampaign,initializeModuleExperience,initializeCreatureExperience,calculateDeathExperience,potentialLevel,effectiveCRForPotentialLevel,applyDeathExperience,nativeExperienceAward,addNativeExperience,nativeCanLevelUp,setNativeExperience} from '../src/combat_experience.js';

const table=()=>parse2da('2DA V2.0\nDEFAULT: 7.5\n\nLevel C0 C1 C2 C3\n999 1 20 50 96 144\n5 2 24 60 115 173');
const module=()=>({nativeIsNWM448:0,nativeNWMName450:'',nativeXPScale3be:10});
function calculation(){const m=module();return{m,p:{module:()=>m,officialCampaign,maximumLevel:()=>40,challengeRating:()=>1,xpTable:table}};}
test('XPTable numeric lookup preserves physical rows and duplicate columns, zero empty cells and table default on invalid indices',()=>{
  const t=parse2da('2DA V2.0\nDEFAULT: 9.5\n\nLabel XP XP\n400 a 11 22\n99 b **** 3.25suffix');
  assert.equal(nativeFloatEntryByIndex(t,0,1).value,11);assert.equal(nativeFloatEntryByIndex(t,0,2).value,22);
  assert.deepEqual(nativeFloatEntryByIndex(t,1,1),{found:false,value:0});assert.equal(nativeFloatEntryByIndex(t,1,2).value,3.25);
  assert.deepEqual(nativeFloatEntryByIndex(t,400,2),{found:false,value:9.5});assert.equal(nativeFloatEntryByIndex(t,0,-1).value,9.5);
});
test('native campaign classification uses exact stored official NWM identifiers and the load flag, never a module filename',()=>{
  for(const [name,expected] of [['Prelude',1],['Chapter1E',1],['XP1-Chapter 2',2],['XP2_Chapter3',3],['chapter1',0],['Witches Wake',0]]){
    const m={};initializeModuleExperience(m,{Mod_IsNWMFile:1,Mod_NWMResName:name});assert.equal(officialCampaign(m),expected);assert.equal(m.nativeXPScale3be,10);
  }
  const m={};initializeModuleExperience(m,{Mod_IsNWMFile:257,Mod_NWMResName:'Prelude',Mod_XPScale:300});assert.equal(officialCampaign(m),0);assert.equal(m.nativeXPScale3be,44);
  initializeModuleExperience(m,{Mod_IsNWMFile:0,Mod_NWMResName:'XP2_Chapter1'});assert.equal(officialCampaign(m),0);
});
test('engine XP award accepts unsigned amounts, narrows active physical class/race cells and favors the first ordinary highest class',async()=>{
  const rules={racialtypes:parse2da('2DA V2.0\n\nFavored\n99 ****'),
    classes:parse2da('2DA V2.0\n\nPreReqTable XPPenalty\n55 **** 1\n99 **** 1\n7 prestige 1')};
  const actor={associateType:0,classes:[{id:0,level:10},{id:1,level:1},{id:2,level:20}],xp:0xfffffffe};
  const p={classes:o=>o.classes,race:()=>0,experience:o=>o.xp,setExperience:(o,xp,feedback)=>{o.xp=xp;assert.equal(feedback,1);}};
  assert.equal(nativeExperienceAward(actor,0xffffffff,rules,p),3435973836);
  assert.equal(nativeExperienceAward(actor,101,rules,p),80);
  rules.classes.orderedRows[2].XPPenalty='257';assert.equal(nativeExperienceAward(actor,101,rules,p),101,'XPPenalty is an int exact1');
  await addNativeExperience(actor,5,rules,p);assert.equal(actor.xp,3);
  actor.associateType=3;await addNativeExperience(actor,5,rules,p);assert.equal(actor.xp,3);
  actor.associateType=65536;await addNativeExperience(actor,0,rules,p);assert.equal(actor.xp,3,'associate gate is WORD; zero still invokes SetExperience');
  assert.throws(()=>nativeExperienceAward(actor,-1,rules,p),/OBJECT_ID/);
});
test('favored BYTE narrowing, equal ordinary class ties and missing race defaults follow the loaded rule owner',()=>{
  const rules={racialtypes:parse2da('2DA V2.0\n\nFavored\n9 257'),classes:parse2da('2DA V2.0\n\nPreReqTable XPPenalty\n9 **** 1\n8 **** 1\n7 **** 1')};
  const p={classes:()=>[{id:0,level:5},{id:1,level:3},{id:2,level:1}],race:()=>0};
  assert.equal(nativeExperienceAward({},101,rules,p),80);
  rules.racialtypes.orderedRows[0].Favored='****';assert.equal(nativeExperienceAward({},101,rules,p),80);
  p.classes=()=>[{id:0,level:5},{id:1,level:5},{id:2,level:1}];assert.equal(nativeExperienceAward({},101,rules,p),80);
  p.race=()=>1;assert.throws(()=>nativeExperienceAward({},101,rules,p),/race index/);
});
test('trap death XP performs three owner casts and re-reads the creator after the invalid-ID gate',async()=>{
  const {p}=calculation(),actor={id:1,associateType:0,lastKillerId:2,factionId:1},trap={objectType:7},killer={objectType:5,factionId:2};let casts=0,reads=0;
  const providers={...p,object:()=>trap,asDeathOwner:o=>{casts++;return o;},deathOwnerId:()=>++reads===1?3:4,
    creature:id=>{assert.equal(id,4);return killer;},faction:o=>o.factionId,factionMembers:()=>new NativeIdList()};
  await applyDeathExperience(actor,providers);assert.equal(casts,3);assert.equal(reads,2);
});
test('native level-up eligibility uses actual client40 cap and nonzero stats PC; ordinary NPC needs no XP',()=>{
  const actor={id:0,associateType:0,level:40,pc:0,xp:0},p={client:()=>null,level:o=>o.level,maximumLevel:()=>50,statsIsPC:o=>o.pc,experience:o=>o.xp,threshold:()=>1000};
  assert.equal(nativeCanLevelUp(actor,p),1);p.client=()=>({});assert.equal(nativeCanLevelUp(actor,p),0);
  actor.level=2;actor.pc=2;assert.equal(nativeCanLevelUp(actor,p),0);actor.xp=1000;assert.equal(nativeCanLevelUp(actor,p),1);
  actor.associateType=5;assert.equal(nativeCanLevelUp(actor,p),0);actor.associateType=65536;assert.equal(nativeCanLevelUp(actor,p),1);
});
const setFixture=()=>{
  const actor={id:0,associateType:0,level:2,xp:1000,history:[{level:1},{level:2},{level:3},{level:4}]},trace=[];
  const p={client:()=>({}),dm:()=>0,experience:o=>o.xp,writeExperience:(o,n)=>{trace.push(['write',n]);o.xp=n;},
    level:o=>o.level,minimumLevel:()=>1,threshold:level=>[0,0,1000,3000,6000][level],
    historyCount:o=>o.history.length,history:(o,n)=>{trace.push(['history',n]);return o.history[n];},
    levelUp:(o,h,...args)=>{trace.push(['up',h.level,args]);o.level++;},levelDown:(o,h)=>{trace.push(['down',h.level]);o.level--;},
    canLevelUp:o=>Number(o.level<4&&o.xp>=[0,0,1000,3000,6000][o.level]),
    feedback:(o,code,data)=>trace.push(['feedback',code,data?.integers?.[0],o.xp,o.level])};
  return {actor,p,trace};
};
test('SetExperience sends gain feedback before write, replays history afterwards and checks level-up notification against the final threshold',async()=>{
  const {actor,p,trace}=setFixture();await setNativeExperience(actor,3500,1,p);
  assert.deepEqual(trace,[['feedback',182,2500,1000,2],['write',3500],['history',2],['up',3,[0,0,0,0]],['history',3],['up',4,[0,0,0,0]]]);
  assert.equal(actor.level,4);assert.equal(actor.xp,3500);
  actor.history.length=4;actor.level=3;actor.xp=1000;trace.length=0;p.historyCount=()=>3;
  await setNativeExperience(actor,3500,1,p);
  assert.deepEqual(trace,[['feedback',182,2500,1000,3],['write',3500],['feedback',11,undefined,3500,3]]);
});
test('SetExperience signed delta and unsigned feedback diverge at DWORD boundaries; no-update and DM gates preserve native side effects',async()=>{
  const {actor,p,trace}=setFixture();actor.level=1;actor.xp=0;await setNativeExperience(actor,0xffffffff,1,p);
  assert.deepEqual(trace,[['feedback',182,-1,0,1],['write',0xffffffff]]);
  trace.length=0;p.dm=()=>2;await setNativeExperience(actor,5,1,p);assert.deepEqual(trace,[]);assert.equal(actor.xp,0xffffffff);
  p.dm=()=>0;await setNativeExperience(actor,5,0,p);assert.deepEqual(trace,[['write',5]]);
});
test('SetExperience delevel uses descending captured BYTE level and live minimum/XP checks, retaining sparse history semantics',async()=>{
  const {actor,p,trace}=setFixture();actor.level=4;actor.xp=7000;actor.history[2]=null;
  await setNativeExperience(actor,0,1,p);
  assert.deepEqual(trace,[['feedback',183,7000,7000,4],['write',0],['history',3],['down',4],['history',2]]);
  assert.equal(actor.level,3,'sparse native history does not invent a LevelDown call');
});
test('native XP calculation clamps levels separately, adds CR+0.49 first in f32, and re-reads the module scale after lookup',()=>{
  const {m,p}=calculation();assert.equal(calculateDeathExperience({},1,1,p),50);
  p.challengeRating=()=>.5099999;assert.equal(calculateDeathExperience({},1,1,p),20);
  p.challengeRating=()=>.51;assert.equal(calculateDeathExperience({},1,1,p),50);
  p.challengeRating=()=>1;p.xpTable=()=>{m.nativeXPScale3be=255;return table();};assert.equal(calculateDeathExperience({},0,-3,p),1000);
  let calls=0;p.maximumLevel=()=>++calls===1?2:1;p.xpTable=table;m.nativeXPScale3be=10;
  assert.equal(calculateDeathExperience({},50,50,p),115);assert.equal(calls,2);
});
test('XP calculation uses the native expansion2 CR20 cap and the table default for unavailable physical rows',()=>{
  const {m,p}=calculation();const columns=['Level',...Array.from({length:41},(_,i)=>`C${i}`)];
  p.xpTable=()=>parse2da(`2DA V2.0\nDEFAULT: 7\n\n${columns.join(' ')}\n44 1 ${Array.from({length:41},(_,i)=>i).join(' ')}`);
  p.challengeRating=()=>100;assert.equal(calculateDeathExperience({},1,1,p),40);
  Object.assign(m,{nativeIsNWM448:1,nativeNWMName450:'XP2_Chapter1'});assert.equal(calculateDeathExperience({},1,1,p),20);
  assert.equal(calculateDeathExperience({},40,40,p),7);
});
test('potential and effective CR use the stats IsPC exact1, unsigned XP, BYTE class slots and physical EffCRLvlNN rows',()=>{
  const actor={};initializeCreatureExperience(actor,{IsPC:1,ChallengeRating:1.7});assert.equal(actor.nativeChallengeRatingD0,Math.fround(1.7));
  const p={level:()=>4,statsIsPC:o=>o.nativeStatsIsPCb0,experience:()=>10000,threshold:n=>[0,0,1000,3000,6000,10000,15000][n],maximumLevel:()=>40,classes:()=>[{id:1,level:2},{id:0,level:2}]};
  assert.equal(potentialLevel(actor,p),6);
  const rules={classes:parse2da('2DA V2.0\n\nEffCRLvl02\n999 2\n400 1')};assert.equal(effectiveCRForPotentialLevel(actor,rules,p),5);
  actor.nativeStatsIsPCb0=2;assert.equal(potentialLevel(actor,p),4);assert.equal(effectiveCRForPotentialLevel(actor,rules,p),4);
  actor.nativeStatsIsPCb0=1;p.experience=()=>0xffffffff;p.maximumLevel=()=>5;assert.equal(potentialLevel(actor,p),5);
});
function party(){
  const victim={id:100,objectType:5,associateType:0,lastKillerId:0x80000001,areaId:9,position:[0,0,0],faction:2};
  const killer={id:0x80000001,objectType:5,areaId:10,position:[100,0,0],faction:1,pc:1,potential:6,effective:4};
  const edge={id:2,objectType:5,areaId:9,position:[40,0,0],pc:1,potential:4,effective:2};
  const npc={id:3,objectType:5,areaId:9,position:[0,0,0],pc:0};
  const outside={...edge,id:4,position:[40.0001,0,0]};const dead={...edge,id:5,dead:1};
  const objects=new Map([victim,killer,edge,npc,outside,dead].map(o=>[o.id,o])),members=new NativeIdList();for(const id of [killer.id,edge.id,npc.id,outside.id,dead.id])members.append(id);
  const m=module(),awards=[],lookups=[];
  const p={module:()=>m,officialCampaign,maximumLevel:()=>40,challengeRating:()=>0,
    xpTable:()=>{lookups.push(1);return parse2da('2DA V2.0\n\nLevel C0 C1 C2\n0 1 1 1 1\n1 2 1 1 1\n2 3 1 1 1\n3 4 1 1 1\n4 5 90 120 180');},
    object:id=>objects.get(id),creature:id=>objects.get(id),asCreature:o=>o,faction:o=>o.faction,factionMembers:()=>members,
    dead:o=>o.dead??0,dying:o=>0,isPC:o=>o.pc,possessed:o=>0,potentialLevel:o=>o.potential,effectiveLevel:o=>o.effective,
    addExperience:(o,xp)=>awards.push([o.id,xp])};return{victim,killer,m,members,p,awards,lookups,objects};
}
test('death XP scans native faction order, includes distant killer, uses inclusive40m distance and NPC quarter weight; campaign1 selects effective average',async()=>{
  const f=party();await applyDeathExperience(f.victim,f.p);assert.deepEqual(f.awards,[[f.killer.id,40],[2,40]]);
  f.awards.length=0;Object.assign(f.m,{nativeIsNWM448:1,nativeNWMName450:'Prelude'});
  await applyDeathExperience(f.victim,f.p);assert.deepEqual(f.awards,[[f.killer.id,80],[2,80]]);
});
test('death XP relooks up captured recipients for award and still performs calculation with zero recipients',async()=>{
  const f=party();f.p.addExperience=(o,xp)=>{f.awards.push([o.id,xp]);f.objects.delete(2);};
  await applyDeathExperience(f.victim,f.p);assert.deepEqual(f.awards,[[f.killer.id,40]]);
  f.members.setSize(0);f.lookups.length=0;f.awards.length=0;await applyDeathExperience(f.victim,f.p);assert.equal(f.lookups.length,1);assert.deepEqual(f.awards,[]);
});
test('death XP gates summon associates and same faction, and refuses to invent faction storage; live calculator uses active resources',async()=>{
  const f=party();f.victim.associateType=3;f.p.object=()=>assert.fail('Suppressed associate queried killer');await applyDeathExperience(f.victim,f.p);
  const same=party();same.victim.faction=1;same.p.factionMembers=()=>assert.fail('Same-faction kill granted XP');await applyDeathExperience(same.victim,same.p);
  const missing=party();missing.p.factionMembers=()=>[];await assert.rejects(applyDeathExperience(missing.victim,missing.p),/canonical faction/);
  const s=new ModuleSession(null);s.module=module();s.characterRules={xptable:table()};
  const o=s.register('creature','cr',{});o.nativeChallengeRatingD0=1;assert.equal(s.combat.calculateDeathExperience(o,1,1),50);
});
