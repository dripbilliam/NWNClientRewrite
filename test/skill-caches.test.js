import test from 'node:test';
import assert from 'node:assert/strict';
import { parse2da } from '../src/area.js';
import { initializeSkillArmorPenalties, initializeClassSkillPenalties, classSkillUsable } from '../src/skill_caches.js';
import { ModuleSession } from '../src/module_session.js';

const table=(columns,rows)=>parse2da(`2DA V2.0\n\n${columns}\n${rows}`);
const rules=()=>({parts_chest:table('ACBonus','0 0\n1 1.9\n2 8'),armor:table('ACCHECK','0 0\n1 -2\n2 -3\n8 -6'),
  baseitems:table('ArmorCheckPen',Array.from({length:58},(_,id)=>`${id} ${id===14?-1:id===56?-2:id===57?-10:0}`).join('\n'))});
test('initial chest penalty truncates float32 ACBonus before active armor ACCHECK query; shield uses ArmorCheckPen',()=>{
  const a={},r=rules(),items=[{slot:2,data:{BaseItem:16,ArmorPart_Torso:1}},{slot:32,data:{BaseItem:57}}];
  assert.deepEqual(initializeSkillArmorPenalties(a,items,r),[-2,-10]);
  r.armor.orderedRows[1].ACCHECK='-258';const b={};assert.deepEqual(initializeSkillArmorPenalties(b,items,r),[-2,-10]);
  const retained=a.skillArmorPenalties;retained[0]=-9;assert.equal(initializeSkillArmorPenalties(a,[],r),retained);assert.equal(retained[0],-9);
});
test('missing torso float leaves native initialized zero; nonshield left hand has no armor penalty',()=>{
  const r=rules();r.parts_chest.orderedRows[0].ACBonus='****';
  assert.deepEqual(initializeSkillArmorPenalties({},[{slot:2,data:{}},{slot:32,data:{BaseItem:1}}],r),[0,0]);
  assert.deepEqual(initializeSkillArmorPenalties({},[],{}),[0,0]);
  assert.throws(()=>initializeSkillArmorPenalties({},[{slot:2,data:{}}],{}),/armor skill cache/);
});
test('class penalty bytes initialize once on each mutable record and retain native slot identity',()=>{
  const first={Class:4,ClassLevel:1},second={Class:10,ClassLevel:2,skillPenaltyByte:2},a={creatureData:{ClassList:[first,second]}};
  initializeClassSkillPenalties(a);assert.equal(first.skillPenaltyByte,0);assert.equal(second.skillPenaltyByte,2);
  a.creatureData.ClassList.reverse();initializeClassSkillPenalties(a);assert.equal(a.creatureData.ClassList[0],second);assert.equal(second.skillPenaltyByte,2);
});
test('class use checks active AllClassesCanUse, ushort SkillIndex physical rows and disregards ClassSkill flag',()=>{
  const r={skills:table('AllClassesCanUse','0 1\n1 0\n2 0'),classes:table('SkillsTable','0 cls_test\n1 ****'),
    classTables:new Map([['cls_test',table('SkillIndex ClassSkill','99 1 0\n77 65538 1')]])};
  assert.equal(classSkillUsable(r,1,0),1);assert.equal(classSkillUsable(r,0,1),1);assert.equal(classSkillUsable(r,0,2),1);
  assert.equal(classSkillUsable(r,1,2),0);const warnings=[];assert.equal(classSkillUsable(r,0,100,m=>warnings.push(m)),0);assert.equal(warnings.length,1);
  r.classTables=new Map();assert.throws(()=>classSkillUsable(r,0,1),/table cls_test/);
});
test('live script effective Parry uses ability, active armor cache, effects and class penalties',async()=>{
  const s=new ModuleSession({},{});s.characterRules={skills:table('KeyAbility Untrained ArmorCheckPenalty',Array.from({length:22},(_,i)=>`${i} DEX 1 1`).join('\n'))};
  const a=s.register('creature','a',{creatureData:{ClassList:[{Class:4,skillPenaltyByte:2}],FeatList:[]},
    stats:{skills:Array(22).fill(4),equippedAbilities:{Dex:14},feats:[]},skillArmorPenalties:[-3,-1]});
  assert.equal(await s.commands.GetSkillRank([10,a.id,0],{}),0);
  a.skillArmorPenalties=[0,0];assert.equal(await s.commands.GetSkillRank([10,a.id,0],{}),4);
  a.effects=[{type:55,integers:[10,5,28,0,0]}];assert.equal(await s.commands.GetSkillRank([10,a.id,0],{}),9);
  assert.equal(s.commands.GetSkillRank([10,a.id,1],{}),4);
});
