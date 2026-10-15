import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import { creationAlignmentAllowed,abilityPointCost,creationSkillBudget,creationSkillRule,creationFeatListAllows,creationFeatRequirements,creationGrantedFeats,initializeCreationAbilities,creationAbilityCanDecrease } from '../src/character_creation.js';
import { gffField as f,gffRecord as record,writeGff,typedGff,encodeGffText } from '../src/gff_writer.js';
import { parseGff,cloneGff,getGffStructType,getGffFieldTypes } from '../src/gff.js';
import { ABILITIES } from '../src/character.js';
import { describeCharacter } from '../src/character_vault.js';
const table=orderedRows=>({orderedRows,rows:new Map(orderedRows.map((r,i)=>[i,r]))});
const ruleset=values=>table(Object.entries(values).map(([Label,Value])=>({Label,Value:String(Value)})));
const oraclePath=new URL('../backups/animations/native-character-creation-observations.json',import.meta.url);

test('creation alignment matches 2304 original CNWClass executions', {skip:!fs.existsSync(oraclePath)},()=>{
  const observed=JSON.parse(fs.readFileSync(oraclePath));assert.equal(observed.alignment.length,2304);
  for(const c of observed.alignment)assert.equal(Number(creationAlignmentAllowed({AlignRestrict:c.mask,AlignRstrctType:c.axes,InvertRestrict:c.invert},c.goodEvil,c.lawChaos)),c.result,JSON.stringify(c));
});
test('ability increments match original client helper across stock and changed rulesets',{skip:!fs.existsSync(oraclePath)},()=>{
  for(const c of JSON.parse(fs.readFileSync(oraclePath)).increments){const rules={ruleset:ruleset({CHARGEN_BASE_ABILITY_MAX:20,CHARGEN_ABILITY_COST_INCREMENT2:c.thresholds[0],CHARGEN_ABILITY_COST_INCREMENT3:c.thresholds[1],CHARGEN_ABILITY_COST_INCREMENT4:c.thresholds[2]})};assert.equal(abilityPointCost(c.score+1,rules)-abilityPointCost(c.score,rules),c.result);}
});
test('native point buy totals, limits and expensive purchases',()=>{
  assert.deepEqual([8,14,15,16,17,18].map(n=>abilityPointCost(n,{})),[0,6,8,10,13,16]);assert.equal(abilityPointCost(19,{}),Infinity);assert.equal(abilityPointCost(7,{}),Infinity);assert.equal(abilityPointCost(NaN,{}),Infinity);
});
function fixture(){
  const rules={racialtypes:table([{FeatsTable:'race',IntAdjust:'2',ExtraSkillPointsPerLevel:'1',FirstLevelSkillPointsMultiplier:'4',SkillPointModifierAbility:'INT'}]),classes:table([{SkillsTable:'skills',FeatsTable:'feats',SkillPointBase:'2',AttackBonusTable:'bab',SavingThrowTable:'saves'}]),
    skills:table([{AllClassesCanUse:0},{AllClassesCanUse:1},{AllClassesCanUse:0}]),feat:table([{FEAT:1,ALLCLASSESCANUSE:1},{FEAT:2,ALLCLASSESCANUSE:0},{FEAT:3,ALLCLASSESCANUSE:1}]),creationTables:new Map([['race',table([{FeatIndex:5}])]]),classTables:new Map([['skills',table([{SkillIndex:0,ClassSkill:1},{SkillIndex:1,ClassSkill:0}])],['feats',table([{FeatIndex:0,List:1,GrantedOnLevel:1},{FeatIndex:1,List:3,GrantedOnLevel:1},{FeatIndex:2,List:2,GrantedOnLevel:-1}])],['bab',table([{BAB:1}])],['saves',table([{FortSave:2}])]])};
  const d={raceId:0,classId:0,domains:[],abilities:Object.fromEntries(ABILITIES.map(a=>[a,14])),skills:{}};return{d,rules};
}
test('first-level skill budget interprets ability names, racial adjustments and multiplier',()=>{
  const{d,rules}=fixture();assert.equal(creationSkillBudget(d,rules),24);rules.racialtypes.orderedRows[0].SkillPointModifierAbility='WIS';assert.equal(creationSkillBudget(d,rules),20);d.abilities.Wis=8;rules.racialtypes.orderedRows[0].ExtraSkillPointsPerLevel='0';assert.equal(creationSkillBudget(d,rules),4);
});
test('class/cross-class costs and unavailable skills follow active class table',()=>{
  const{d,rules}=fixture();assert.deepEqual(creationSkillRule(d,rules,0),{allowed:true,classSkill:true,cost:1,max:4});assert.deepEqual(creationSkillRule(d,rules,1),{allowed:true,classSkill:false,cost:2,max:2});assert.equal(creationSkillRule(d,rules,2).allowed,false);
});
test('caster minimum follows adjusted SpellcastingAbil; martial PrimaryAbil remains optional',()=>{
  const{d,rules}=fixture();Object.assign(rules.classes.orderedRows[0],{PrimaryAbil:'STR',SpellCaster:1,SpellcastingAbil:'INT'});initializeCreationAbilities(d,rules);assert.equal(d.abilities.Int,9);assert.equal(d.abilities.Str,8);assert.equal(creationAbilityCanDecrease(d,rules,'Int'),false);d.abilities.Int++;assert.equal(creationAbilityCanDecrease(d,rules,'Int'),true);
  rules.classes.orderedRows[0].SpellCaster=0;initializeCreationAbilities(d,rules);assert.equal(d.abilities.Str,8);assert.equal(d.abilities.Int,8);
});
test('GrantedOnLevel does not turn normal/bonus entries into automatic feats',()=>{
  const{d,rules}=fixture();assert.deepEqual(creationGrantedFeats(d,rules),[1]);assert.equal(creationFeatListAllows(d,rules,0,'normal'),true);assert.equal(creationFeatListAllows(d,rules,0,'bonus'),true);assert.equal(creationFeatListAllows(d,rules,2,'bonus'),true);assert.equal(creationFeatListAllows(d,rules,2,'normal'),false);
});
test('feat prerequisites see adjusted abilities, prior feats and purchased ranks',()=>{
  const{d,rules}=fixture();Object.assign(rules.feat.orderedRows[0],{MININT:16,PREREQFEAT1:1,REQSKILL:0,ReqSkillMinRanks:4});assert.match(creationFeatRequirements(d,rules,0,[1]),/Skill ranks/);d.skills[0]=4;assert.equal(creationFeatRequirements(d,rules,0,[1]),null);assert.match(creationFeatRequirements(d,rules,0,[]),/Feat 1/);d.abilities.Int=13;assert.match(creationFeatRequirements(d,rules,0,[1]),/Int 16/);
});
test('browser GFF writer preserves signed widths, localized text and equipment struct metadata',()=>{
  const bytes=writeGff('BIC ',record({Name:f(12,'Éowyn €'),Signed:f(3,-7),Counter:f(6,0x123456789abcdef0n),Vector:f(17,[1,2,3]),Equip_ItemList:f(15,[record({BaseItem:f(5,16),Identified:f(0,1)},2)])}));
  const root=parseGff(bytes).root;assert.equal(root.Name.entries[0].text,'Éowyn €');assert.equal(root.Signed,-7);assert.equal(root.Counter,0x123456789abcdef0n);assert.equal(getGffStructType(root.Equip_ItemList[0]),2);
  const copied=cloneGff(root),roundtrip=parseGff(writeGff('BIC ',typedGff(copied))).root;assert.deepEqual(roundtrip,root);assert.deepEqual(getGffFieldTypes(roundtrip),getGffFieldTypes(root));assert.equal(getGffStructType(roundtrip.Equip_ItemList[0]),2);
});
test('GFF writer rejects lossy text, long labels, resrefs and overflowing fields',()=>{
  assert.throws(()=>encodeGffText('😀'),/cannot be saved/);assert.throws(()=>writeGff('BIC ',record({Bad:f(0,256)})),/range/);assert.throws(()=>writeGff('BIC ',record({TooLongLabelForGFF:f(0,1)})),/label/);assert.throws(()=>writeGff('BIC ',record({Portrait:f(11,'12345678901234567')})),/too long/);
});
test('selector refuses an arbitrary GFF as a playable character',()=>{
  assert.throws(()=>describeCharacter(writeGff('BIC ',record({IsPC:f(0,0)})),'invalid.bic'),/not a player/);
});
