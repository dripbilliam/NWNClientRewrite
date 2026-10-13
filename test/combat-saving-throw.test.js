import test from 'node:test';
import assert from 'node:assert/strict';
import { savingThrowRoll,savingThrowWithoutEffects } from '../src/combat_saving_throw.js';
import { createCombatRound } from '../src/combat_round.js';
import { parse2da } from '../src/area.js';

const table=(columns,rows)=>parse2da(`2DA V2.0\n\n${columns}\n${rows}`);
function fixture(rolls=[10]){
  const actor={id:1,objectType:5,feats:[],combatRound:createCombatRound(),spellId:-1},caster={id:2,objectType:5,spellId:-1,combatRound:createCombatRound()},trace=[];
  const p={baseSave:()=>0,getObject:id=>id===2?caster:null,asObject:o=>o,creature:o=>o.objectType===5?o:null,areaEffect:()=>null,getCreature:id=>id===2?caster:null,
    spellId:o=>o.spellId,spell:()=>null,effectBonus:(o,s,c)=>{trace.push(['effect',s,c]);return 0;},hasFeat:(o,f)=>Number(o.feats.includes(f)),classLevel:()=>0,
    canUseSkill:()=>0,skillRank:()=>0,trapSource:()=>null,bonusLimit:()=>20,immunityTable:()=>null,effectImmunity:(o,c,v,f)=>{trace.push(['immune',c,v?.id??null,f]);return 0;},
    autoFail:()=>1,message:(type,data)=>({type,...data}),client:()=>false,broadcast:(o,m)=>trace.push(['broadcast',o.id,m]),
    random:{dice:(n,s)=>{trace.push(['die',n,s]);assert.ok(rolls.length,'Unexpected draw');return rolls.shift();}}};
  const run=(save=1,dc=10,category=0,feedback=0,feat=65535,attackFeedback=0,rules={})=>savingThrowRoll(actor,save,dc,category,2,feedback,feat,attackFeedback,rules,p);
  return{actor,caster,p,trace,run};
}
test('invalid save returns before querying providers; missing required providers fail before randomness',async()=>{
  assert.equal(await savingThrowRoll({},4,0,0,0,0,0,0,{},{}),0);
  const{p,run,trace}=fixture();delete p.baseSave;await assert.rejects(run(),/baseSave/);assert.deepEqual(trace,[]);
});
test('save base query excludes general effects without subtracting an already wrapped final total',()=>{
  const actor={stats:{combat:{finalBreakdown:{saves:{fortitude:{base:126,ability:3,authored:-2,luck:1,darkBlessing:-1,effect:{total:20},total:-109}}}}}};
  assert.equal(savingThrowWithoutEffects(actor,1),127);
  assert.equal(savingThrowWithoutEffects(actor,4),0);
  delete actor.stats.combat.finalBreakdown.saves.fortitude.ability;
  assert.throws(()=>savingThrowWithoutEffects(actor,1),/ability/);
});
test('natural one obeys auto-fail, natural twenty always succeeds, and the DC is unsigned short',async()=>{
  let f=fixture([1]);f.p.baseSave=()=>100;assert.equal(await f.run(),0);
  f=fixture([1]);f.p.baseSave=()=>100;f.p.autoFail=()=>0;assert.equal(await f.run(),1);
  f=fixture([20]);f.p.baseSave=()=>-100;assert.equal(await f.run(1,65535),1);
  f=fixture([10]);assert.equal(await f.run(1,65536+10),1);
});
test('base save narrows to signed byte, positive contextual bonuses cap but penalties have no lower cap',async()=>{
  let f=fixture([10]);f.p.baseSave=()=>128;f.p.effectBonus=()=>100;assert.equal(await f.run(1,10,0,1),0);
  assert.equal(f.trace.find(v=>v[0]==='broadcast')[2].integers[1],-108);
  f=fixture([10]);f.p.effectBonus=()=>-100;assert.equal(await f.run(1,1,0,1),0);
  assert.equal(f.trace.find(v=>v[0]==='broadcast')[2].integers[1],-100);
});
test('legacy immunity consumes d20, returns two, and skips feedback',async()=>{
  const f=fixture([1]);f.p.effectImmunity=()=>{f.trace.push(['immunity']);return 1;};
  assert.equal(await f.run(1,100,2,1),2);assert.deepEqual(f.trace.slice(-2),[['die',1,20],['immunity']]);
  assert.ok(!f.trace.some(v=>v[0]==='broadcast'));
});
test('optional immunity table replaces legacy categories and narrows the immunity byte',async()=>{
  const f=fixture([10]);f.p.immunityTable=()=>table('Immunity ImmunityOnlyIfSpell','0 258 0');f.p.effectImmunity=(o,c)=>{assert.equal(c,2);return 1;};
  assert.equal(await f.run(1,30),2);
  const g=fixture([10]);g.p.immunityTable=()=>table('Immunity ImmunityOnlyIfSpell','0 0 0\n1 0 0');g.p.effectImmunity=()=>{throw new Error('Legacy immunity must be bypassed');};
  assert.equal(await g.run(1,10,1),1);
});
test('table immunity only-if-spell requires a classified versus spell, including an AoE caster',async()=>{
  let f=fixture([10]);f.p.immunityTable=()=>table('Immunity ImmunityOnlyIfSpell','0 32 1');f.p.effectImmunity=()=>1;
  assert.equal(await f.run(),1);
  f=fixture([10]);const aoe={id:2,objectType:11,spellId:-1};f.p.getObject=()=>aoe;f.p.areaEffect=()=>({creatorId:2,spellId:44});f.p.spell=id=>{assert.equal(id,44);return{classification:2,school:0};};
  f.p.immunityTable=()=>table('Immunity ImmunityOnlyIfSpell','0 32 1');f.p.effectImmunity=(o,c,v)=>{assert.equal(v,f.caster);return 1;};
  assert.equal(await f.run(),2);
});
test('Slippery Mind recomputes providers once, reports its feat on reroll, and cannot reroll when already tagged',async()=>{
  const f=fixture([2,10]);f.actor.feats=[259];f.p.effectBonus=()=>{f.trace.push(['bonus']);return f.trace.filter(v=>v[0]==='bonus').length===1?0:10;};
  assert.equal(await f.run(3,20,1,1,65535,1),1);assert.equal(f.trace.filter(v=>v[0]==='die').length,2);
  const feedback=f.caster.combatRound.attacks[0].lists[3];assert.equal(feedback.length,2);assert.deepEqual(feedback.map(m=>m.integers[5]),[65535,259]);
  const g=fixture([1]);g.actor.feats=[259];assert.equal(await g.run(3,100,1,0,259),0);
});
test('feedback broadcasts to client and distinct caster, or attaches to the caster current record',async()=>{
  const f=fixture([10]);f.p.client=()=>true;assert.equal(await f.run(2,10,0,1,8),1);
  assert.deepEqual(f.trace.filter(v=>v[0]==='broadcast').map(v=>v[1]),[1,2]);
  const g=fixture([10]);g.caster.combatRound.currentAttack=3;assert.equal(await g.run(2,10,0,1,8,1),1);
  assert.deepEqual(g.caster.combatRound.attacks[3].lists[3][0],{type:1,objects:[1],integers:[10,0,10,2,0,8]});
  assert.ok(!g.trace.some(v=>v[0]==='broadcast'));
});
test('spell saves replace general effect part and stack Hardiness and matching Arcane Defense',async()=>{
  const f=fixture([10]);f.caster.spellId=20;f.actor.feats=[230,416];f.p.spell=()=>({classification:1,school:2});f.p.effectBonus=(o,s,c)=>({0:5,2:7,15:9})[c];
  assert.equal(await f.run(1,25,2,1),1);
  assert.equal(f.trace.find(v=>v[0]==='broadcast')[2].integers[1],15);
});
test('native poison feat progression chooses class levels over tier feats and only Fortitude receives extra resistance',async()=>{
  const f=fixture([10,10]);f.actor.feats=[229,1070,467,383,386];f.p.classLevel=()=>9;
  assert.equal(await f.run(1,22,2,1),1);assert.equal(await f.run(2,22,2,1),0);
  assert.deepEqual(f.trace.filter(v=>v[0]==='broadcast').map(v=>v[2].integers[1]),[12,6]);
});
test('trap Reflex bonuses preserve exact trap flags, highest Uncanny Dodge, and epic tie branch',async()=>{
  const f=fixture([10,10,10]);f.actor.feats=[255,251,951];f.p.classLevel=(o,c)=>c===0?26:26;f.p.trapSource=()=>({kind:'door',flag:2});
  await f.run(2,10,0,1);f.p.trapSource=()=>({kind:'placeable',flag:2});await f.run(2,10,0,1);
  f.p.hasFeat=(o,id)=>id===951?2:Number(o.feats.includes(id));await f.run(2,10,0,1);
  assert.deepEqual(f.trace.filter(v=>v[0]==='broadcast').map(v=>v[2].integers[1]),[0,8,7]);
});
test('Spellcraft uses effective signed skill divided toward zero; zero rule divisors fail before a die',async()=>{
  const f=fixture([10]);f.caster.spellId=20;f.p.spell=()=>null;f.p.canUseSkill=()=>1;f.p.skillRank=()=>249;
  await f.run(1,10,15,1);assert.equal(f.trace.find(v=>v[0]==='broadcast')[2].integers[1],-1);
  const g=fixture();g.caster.spellId=20;g.p.canUseSkill=()=>1;
  await assert.rejects(g.run(1,10,15,0,0,0,{ruleset:table('Label Value','0 SPELLCRAFT_NUM_RANKS_PER_SAVE_BONUS 0')}),/division/);
  assert.ok(!g.trace.some(v=>v[0]==='die'));
});
test('legacy death immunity checks the saving actor spell, while a versus spell alone does not qualify',async()=>{
  let f=fixture([10]);f.caster.spellId=20;f.p.spell=()=>({classification:1,school:0});f.p.effectImmunity=()=>1;
  assert.equal(await f.run(1,10,11),1);
  f=fixture([10]);f.actor.spellId=20;f.p.spell=()=>({classification:2,school:0});f.p.effectImmunity=(o,c)=>{assert.equal(c,32);return 1;};
  assert.equal(await f.run(1,10,11),2);
});
test('active ruleset labels override the native mind/fear/disease/death bonus defaults',async()=>{
  const f=fixture([10,10,10,10]);f.actor.feats=[208,439,241,236,249,202,426,388];
  const rules={ruleset:table('Label Value','0 STILL_MIND_COMPETANCE_BONUS 3\n1 LLIIRAS_HEART_SAVE_BONUS 4\n2 HARDINESS_SAVE_BONUS 5\n3 RESIST_NATURES_LURE_SAVE_BONUS 6\n4 RESIST_DISEASE_BONUS 7\n5 STRONG_SOUL_SAVE_VS_DEATH_BONUS 8')};
  for(const category of [1,4,3,11])await f.run(1,10,category,1,0,0,rules);
  assert.deepEqual(f.trace.filter(v=>v[0]==='broadcast').map(v=>v[2].integers[1]),[12,8,7,8]);
});
