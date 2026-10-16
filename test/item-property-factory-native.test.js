import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createItemProperty,bindItemPropertyFactory} from '../src/item_property_factory.js';

test('shared item-property factory matches original selector, integers and active-table query order',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-item-property-factory-observations.json',import.meta.url)));
 assert.equal(data.rows.length,1262);
 const defaults={definition:{CostTableResRef:[1,3],Param1ResRef:[1,0],SubTypeResRef:[1,'subtype']},subtype:{Name:[1,1],Param1ResRef:[1,0]},cost:{Name:[1,1]},IPRP_PARAMTABLE:{TableResRef:[1,'param']},param:{}};
 for(const row of data.rows){
  const c=row.case,trace=[],table=name=>({name,count:c.counts?.[name]??16}),query=(kind,t,index,column)=>{
   const [status,value]=c.queries?.[t.name]?.[column]??defaults[t.name][column]??[0,kind==='string'?'':0];trace.push([kind,t.name,index,column,status,value]);return{status,value};
  };
  const effect=await createItemProperty(c.ordinal,c.args,99,{create:(type,id,integers)=>{trace.push(['creator',id]);return{type,durationType:0,integers};},definition:()=>table('definition'),
   int:(...args)=>query('int',...args),string:(...args)=>query('string',...args),
   table:name=>{const found=Object.hasOwn(defaults,name)&&!c.missing?.includes(name);trace.push(['table',name,found]);return found?table(name):null;},
   cost:id=>{const found=!c.missing?.includes('cost');trace.push(['cost',id,found]);return found?table('cost'):null;}});
  assert.deepEqual({type:effect.type,durationType:effect.durationType,integers:effect.integers,trace},{type:row.type,durationType:row.durationType,integers:row.integers,trace:row.trace},JSON.stringify(c));
 }
});

test('all79 installed constructors bind and match237 original executions with active-table inputs',async()=>{
 const load=name=>JSON.parse(fs.readFileSync(new URL(`../backups/animations/${name}.json`,import.meta.url))),live=load('live-item-property-factory'),native=load('native-live-item-property-factory-observations');
 assert.equal(live.rows.length,237);assert.equal(native.rows.length,237);assert.equal(live.constructors,79);assert.ok(live.valid>0);assert.ok(live.invalid>0);
 for(const [index,row]of live.rows.entries()){
  let cursor=0;const c=row.case,p={create:(type,id,integers)=>{assert.equal(id,c.creator);return{type,durationType:0,integers};},definition:()=>({name:'definition'})},consume=request=>{
   const entry=c.replay[cursor++];for(const [key,value]of Object.entries(request))assert.deepEqual(entry[key],value,JSON.stringify({name:row.name,args:c.args,request}));return entry;
  };
  for(const kind of ['int','string'])p[kind]=(table,row,column)=>{const entry=consume({kind,table:table.name,row,column});return{status:entry.status,value:entry.value};};
  p.table=name=>consume({kind:'table',name}).result;p.cost=id=>consume({kind:'cost',id}).result;
  const session={commands:{},items:{propertyFactoryProviders:()=>p}};bindItemPropertyFactory(session,[{id:c.ordinal,name:row.name,returns:'itemproperty'}]);
  const result=await session.commands[row.name](c.args,{self:c.creator}),actual={type:result.type,durationType:result.durationType,integers:result.integers},expected={type:row.type,durationType:row.durationType,integers:row.integers};
  assert.deepEqual(actual,expected);assert.deepEqual(actual,{type:native.rows[index].type,durationType:native.rows[index].durationType,integers:native.rows[index].integers});assert.equal(cursor,c.replay.length);assert.equal(native.rows[index].result,0);assert.deepEqual(native.rows[index].trace.slice(1),c.replay);
 }
 const audit=load('spell-ecosystem-active-audit-v18');assert.equal(audit.unboundCommands.filter(c=>c.name.startsWith('ItemProperty')).length,0);
});
