import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { FeatUsePool, featInfo, hasNativeFeat, highestFeat, featUses, setFeatRemainingUses, addNativeFeat, removeNativeFeat, initializeFeatUses } from '../src/feat_uses.js';
import { ModuleSession } from '../src/module_session.js';
import { createCombatRound } from '../src/combat_round.js';

function fixture(overrides={},feats=[223],classes=[{Class:4,ClassLevel:11}]) {
  const rows=Array.from({length:1100},(_,id)=>`${id} ${id} ${overrides[id]?.uses??1} ${overrides[id]?.next??'****'}`);
  const rules={feat:parse2da('2DA V2.0\n\nFeat UsesPerDay SUCCESSOR\n'+rows.join('\n'))};
  const o={id:1,objectType:5,isDM:false,creatureData:{FeatList:feats.map(Feat=>({Feat})),ClassList:classes},stats:{feats:[...feats]},featUsePool:new FeatUsePool()};
  const warnings=[],p={hasFeat:(o,f)=>hasNativeFeat(o,f,()=>0),isDM:o=>Number(o.isDM),charismaModifier:()=>2,warning:m=>warnings.push(m)};
  const uses=(f,remaining=true)=>featUses(o,f,rules,p,remaining);
  const add=f=>addNativeFeat(o,f,rules,p);
  return{o,rules,p,uses,add,warnings};
}

test('feat loader uses physical rows, presence of Feat, ctor defaults and native byte/ushort narrowing',()=>{
  const rules={feat:parse2da('2DA V2.0\n\nFeat UsesPerDay SUCCESSOR\n400 999 0x101 0x10002\n20 **** 4 5\n88 5 **** ****')};
  assert.deepEqual(featInfo(rules,0),{uses:1,successor:2});assert.equal(featInfo(rules,1),null);
  assert.deepEqual(featInfo(rules,2),{uses:0,successor:65535});assert.equal(featInfo(rules,400),null);
  const missing={feat:parse2da('2DA V2.0\nDEFAULT: 7\n\nFeat\n0 1')};
  assert.deepEqual(featInfo(missing,0),{uses:0,successor:65535});
});

test('native ownership includes pending feats and Ranger grants only while chest AC is below four',()=>{
  const {o}=fixture({},[],[{Class:7,ClassLevel:1}]);
  assert.equal(hasNativeFeat(o,1,()=>3),1);assert.equal(hasNativeFeat(o,41,()=>4),0);
  assert.equal(hasNativeFeat(o,41,()=>-1),1);assert.throws(()=>hasNativeFeat(o,1),/armor provider/);
  o.pendingFeats=[1];assert.equal(hasNativeFeat(o,1,()=>6),1);
  o.creatureData.FeatList.push({Feat:41});assert.equal(hasNativeFeat(o,41,()=>6),1);
});

test('feat-use pool owns four-byte spent records and grows 16 then doubles without replacing records',()=>{
  const pool=new FeatUsePool(),record=pool.append(65537,255);
  assert.equal(pool.capacity,16);assert.equal(record.getUint16(0,true),1);assert.equal(record.getUint8(2),255);
  pool.decrement(1);assert.equal(record.getUint8(2),0);
  for(let id=2;id<=17;id++)pool.append(id);assert.equal(pool.capacity,32);assert.equal(pool.find(1),record);
  pool.append(1,8);pool.decrement(1);assert.equal(record.getUint8(2),1);assert.equal(pool.records.at(-1).getUint8(2),9);
  pool.reset();assert.ok(pool.records.every(r=>r.getUint8(2)===0));
  pool.remove(1);assert.equal(pool.find(1),record);assert.equal(pool.capacity,32);
});

test('invalid feat precedes DM; total does not use the remaining-query DM shortcut',()=>{
  const {o,uses,warnings}=fixture();o.isDM=true;
  assert.equal(uses(60000),0);assert.equal(warnings.length,1);assert.equal(uses(5),100);assert.equal(uses(5,false),0);
  o.isDM=false;assert.equal(uses(223),100);o.featUsePool.append(223);assert.equal(uses(223),1);
  o.featUsePool.decrement(223);assert.equal(uses(223),0);assert.equal(uses(223,false),1);
});

test('setting remaining encodes total-minus-requested and retains native absent-pool total100 quirk',()=>{
  const {o,rules,p,uses,add}=fixture({223:{uses:8}});add(223);
  setFeatRemainingUses(o,223,3,rules,p);assert.equal(o.featUsePool.find(223).getUint8(2),5);assert.equal(uses(223),3);
  setFeatRemainingUses(o,223,100,rules,p);assert.equal(uses(223),8);
  o.creatureData.FeatList.push({Feat:39});setFeatRemainingUses(o,39,2,rules,p);
  assert.equal(o.featUsePool.find(39).getUint8(2),98);assert.equal(uses(39),0);
  setFeatRemainingUses(o,65000,2,rules,p);assert.equal(o.featUsePool.find(65000).getUint8(2),0);
});

test('saved Uses restores remaining charges after AddFeat; missing Uses starts fresh and duplicates reuse storage',()=>{
  const {o,rules,p,uses}=fixture({223:{uses:4},5:{uses:0}},[223,5]);delete o.featUsePool;
  o.creatureData.FeatList=[{Feat:223,Uses:2},{Feat:223,Uses:1},{Feat:5,Uses:6},{Feat:39}];
  const source=structuredClone(o.creatureData.FeatList);initializeFeatUses(o,rules,p);
  assert.equal(uses(223),1);assert.equal(uses(39),3);assert.equal(uses(5),0);
  assert.equal(o.featUsePool.records.length,3);assert.deepEqual(o.creatureData.FeatList,source);
  assert.throws(()=>initializeFeatUses(o,rules,p),/already initialized/);
});

test('music maximum reads active ruleset, epic Bard level and wraps before spending/cap100',()=>{
  const {o,rules,uses,add}=fixture({257:{uses:250}},[257,423],[{Class:1,ClassLevel:25}]);add(257);
  assert.equal(uses(257),3);o.featUsePool.decrement(257);assert.equal(uses(257),2);
  rules.ruleset=parse2da('2DA V2.0\n\nLabel Value\n0 EXTRA_MUSIC_BONUS_USES 7');
  assert.equal(uses(257),5);assert.equal(uses(257,false),6);
});

test('stunning uses Monk levels or ceil total/4; extra feat requires exactly one',()=>{
  const {o,p,uses,add}=fixture({39:{uses:9}},[39,410],[{Class:4,ClassLevel:8},{Class:2,ClassLevel:1}]);add(39);
  assert.equal(uses(39),6);o.creatureData.ClassList=[{Class:5,ClassLevel:17}];assert.equal(uses(39),20);
  p.hasFeat=(o,f)=>f===410?2:hasNativeFeat(o,f,()=>0);assert.equal(uses(39),17);
});

test('turning uses signed Charisma and configurable extras; byte underflow precedes cap',()=>{
  const {p,uses,add,o}=fixture({294:{uses:1}},[294,13]);add(294);assert.equal(uses(294),11);
  p.charismaModifier=()=>255;o.creatureData.FeatList=o.creatureData.FeatList.filter(e=>e.Feat!==13);assert.equal(uses(294),2);
  p.charismaModifier=()=>-5;assert.equal(uses(294),100);o.featUsePool.find(294).setUint8(2,200);assert.equal(uses(294),54);
});

test('native class-derived rage, Harper, Weapon Master, Pale Master and defender budgets preserve signed division',()=>{
  const {o,uses,add}=fixture({331:{uses:6},441:{uses:2},442:{uses:2},443:{uses:2},444:{uses:2},882:{uses:3},893:{uses:6},947:{uses:9}},[331,441,442,443,444,882,893,947],
    [{Class:0,ClassLevel:17},{Class:28,ClassLevel:12},{Class:33,ClassLevel:7},{Class:34,ClassLevel:8},{Class:36,ClassLevel:5}]);
  for(const f of o.stats.feats)add(f);
  assert.deepEqual(o.stats.feats.map(f=>uses(f)),[6,5,4,4,4,21,6,3]);
  o.creatureData.ClassList=[];assert.equal(uses(331),1);assert.equal(uses(893),3);assert.equal(uses(882),3);assert.equal(uses(947),9);
});

test('smite extras and native unlimited-feat gates ignore spent records when active',()=>{
  const gates=[[304,1069],[340,1069],[305,1068],[335,1068],[898,1062],[900,1063],[901,1064],[902,1066],[903,1065]];
  const {o,uses,add}=fixture({},[301,472,910,...gates.flat()]);
  add(301);add(472);assert.equal(uses(301),3);assert.equal(uses(472),3);
  for(const [f,gate]of gates){add(f);o.featUsePool.find(f).setUint8(2,255);assert.equal(uses(f),100);assert.equal(uses(f,false),100);
    o.creatureData.FeatList=o.creatureData.FeatList.filter(e=>e.Feat!==gate);assert.equal(uses(f),0);o.creatureData.FeatList.push({Feat:gate});}
});

test('highest feat follows unowned intermediate successors, special aliases and diagnoses cycles',()=>{
  const {o,rules,p}=fixture({257:{next:355},355:{next:356},356:{next:357},5:{next:6}},[257,356,5]);
  assert.equal(highestFeat(o,257,rules,p),356);assert.equal(highestFeat(o,65000,rules,p),65000);
  assert.equal(highestFeat(o,99,rules,p),65535);
  const cyc=fixture({10:{next:11},11:{next:10}},[10]);assert.throws(()=>highestFeat(cyc.o,10,cyc.rules,cyc.p),/cycle/);
});

test('feat871 alias total ALSO returns remaining highest song uses; own pool gate comes first',()=>{
  const {o,rules,p,uses,add}=fixture({257:{next:355,uses:2},355:{uses:7}},[257,355,871]);
  assert.equal(uses(871),100);for(const f of [257,355,871])add(f);
  setFeatRemainingUses(o,355,3,rules,p);assert.equal(uses(871),3);assert.equal(uses(871,false),3);
  assert.equal(uses(355,false),7);
});

test('RemoveFeat removes the last spent record; regrant starts fresh without replacing pool',()=>{
  const {o,rules,p,uses,add}=fixture({223:{uses:4}});add(223);const pool=o.featUsePool;
  pool.decrement(223);removeNativeFeat(o,223);assert.equal(uses(223),0);assert.equal(pool.records.length,0);
  add(223);assert.equal(o.featUsePool,pool);assert.equal(uses(223),4);assert.deepEqual(o.stats.feats,[223]);
});

test('native script queries follow successors, respect exhausted uses and map100 to INT_MAX',()=>{
  const {o,rules,p,add}=fixture({223:{uses:1},257:{next:355},355:{uses:4}},[223,257,355,5]);
  for(const f of o.stats.feats)if(f!==5)add(f);
  const s=new ModuleSession({});s.characterRules=rules;
  const actor=s.register('creature','actor',o);actor.featUsePool=o.featUsePool;
  assert.equal(s.commands.GetFeatRemainingUses([257,actor.id]),4);
  assert.equal(s.commands.GetFeatRemainingUses([5,actor.id]),2147483647);
  assert.equal(s.commands.GetHasFeat([223,actor.id]),1);s.combat.decrementUses(actor,223);
  assert.equal(s.commands.GetHasFeat([223,actor.id]),0);assert.equal(s.commands.GetHasFeat([223,actor.id,1]),1);
  assert.equal(s.commands.GetFeatRemainingUses([223,actor.id]),0);assert.equal(s.commands.GetHasFeat([223,999]),0);
  s.commands.DecrementRemainingFeatUses([actor.id,223]);assert.equal(actor.featUsePool.find(223).getUint8(2),1);
  s.commands.IncrementRemainingFeatUses([actor.id,223]);assert.equal(s.commands.GetFeatRemainingUses([223,actor.id]),1);
  s.commands.IncrementRemainingFeatUses([actor.id,223]);assert.equal(actor.featUsePool.find(223).getUint8(2),0);
});

test('live Defensive Roll consumes canonical feat pool once and does not commit victim HP',async()=>{
  const {o,rules,add}=fixture({223:{uses:1}});add(223);const s=new ModuleSession({});s.characterRules=rules;
  const attacker=s.register('creature','a',{creatureData:{FeatList:[],ClassList:[{Class:4,ClassLevel:1}]},stats:{feats:[]},combatRound:createCombatRound(),inventory:[]});
  const target=s.register('creature','t',{...o,stats:{...o.stats,currentHP:5},combatRound:createCombatRound(),inventory:[],plot:false});
  const data=attacker.combatRound.attacks[0];data.result=1;const trace=[];
  const providers={flatFooted:()=>0,damageRoll:()=>8,savingThrow:(o,save,dc,cat,versus,feedback,feat)=>{trace.push([save,dc,feat]);return 1;},
    deathAttack:()=>{throw new Error('unexpected death attack');},rangedEquipped:()=>0,energyBonus:()=>{},onHit:()=>{},itemCastSpell:()=>{},onHitVisuals:()=>{}};
  await s.combat.resolveDamage(attacker,target,providers);assert.equal(data.damage[12],4);assert.equal(s.combat.remainingUses(target,223),0);
  data.result=1;await s.combat.resolveDamage(attacker,target,providers);assert.equal(data.damage[12],8);assert.deepEqual(trace,[[2,8,223]]);assert.equal(target.stats.currentHP,5);
});
