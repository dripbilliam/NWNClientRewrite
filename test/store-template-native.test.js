import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {loadStoreData} from '../src/store_template.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-store-template-observations.json',import.meta.url)));
test('complete store loader matches291 original executions of fields, nested import, sorting and acquisition order',async()=>{
 assert.equal(capture.rows.length,291);
 for(const expected of capture.rows){
  const c=expected.case,calls=[],fields={},types={0x398:[...c.initialNot??[]],0x3a8:[...c.initialOnly??[]]},names=new WeakMap(),items=new Map(),object={id:99};let current,tag;
  const register=(row,path)=>{names.set(row,path);for(const[name,list]of Object.entries(row.lists??{})){names.set(list,`${path}/${name}`);for(const[i,entry]of(list.rows??[]).entries())register(entry,`${path}/${name}[${i}]`);}};register(c,'root');
  const read=(row,kind,name,fallback)=>{calls.push(['read',names.get(row),kind,name,fallback]);return row.fields?.[name]??{status:0,value:fallback};};
  const list=(row,name)=>{calls.push(['list',names.get(row),name]);const value=row.lists?.[name];return{status:value?.status??Number(Boolean(value)),value};};
  const possession=(item,...args)=>calls.push(['possessor',item?names.get(item.row):null,...args]);
  const result=await loadStoreData(object,c.loading??0,c.tag??null,{
   read:(...args)=>read(c,...args),asTag:value=>{calls.push(['asTag',value]);return value;},setTag:(_o,value)=>{tag=value;calls.push(['tag',value]);},localized:(_o,offset,value)=>calls.push(['localized',offset,value]),field:(_o,offset,value)=>{fields[offset]=value|0;},
   list:name=>list(c,name),rowList:(row,name)=>list(row.value,name),count:handle=>{calls.push(['count',handle.value?names.get(handle.value):null]);return handle.value?.rows?.length??0;},
   element:(handle,index)=>{calls.push(['element',names.get(handle.value),index]);const value=handle.value.rows[index];current=value;return{status:value.elementStatus??1,value};},
   readRow:(row,...args)=>read(row.value,...args),arrayCount:(_o,offset)=>types[offset].length,appendType:(_o,offset,type)=>{calls.push(['appendType',offset,type]);types[offset].push(type);},string:(_o,offset,value)=>calls.push(['string',offset,value]),
   existing:id=>{calls.push(['existing',id]);return current.existing??false;},
   newItem:id=>{calls.push(['newItem',names.get(current),id]);if(current.allocationFail)return null;const item={row:current,infinite:7};items.set(names.get(current),item);return item;},
   loadItem:(item,row,loading,last)=>{calls.push(['loadItem',names.get(item.row),names.get(row.value),loading,last]);return item.row.loadResult??1;},destroyItem:(item,flag)=>calls.push(['destroyItem',names.get(item.row),flag]),itemField:(item,offset,value)=>{assert.equal(offset,0x444);item.infinite=value;},
   identified:(item,value)=>calls.push(['identified',names.get(item.row),value]),baseInfo:item=>{calls.push(['baseInfo',names.get(item.row)]);return{storePanel:item.row.panel??0,storePanelSort:item.row.sort??0};},price:(item,...args)=>{calls.push(['price',names.get(item.row),...args]);return item.row.price??0;},setPossessor:possession,
   acquire:(_o,ref,...args)=>{const row=ref.item.row;calls.push(['acquire',names.get(row),...args]);if(row.acquireMutation&&items.has(row.acquireMutation))ref.item=items.get(row.acquireMutation);return row.acquireResult??1;},
   warning:text=>calls.push(['warning',text]),addTag:()=>calls.push(['addTag',tag.startsWith('\0')?'':tag,99]),loadUUID:()=>calls.push(['uuid']),
  });
  const infinite=Object.fromEntries([...items].map(([name,item])=>[name,item.infinite]));
  assert.deepEqual({result,calls,fields,types,infinite},{result:expected.result,calls:expected.calls,fields:expected.fields,types:expected.types,infinite:expected.infinite},JSON.stringify(c));
 }
});
