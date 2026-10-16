import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptUseItem} from '../src/script_use_item.js';
import {ModuleSession} from '../src/module_session.js';
import {NwScriptVm} from '../src/nwscript_vm.js';
import {RuntimeDiagnostics} from '../src/runtime_diagnostics.js';
const oracle=()=>JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-use-item-observations.json',import.meta.url)));
test('script item use matches full original property ID scan, narrowing, current actor area, null point and cleanup',async()=>{
 for(const row of oracle().rows){
  const c=row.case,ordinal=c.ordinal??910,actor={id:99},item={},area={id:c.areaId??7},handle=c.nullProperty?null:{propertyId:c.propertyId??'0000000100000001'},location=c.location===false?null:{areaId:999,position:[4.5,6.25,-8.75]},
   ids=c.properties??['0000000000000001','0000000100000001','ffffffffffffffff'],values=[c.itemId??20,handle,...(ordinal===910?[c.targetId??100]:ordinal===911?[location]:[]),c.variant??0,c.consume??1],calls=[],pops=[],cleanup=[];let index=0;
  const p={pop:type=>{const i=index++;pops.push([type,i]);return{ok:i<(c.argc??5)&&i!==(c.failPop??-1),value:values[i]};},
   creature:id=>{calls.push(['creature',id]);return c.missingActor?null:actor;},item:id=>{calls.push(['item',id]);return c.missingItem?null:item;},
   activeCount:()=>c.count??ids.length,activeProperty:(_i,n)=>{calls.push(['property',n]);return{propertyId:ids[n]};},
   area:()=>{calls.push(['area']);return c.missingArea?null:area;},use:(_o,...args)=>{calls.push(['use',...args]);return c.useResult??1;},
   release:(type,value)=>{cleanup.push(['destroy',type,Boolean(value)],['delete',type,0]);}};
  const result=await scriptUseItem(ordinal,99,p);
  assert.deepEqual({result,pops,calls,cleanup},{result:row.result,pops:row.pops,calls:row.calls,cleanup:row.cleanup},JSON.stringify(c));
 }
});
const specs={910:{name:'ActionUseItemOnObject',returns:'void',args:[{type:'object'},{type:'itemproperty'},{type:'object'},{type:'int',optional:true},{type:'int',optional:true}]},911:{name:'ActionUseItemAtLocation',returns:'void',args:[{type:'object'},{type:'itemproperty'},{type:'location'},{type:'int',optional:true},{type:'int',optional:true}]}};
test('typed item commands share canonical runtime dispatch and preserve void result and passed property ID',async()=>{
 for(const ordinal of [910,911]){
  const s=new ModuleSession(null),actor=s.register('creature','actor',{}),item=s.register('item','item',{}),area=s.register('area','area',{});actor.areaId=area.id;item.activeProperties=[{propertyId:'0000000100000001'}];
  const calls=[];s.items.use=(...args)=>{calls.push(args);return 2;};const vm=new NwScriptVm({api:specs,command:name=>s.commands[name]}),frame={stack:[],self:actor.id,program:{name:'owned-item-script'}};
  const args=[item.id,{type:0,id:'ffffffffffffffff',propertyId:'0000000100000001'},ordinal===910?0xf1234567:{areaId:999,position:[1.25,2.5,-3.75]},258,-2];
  for(let i=4;i>=0;i--)vm.push(frame,specs[ordinal].args[i].type,args[i]);
  await vm.step(frame,{op:5,command:ordinal,argc:5,pc:13});assert.deepEqual(frame.stack,[]);assert.equal(calls.length,1);
  assert.deepEqual(calls[0],[actor,item.id,0,2,ordinal===910?0xf1234567:0x7f000000,ordinal===910?[0,0,0]:[1.25,2.5,-3.75],area.id,-2]);
  assert.equal(item.activeProperties[0].propertyId,'0000000100000001');
 }
});
test('malformed typed item call reports engine context after native ordered pop failure',async()=>{
 const s=new ModuleSession(null),diagnostics=new RuntimeDiagnostics(),vm=new NwScriptVm({api:specs,command:name=>s.commands[name],diagnostics}),program={name:'owned-item-malformed',instructions:new Map([[13,{op:5,command:910,argc:5,pc:13,next:14}],[14,{op:0x20,pc:14,next:15}]])};
 const stack=[{type:3,value:1},{type:3,value:0},{type:3,value:100},{type:0x14,value:{propertyId:'0000000000000001'}},{type:6,value:20}];
 await assert.rejects(vm.run(program,99,{situation:{pc:13,bp:0,stack}}),/Stack type mismatch/);
 const record=diagnostics.records.at(-1);assert.equal(record.code,'engine.failure');assert.equal(record.context.engineCall,'ActionUseItemOnObject');assert.equal(record.context.engineId,910);assert.equal(record.context.argumentCount,5);
});
