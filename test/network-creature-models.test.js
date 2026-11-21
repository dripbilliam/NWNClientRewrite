import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {networkCreatureModelPlan,nativeHelmetAttachment,relayRobeAnimation} from '../src/network_creature_models.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-robe-part-plan-v1.json',import.meta.url)));
function fixture(robe=3){
 const parts=Array(18).fill(7).concat(robe),colors=[10,20,30,40,50,60],partColors=Array.from({length:19},()=>Array(6).fill(255));
 const item={modelType:3,parts,colors,partColors},object={id:2,objectType:5,replicated:{stats:{racialType:3}},appearance:{appearance:3,head:20,gender:0,phenotype:0,skin:8,hair:9,tattoo1:10,tattoo2:11,bodyParts:[],equipment:[{slot:2,item}]}};
 const columns=['COSTMODIFIER','ACBONUS',...Array.from({length:18},(_,i)=>'HIDE'+i)];
 const tables={appearance:{rows:new Map([[3,{MODELTYPE:'P',RACE:'A'}]])},racialtypes:{rows:new Map([[3,{Appearance:'3'}]])},gender:{rows:new Map([[0,{GENDER:'M'}]])},phenotype:{rows:new Map([[0,{DefaultPhenoType:'0'}]])},
  capart:{rows:new Map(Array.from({length:19},(_,i)=>[i,{MDLNAME:'PART'+i,NODENAME:'ANCHOR'+i}]))},parts_robe:{columns,rows:new Map([[robe,Object.fromEntries(columns.map(c=>[c,'0']))]])}};
 return{object,tables,item};
}
test('912 original robe branch cases match model admission and active numbered hide rules',()=>{
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.visibility.length,912);
 for(const row of oracle.visibility){const f=fixture(row.robe),column=f.tables.parts_robe.columns[row.index+2];if(column)f.tables.parts_robe.rows.get(row.robe)[column]=row.found?String(row.hide):'****';
  const before=structuredClone(f.object),plan=networkCreatureModelPlan(f.object,f.tables),part=plan.parts.find(p=>p.partIndex===row.index);
  assert.equal(Boolean(part),!row.absent&&row.part!==0,JSON.stringify(row));assert.deepEqual(f.object,before);
  if(part){assert.equal(part.node,row.index===18?null:'ANCHOR'+row.index);assert.equal(part.nativeVisualScope,row.index===18?18:undefined);}
 }
});
test('152 native palette rows match six per-part overrides, 255 fallback and skin/hair/tattoo preservation',()=>{
 assert.equal(oracle.palettes.length*19,152);
 for(const row of oracle.palettes){const f=fixture();f.item.colors=row.base;f.item.partColors=row.overrides;Object.assign(f.object.appearance,{skin:row.skin,hair:row.hair,tattoo1:row.tattoo1,tattoo2:row.tattoo2});
  const plan=networkCreatureModelPlan(f.object,f.tables);
  for(const part of plan.parts.filter(p=>p.partIndex!==undefined))assert.deepEqual(part.paletteColors,row.palettes[part.partIndex].map(v=>v&255));
  const other=fixture(),otherPlan=networkCreatureModelPlan(other.object,other.tables);assert.notDeepEqual(plan.parts.at(-1).paletteColors,otherPlan.parts.at(-1).paletteColors);
 }
});
test('server CAPart names/anchors, phenotype fallback and absent robe rules are owned by each plan',()=>{
 const f=fixture();f.object.appearance.phenotype=3;f.tables.phenotype.rows.set(3,{DefaultPhenoType:'2'});f.tables.capart.rows.set(18,{MDLNAME:'ROBE',NODENAME:'root'});
 const robe=networkCreatureModelPlan(f.object,f.tables).parts.find(p=>p.partIndex===18);assert.equal(robe.model,'pma3_robe003');assert.equal(robe.fallbackModel,'pma2_robe003');
 f.tables.parts_robe.rows.clear();assert.deepEqual(networkCreatureModelPlan(f.object,f.tables).parts.map(p=>p.partIndex),[undefined,18]);
 f.tables.capart.rows.delete(18);assert.throws(()=>networkCreatureModelPlan(f.object,f.tables),/CAPart/);
});
test('robe receives playback requests and keeps its own animator; disposal restores the source',()=>{
 const calls=[],play=function(name,options){calls.push(['body',name,options]);return name!=='absent';},source={play,clip:{name:'pause1'},loop:true},robe={play:(name,options)=>{calls.push(['robe',name,options]);return true;}};
 const dispose=relayRobeAnimation(source,robe),complete=()=>{};source.play('walk',{loop:true,onComplete:complete});source.play('absent',{loop:false});
 assert.deepEqual(calls.map(c=>c.slice(0,2)),[['robe','pause1'],['body','walk'],['robe','walk'],['body','absent']]);assert.equal(calls[2][2].onComplete,null);assert.equal(calls[1][2].onComplete,complete);dispose();assert.equal(source.play,play);
});
test('equipped helmets replace the bare head and use gendered appearance scales without altering canonical slots',()=>{
 const f=fixture();f.tables.appearance.columns=['HELMET_SCALE_M','HELMET_SCALE_F'];f.tables.appearance.orderedRows=Array(4);f.tables.appearance.orderedRows[3]=f.tables.appearance.rows.get(3);f.tables.appearance.rows.get(3).HELMET_SCALE_M='0.75';f.tables.appearance.rows.get(3).HELMET_SCALE_F='1.125';
 assert.equal(nativeHelmetAttachment(f.object,f.tables),null);const head={id:91,slot:1,item:{baseItem:35}};f.object.appearance.equipment.push(head);
 assert.equal(networkCreatureModelPlan(f.object,f.tables).parts.some(p=>p.node==='head_g'),false);
 assert.deepEqual(nativeHelmetAttachment(f.object,f.tables),{itemId:91,anchor:'head_g',scale:.75,kind:'helmet'});
 f.object.appearance.gender=1;assert.equal(nativeHelmetAttachment(f.object,f.tables).scale,1.125);
 f.tables.appearance.rows.get(3).HELMET_SCALE_F='0';assert.equal(nativeHelmetAttachment(f.object,f.tables).scale,0);
 delete f.tables.appearance.rows.get(3).HELMET_SCALE_F;assert.equal(nativeHelmetAttachment(f.object,f.tables).scale,1);
 assert.equal(f.object.appearance.equipment.at(-1),head);
 f.object.appearance.equipment.pop();f.object.appearance.gender=0;assert.equal(networkCreatureModelPlan(f.object,f.tables).parts.some(p=>p.node==='head_g'),true);
});
