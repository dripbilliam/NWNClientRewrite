import test from 'node:test';
import assert from 'node:assert/strict';
import { effectiveSkillRank,canUseSkill,skillInfo } from '../src/skill_rank.js';
import { parse2da } from '../src/area.js';
const table=(columns,rows)=>parse2da(`2DA V2.0\n\n${columns}\n${rows}`);
function fixture(){
  const rows=Array.from({length:27},(_,id)=>`${id} DEX 1 0`).join('\n');
  const rules={skills:table('KeyAbility Untrained ArmorCheckPenalty',rows)},object={feats:[],rank:10,classes:[]},trace=[];
  const p={isDM:()=>0,rawRank:o=>o.rank,effectBonus:()=>{trace.push('effects');return 0;},abilityModifier:(o,a)=>{trace.push(['ability',a]);return 2;},
    blind:()=>{trace.push('blind');return 0;},armorPenalties:()=>[0,0],hasFeat:(o,f)=>Number(o.feats.includes(f)),area:()=>null,classes:o=>o.classes,classPenalties:()=>[],
    baseRank:o=>o.rank,classSkillUsable:()=>0};
  const run=(skill=10,base=0)=>effectiveSkillRank(object,skill,null,base,rules,p);
  return{object,rules,p,trace,run};
}
test('skill loader selects exact ability spelling, native STR fallback, and integer defaults',()=>{
  const rules={skills:table('KeyAbility Untrained ArmorCheckPenalty','0 DEX 1 1\n1 dex 0 2\n2 **** **** ****')};
  assert.deepEqual(skillInfo(rules,0),{ability:1,untrained:1,armorCheckPenalty:1});
  assert.deepEqual(skillInfo(rules,1),{ability:0,untrained:0,armorCheckPenalty:2});
  assert.deepEqual(skillInfo(rules,2),{ability:0,untrained:0,armorCheckPenalty:0});
});
test('invalid indices precede DM override; base-only and zero-trained-rank gates require no effective providers',async()=>{
  const f=fixture();f.p.isDM=()=>1;assert.equal(await f.run(27),0);assert.equal(await f.run(10),127);
  f.p.isDM=()=>0;f.object.rank=128;assert.equal(await effectiveSkillRank(f.object,10,null,1,f.rules,{isDM:f.p.isDM,rawRank:f.p.rawRank}),-127);
  f.object.rank=0;f.rules.skills.orderedRows[10].Untrained='0';assert.equal(await effectiveSkillRank(f.object,10,null,0,f.rules,{isDM:f.p.isDM,rawRank:f.p.rawRank}),0);
  f.object.rank=-1;await assert.rejects(effectiveSkillRank(f.object,10,null,0,f.rules,{isDM:f.p.isDM,rawRank:f.p.rawRank}),/effectBonus/);
});
test('skills use effect then signed ability, blindness only for STR/DEX, and exact armor-penalty flag',async()=>{
  const f=fixture();f.p.effectBonus=()=>3;f.p.blind=()=>1;f.p.armorPenalties=()=>[-127,-2];f.rules.skills.orderedRows[10].ArmorCheckPenalty='1';
  assert.equal(await f.run(),127,'Armor sum wraps to +127 before addition');
  f.rules.skills.orderedRows[10].ArmorCheckPenalty='2';assert.equal(await f.run(),11);
  f.rules.skills.orderedRows[10].KeyAbility='CON';assert.equal(await f.run(),15);
});
test('Parry and Spellcraft apply native focus IDs and skill-specific bonuses with active ruleset values',async()=>{
  const f=fixture();f.object.feats=[183,599,18,189,605,381];assert.equal(await f.run(10),29);assert.equal(await f.run(16),27);
  f.rules.ruleset=table('Label Value','0 SKILL_FOCUS_SKILL_BONUS 4\n1 EPIC_SKILL_FOCUS_SKILL_BONUS 12\n2 IMPROVED_PARRY_MODIFIER 6\n3 COURTEOUS_MAGOCRACY_LORE_BONUS 7');
  assert.equal(await f.run(10),34);assert.equal(await f.run(16),35);
});
test('Hide and Move Silently require outdoor natural area flags for Trackless Step; search Stonecunning needs interior bit',async()=>{
  const f=fixture();f.object.feats=[201,227,387];f.p.area=()=>({flags:4});assert.equal(await f.run(5),18);assert.equal(await f.run(8),18);assert.equal(await f.run(14),12);
  f.p.area=()=>({flags:6});assert.equal(await f.run(5),14);assert.equal(await f.run(14),14);
});
test('Bard Knowledge uses native Bard and Harper class IDs and byte levels',async()=>{
  const f=fixture();f.object.feats=[197];f.object.classes=[{Class:1,ClassLevel:5},{Class:28,ClassLevel:3},{Class:4,ClassLevel:30}];f.p.classPenalties=()=>[0,0,0];
  assert.equal(await f.run(7),20);f.object.classes[0].ClassLevel=261;assert.equal(await f.run(7),20);
});
test('native class penalty bytes are subtracted after all skill bonuses and final range saturates',async()=>{
  const f=fixture();f.object.classes=[{},{}];f.p.classPenalties=()=>[257,2];assert.equal(await f.run(),9);
  f.p.effectBonus=()=>200;assert.equal(await f.run(),127);
  f.p.effectBonus=()=>-200;assert.equal(await f.run(),-127);
});
test('Listen and Spot receive Alertness, racial affinity and partial focus; Spot adds Artist and Blooded',async()=>{
  const f=fixture();f.object.feats=[0,237,244,239,246,379,378];assert.equal(await f.run(6),17);assert.equal(await f.run(17),21);
});
test('Epic Reputation applies only the native persuade/intimidate/bluff/taunt gates',async()=>{
  const f=fixture();f.object.feats=[586];for(const skill of [12,18,23,24])assert.equal(await f.run(skill),16);for(const skill of [10,16,25,26])assert.equal(await f.run(skill),12);
});
test('class penalty records cannot silently change count or substitute another class slot',async()=>{
  const f=fixture();f.object.classes=[{Class:4,ClassLevel:3}];
  await assert.rejects(f.run(),/class penalty count/);
  f.p.classPenalties=()=>[undefined];await assert.rejects(f.run(),/class penalty/);
});
test('GetCanUseSkill requires strictly positive trained base rank or a usable class for untrained skills',async()=>{
  const f=fixture();f.rules.skills.orderedRows[16].Untrained='0';assert.equal(await canUseSkill(f.object,16,f.rules,f.p),1);
  f.object.rank=-1;assert.equal(await canUseSkill(f.object,16,f.rules,f.p),0);
  f.object.classes=[{Class:4,ClassLevel:1},{Class:10,ClassLevel:1}];f.p.classSkillUsable=(c,s)=>Number(c===10&&s===10);
  assert.equal(await canUseSkill(f.object,10,f.rules,f.p),1);
});
test('special skill IDs 100..102 validate skill two but keep original class usability query',async()=>{
  const f=fixture();f.object.classes=[{Class:4}];f.p.classSkillUsable=(c,s)=>{assert.equal(c,4);assert.ok(s>=100&&s<=102);return 1;};
  for(const id of [100,101,102])assert.equal(await canUseSkill(f.object,id,f.rules,f.p),1);
  assert.equal(await canUseSkill(f.object,103,f.rules,f.p),0);
});
