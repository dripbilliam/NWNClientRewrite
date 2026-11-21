import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadPlaceableData} from '../src/placeable_template.js';
import {ModuleSession} from '../src/module_session.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-placeable-template-observations.json',import.meta.url)));
const canonical=value=>JSON.parse(JSON.stringify(value));
const widths={0x3a8:1,0x3b8:1,0x3b0:1,0x3d0:1,0x32c:2,0x370:1,0x4e0:1,0x4e1:1,0x4e2:1,0x3a9:1,0x59c:1};
const assigned=value=>value.startsWith('\0')?'':value;

test('full placeable loader matches original defaults, widths, script fallback, animation, inventory and tail order',async()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],fields=Object.fromEntries(Object.keys(row.fields).map(k=>[k,widths[k]===1?(c.initial?.[k]??0)&255:widths[k]===2?(c.initial?.[k]??0)&65535:(c.initial?.[k]??0)|0])),o={id:99,fields,strings:{},resrefs:{}};
  const read=(kind,name,fallback)=>{calls.push(['read',kind,name,fallback]);const r=c.fields?.[name]??{status:0,value:fallback};return{...r,value:kind==='resref'?r.value.slice(0,16).split('\0')[0]:r.value};};
  const result=await loadPlaceableData(o,c.loading??0,c.tag??null,{
   read,field:(obj,k,value,width)=>{assert.equal(obj,o);if(value===undefined)return fields[k];fields[k]=width===1?value&255:width===2?value&65535:value|0;},
   asTag:value=>{calls.push(['asTag',value]);return value;},
   setTag:(obj,value)=>{obj.tag=value;calls.push(['tag',value]);},
   setTemplate:(obj,value)=>{obj.template=value;calls.push(['template',value]);},
   localized:(obj,k,value)=>calls.push(['localized',k,value]),
   string:(obj,k,value)=>{obj.strings[k]=assigned(value);calls.push(['string',k,assigned(value)]);},
   resref:(obj,k,value)=>{if(value===undefined)return obj.resrefs[k];obj.resrefs[k]=value;calls.push(['resref',k,value]);},
   getScript:(obj,k)=>{calls.push(['getScript',k]);return c.scriptNull?null:obj.strings[0x480];},
   portraitId:(obj,value)=>calls.push(['portraitId',value]),portrait:(obj,value)=>calls.push(['portrait',value]),
   light:obj=>{calls.push(['light']);return c.lightResult??fields[0x594];},
   lightColor:(...args)=>{calls.push(['lightColor',...args]);return c.lightColor??{status:0,value:0};},
   trapScript:(...args)=>{calls.push(['trapScript',...args]);return c.trapScript??'';},
   animation:(obj,value)=>calls.push(['animation',value]),
   list:name=>{calls.push(['list',name]);return{status:c.listStatus??0};},
   count:()=>{calls.push(['count']);return c.items?.length??0;},element:(_list,index)=>{calls.push(['element',index]);return index;},
   readItem:(index,...args)=>{calls.push(['readItem',index,...args]);return c.items[index].fields?.[args[1]]??{status:0,value:args[2]};},
   newItem:id=>{calls.push(['newItem',id]);const index=calls.filter(c=>c[0]==='newItem').length-1;return c.items[index].allocationFail?null:{index};},
   loadItem:(item,index,...args)=>{calls.push(['loadItem',item.index,index,...args]);return c.items[index].loadResult??1;},
   destroyItem:(item,flag)=>calls.push(['destroyItem',item.index,flag]),
   acquire:(obj,ref,...args)=>{calls.push(['acquire',ref.item.index,...args]);return c.acquireResult??1;},
   visual:(obj,owner)=>calls.push(['visual',owner]),loadUUID:()=>{calls.push(['uuid']);return c.uuidResult??0;},
   addTag:obj=>calls.push(['addTag',assigned(obj.tag),obj.id]),
  });
  const label=JSON.stringify(c);assert.equal(result,row.result,label);assert.deepEqual(canonical(calls),row.calls,label);assert.deepEqual(fields,row.fields,label);
 }
 assert.equal(native.rows.length,431);
});

test('placeable field bridge keeps injured current HP separate from maximum HP',()=>{
 const s=new ModuleSession(null),o=s.register('placeable','unequal-hp',{authored:{HP:99,CurrentHP:98}});
 s.lifecycle.bodyBagField(o,0xe4,31,4);s.lifecycle.bodyBagField(o,0xe0,7,4);
 assert.equal(s.hitPoints(o.id,true),31);assert.equal(s.hitPoints(o.id,false),7);
 assert.equal(o.authored.HP,31);assert.equal(o.authored.CurrentHP,7);
 s.lifecycle.bodyBagField(o,0xe0,-3,4);
 assert.equal(s.hitPoints(o.id,true),31);assert.equal(s.hitPoints(o.id,false),-3);
 assert.equal(o.nativeMessageFields[0xe4],31);assert.equal(o.nativeMessageFields[0xe0],-3);
});
