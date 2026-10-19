import test from 'node:test';
import assert from 'node:assert/strict';
import { ModuleSession } from '../src/module_session.js';
import { createCombatRound } from '../src/combat_round.js';
import { savingThrowSpell } from '../src/spell_metadata.js';
import { classSkillUsable } from '../src/skill_caches.js';
import { parse2da } from '../src/area.js';
import { OBJECT_INVALID as invalid } from '../src/game_object_array.js';
import { clearAllAttacks } from '../src/combat_attack_data.js';
import { runtimeDiagnostics } from '../src/runtime_diagnostics.js';
import { NativeRandom } from '../src/native_random.js';
import { FactionReputationTable } from '../src/reputation.js';
import { addObjectAction } from '../src/object_actions.js';

const table=(cols,rows)=>parse2da(`2DA V2.0\n\n${cols}\n${rows}`);
function fixture(rolls=[10],options={}){
  const messages=[],s=new ModuleSession({}, {onCombatMessage:m=>messages.push(m),...options});
  s.characterRules={appearance:table('SIZECATEGORY','0 3'),racialtypes:table('Label','0 Human'),
    spells:table('School UserType','0 V 1\n1 I 2'),skills:table('AllClassesCanUse','0 0'),savingthrowtypes:null};
  const area=s.register('area','area',{flags:0,objects:[]});
  const create=(kind,key,race)=>{
    const a=s.register(kind,key,{areaId:area.id,position:[0,0,0],inventory:[],plot:0,creatureData:{Race:race,Appearance_Type:0,ClassList:[],SkillList:[],FeatList:[]},
      stats:{feats:[],level:1,equippedAbilities:{Str:12,Dex:10,Wis:10,Int:10,Cha:10},combat:{baseAttackBonus:2,finalBreakdown:{armor:{
        natural:{authored:0,classGains:[],dwarvenDefender:0,armorSkin:0,monkWisdom:0,monkLevels:0},components:{dexterity:0},monkAbilities:false,
        cache:{up:[0,0,0,0,0],down:[0,0,0,0,0]}},saves:Object.fromEntries(['fortitude','reflex','will'].map(k=>[k,{base:0,ability:0,authored:0,luck:0,darkBlessing:0}]))}},
      },combatRound:createCombatRound(),creatureAnimation:2,animationState:1});
    a.combatRound.attacks[0].weaponAttackType=7;return a;
  };
  const actor=create('player','player',0),target=create('creature','target',6);s.player=actor;
  actor.perception.set(target.id,1);target.perception.set(actor.id,1);
  const constructorRandom=new NativeRandom(1);
  let draws=0;s.random={next:()=>constructorRandom.next(),dice:(n,size)=>{assert.deepEqual([n,size],[1,20]);assert.ok(rolls.length,'Unexpected native RNG draw');draws++;return rolls.shift();}};
  return{s,actor,target,messages,draws:()=>draws};
}

function meleeFixture(){
  const f=fixture(),{s,actor,target}=f;
  Object.assign(s.characterRules,{
    iprp_damagecost:table('Rank NumDice Die','0 0 0 0'),
    damagehitvisual:table('VisualEffectID RangedEffectID',Array.from({length:13},(_,i)=>`${i} **** ****`).join('\n')),
    excitedduration:table('DURATION','0 0\n1 8000'),
    diffsettings:table('A B C D E',Array.from({length:7},(_,i)=>`${i} 0 0 0 0 0`).join('\n'))
  });
  for(const [i,o] of [actor,target].entries()){
    o.stats.currentHP=o.stats.maxHP=30;o.factionId=i;o.isPC=i===0;o.creatureData.IsPC=i===0?1:0;
    o.scripts={};o.combatRound.onhandAttacks=1;
  }
  s.registry.get(actor.areaId).pvpSetting=0;
  actor.creatureData.FeatList=[{Feat:21}];actor.stats.feats=[21];
  return f;
}

test('script ClearAllActions honors explicit object and combat flag, unlocks orientation and retains the distinct +738 target',async()=>{
  const {s,actor,target}=meleeFixture();
  target.attackActionTargetId=actor.id;target.nativeAttackTarget724=actor.id;target.spellActionTargetId=actor.id;
  target.attackTargetId=actor.id;target.nativeField700=1;target.nativeField704=8000;s.combat.setLock(target,actor.id);
  target.combatRound.started=true;target.combatRound.paused=true;
  await s.commands.ClearAllActions([0,target.id],{self:actor.id});
  assert.equal(target.lockOrientationId,invalid);assert.equal(target.attackActionTargetId,invalid);
  assert.equal(target.nativeAttackTarget724,invalid);assert.equal(target.spellActionTargetId,invalid);
  assert.equal(target.attackTargetId,actor.id);assert.equal(target.nativeField700,1);assert.equal(target.nativeField704,8000);
  assert.equal(target.combatRound.started,true);assert.equal(target.combatRound.paused,true);
  actor.nativeField700=1;await s.commands.ClearAllActions([1],{self:actor.id});
  assert.equal(actor.nativeField700,0);assert.equal(actor.nativeField704,0);assert.equal(actor.initiativePending,1);
  await s.commands.ClearAllActions([1,invalid],{self:actor.id});
});

test('live frame drains a self attack through canonical native queue, unlocks and records the distinct last-action field',async()=>{
  const {s,actor,target}=meleeFixture();s.combat.setLock(actor,target.id);
  const node=addObjectAction(actor.objectActionState,12,65535,[{type:3,value:actor.id}]);
  actor.attackActionTargetId=actor.id;actor.nativeAttackTarget724=actor.id;s.nativeAIFieldB4=7;
  await s.combat.updateAfterEffects(actor,0);
  assert.equal(actor.objectActionState.list.count,0);assert.equal(actor.objectActionState.executingId,65535);
  assert.equal(actor.objectActionState.executingTargetId,invalid);assert.equal(actor.lockOrientationId,invalid);
  assert.equal(actor.attackActionTargetId,invalid);assert.equal(actor.nativeAttackTarget724,invalid);
  assert.equal(s.nativeAIFieldBC,12);assert.equal(s.nativeAIFieldB4,7);
  assert.equal(actor.objectActionState.startDay,0);assert.equal(actor.creatureAnimation,0);
  assert.equal(node.parameterData[0]>>>0,actor.id);
});

test('live action driver retains an attack when native LOS is unavailable, including linked identity and timestamps',async()=>{
  const {s,actor,target}=meleeFixture();
  s.characterRules.appearance=table('SIZECATEGORY PREFATCKDIST HITDIST','0 3 1 0.5');
  const node=addObjectAction(actor.objectActionState,12,65535,[{type:3,value:target.id}]);
  await assert.rejects(s.combat.runActions(actor,123,456,0n,{microseconds:()=>0n}),/lineOfSight/);
  assert.equal(actor.objectActionState.list.head.action,node);assert.equal(actor.objectActionState.list.count,1);
  assert.equal(actor.objectActionState.executingNode,null);assert.equal(actor.objectActionState.executingId,65535);
  assert.equal(actor.objectActionState.lastRunDay,123);assert.equal(actor.objectActionState.lastRunTime,456);
  assert.equal(actor.objectActionState.startDay,123);assert.equal(actor.objectActionState.startTime,456);
  assert.equal(s.nativeAIFieldBC,12);
});

test('live attack eligibility maps raised render coordinates to native area LOS and preserves canonical IDs/ranged flag',async()=>{
  const {s,actor,target}=meleeFixture();
  s.characterRules.appearance=table('SIZECATEGORY PREFATCKDIST HITDIST','0 3 1 0.5');
  actor.position=[4,2,-6];target.position=[5,3,-7];
  const area=s.registry.get(actor.areaId),calls=[];
  area.nativeGeometry={lineOfSight:(...args)=>{calls.push(args);return 0;}};
  const savedTarget=actor.nativePathInfo.field28;
  const result=await s.combat.evaluateAttack(actor,target.id);
  assert.equal(result.decision,'approach');
  assert.deepEqual(calls[0],[[4,6,3],[5,7,4],[0,0,0],{id:invalid},actor.id,target.id,0]);
  assert.equal(actor.nativePathInfo.field28,savedTarget);
});

test('live target clearing honors active sticky setting and defensive-casting side effect',async()=>{
  for(const sticky of [false,true]){
    const {s,actor,target}=meleeFixture();s.stickyCombatModes=sticky;
    const node=addObjectAction(actor.objectActionState,12,65535,[{type:3,value:target.id}]);
    actor.combatMode=9;actor.activities=0x40000;actor.nativeField6ee=1;
    await s.combat.changeTarget(actor,node,invalid);
    assert.equal(actor.combatMode,sticky?9:0);assert.equal(actor.nativeField6ee,Number(sticky));
    assert.equal(actor.activities,sticky?0x40000:0);assert.equal(node.parameterData[0]>>>0,invalid);
  }
});

test('live unavailable combat movement retains both the object attack and due round action',async()=>{
  const {s,actor,target}=meleeFixture();
  const node=addObjectAction(actor.objectActionState,12,65535,[{type:3,value:target.id}]);
  actor.combatRound.started=true;actor.combatRound.actions.push({nativeActionType:4,time:0,duration:500});
  const evaluate=s.combat.evaluateAttack;s.combat.evaluateAttack=async()=>({decision:'round',targetValid:true});
  s.characterRules.appearance=table('SIZECATEGORY PREFATCKDIST HITDIST','0 3 1 0.5');
  try{await assert.rejects(s.combat.runActions(actor,1,2,0n,{microseconds:()=>0n}),/testDirectLine/);}
  finally{s.combat.evaluateAttack=evaluate;}
  assert.equal(actor.objectActionState.list.head.action,node);assert.equal(actor.combatRound.actions.length,1);
  assert.equal(actor.combatRound.actions[0].nativeActionType,4);
});

test('live melee spatial query uses canonical third-creature collision and actual cutscene-ghost effects',async()=>{
  const {s,actor,target}=meleeFixture();s.characterRules.appearance=table('SIZECATEGORY PREFATCKDIST HITDIST','0 3 1 0.5');
  target.position=[2,0,0];const area=s.registry.get(actor.areaId);area.objects=[actor.id,target.id];
  const los={lineOfSight:()=>1}; // Explicit fixture, not native tile LOS.
  assert.equal((await s.combat.evaluateAttack(actor,target.id,los)).decision,'round');
  const third=s.register('creature','blocker',{areaId:area.id,position:[0.7,10,0],inventory:[],stats:{currentHP:20},creatureData:{IsPC:0}});
  area.objects.push(third.id);actor.perception.set(third.id,1);
  assert.equal((await s.combat.evaluateAttack(actor,target.id,los)).decision,'approach');
  s.effects.apply(2,s.effects.create(93,actor.id),third.id);
  assert.equal((await s.combat.evaluateAttack(actor,target.id,los)).decision,'round');
  assert.equal(actor.nativePathInfo.field8,Math.fround(0.6));assert.equal(actor.nativePathInfo.field28,0);
});

test('live in-band non-random combat step ends without a fabricated movement pause or position change',async()=>{
  const {s,actor,target}=meleeFixture();s.characterRules.appearance=table('SIZECATEGORY PREFATCKDIST HITDIST','0 3 1 0.5');
  target.position=[1.5,0,0];actor.combatRound.paused=true;actor.combatRound.pauseTimer=50;
  assert.equal((await s.combat.combatStep(actor,0,9999,target.id)).moved,false);
  assert.deepEqual(actor.position,[0,0,0]);assert.equal(actor.combatRound.paused,false);assert.equal(actor.combatRound.pauseTimer,50);
});

test('stationary melee fixture runs request, round, hostility, attack copy, delayed HP and next-round startup through world frames',async()=>{
  const {s,actor,target}=meleeFixture();s.random=new NativeRandom(1);
  s.characterRules.appearance=table('SIZECATEGORY PREFATCKDIST HITDIST','0 3 1 0.5');
  const columns='PERSONALREP FACTIONREP WITFRIA WITFRIB WITFRIC WITNEUA WITNEUB WITNEUC WITENEA WITENEB WITENEC';
  s.characterRules.repadjust=table(columns,Array.from({length:4},(_,i)=>`${i} -100 -10 0 0 0 0 0 0 0 0 0`).join('\n'));
  s.factionTable=new FactionReputationTable(1,[{FactionID1:0,FactionID2:1,FactionRep:0}]);
  actor.factionId=2;actor.reputationPCFlag=1;actor.factionReputation=[0];target.factionId=1;
  actor.stats.combat.baseAttackBonusWithoutEpic=2;target.position=[1.5,0,0];actor.perceptionUpdateFlags=132;
  s.registry.get(actor.areaId).objects=[actor.id,target.id];
  // The stationary flag and LOS are explicit fixture inputs. No native tile
  // LOS, pathfinding, dynamic perception or independent encounter is asserted.
  const evaluate=s.combat.evaluateAttack.bind(s.combat);
  s.combat.evaluateAttack=(o,id)=>evaluate(o,id,{lineOfSight:()=>1});
  await s.commands.ActionAttack([target.id],{self:actor.id});const node=actor.objectActionState.list.head.action;
  await s.scheduler.pump();assert.equal(actor.combatRound.length,4250);assert.equal(actor.combatRound.started,true);
  s.scheduler.advance(707);await s.scheduler.pump();
  assert.equal(actor.combatRound.currentAttack,1);assert.equal(actor.combatRound.paused,true);
  assert.equal(target.lastAttackerId,actor.id);assert.equal(target.stats.currentHP,30);
  assert.equal(actor.personalReputationList.length,1);assert.equal(actor.personalReputationList[0].objectId,target.id);
  assert.equal(actor.personalReputationList[0].amount,-100);assert.equal(actor.personalReputationCapacity,16);
  assert.equal(actor.objectActionState.list.head.action,node);
  const damage=s.scheduler.events.find(e=>e.event.eventId===5);assert.ok(damage);const damageDue=damage.due;
  s.scheduler.advance(damageDue-s.scheduler.time-1);await s.scheduler.pump();assert.equal(target.stats.currentHP,30);
  s.scheduler.advance(1);await s.scheduler.pump();assert.ok(target.stats.currentHP<30);
  // Strict pause expiry, then the due no-movement step, then strict round
  // overrun. The same object action survives and starts its next native round.
  s.scheduler.advance(626);await s.scheduler.pump();
  s.scheduler.advance(1417);await s.scheduler.pump();assert.equal(actor.combatRound.paused,false);
  s.scheduler.advance(2126);await s.scheduler.pump();
  assert.equal(actor.combatRound.started,true);assert.equal(actor.combatRound.timer,0);
  assert.equal(actor.combatRound.length,4250);assert.equal(actor.objectActionState.list.head.action,node);
  assert.deepEqual(s.diagnostics,[]);
});

test('live normal strike uses canonical attacker/defender state through default modifier, AC, precision and defenses',async()=>{
  const {s,actor,target,draws}=fixture();await s.combat.resolveRoll(actor,target);
  const data=actor.combatRound.attacks[0];assert.equal(data.modifier,3);assert.equal(data.roll,10);assert.equal(data.result,1);assert.equal(draws(),1);
  assert.equal(s.registry.get(actor.id),actor);assert.equal(s.registry.get(target.id),target);
});

test('live attack modifier preserves the native self-observer invisibility call, while defender AC uses the defender observer',async()=>{
  const {s,actor,target}=fixture();actor.effects=[{type:47,integers:[1,0,0,0]}];
  assert.equal(await s.combat.invisible(actor,actor),1);assert.equal(await s.combat.invisible(actor,target),0);
  await s.combat.resolveRoll(actor,target);assert.equal(actor.combatRound.attacks[0].modifier,5);
});

test('live successful Parry queries the effective skill and writes the defender riposte queue',async()=>{
  const {s,actor,target,draws}=fixture([5,20]);
  s.characterRules.skills=table('KeyAbility Untrained ArmorCheckPenalty',Array.from({length:11},(_,i)=>`${i} DEX 1 0`).join('\n'));
  target.stats.skills=Array(11).fill(0);target.skillArmorPenalties=[0,0];target.combatMode=1;
  target.combatRound.parryActions=1;target.combatRound.started=true;target.combatRound.length=6000;
  await s.combat.resolveRoll(actor,target);
  assert.equal(actor.combatRound.attacks[0].result,2);assert.equal(target.combatRound.parryActions,0);
  assert.deepEqual(target.combatRound.specialAttacks,[65003]);assert.equal(target.combatRound.actions[0].targetId,actor.id);assert.equal(draws(),2);
});

test('live save honors native default and changed natural-one setting and emits actual local check feedback',async()=>{
  for(const [setting,result] of [[true,0],[false,1]]){
    const {s,actor,messages,draws}=fixture([1],{naturalOnesFailSavingThrows:setting});
    actor.stats.combat.finalBreakdown.saves.will.base=100;
    assert.equal(await s.combat.savingThrow(actor,3,10,0,invalid,1,0,0),result);
    assert.equal(draws(),1);assert.deepEqual(messages.map(m=>[m.recipientId,m.type,m.data.integers]),[[actor.id,7,[10,100,1,3,0,0]]]);
    assert.equal(actor.lastSpellId,-1);
  }
});

test('live contextual save uses physical spell row school and UserType, adding owned Arcane Defense',async()=>{
  const {s,actor,target}=fixture([10]);target.lastSpellId=0;actor.creatureData.FeatList=[{Feat:419}];actor.stats.feats=[419];
  assert.equal(await s.combat.savingThrow(actor,3,12,0,target.id,0,0,0),1);
  target.lastSpellId=1;assert.equal(savingThrowSpell(s.characterRules,1).school,6);
});

test('spell metadata follows verified school switch, byte classification and signed physical ID bounds',()=>{
  const schools=['A','C','D','E','V','I','N','T'],r={spells:table('School UserType',schools.map((school,i)=>`${999-i} ${school} ${257+i}`).join('\n'))};
  schools.forEach((_,i)=>assert.deepEqual(savingThrowSpell(r,i),{classification:i+1,school:i+1}));
  assert.equal(savingThrowSpell(r,-1),null);assert.equal(savingThrowSpell(r,99),null);
  r.spells=table('School UserType','0 x 1');assert.throws(()=>savingThrowSpell(r,0).school,/uninitialized/);
});

test('class skill loader retains GetINTEntry output for failed reads, including explicit empty and DEFAULT',()=>{
  const r={skills:table('AllClassesCanUse','0 0\n1 0'),classes:table('SkillsTable','0 cls'),classTables:new Map([['cls',table('SkillIndex','0 ****')]])};
  assert.equal(classSkillUsable(r,0,0),1);assert.equal(classSkillUsable(r,0,1),0);
  r.classTables.set('cls',parse2da('2DA V2.0\nDEFAULT: 1\n\nClassSkill\n0 0'));
  assert.equal(classSkillUsable(r,0,1),1);assert.equal(classSkillUsable(r,0,0),0);
});

test('live ordinary melee resolves without query callbacks, then delivers an independent attack copy before delayed damage',async()=>{
  const {s,actor,target,messages}=meleeFixture();
  const draws=[],values=[10,2];
  s.random={dice:(n,size)=>{draws.push([n,size]);assert.ok(values.length,'Unexpected RNG draw');return values.shift();}};
  const before=runtimeDiagnostics.records.length;
  await s.combat.resolveMelee(actor,target,1,857);
  assert.deepEqual(draws,[[1,20],[1,3]]);
  assert.equal(actor.combatRound.currentAttack,1);assert.equal(actor.combatRound.attacks[0].damage[12],3);
  assert.equal(target.stats.currentHP,30);
  assert.deepEqual(s.scheduler.events.map(e=>[e.event.eventId,e.due]),[[15,0],[5,428]]);
  clearAllAttacks(actor.combatRound);await s.scheduler.pump();
  assert.equal(target.lastAttackerId,actor.id);assert.equal(target.stats.currentHP,30);
  assert.equal(messages[0].attack.damage[12],3);
  s.scheduler.advance(428);await s.scheduler.pump();
  assert.equal(target.stats.currentHP,27);assert.equal(target.lastDamagerId,actor.id);
  assert.deepEqual(s.diagnostics,[]);
  assert.ok(!runtimeDiagnostics.records.slice(before).some(r=>r.kind==='session.failure'||/party combat-state broadcasts/.test(r.message)));
});

test('live miss animation and the next strike consume the same native dice stream',async()=>{
  const {s,actor,target}=meleeFixture();s.random=new NativeRandom(1);
  await s.combat.resolveMelee(actor,target,1,600);
  const miss=actor.combatRound.attacks[0];
  assert.equal(miss.roll,2);assert.equal(miss.result,4);assert.equal(miss.reactionAnimation,11);
  assert.equal(s.random.draws,2);assert.deepEqual(s.scheduler.events.map(e=>e.event.eventId),[15]);
  await s.combat.resolveMelee(actor,target,1,600);
  const hit=actor.combatRound.attacks[1];
  assert.equal(hit.roll,15);assert.equal(hit.result,1);assert.equal(hit.damage[12],3);
  assert.equal(s.random.draws,4);
  assert.deepEqual(s.scheduler.events.map(e=>[e.event.eventId,e.due]),[[15,0],[15,0],[5,300]]);
});

test('live melee miss signaling routes Epic Dodge feedback without fixture message accessors',async()=>{
  const {s,actor,target}=fixture(),data=actor.combatRound.attacks[0];
  actor.creatureData.FeatList=[{Feat:21}];actor.stats.feats=[21];
  data.result=4;data.animationDuration=600;data.lists[3].push({type:0,integers:[126]},{type:2,integers:[234]});
  actor.combatRound.currentAttack=1;await s.combat.signalMelee(actor,target,1);
  assert.deepEqual(s.scheduler.events.map(e=>[e.event.eventId,e.due]),[[15,0],[22,300]]);
  assert.equal(s.scheduler.events[1].event.payload.integers[0],234);
});

test('live item spell payloads schedule offensive and defensive event19 with their own canonical caster and impact delay',async()=>{
 for(const ranged of [false,true]){
  const {s,actor,target}=meleeFixture();
  s.characterRules.iprp_onhitspell=table('SpellIndex','0 1');
  s.characterRules.spells=table('ImpactScript','0 none\n1 fixture_impact');
  const offensive={id:77,data:{BaseItem:22}},defensive={id:78,data:{BaseItem:16}},property={PropertyName:82,Subtype:0,CostValue:9};
  const data=actor.combatRound.attacks[0];data.result=1;data.animationDuration=600;data.reactionDelay=40;data.damage[12]=1;
  await s.combat.itemOnHitSpell(actor,target,property,offensive);
  await s.combat.itemOnHitSpell(actor,target,property,defensive);
  assert.equal(data.lists[1][0].casterId,actor.id);assert.equal(data.lists[2][0].casterId,target.id);
  actor.combatRound.currentAttack=1;
  if(ranged)await s.combat.signalRanged(actor,target,1,{safeProjectile:()=>{},ammunition:()=>{}});else await s.combat.signalMelee(actor,target,1);
  const events=s.scheduler.events.filter(e=>e.event.eventId===19);
  assert.deepEqual(events.map(e=>[e.targetId,e.event.callerId,e.due]),[[target.id,target.id,ranged?340:300],[actor.id,actor.id,ranged?340:300]]);
  assert.equal(events[0].event.payload.targetId,actor.id);assert.equal(events[1].event.payload.targetId,target.id);
  assert.ok(events.every(e=>e.event.payload.casterLevel===10&&e.event.payload.areaId===actor.areaId));
 }
});

test('live script attack request shares canonical queue, reputation, combat state, RNG and cancellation',async()=>{
  const {s,actor,target,messages}=meleeFixture();
  s.factionTable=new FactionReputationTable(1,[{FactionID1:0,FactionID2:1,FactionRep:0}]);
  actor.factionId=2;actor.reputationPCFlag=1;actor.factionReputation=[0];target.factionId=1;
  s.registry.get(actor.areaId).objects=[actor.id,target.id];s.random=new NativeRandom(0);
  await s.commands.ActionAttack([target.id,1],{self:actor.id});
  const state=actor.objectActionState,node=state.list.head.action;
  assert.equal(node.actionId,12);assert.equal(node.parameterData[0]>>>0,target.id);
  assert.equal(node.parameterTypes[0],3);assert.equal(state.list.count,1);
  assert.equal(actor.attackActionTargetId,target.id);assert.equal(actor.nativeField700,1);assert.equal(actor.passiveAttack,1);
  assert.equal(s.random.draws,2); // request gate, then nearby local client's cry choice
  const voice=messages.find(m=>m.type==='voice-chat');assert.ok(voice);assert.equal(voice.recipientId,actor.id);assert.equal(voice.actorId,actor.id);assert.ok(voice.code>=1&&voice.code<=3);
  await s.commands.ActionAttack([target.id,0],{self:actor.id});
  assert.equal(state.list.count,1);assert.equal(state.list.head.action,node);assert.equal(s.random.draws,2);
  assert.equal(actor.attackActionTargetId,invalid); // native duplicate request clears +728 before suppressing insertion
  actor.attackTargetId=target.id;actor.lockOrientationId=target.id;
  actor.nativePathInfo.field28=target.id;actor.nativePathInfo.raw.setUint32(0x19c,1,true);
  await s.combat.clearActions(actor);
  assert.equal(state.list.count,0);assert.equal(actor.attackTargetId,target.id);
  assert.equal(actor.lockOrientationId,invalid);assert.equal(actor.nativePathInfo.field28,target.id);
  assert.equal(actor.nativePathInfo.raw.getUint32(0x19c,true),0);
  actor.commandable=false;await s.commands.ActionAttack([target.id],{self:actor.id});
  assert.equal(state.list.count,0);assert.equal(s.random.draws,2);
});

test('live zero-damage weapon simulation distinguishes full immunity, elemental damage and on-hit spells without consuming mitigation budgets or HP',async()=>{
  const {s,actor,target}=meleeFixture();s.random=new NativeRandom(1);
  target.damageImmunityCache=Array(32).fill(0);target.damageImmunityCache[0]=100;
  assert.equal(await s.combat.weaponEffective(actor,target.id,0),0);
  assert.equal(s.random.draws,0);assert.equal(target.stats.currentHP,30);
  s.characterRules.baseitems=table('WeaponType EpicWeaponOverwhelmingCriticalFeat WeaponSpecializationFeat EpicWeaponSpecializationFeat',
    Array.from({length:37},(_,i)=>`${i} 2 65535 65535 65535`).join('\n'));
  const glove=s.register('item','glove',{equipmentSlot:8,authored:{BaseItem:36,PropertiesList:[{PropertyName:82,Subtype:3}]}});
  actor.inventory.push(glove.id);
  assert.equal(await s.combat.weaponEffective(actor,target.id,0),1);
  actor.inventory=[];
  s.characterRules.iprp_damagecost=table('Rank NumDice Die','0 0 0 0\n1 5 0 5');
  actor.effects=[{type:13,spellId:-1,integers:[1,256,28,0,0,0]}];
  const resistance={id:'resistance',type:2,integers:[256,2,1,0]};target.effects=[resistance];
  assert.equal(await s.combat.weaponEffective(actor,target.id,0),1);
  assert.equal(target.effects[0],resistance);assert.equal(resistance.integers[2],1);
  assert.equal(target.stats.currentHP,30);assert.equal(s.random.draws,0);
  target.plot=true;assert.equal(await s.combat.weaponEffective(actor,target.id,0),0);
  assert.equal(s.random.draws,0);
});
