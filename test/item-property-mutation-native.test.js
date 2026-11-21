import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptAddItemProperty,scriptRemoveItemProperty,itemPropertyApplied,removeItemProperty,materializeItemProperty,dematerializeItemProperty} from '../src/item_property_mutation.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {itemPropertyApplyHandlers,itemPropertyRemoveHandlers} from '../src/item_property_handlers.js';

test('item-property commands match original duration flags, ILR ordering and duplicate-ID hide/event behavior',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-property-command-observations.json',import.meta.url)));
 assert.equal(data.rows.length,452);
 for(const row of data.rows){
  const c=row.case,trace=[],effect={id:'1000000000000001',durationType:c.flags??0xabca,duration:17,spellId:c.spell??419},object={possessorId:55,effects:(c.ids??[]).map((id,i)=>({id,exposed:i+1}))},owner={};
  const p={object:id=>{trace.push(['object',id]);return c.present!==false&&(c.status??0)===0?object:null;},asItem:o=>{trace.push(['asItem']);return c.item!==false?o:null;},release:()=>trace.push(['release']),
   apply:(_o,e,a,b)=>trace.push(['apply',e.durationType,e.duration,a,b]),ilrSetting:()=>{trace.push(['ilr']);return c.ilr??1;},creature:id=>{trace.push(['creature',id]);return c.owner===false?null:owner;},
   hasStats:()=>c.stats!==false,equipmentLocked:()=>c.locked??0,slot:()=>{trace.push(['slot']);return c.slot??16;},level:()=>{trace.push(['level']);return c.level??1;},minimumLevel:()=>{trace.push(['minimum']);return c.minimum??2;},
   unequip:(_o,_i,a,b)=>trace.push(['unequip',a,b]),repositoryAdd:(_o,_ref,...args)=>trace.push(['repositoryAdd',...args]),event:(id,caller,target,time,e)=>trace.push(['event',id,caller,target,0,time,object.effects.indexOf(e)])};
  if(c.kind==='add')await scriptAddItemProperty(c.duration,effect,123,c.seconds??2.5,p);else await scriptRemoveItemProperty(123,c.null?null:effect,99,p);
  assert.deepEqual({trace,durationType:effect.durationType,seconds:effect.duration,exposed:object.effects.map(e=>Number(e.exposed))},{trace:row.trace,durationType:row.durationType,seconds:row.seconds,exposed:row.exposed},JSON.stringify(c));assert.equal(row.result,0);
 }
});

test('original pool removal and post-application callbacks retain active/passive matching and live owner order',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-property-pool-mutation-observations.json',import.meta.url)));
 assert.equal(data.rows.length,980);
 for(const row of data.rows){
  const c=row.case,trace=[],original=c.properties.map(p=>p?{...p,type:p.type&65535,durationType:p.durationType&255,subtype:p.subtype&65535,costTable:p.costTable&255,costValue:p.costValue&65535,param1:p.param1&255,param1Value:p.param1Value&255,usesPerDay:p.usesPerDay&255,chance:p.chance&255}:null),pool=[...original],item={objectType:6,possessorId:c.possessed===false?OBJECT_INVALID:55,nativePriceDirty398:0,nativeRepository:c.repository?{}:null,activeProperties:pool,passiveProperties:pool},owner={},ai={},effect={integers:c.integers,durationType:c.duration};
  const p={weight:()=>trace.push(['weight']),creature:id=>{trace.push(['creature',id]);return c.owner===false?null:owner;},equipped:()=>{trace.push(['equipped']);return c.equipped??1;},ai:()=>{trace.push(['ai']);return c.ai===false?null:ai;},slot:()=>{trace.push(['slot']);return 16;},
   applyProperty:(_ai,_i,prop,_o,slot,flag)=>trace.push(['applyProperty',original.indexOf(prop),slot,flag]),removeProperty:(_ai,_i,prop,_o,slot)=>trace.push(['removeProperty',prop?original.indexOf(prop):null,slot]),combatInformation:()=>trace.push(['combatInformation']),
   contentsWeight:()=>trace.push(['contentsWeight']),encumbrance:(_o,flag)=>trace.push(['encumbrance',flag]),visual:()=>trace.push(['visual']),activeChanged:(_i,flag)=>trace.push(['activeChanged',flag]),
   removeActive:(_i,index)=>{trace.push(['removeActive',index]);pool.splice(index,1);},removePassive:(_i,index)=>{trace.push(['removePassive',index]);pool.splice(index,1);}};
  let result=null;if(c.kind==='post')await itemPropertyApplied(item,original[0],effect,p);else result=await removeItemProperty(item,effect,p);
  assert.deepEqual({result,trace,remaining:pool.map(prop=>original.indexOf(prop)),priceDirty:item.nativePriceDirty398},{result:row.result,trace:row.trace,remaining:row.remaining,priceDirty:row.priceDirty},JSON.stringify(c));
 }
});

test('pointer snapshots and property-ID linkage match102 original wrapper executions',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-property-effect-linkage-observations.json',import.meta.url)));assert.equal(data.rows.length,102);
 for(const row of data.rows){
  const c=row.case,effects=structuredClone(c.effects),owner={effects:c.before.map(i=>effects[i])},item={id:123},property=c.null?null:{type:c.type,propertyId:c.propertyId},trace=[];
  if(c.kind==='apply')await materializeItemProperty({},item,property,owner,16,0,{handler:()=>c.enabled?(_item,_property,o,slot,loading)=>{trace.push(['apply',slot,loading]);o.effects=c.after.map(i=>effects[i]);}:null,warning:kind=>trace.push(['warning',kind])});
  else{
   const result=await dematerializeItemProperty(item,property,owner,16,{remove:(o,e)=>{trace.push(['remove',effects.indexOf(e)]);const i=o.effects.indexOf(e);if(i>=0)o.effects.splice(i,1);},handler:()=>c.enabled?(_item,_property,_o,slot)=>{trace.push(['customRemove',slot]);return 7;}:null});assert.equal(result,row.result);
  }
  assert.deepEqual({trace,after:owner.effects.map(e=>effects.indexOf(e)),propertyIds:effects.map(e=>e.propertyId)},{trace:row.trace,after:row.after,propertyIds:row.propertyIds},JSON.stringify({kind:c.kind,n:c.before.length,type:c.type,enabled:c.enabled}));
 }
});

test('property handler map matches both88-entry original initialization tables',()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-property-handler-map.json',import.meta.url)));assert.equal(data.rows.length,88);
 for(const row of data.rows){assert.equal(itemPropertyApplyHandlers.get(row.type)??'0',row.apply);assert.equal(itemPropertyRemoveHandlers.get(row.type)??'0',row.remove);}
});

test('installed repository item supports API add/query, hidden queued removal and strict lifetime expiry',()=>{
 const report=JSON.parse(fs.readFileSync(new URL('../backups/animations/live-item-property-mutation.json',import.meta.url)));
 for(const key of ['explicitRemoval','exposureHiddenBeforeRemoval','exactExpiryRetained','afterExpiryRemoved','canonicalOwnerPreserved'])assert.equal(report[key],true,key);
 assert.equal(report.unsupportedChangesDoNotLeakProperties,true);assert.equal(report.expectedUnsupported.length,2);
 assert.equal(report.eventId,14);assert.deepEqual(report.errors,[]);assert.match(report.limits,/Unworn item/);
});
