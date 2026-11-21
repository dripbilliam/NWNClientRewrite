import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {saveCreatureClassInfo} from '../src/creature_class_save.js';
import {writeGff} from '../src/gff_writer.js';
import {parseGff,getGffFieldTypes,getGffStructType} from '../src/gff.js';

const observations=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-creature-class-save-observations.json',import.meta.url)));
function providers(c,calls){return{
  classes:()=>c.classes,classDefinition:id=>c.classes.find(x=>x.Class===id).definition,
  perDay:(i,l)=>c.classes[i].perDay[l],known:(i,l)=>c.classes[i].known[l],memorized:(i,l)=>c.classes[i].memorized[l],
  histories:()=>c.histories,isPC:()=>c.isPC,totalLevel:()=>c.classes.reduce((sum,c)=>sum+c.ClassLevel,0),
  historySpells:(h,p,l)=>h[p][l],historySkill:(h,i)=>h.skills[i],historyFeats:h=>h.feats,
  associate:name=>c[name],skillPoints:()=>c.skillPoints,skillCount:()=>c.skills.length,
  skillRank:(i,t,b)=>{calls.push(['skill',i,0,b]);assert.equal(t,null);return c.skills[i];},
  feats:()=>c.feats,featRemainingUses:id=>{calls.push(['feat',id]);return c.uses[id]??100;},abilities:()=>c.abilities,
};}
test('complete SaveClassInfo matches original fields, widths, struct IDs and lower calls',async()=>{
  assert.equal(observations.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
  for(const {case:c,output,calls:expected,wrapped} of observations.cases){
    const calls=[],p=providers(c,calls);
    if(wrapped){await assert.rejects(saveCreatureClassInfo(p),/known-spell cursor would wrap/,c.name);continue;}
    const actual=await saveCreatureClassInfo(p);assert.deepEqual(actual,output,c.name);assert.deepEqual(calls,expected,c.name);
  }
});
test('native class save writes a readable GFF without allocating game object IDs',async()=>{
  const c=observations.cases.find(x=>x.case.name==='all-fields').case;
  const tree=await saveCreatureClassInfo(providers(c,[])),bytes=writeGff('UTC ',tree),root=parseGff(bytes,'UTC ').root;
  assert.equal(getGffFieldTypes(root.ClassList[0]).Class,5);
  assert.equal(getGffFieldTypes(root.ClassList[0]).ClassLevel,3);
  assert.equal(getGffStructType(root.ClassList[0].SpellsPerDayList[0]),0x4567);
  assert.equal(getGffStructType(root.ClassList[1].MemorizedList2[0]),3);
  assert.equal(root.ClassList[1].MemorizedList2[0].Ready,2);
  assert.equal(root.ClassList[1].MemorizedList2[0].DomainSpell,1);
  assert.equal(root.ClassList[1].MemorizedList2.length,2);
  assert.ok(!('LvlStatAbility'in root.LvlStatList[0]));
  assert.ok(!('LvlStatAbility'in root.LvlStatList[2]));
  assert.equal(root.LvlStatList[1].LvlStatAbility,2);
  assert.ok(!('Uses'in root.FeatList[0]));
  assert.equal(root.FeatList[1].Uses,0);assert.equal(root.FeatList[2].Uses,1);
  assert.equal(root.SpecAbilityList[0].Spell,0x5678);assert.equal(root.SpecAbilityList[0].SpellFlags,2);
  assert.ok(!('ObjectId'in root));
});
test('missing live storage is diagnosed instead of producing a stale-resource save',async()=>{
  const c=structuredClone(observations.cases[0].case),p=providers(c,[]);
  p.known=()=>undefined;await assert.rejects(saveCreatureClassInfo(p),/known spell storage is unavailable/);
  p.known=()=>[];c.isPC=1;await assert.rejects(saveCreatureClassInfo(p),/level-history record is unavailable/);
});
