import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {materializeLight,materializeArmor,materializeEnhancement,materializeDamage,materializeAbility,materializeRegeneration,materializeFreeAction,materializeSkill,materializeMitigation,itemPropertyMaterializers,applyEquippedPropertyList,removeEquippedPropertyList} from '../src/item_property_materializers.js';
import {applyLightEffect} from '../src/visual_effect.js';
import {EffectRuntime} from '../src/effect_runtime.js';

test('armor, enhancement, damage and ability materializers match original constructors, copies, queries and application order',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-property-materializer-observations.json',import.meta.url))),armor=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-ac-materializer-observations.json',import.meta.url))),light=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-light-observations.json',import.meta.url)));
 assert.equal(data.rows.length,658);assert.equal(armor.rows.length,151);assert.equal(light.rows.length,378);
 const regeneration=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-regeneration-observations.json',import.meta.url)));assert.equal(regeneration.rows.length,72);
 const polymorph=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-polymorph-item-property-observations.json',import.meta.url)));assert.equal(polymorph.rows.length,984);
 const immunities=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-form-immunity-observations.json',import.meta.url)));assert.equal(immunities.rows.length,1970);
 const saves=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-form-save-attack-observations.json',import.meta.url)));assert.equal(saves.rows.length,4268);
 const kinds=new Set([...immunities.rows,...saves.rows].map(r=>r.case.kind));
 for(const row of [...data.rows,...armor.rows,...light.rows,...regeneration.rows,...polymorph.rows,...immunities.rows,...saves.rows]){
  const c=row.case,trace=[],item={id:123,baseItem:c.baseItem??22},property={type:c.type??6,subtype:c.subtype??0,costTable:c.costTable??0,costValue:c.costValue??1,param1Value:c.param1Value??5};let next=100n;
  const p={base:i=>{trace.push(['base',i.baseItem|0]);return{weaponWield:c.wield??0,acEnchant:c.acEnchant??3};},
   has:(_i,type,subtype)=>{trace.push(['has',type,subtype]);return c.has??1;},
   create:()=>{trace.push(['ctor',1]);return{id:(next++).toString(16).padStart(16,'0'),type:0,durationType:0,exposed:1,showIcon:1,creatorId:0x7f000000,spellId:-1,casterLevel:-1,propertyId:'0000000000000000',integers:Array(8).fill(0)};},
   copy:(e,mode)=>{const copy=structuredClone(e);if(mode==='assign'){trace.push(['ctor',0],['copyAssign',0]);}else{trace.push(['copyCtor',0]);copy.type=0;copy.exposed=0;copy.showIcon=0;copy.integers.fill(0);}return copy;},
   saveElements:()=>c.saveTable?{name:'saveElements'}:null,hasStats:()=>!c.noStats,feats:()=>({name:'feats'}),melee:()=>({name:'melee'}),cost:id=>{trace.push(['cost',id]);return kinds.has(c.kind)?c.noTable?null:{name:'armor'}:id===1?{name:'ability'}:[2,6,7].includes(id)?{name:'armor'}:c.noDamageTable?null:{name:'damage'};},count:()=>c.damageRows?.length??4,
   int:(table,index,column)=>{let value=c.value??3,status=c.status??1;if(table.name==='damage'){const pair=(c.damageRows??[[0,3],[0,6],[1,7],[0,7]])[index];value=pair[column==='NumDice'?0:1];status=c.damageStatus??1;}else if(table.name==='saveElements'){value=c.saveValue??22;status=c.saveStatus??1;}trace.push(['int',table.name,index,column,status,value]);return{status,value};},
   creator:(e,id)=>{trace.push(['creator',id]);e.creatorId=id;e.casterLevel=0;},damageFlags:()=>{trace.push(['damageFlags']);return c.damageFlags??4;},
   apply:(_o,e,loading,flag)=>trace.push(['apply',structuredClone(e),loading>>>0,flag>>>0]),release:e=>trace.push(['release',structuredClone(e)]),warning:kind=>trace.push(['warning',kind])};
  const fn=kinds.has(c.kind)?itemPropertyMaterializers.get(property.type):({freeAction:materializeFreeAction,skill:materializeSkill,reduction:materializeMitigation,resistance:materializeMitigation,regeneration:materializeRegeneration,light:materializeLight,armor:materializeArmor,enhancement:materializeEnhancement,damage:materializeDamage,ability:materializeAbility})[c.kind];
  const result=await fn(item,property,{},c.slot??16,c.loading??0,p);
  assert.deepEqual({result,trace,nextId:next.toString(16).padStart(16,'0')},{result:row.result,trace:row.trace,nextId:row.nextId},JSON.stringify(c));
 }
});

test('light apply owner matches18 original executions with actual native copy-constructor output',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-light-observations.json',import.meta.url)));assert.equal(data.effects.length,18);
 for(const row of data.effects){const c=row.case,trace=[],owner={},source={...structuredClone(row.source),floats:Array(4).fill(0),vectors:[[0,0,0],[0,0,0]],objectIds:Array(4).fill(0x7f000000),customTag:''};
  const result=await applyLightEffect(owner,source,{asCreature:()=>{trace.push(['creature']);return c.creature?owner:null;},copyConstruct:e=>{trace.push(['copyCtor',0]);return EffectRuntime.prototype.copyConstruct(e);},apply:(_o,e,loading,flag)=>{const snapshot=Object.fromEntries(Object.keys(row.source).map(key=>[key,key==='exposed'?Number(e.exposed):e[key]]));trace.push(['apply',snapshot,loading,flag]);}},c.loading);
  // The native GetInteger helper is captured; JS reads the data array
  // directly. Compare all instrumented callbacks and the full child payload.
  const expected=row.trace.filter(entry=>entry[0]!=='integer');
  assert.deepEqual({result,trace},{result:row.result,trace:expected},JSON.stringify(c));
 }
});

test('equipped apply/remove traversal matches96 original runs with callback pool mutation',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-equipped-property-traversal-observations.json',import.meta.url)));assert.equal(data.rows.length,96);
 for(const row of data.rows){
  const c=row.case,trace=[];let pool=[...c.pool],calls=0;
  const callback=(kind,property,slot,loading)=>{trace.push([kind,property,slot,...(kind==='apply'?[loading]:[])]);if(++calls===c.mutateAt)pool=[...c.after];};
  const p={ai:()=>{trace.push(['ai']);return c.ai?{}:null;},count:()=>pool.length,property:(_i,n)=>pool[n],apply:(_ai,_i,property,_o,slot,loading)=>callback('apply',property,slot,loading),remove:(_ai,_i,property,_o,slot)=>callback('remove',property,slot),removeCreator:(_o,id)=>trace.push(['removeCreator',id])};
  if(c.kind==='apply')await applyEquippedPropertyList({id:123},{},c.slot,c.loading,p);else await removeEquippedPropertyList({id:123},{},c.slot,p);
  assert.deepEqual({trace,pool},{trace:row.trace,pool:row.pool},JSON.stringify(c));
 }
});
