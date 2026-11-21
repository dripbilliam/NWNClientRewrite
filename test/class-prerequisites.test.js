import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {meetsClassPrerequisites} from '../src/class_prerequisites.js';
import {creationClassRequirement,initialCreationDraft,creationSpellOptions} from '../src/character_creation.js';
const table=orderedRows=>({orderedRows,rows:new Map(orderedRows.map((r,i)=>[i,r]))});
test('prerequisite dispatch agrees with original code across typed provider boundaries',()=>{
 const observed=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-class-prerequisite-observations.json',import.meta.url)));
 assert.equal(observed.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.ok(observed.rows.length>1000);
 for(const {case:c,result}of observed.rows){const p={race:c.race,hasFeat:id=>Number(c.feats.includes(id)),skillRank:id=>c.skills[id]??0,baseAttackBonus:c.bab,baseSave:id=>c.saves[id-1],classes:c.classes,getInt:name=>c.locals[name]??0};assert.equal(Number(meetsClassPrerequisites(c.requirements,p)),result,JSON.stringify(c));}
});
test('a prerequisite table does not exclude otherwise eligible starting classes',()=>{
 const rules={racialtypes:table([{PlayerRace:1,FeatsTable:'race'}]),classes:table([{PlayerClass:1,PreReqTable:'exclude',Package:4},{PlayerClass:1,PreReqTable:'require'},{PlayerClass:1,EpicLevel:0}]),creationTables:new Map([['race',table([])]]),classTables:new Map([['exclude',table([{ReqType:'CLASSNOT',ReqParam1:'199'}])],['require',table([{ReqType:'CLASSOR',ReqParam1:'199'}])]])};
 const d=initialCreationDraft(rules);assert.equal(d.classId,0);assert.equal(d.packageId,4);assert.equal(creationClassRequirement(d,rules,0),null);assert.match(creationClassRequirement(d,rules,1),/prerequisites/);assert.match(creationClassRequirement(d,rules,2),/epic/);assert.match(creationClassRequirement(d,rules,-1),/not player-selectable/);
});
test('spell choices handle an unselected or martial class and use a caster supplied column',()=>{
 const rules={classes:table([{SpellCaster:0},{SpellCaster:1,SpellTableColumn:'CustomColumn'}]),spells:table([{Name:1,CustomColumn:0},{Name:2,CustomColumn:1}])};assert.deepEqual(creationSpellOptions({classId:-1},rules,0),[]);assert.deepEqual(creationSpellOptions({classId:0},rules,0),[]);assert.deepEqual(creationSpellOptions({classId:1},rules,1).map(s=>s.id),[1]);
});
